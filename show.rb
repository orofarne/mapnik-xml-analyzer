#!/usr/bin/env ruby

require 'json'
require 'sinatra'
require 'haml'
require 'pg'

require_relative 'analyze.rb'

class App < Sinatra::Base

get '/' do
	haml :index, :locals => {:data => $data, :title => $options[:title]}
end

get '/urows/:layer' do |layer|
	JSON.pretty_generate(
		$data.select { |l| l[:name] == layer }.first[:unnecessary_rows]
	)
end

get '/getsql/:layer' do |layer|
	data = $data.select { |l| l[:name] == layer }.first
	data[:query]
end

get '/details/:layer' do |layer|
	data = $data.select { |l| l[:name] == layer }.first
	haml :details, :locals => {:title => $options[:title], :layer => data}
end

get '/editsql/:layer' do |layer|
	data = $data.select { |l| l[:name] == layer }.first
	haml :editsql, :locals => {:title => $options[:title], :layer => data}
end

post '/checksql/:layer' do |layer|
	data = $data.select { |l| l[:name] == layer }.first

	query = request.body.read.to_s
	query = Analyzer.sub_bbox(query, $options[:bbox])

	qopts = {
		:host => data[:query_opts][:host],
		:user => data[:query_opts][:user],
		:password => data[:query_opts][:password],
		:dbname => data[:query_opts][:dbname]
	}

	necessary_rows = data[:necessary_rows].clone
	unnecessary_rows_count = 0
	begin
		conn = PGconn.open(qopts)
		res = conn.exec(query)
		res.each do |row|
			row['way'] = '...' if !row['way'].nil?
			i = necessary_rows.index { |r| r == row }
			if i.nil? then
				unnecessary_rows_count += 1
			else
				necessary_rows.delete_at i
			end
		end
	rescue Exception => e
		return "SQL ERROR: #{e}"
	end

	if necessary_rows.size > 0 then
		return "WARNING: #{necessary_rows.size} rows lost!"
	end

	if unnecessary_rows_count > 0 then
		return "#{unnecessary_rows_count} unnecessary rows"
	end

	'Ok'
end

post '/sqleditdone/:layer' do |layer|
	data = $data.select { |l| l[:name] == layer }.first

	query = request.body.read.to_s.force_encoding("UTF-8")

	haml :sqleditdone, :locals => {
		:layer => data,
		:new_query => query,
		:title => $options[:title]
	}, :layout => false
end

end
