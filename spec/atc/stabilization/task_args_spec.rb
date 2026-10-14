# frozen_string_literal: true

require 'rails_helper'

describe Atc::Stabilization::TaskArgs do
  include ActiveSupport::Testing::TimeHelpers

  let(:default_args) do
    {
      source_type: 'ldrive', source_path: '/existing-dir/subdir',
      repository_name: 'Starr', collection_name: 'Wango Weng Interview'
    }
  end
  let(:task_args) { build_task_args }

  before { travel_to(Time.zone.local(2026, 9, 1, 12, 15, 45)) }

  after { travel_back }

  def build_task_args(**overrides)
    described_class.new(**default_args.merge(overrides))
  end

  describe '.from_env' do
    it 'reads each argument from the environment' do
      args = described_class.from_env(
        'source_type' => 'ldrive', 'source_path' => '/existing-dir/subdir',
        'repository_name' => 'Starr', 'collection_name' => 'Wango Weng Interview'
      )
      expect(args).to have_attributes(
        source_type: 'ldrive', source_path: '/existing-dir/subdir',
        repository_name: 'Starr', collection_name: 'Wango Weng Interview'
      )
    end

    it 'reads the optional retain_stabilization_files flag from the environment' do
      args = described_class.from_env(
        'source_type' => 'ldrive', 'source_path' => '/existing-dir/subdir',
        'repository_name' => 'Starr', 'collection_name' => 'Wango Weng Interview',
        'retain_stabilization_files' => 'true'
      )
      expect(args.retain_stabilization_files?).to be(true)
    end

    it 'defaults the optional retain_stabilization_files flag to false when it is absent' do
      args = described_class.from_env(
        'source_type' => 'ldrive', 'source_path' => '/existing-dir/subdir',
        'repository_name' => 'Starr', 'collection_name' => 'Wango Weng Interview'
      )
      expect(args.retain_stabilization_files?).to be(false)
    end

    it 'raises an error when an argument is missing from the environment' do
      expect { described_class.from_env({}) }.to raise_error(ArgumentError, /source_type/)
    end
  end

  describe 'source_type' do
    it 'accepts an implemented source type' do
      expect(task_args.source_type).to eq('ldrive')
    end

    it 'ignores surrounding whitespace and capitalization' do
      expect(build_task_args(source_type: '  LDrive ').source_type).to eq('ldrive')
    end

    it 'raises an error when it is missing' do
      expect { build_task_args(source_type: nil) }.to raise_error(
        ArgumentError, "Missing required argument: #{described_class::SOURCE_TYPE_EXAMPLE}"
      )
    end

    it 'raises an error when it is not a known source type' do
      expect { build_task_args(source_type: 'dropbox') }.to raise_error(
        ArgumentError, /Unknown source_type: "dropbox"/
      )
    end

    it 'raises an error for a known source type that has not been implemented yet' do
      expect { build_task_args(source_type: 'googledrive') }.to raise_error(
        NotImplementedError, /googledrive is not implemented yet/
      )
    end
  end

  describe 'source_path' do
    it 'keeps a path that already starts with a slash' do
      expect(build_task_args(source_path: '/existing-dir/subdir').source_path).to eq('/existing-dir/subdir')
    end

    it 'adds a leading slash when one is missing' do
      expect(build_task_args(source_path: 'existing-dir/subdir').source_path).to eq('/existing-dir/subdir')
    end

    it 'raises an error when it is missing' do
      expect { build_task_args(source_path: nil) }.to raise_error(
        ArgumentError, "Missing required argument: #{described_class::SOURCE_PATH_EXAMPLE}"
      )
    end

    it 'raises an error when it has no usable segments' do
      expect { build_task_args(source_path: '///') }.to raise_error(ArgumentError, /Invalid source_path/)
    end
  end

  describe 'repository_name and collection_name' do
    it 'raises an error when the repository name is missing' do
      expect { build_task_args(repository_name: '') }.to raise_error(
        ArgumentError, "Missing required argument: #{described_class::REPOSITORY_NAME_EXAMPLE}"
      )
    end

    it 'raises an error when the collection name is missing' do
      expect { build_task_args(collection_name: nil) }.to raise_error(
        ArgumentError, "Missing required argument: #{described_class::COLLECTION_NAME_EXAMPLE}"
      )
    end
  end

  describe 'retain_stabilization_files' do
    it 'is false when it is not given' do
      expect(task_args.retain_stabilization_files?).to be(false)
    end

    it 'is true when it is "true"' do
      expect(build_task_args(retain_stabilization_files: 'true').retain_stabilization_files?).to be(true)
    end

    it 'ignores surrounding whitespace and capitalization' do
      expect(build_task_args(retain_stabilization_files: ' True ').retain_stabilization_files?).to be(true)
    end

    it 'is false when it is "false"' do
      expect(build_task_args(retain_stabilization_files: 'false').retain_stabilization_files?).to be(false)
    end

    it 'raises an error for a value that is neither true nor false' do
      expect { build_task_args(retain_stabilization_files: 'yes') }.to raise_error(
        ArgumentError,
        'Invalid retain_stabilization_files: "yes". Expected true or false.'
      )
    end
  end

  describe 'bag_name' do
    it 'combines the repository name, collection name and the current time' do
      expect(task_args.bag_name).to eq('Starr_Wango_Weng_Interview_20260901_121545')
    end

    it 'replaces a run of separator characters with a single underscore' do
      expect(build_task_args(collection_name: 'Wango  Weng  Interview').bag_name).to(
        start_with('Starr_Wango_Weng_Interview_')
      )
    end

    it 'does not leave a trailing underscore when a name ends in a period' do
      expect(build_task_args(collection_name: 'Wango Weng Interview.').bag_name).to(
        start_with('Starr_Wango_Weng_Interview_')
      )
    end

    it 'transliterates characters that are not ascii' do
      expect(build_task_args(collection_name: '我能').bag_name).to start_with('Starr_WoNeng')
    end
  end
end
