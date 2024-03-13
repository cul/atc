# frozen_string_literal: true

# NOTE: This class will be going away.  It's only here temporarily during a data migration.
# After we're done with it, there will be a migration that calls `drop_table :checksums`.
class Checksum < ApplicationRecord
  belongs_to :checksum_algorithm
  belongs_to :source_object
  validates :value, presence: true
end
