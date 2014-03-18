#!/usr/bin/env ruby

require 'optparse'
require 'nokogiri'
require 'json'
require 'pygments.rb'
require 'pg'

require_relative 'parser.rb'

$options = {}
opt_parser = OptionParser.new do |opts|
	opts.banner = "Usage: sql-test.rb [options]"

	opts.on("-i", "--input FILE", "Mapnik XML style file") do |v|
		$options[:input] = v
	end

	opts.on("--[no-]color", "Colorize json output") do |v|
		$options[:color] = v
	end
end

opt_parser.parse!

if $options[:input].nil? then
	$stderr.puts opt_parser.help
	exit 1
end

f = File.open($options[:input])
doc = Nokogiri::XML(f)
f.close

def to_text(node)
	if node.nil? then
		nil
	else
		node.text
	end
end

def print_json(obj)
	json = JSON.pretty_generate(obj)
	if $options[:color] then
		puts Pygments.highlight(json,
							:formatter => 'terminal',
							:lexer => 'javascript',
							:options => {:encoding => 'utf-8'}
						)
	else
		puts json
	end
end

def apply_filter(filter, row)
	lval = row[filter[:field]]
	rval = filter[:val]
	case filter[:cond]
	when '!='
		return lval != rval
	when '='
		return lval == rval
	when '&lt;='
		return lval <= rval
	when '&gt;='
		return lval >= rval
	when '&gt;'
		return lval > rval
	when '&lt;'
		return lval < rval
	else
		return false
	end
end

def apply_expression(expr, row)
	fres = apply_filter(expr[:filter], row)
	if expr[:next] then
		case expr[:next][:lop]
		when 'or'
			return fres || apply_expression(expr[:next], row)
		when 'and'
			return fres && apply_expression(expr[:next], row)
		else
			raise "Invalid lop #{expr[:next][:lop]}"
		end
	else
		return fres
	end
end

def filter_row(filters, row)
	filters.each { |filter|
		return true if apply_expression(filter, row)
	}
	false
end


data = []

doc.xpath('/Map/Layer').each { |layer|
	filters = []
	layer.xpath('./StyleName').each { |style|
		doc.xpath("/Map/Style[@name=\"#{style.child}\"]/Rule/Filter").each { |filter|
			begin
				tree = Parser.parse(filter.child.to_s)
				filters << tree.to_hash
			rescue Exception
				$stderr.puts "ERROR on #{filter.child}"
			end
		}
	}

	next if filters.empty?

	datasource = layer.xpath('./Datasource').first
	qtype = to_text(datasource.xpath('./Parameter[@name="type"]').first)

	next if qtype != 'postgis'

	qopts = {
		:host => to_text(datasource.xpath('./Parameter[@name="host"]').first),
		:user => to_text(datasource.xpath('./Parameter[@name="user"]').first),
		:password => to_text(datasource.xpath('./Parameter[@name="password"]').first),
		:dbname => to_text(datasource.xpath('./Parameter[@name="dbname"]').first)
	}
	query = to_text(datasource.xpath('./Parameter[@name="table"]').first)
	query = "SELECT * FROM #{query}"

	layer_data = {
		:name => layer['name'],
		:query => query
	}

	unnecessary_rows = []
	ts_before = Time.now
	begin
		conn = PGconn.open(qopts)
		res = conn.exec(query)
		res.each do |row|
			if filter_row(filters, row) then
				row['way'] = '...' if !row['way'].nil?
				unnecessary_rows << row
			end
		end
	rescue Exception => e
		$stderr.puts "[ERROR]: Postgresql #{e}"
	end
	ts_after = Time.now

	layer_data[:unnecessary_rows] = unnecessary_rows
	layer_data[:time] = ts_after - ts_before

	data << layer_data
}

print_json data
