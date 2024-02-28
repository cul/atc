# frozen_string_literal: true

class PathHashValidator < ActiveModel::Validator
  def validate(record)
    return if record.path_hash == Digest::SHA256.digest(record.path)

    record.errors.add :path_hash, 'path_hash does not match calculated value for path field'
  end
end
