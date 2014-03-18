module Filter
	class Expr < Treetop::Runtime::SyntaxNode
		def to_hash
			res = {}
			res[:filter] = self.elements.select{ |elem| elem.instance_of?(Filt) }[0].to_hash
			rexpr = self.elements.select{ |elem| elem.instance_of?(ExprRight) }[0]
			res[:next] = rexpr.to_hash if !rexpr.nil?
			res
		end
	end

	class ExprRight < Treetop::Runtime::SyntaxNode
		def to_hash
			res = {}
			res[:filter] = self.elements.select{ |elem| elem.instance_of?(Filt) }[0].to_hash
			res[:lop] = self.elements.select{ |elem| elem.instance_of?(Lop) }[0].to_s
			rexpr = self.elements.select{ |elem| elem.instance_of?(ExprRight) }[0]
			res[:next] = rexpr.to_hash if !rexpr.nil?
			res
		end
	end


	class Lop < Treetop::Runtime::SyntaxNode
		def to_s
			self.text_value.to_s
		end
	end

	class Filt < Treetop::Runtime::SyntaxNode
		def to_hash
			fields = self.elements.select{ |elem| elem.instance_of? Field }
			conds = self.elements.select{ |elem| elem.instance_of? Cond }
			vals = self.elements.select{ |elem| elem.instance_of? ValueExt }
			{
				:field => fields[0].to_s,
				:cond => conds[0].to_s,
				:val => vals[0].to_s
			}
		end
	end

	class Field < Treetop::Runtime::SyntaxNode
		def to_s
			self.text_value.to_s
		end
	end

	class Cond < Treetop::Runtime::SyntaxNode
		def to_s
			self.text_value.to_s
		end
	end

	class ValueExt < Treetop::Runtime::SyntaxNode
		def to_s
			self.elements.select{ |elem| elem.instance_of? Value}[0].to_s
		end
	end

	class Value < Treetop::Runtime::SyntaxNode
		def to_s
			self.text_value.to_s
		end
	end
end
