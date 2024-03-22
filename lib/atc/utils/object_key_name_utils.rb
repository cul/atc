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

  def self.valid_key_name?(path_filename)
    return false if ['', '.', '..', '/'].include? path_filename

    pathname = Pathname.new(path_filename)

    # a relative path is invalid
    return false if pathname.absolute?

    path_to_file, filename = pathname.split

    # validate filename
    return false if filename.to_s.end_with?('.') || /[^-a-zA-Z0-9_.]/.match?(filename.to_s)
    # if the valid filename is at the top level, return true
    return true if pathname == pathname.basename

    # check each component in the path to the file
    path_to_file.each_filename do |path_segment|
      return false if /[^-a-zA-Z0-9_.]/.match? path_segment
    end
    true
  end

  def self.remediate_key_name(filepath_key_name, unavailable_key_names = [])
    raise ArgumentError, "Bad argument: '#{filepath_key_name}'" if ['', '.', '..', '/'].include? filepath_key_name

    pathname = Pathname.new(filepath_key_name)
    remediated_pathname = Pathname.new(pathname.absolute? ? '/' : '')
    path_to_file, filename = pathname.split

    # remediate each component in the path to the file
    path_to_file.each_filename do |path_segment|
      remediated_path_segment = Stringex::Unidecoder.decode(path_segment).gsub(/[^-a-zA-Z0-9_]/, '_')
      remediated_pathname += remediated_path_segment
    end

    # remediate filename
    filename_valid_ascii = self.remediate_filename(filename)

    remediated_key_name = remediated_pathname.join(filename_valid_ascii).to_s

    # no collisions
    return remediated_key_name unless unavailable_key_names.include? remediated_key_name

    # handle collisions
    self.handle_collision(remediated_key_name, unavailable_key_names)
  end

  def self.remediate_filename(filename)
    # Handle base filename and extension separately
    extension = filename.extname
    base = filename.to_s.delete_suffix(extension)

    # remediate base filename. Do not replace starting '.' for hidden files
    base_ascii = Stringex::Unidecoder.decode(base)
    base_valid_ascii = if base_ascii.starts_with?('.')
                         ".#{base_ascii.delete_prefix('.').gsub(/[^-a-zA-Z0-9_]/, '_')}"
                       else
                         base_ascii.gsub(/[^-a-zA-Z0-9_]/, '_')
                       end

    # remediate extension if present
    if extension.present?
      filename_valid_ascii =
        "#{base_valid_ascii}.#{Stringex::Unidecoder.decode(extension.delete_prefix('.')).gsub(/[^-a-zA-Z0-9_]/, '_')}"
    else
      filename_valid_ascii = base_valid_ascii
    end
    filename_valid_ascii
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
