class PathValidator < ActiveModel::Validator
	def validate(record)
		return unless record.changed_attributes.include? :path

		record.errors.add :path, "path cannot be updated after source creation"
	end
end
