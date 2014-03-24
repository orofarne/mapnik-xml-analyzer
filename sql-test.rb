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

	opts.on("-p", "--[no-]progress", "Output progress information to stderr") do |v|
		$options[:progress] = v
	end

	opts.on("--[no-]color", "Colorize json output") do |v|
		$options[:color] = v
	end

	opts.on("--host HOST", "Override host option") do |v|
		$options[:host] = v
	end

	opts.on("--user USER", "Override user option") do |v|
		$options[:user] = v
	end

	opts.on("--password PASS", "Override password option") do |v|
		$options[:password] = v
	end

	opts.on("--dbname DBNAME", "Override dbname option") do |v|
		$options[:dbname] = v
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
		return true if filter[:all]
		return true if apply_expression(filter, row)
	}
	false
end


data = []

xml_layers = doc.xpath('/Map/Layer');
xml_layers_i = 0.0
xml_layers_count = xml_layers.size
$stderr.puts "#{xml_layers_count} layers found" if $options[:progress]

xml_layers.each { |layer|
	xml_layers_i += 1

	filters = []
	layer.xpath('./StyleName').each { |style|
		doc.xpath("/Map/Style[@name=\"#{style.child}\"]/Rule").each { |rule|
			all_data = true
			rule.xpath("./Filter").each { |filter|
				begin
					tree = Parser.parse(filter.child.to_s)
					filters << tree.to_hash
					all_data = false
				rescue Exception
					$stderr.puts "ERROR on #{filter.child}"
				end
			}
			filters << {:all => true} if all_data
		}
	}

	next if filters.empty?

	datasource = layer.xpath('./Datasource').first
	qtype = to_text(datasource.xpath('./Parameter[@name="type"]').first)

	next if qtype != 'postgis'

	qopts = {
		:host => $options[:host] || to_text(datasource.xpath('./Parameter[@name="host"]').first),
		:user => $options[:user] || to_text(datasource.xpath('./Parameter[@name="user"]').first),
		:password => $options[:password] || to_text(datasource.xpath('./Parameter[@name="password"]').first),
		:dbname => $options[:dbname] || to_text(datasource.xpath('./Parameter[@name="dbname"]').first)
	}
	query = to_text(datasource.xpath('./Parameter[@name="table"]').first)
	query = "SELECT * FROM #{query}"

	filters.uniq! { |f| f.to_json }

	layer_data = {
		:name => layer['name'],
		:query => query,
		:query_opts => qopts,
		:filters => filters
	}

	necessary_rows = []
	unnecessary_rows = []
	explain = ""
	ts_before = Time.now
	begin
		conn = PGconn.open(qopts)
		res = conn.exec(query)
		res.each do |row|
			row['way'] = '...' if !row['way'].nil?
			if filter_row(filters, row) then
				necessary_rows << row
			else
				unnecessary_rows << row
			end
		end
		explain_res = conn.exec("EXPLAIN ANALYZE #{query}")
		explain_res.each do |row|
			explain << "#{row['QUERY PLAN']}\n"
		end
	rescue Exception => e
		$stderr.puts "[ERROR]: Postgresql #{e}"
	end
	ts_after = Time.now

	layer_data[:necessary_rows] = necessary_rows
	layer_data[:unnecessary_rows] = unnecessary_rows
	layer_data[:query_explain] = explain
	layer_data[:time] = ts_after - ts_before

	data << layer_data

	$stderr.puts "  #{xml_layers_i / xml_layers_count * 100}% done" if $options[:progress]
}

print_json data
