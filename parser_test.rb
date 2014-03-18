require 'test/unit'
require 'shoulda'

require_relative 'parser.rb'

class ParserTest < Test::Unit::TestCase
	context "Parse" do
		should "parse simple expression" do
			tree = Parser.parse("([amenity] = 'clinic')")
		end

		should "parse an expression" do
			Parser.parse("([leisure] = 'track') and ([area] != 'no')")
		end

		should "parse another expr" do
			Parser.parse("([leisure] = 'sports_centre') and ([building] != '')")
		end

		should "parse expression with empty value" do
			Parser.parse("([building] != '')")
		end

		should "parse expression with numeric value" do
			Parser.parse("([building] = 500)")
		end

		should "parse gt expression" do
			Parser.parse("([way_area] &gt; 5000)")
		end

		should "parse gt eq expression" do
			Parser.parse("([population] &gt;= 5000000)")
		end

	end
end
