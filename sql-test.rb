#!/usr/bin/env ruby

require 'nokogiri'
require 'json'
require 'pygments.rb'
require 'pg'

require_relative 'parser.rb'

f = File.open(ARGV[0])
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
	puts Pygments.highlight(json,
							:formatter => 'terminal',
							:lexer => 'javascript',
							:options => {:encoding => 'utf-8'}
						)
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

doc.xpath('/Map/Layer').each { |layer|
	filters = []
	layer.xpath('./StyleName').each { |style|
		doc.xpath("/Map/Style[@name=\"#{style.child}\"]/Rule/Filter").each { |filter|
			begin
				tree = Parser.parse(filter.child.to_s)
				filters << tree.to_hash
			rescue Exception
				puts "ERROR on #{filter.child}"
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

	puts
	puts '=================='
	puts layer['name']
	puts '=================='
	puts

	puts query

	unnecessary_rows = []
	begin
		conn = PGconn.open(qopts)
		res = conn.exec(query)
		res.each do |row|
			unnecessary_rows << row if filter_row(filters, row)
		end
	rescue Exception => e
		puts "[ERROR]: Postgresql #{e}"
	end

	puts "Unnecessary rows:"
	puts
	print_json unnecessary_rows
	puts
}
