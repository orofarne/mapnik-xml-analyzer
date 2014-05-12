#!/usr/bin/env ruby

require 'sinatra/base'
require 'optparse'

require_relative 'analyze.rb'
require_relative 'show.rb'

class App < Sinatra::Base
	configure :production, :development do
		set :haml, {:format => :html5, :attr_wrapper => '"'}
	end

	def self.set_data(data)
		$data = data
	end

	def self.set_options(options)
		$options = options
	end
end

$options = {}
opt_parser = OptionParser.new do |opts|
	opts.banner = "Usage: sql-test.rb [options]"

	opts.on("-i", "--input FILE", "Mapnik XML style file") do |v|
		$options[:input] = v
	end

	opts.on("-p", "--[no-]progress", "Output progress information to stderr") do |v|
		$options[:progress] = v
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

	opts.on("--bbox BBOX", "Operate in bbox, format ") do |v|
		$options[:bbox] = v
	end
end

opt_parser.parse!

if $options[:input].nil? then
	$stderr.puts opt_parser.help
	exit 1
end

$options[:title] = /[^\/]+$/.match($options[:input]).to_s

doc = Analyzer.parse $options

App.set_data doc
App.set_options $options

App.run!

