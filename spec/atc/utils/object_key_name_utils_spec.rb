# frozen_string_literal: true

require 'rails_helper'

describe Atc::Utils::ObjectKeyNameUtils do
  describe '.valid_key_name?' do
    let(:sample_invalid_path_key_names) do
      [
        '',
        '/',
        '.',
        './',
        './file',
        '../',
        '../file',
        '/top_dir/sub_dir/file',
        '.top_dir/sub_dir/file',
        'top_dir/sub_dir/(file)',
        'top_dir/sub_dir/file ',
        'top_dir/sub_dir/ file',
        'top_dîr/sub_dir/file',
        'top_dir/sub_dîr/file',
        'top_dir/sub_dir/fîle',
        'top dir/sub_dir/file',
        'top_dir/sub_dir/fîle.txt',
        'top_dir/sub_dir/file.îxt',
        'top_dir/sub.dir/file.txt',
        'top_dir/sub_dir/file.txt.txt',
        'top_dir/sub_dir/.ext.txt.txt',
        'top_dir/./file',
        'top_dir/../file',
        'top_dir/.../file',
        'top_dir/sub_dir/..',
        'top_dir/sub_dir/...',
        'top_dir/我能/我能.我能.我能'
      ]
    end
    let(:sample_valid_path_key_names) do
      [
        'top_dir/sub_dir/file',
        'top-dir/sub-dir/a-file.txt',
        'top_dir/sub_dir/.hidden_file',
        'top_dir/sub_dir/.hidden_file.txt',
        'top_dir/sub_dir/file.txt'
      ]
    end

    it 'returns false for all sample invalid paths' do
      sample_invalid_path_key_names.each do |path|
        expect(described_class.valid_key_name?(path)).to (be false), -> { "Test failed on path '#{path}'" }
      end
    end

    it 'returns true for all sample valid paths' do
      sample_valid_path_key_names.each do |path|
        expect(described_class.valid_key_name?(path)).to (be true), -> { "Test failed on path '#{path}'" }
      end
    end
  end

  describe '.remediate_key_name' do
    it "remediates '/top_dîr/ça_sub dir/file .txt.txt' to '/top_dir/ca_sub_dir/file__txt.txt'" do
      expect(described_class.remediate_key_name(
               '/top_dîr/ça_sub dir/file .txt.txt'
             )).to eql '/top_dir/ca_sub_dir/file__txt.txt'
    end

    # NOTE: an ending '.' at the end of the filename is allowed
    it "remediates 'top_dîr/ça_sub dir/file.' to 'top_dir/ca_sub_dir/file.'" do
      expect(described_class.remediate_key_name(
               'top_dîr/ça_sub dir/file.'
             )).to eql 'top_dir/ca_sub_dir/file.'
    end

    it "remediates 'top_dîr/ça_sub dir/بخورم.بخورم' to 'top_dir/ca_sub_dir/file.'" do
      expect(described_class.remediate_key_name(
               'top_dîr/ça_sub dir/بخورم.بخورم'
             )).to eql 'top_dir/ca_sub_dir/bkhwrm.bkhwrm'
    end

    it "remediates '/top_dîr/我能/我能.我能.我能' to '/top_dir/Wo_Neng_/Wo_Neng__Wo_Neng_.Wo_Neng_'" do
      expect(described_class.remediate_key_name(
               '/top_dîr/我能/我能.我能.我能'
             )).to eql '/top_dir/Wo_Neng_/Wo_Neng__Wo_Neng_.Wo_Neng_'
    end

    it "returns original valid path '/top_dir/sub_dir/file'" do
      expect(described_class.remediate_key_name('/top_dir/sub_dir/file')).to eql '/top_dir/sub_dir/file'
    end

    it "returns original valid key name '/top_dir/sub_dir/file.txt'" do
      expect(described_class.remediate_key_name('/top_dir/sub_dir/file.txt')).to eql '/top_dir/sub_dir/file.txt'
    end

    it "returns original valid key name (hidden file, starts with '.') '/top_dir/sub_dir/.file'" do
      expect(described_class.remediate_key_name('/top_dir/sub_dir/.file')).to eql '/top_dir/sub_dir/.file'
    end

    it "returns original valid key name (hidden file, starts with '.', has extension) '/top_dir/sub_dir/.file.txt'" do
      expect(described_class.remediate_key_name('/top_dir/sub_dir/.file.txt')).to eql '/top_dir/sub_dir/.file.txt'
    end

    it "returns original valid key name with suffix '_1': '/top_dir/sub_dir/file.txt_1'" do
      expect(described_class.remediate_key_name(
               '/top_dir/sub_dir/file.txt', ['/top_dir/sub_dir/file.txt']
             )).to eql '/top_dir/sub_dir/file.txt_1'
    end

    it "returns original valid key name with suffix '_2': '/top_dir/sub_dir/file.txt_2'" do
      expect(described_class.remediate_key_name(
               '/top_dir/sub_dir/file.txt', ['/top_dir/sub_dir/file.txt', '/top_dir/sub_dir/file.txt_1']
             )).to eql '/top_dir/sub_dir/file.txt_2'
    end
  end
end
