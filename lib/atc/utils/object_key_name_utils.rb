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

  DISALLOWED_ASCII_REGEX = '[^-a-zA-Z0-9_.]'

  def self.valid_key_name?(path_filename)
    return false if ['', '.', '..', '/'].include? path_filename

    pathname = Pathname.new(path_filename)

    # a relative path is invalid
    return false if pathname.absolute?

    path_to_file, filename = pathname.split

    # validate filename
    return false unless remediate_filename(filename.to_s) == filename.to_s
    # if the valid filename is at the top level, return true
    return true if pathname == pathname.basename

    # check each component in the path to the file
    path_to_file.each_filename do |path_segment|
      return false unless remediate_directory_segment(path_segment) == path_segment
    end
    true
  end

  def self.remediate_key_name(filepath_key_name, unavailable_key_names = [])
    if unavailable_key_names.exclude?(filepath_key_name) && self.valid_key_name?(filepath_key_name)
      return filepath_key_name
    end

    self.argument_check(filepath_key_name)

    pathname = Pathname.new(filepath_key_name)
    path_to_file, filename = pathname.split

    remediated_key_name = self.remediate_path(path_to_file).join(remediate_filename(filename.to_s)).to_s

    # no collisions
    return remediated_key_name unless unavailable_key_names.include? remediated_key_name

    # handle collisions
    self.handle_collision(remediated_key_name, unavailable_key_names)
  end

  def self.argument_check(filepath_key_name)
    raise ArgumentError, "Bad argument: '#{filepath_key_name}'" if ['', '.', '..', '/'].include? filepath_key_name
    raise ArgumentError, 'Bad argument: absolute path' if filepath_key_name.start_with?('/')
  end

  def self.remediate_path(path_to_file)
    # remediate each component in the path to the file
    remediated_pathname = Pathname.new('')
    path_to_file.each_filename do |path_segment|
      remediated_pathname += remediate_directory_segment(path_segment)
    end
    remediated_pathname
  end

  # Directories have no file extensions so every period gets replaced with an underscore except
  # an actual leading period that indicates a hidden directory.
  def self.remediate_directory_segment(segment)
    # Pathname#split for a top-level file will have a Pathname(".") as the first element
    return segment if segment == '.'

    collapse_interior_periods(AnyAscii.transliterate(segment).gsub(/#{DISALLOWED_ASCII_REGEX}/, '_'))
  end

  # The filename preserves the single period that separates its base name from its real extension.
  # Every other period is replaced with an underscore.
  def self.remediate_filename(filename)
    extension = File.extname(filename)
    base = extension.empty? ? filename : filename[0...-extension.length]

    remediated_base = collapse_interior_periods(AnyAscii.transliterate(base).gsub(/#{DISALLOWED_ASCII_REGEX}/, '_'))
    remediated_extension =
      extension == '.' ? '_' : AnyAscii.transliterate(extension).gsub(/#{DISALLOWED_ASCII_REGEX}/, '_')

    remediated_base + remediated_extension
  end

  # Replaces every period with an underscore except a leading period (used by the hidden file/directories).
  # Segments made up of nothing but periods get every period replaced.
  def self.collapse_interior_periods(str)
    return str unless str.include?('.')
    return str.tr('.', '_') if str.match?(/\A\.+\z/)

    leading_period, rest = str.start_with?('.') ? ['.', str[1..]] : ['', str]
    leading_period + rest.tr('.', '_')
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
