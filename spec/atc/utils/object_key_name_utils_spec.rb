# frozen_string_literal: true

require 'rails_helper'

describe Atc::Utils::ObjectKeyNameUtils do
  let(:sample_valid_path_key_names) do
    [
      'file.txt',
      'top_dir/sub_dir/file',
      'top-dir/sub-dir/a-file.txt',
      'top_dir/sub_dir/.hidden_file',
      'top_dir/sub_dir/.hidden_file.txt',
      'top_dir/sub_dir/file.txt',
      'top_dir/sub.dir/file.txt',
      '.top_dir/sub_dir/file',
      'top_dir/./file',
      'top_dir/../file',
      'top_dir/.../file',
      'top_dir/sub_dir/file.txt.txt',
      'top_dir/sub_dir/.ext.txt.txt',
      '.a.b.c./.a.b.c',
      'top_dir/sub_dir/(file)',
      '())(top_dir())(/()sub_dir)(/())(file())(',
      '.a.b.c./.a.b.c./.a.b.c',
      '(a)bc/a(b)c/ab(c)',
      '_a_b_c_/_a_b_c_/_a_b_c_'
    ]
  end

  describe '.valid_key_name?' do
    let(:sample_invalid_path_key_names) do
      [
        '',
        '/',
        '.',
        '..',
        './',
        '../',
        '/top_dir/sub_dir/file',
        'top_dir/sub_dir/file ',
        'top_dir/sub_dir/ file',
        'top_dîr/sub_dir/file',
        'top_dir/sub_dîr/file',
        'top_dir/sub_dir/fîle',
        'top dir/sub_dir/file',
        'top_dir/sub_dir/fîle.txt',
        'top_dir/sub_dir/file.îxt',
        'top_dir/sub_dir/..',
        'top_dir/sub_dir/...',
        'top_dir/我能/我能.我能.我能',
        '.a.b.c./.a.b.c.'
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
    let(:sample_remediated_path_key_names) do
      [
        ['.a.b.c./.a.b.c./.a.b.c.', '.a.b.c./.a.b.c./.a.b.c_'],
        [' a b c / a b c / a b c ', '_a_b_c_/_a_b_c_/_a_b_c_'],
        [' a b c/ a b c/ a b c', '_a_b_c/_a_b_c/_a_b_c'],
        ['aîc/aîc/aîc.îii', 'aic/aic/aic.iii'],
        ['top_dîr/我能/我能.我能.我能', 'top_dir/Wo_Neng_/Wo_Neng_.Wo_Neng_.Wo_Neng_'],
        ['top_dîr/ça_sub dir/file .txt.txt', 'top_dir/ca_sub_dir/file_.txt.txt'],
        ['top_dîr/ça_sub dir/مروخب.مروخب', 'top_dir/ca_sub_dir/mrwkhb.mrwkhb']
      ]
    end

    it 'raise an exception if given an absolute path' do
      expect { described_class.remediate_key_name('/top_dir/sub_dir/file.txt') }.to raise_error(ArgumentError)
    end

    it "raise an exception for '/'" do
      expect { described_class.remediate_key_name('/') }.to raise_error(ArgumentError)
    end

    it "raise an exception for ''" do
      expect { described_class.remediate_key_name('') }.to raise_error(ArgumentError)
    end

    it "raise an exception for '.'" do
      expect { described_class.remediate_key_name('.') }.to raise_error(ArgumentError)
    end

    it "raise an exception for '..'" do
      expect { described_class.remediate_key_name('..') }.to raise_error(ArgumentError)
    end

    it 'remediates path key names as expected' do
      sample_remediated_path_key_names.each do |path|
        remediated_key = described_class.remediate_key_name(path[0])
        expect(remediated_key).to (eql path[1]), lambda {
          "original '#{path[0]}', expected '#{path[1]}', actual '#{remediated_key}'"
        }
      end
    end

    it 'returns original path key name path if no remediation needed' do
      sample_valid_path_key_names.each do |path|
        expect(described_class.remediate_key_name(path)).to eql path
      end
    end

    it "Collision: returns original valid key name with suffix '_1' before extension: 'top_dir/sub_dir/file_1.txt'" do
      expect(described_class.remediate_key_name(
               'top_dir/sub_dir/file.txt', ['top_dir/sub_dir/file.txt']
             )).to eql 'top_dir/sub_dir/file_1.txt'
    end

    it "Collision: returns original valid key name with suffix '_2': 'top_dir/sub_dir/file_2.txt'" do
      expect(described_class.remediate_key_name(
               'top_dir/sub_dir/file.txt', ['top_dir/sub_dir/file.txt', 'top_dir/sub_dir/file_1.txt']
             )).to eql 'top_dir/sub_dir/file_2.txt'
    end
  end
end
