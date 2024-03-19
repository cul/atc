# frozen_string_literal: true

module StoredObjectPathHashes
  extend ActiveSupport::Concern

  included do
    before_validation :assign_stored_object_path_hash
  end

  def assign_stored_object_path_hash
    self.stored_object_path_hash = self.stored_object_path.nil? ? nil : Digest::SHA256.digest(self.stored_object_path) # This is a binary digest
  end
end
