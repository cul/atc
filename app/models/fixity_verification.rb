# frozen_string_literal: true

class FixityVerification < ApplicationRecord
  belongs_to :source_object
  belongs_to :stored_object

  enum status: { pending: 0, failure: 1, success: 2 }
end
