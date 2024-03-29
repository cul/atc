# frozen_string_literal: true

module Atc::Utils::ObjectKeyNameUtils
  # About Cloud Storage objects: https://cloud.google.com/storage/docs/objects
  # According to the above (and quite probably most Google Cloud Storage documentation),
  # objects have names
  # AWS - Creating object key names:
  # https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-keys.html
  # As seen in the title for the above page, an object in AWS S3 has a key name (or key)
  # So fcd1 decided to call this module ObjectKeyNameUtils to try and cover both naming
  # conventions. However, it's just a name and fcd1 is cool if module is renamed

  DISALLOWED_ASCII_REGEX = '[^-a-zA-Z0-9_.()]'

  def self.valid_key_name?(path_filename)
    return false if ['', '.', '..', '/'].include? path_filename

    pathname = Pathname.new(path_filename)

    # a relative path is invalid
    return false if pathname.absolute?

    path_to_file, filename = pathname.split

    # validate filename
    return false if filename.to_s.end_with?('.') || /#{DISALLOWED_ASCII_REGEX}/.match?(filename.to_s)
    # if the valid filename is at the top level, return true
    return true if pathname == pathname.basename

    # check each component in the path to the file
    path_to_file.each_filename do |path_segment|
      return false if /#{DISALLOWED_ASCII_REGEX}/.match? path_segment
    end
    true
  end

  def self.remediate_key_name(filepath_key_name, unavailable_key_names = [])
    if unavailable_key_names.exclude?(filepath_key_name) && self.valid_key_name?(filepath_key_name)
      return filepath_key_name
    end

    self.argument_check(filepath_key_name)

    pathname = Pathname.new(filepath_key_name)

    remediated_pathname = Pathname.new('')
    path_to_file, filename = pathname.split

    filename_valid_ascii =
      Stringex::Unidecoder.decode(filename.to_s).gsub(/#{DISALLOWED_ASCII_REGEX}/, '_').gsub(/\.$/, '_')

    remediated_key_name = self.remediate_path(path_to_file, remediated_pathname).join(filename_valid_ascii).to_s

    # no collisions
    return remediated_key_name unless unavailable_key_names.include? remediated_key_name

    # handle collisions
    self.handle_collision(remediated_key_name, unavailable_key_names)
  end

  def self.argument_check(filepath_key_name)
    raise ArgumentError, "Bad argument: '#{filepath_key_name}'" if ['', '.', '..', '/'].include? filepath_key_name
    raise ArgumentError, 'Bad argument: absolute path' if filepath_key_name.start_with?('/')
  end

  def self.remediate_path(path_to_file, remediated_pathname)
    # remediate each component in the path to the file
    path_to_file.each_filename do |path_segment|
      remediated_path_segment = Stringex::Unidecoder.decode(path_segment).gsub(/#{DISALLOWED_ASCII_REGEX}/, '_')
      remediated_pathname += remediated_path_segment
    end
    remediated_pathname
  end

  def self.handle_collision(remediated_key_name, unavailable_key_names)
    pathname = Pathname.new(remediated_key_name)
    base = pathname.to_s.delete_suffix(pathname.extname)
    new_remediated_key_name = "#{base}_1#{pathname.extname}"
    suffix_num = 1
    while unavailable_key_names.include? new_remediated_key_name
      suffix_num += 1
      new_remediated_key_name = "#{base}_#{suffix_num}#{pathname.extname}"
    end
    new_remediated_key_name
  end
end
