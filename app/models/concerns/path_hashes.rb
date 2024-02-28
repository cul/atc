# frozen_string_literal: true

module PathHashes
  extend ActiveSupport::Concern

  included do
    before_validation :assign_path_hash
  end

  def assign_path_hash
    self.path_hash = Digest::SHA256.digest(self.path) # This is a binary digest
  end
end
