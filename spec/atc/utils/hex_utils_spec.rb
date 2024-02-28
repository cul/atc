# frozen_string_literal: true

require 'rails_helper'

describe Atc::Utils::HexUtils do
  context '.unhex' do
    it 'unpacks hex data to binary string per mysql expectations' do
      expect(described_class.unhex('4D7953514C')).to eql 'MySQL'.b
    end
  end
end
