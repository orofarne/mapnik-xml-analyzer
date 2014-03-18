require 'treetop'

class Parser
	@@base_path = File.expand_path(File.dirname(__FILE__))
	require File.join(@@base_path, 'node_extensions.rb')

	Treetop.load(File.join(@@base_path, 'f_parser.treetop'))
	@@parser = FilterParser.new

	def self.parse(data)
		# Pass the data over to the parser instance
		tree = @@parser.parse(data)
		# If the AST is nil then there was an error during parsing
		# we need to report a simple error message to help the user
		if(tree.nil?)
			raise Exception, "Parse error at offset #{@@parser.index}: #{@@parser.inspect}"
		end

		tree
	end
end


