module PathHashes
	extend ActiveSupport::Concern

	def path_hash!
		self.path_hash ||= begin
			raise "cannot compute hash on nil path" unless path
			self.class.binary_hash(path)
		end
	end

	module ClassMethods
		def unhex(value)
			return nil unless value =~ /^([0-9a-fA-F]{2})*$/
			value.scan(/../).map { |chunk| chunk.hex }.pack('c*')
		end

		def binary_hash(value)
			unhex Digest::SHA2.new(256).hexdigest(value)
		end
	end
end