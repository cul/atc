require 'rails_helper'

describe Checksum do
	let(:algorithm) { ChecksumAlgorithm.find_by(name: 'MD5') }
	let(:value) { 'unverifiedValue' }
	subject(:checksum) { described_class.create!(transfer_source: transfer_source, checksum_algorithm: algorithm, value: value) }
	context "no transfer source defined" do
		let(:transfer_source) { nil }
		it "fails" do
			expect { checksum }.to raise_error ActiveRecord::RecordInvalid
		end
	end
	context "transfer source defined" do
		let(:well_known_input) { 'example/path.txt' }
		let(:object_size) { 2048 } # any value fine for these tests
		let(:transfer_source) { TransferSource.create!(path: well_known_input, object_size: object_size) }
		it "works" do
			expect(checksum.value).to eql(value)
		end
		context "with a no-content checksum" do
			let(:value) { algorithm.empty_value }
			it "fails" do
				expect { checksum }.to raise_error ActiveRecord::RecordInvalid
			end
			context "and an empty transfer source" do
				let(:object_size) { 0 }
				it "works" do
					expect(checksum.value).to eql(value)
				end
			end
		end
	end
end