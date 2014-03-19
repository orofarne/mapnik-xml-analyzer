#!/usr/bin/env ruby

require 'json'
require 'sinatra'
require 'haml'

configure :production, :development do
	$fin = ARGV[0]
	exit 1 if $fin.nil?
	puts "Reading data from #{$fin}..."
	f = File.open($fin)
	$data = JSON.load(f)
	f.close
	puts "done."
end

set :haml, {:format => :html5, :attr_wrapper => '"'}

get '/' do
	haml :index, :locals => {:data => $data, :title => $fin}
end

get '/urows/:layer' do |layer|
	JSON.pretty_generate(
		$data.select { |l| l['name'] == layer }.first['unnecessary_rows']
	)
end

get '/details/:layer' do |layer|
	data = $data.select { |l| l['name'] == layer }.first
	haml :details, :locals => {:title => $fin, :layer => data}
end
