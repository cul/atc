require 'csv'
require 'google/apis/drive_v3'

# Docs Editors mime type => [export mime type, file extension]
# https://developers.google.com/workspace/drive/api/guides/ref-export-formats
GOOGLE_EXPORT_FORMATS = {
  'application/vnd.google-apps.document' => ['application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'docx'],
  # Note: CSV exports only include the first sheet
  'application/vnd.google-apps.spreadsheet' => ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'xlsx'],
  'application/vnd.google-apps.presentation' => ['application/vnd.openxmlformats-officedocument.presentationml.presentation', 'pptx'],
  'application/vnd.google-apps.drawing' => ['image/png', 'png'],
}.freeze

namespace :atc do
  def list_files_recursively(drive_service, folder_id, &block)
    page_token = nil
    
    loop do
      response = drive_service.list_files(
        q: "'#{folder_id}' in parents and trashed = false",
        fields: 'nextPageToken, files(id, name, mimeType, fileExtension, size, sha256Checksum, exportLinks)',
        page_token: page_token,
        supports_all_drives: true,
        include_items_from_all_drives: true
      )

      response.files.each do |file|
        yield file

        # If the item is a folder, recursively list its contents
        if file.mime_type == 'application/vnd.google-apps.folder'
          puts "Folder: #{file.name}"
          list_files_recursively(drive_service, file.id, &block)
          puts "========== End of folder =========="
        end
      end

      page_token = response.next_page_token
      break if page_token.nil?
    end
  end

  task gdrive_test: :environment do
    folder_id = ENV['folder_id']
    output_path = Rails.root.join('tmp', 'gdrive-stabilization') # later use config file to set this
    
    # Create a CSV report
    current_datetime = Time.current.strftime('%Y%m%d_%H%M%S')
    inventory_file = File.join(output_path, "inventory-#{current_datetime}.csv")
    FileUtils.mkdir_p(output_path)
    CSV.open(inventory_file, 'w') { |csv| csv << %w[file_name mime_type file_extension sha256] }

    # https://docs.cloud.google.com/ruby/docs/reference/googleauth/latest/Google-Auth-ServiceAccountCredentials#Google__Auth__ServiceAccountCredentials_make_creds_class_
    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(GCP_CONFIG[:credentials].to_h.to_json),
      scope: Google::Apis::DriveV3::AUTH_DRIVE_READONLY
    )

    drive = Google::Apis::DriveV3::DriveService.new
    drive.authorization = credentials

    list_files_recursively(drive, folder_id) do |file|
      next if file.mime_type == 'application/vnd.google-apps.folder'

      # ! Docs Editors files (like Google Spreadsheet) don't have checksums
      # https://developers.google.com/workspace/drive/api/reference/rest/v3/files#File
      puts "File: #{file.name} (id: #{file.id}), size: #{file.size}, file_extension: #{file.file_extension}, mime_type: #{file.mime_type}, sha256: #{file.sha256_checksum}"

      local_path = nil
      extension = file.file_extension
      sha256 = nil

      # Docs Editors
      if GOOGLE_EXPORT_FORMATS.include?(file.mime_type)
        export_mime_type, extension = GOOGLE_EXPORT_FORMATS[file.mime_type]
        # Names can contain '/', which would be treated as a subdir so it's replaced with '_'
        # Later we should use Atc::Utils::ObjectKeyNameUtils
        local_path = output_path.join("#{file.name.tr('/', '_')}.#{extension}")

        begin
          drive.export_file(file.id, export_mime_type, download_dest: local_path)
        rescue Google::Apis::ClientError => e
          # TODO: Fall back to using export links since export_file is limited to 10 MB
          # Watch out for: https://github.com/googleapis/google-api-ruby-client/issues/906
          puts "export_file failed (#{e.message}), retrying with export link"
        end
      elsif !file.mime_type.start_with?('application/vnd.google-apps.')
        # For binary files, file.name already includes extension
        local_path = output_path.join(file.name.tr('/', '_'))
        drive.get_file(file.id, download_dest: local_path, supports_all_drives: true)
      else
        puts "Unsupported file: #{file.name} (id: #{file.id}), mime_type: #{file.mime_type}"
      end

      if local_path
        sha256 = Digest::SHA256.file(local_path).hexdigest
        puts "Downloaded: #{local_path}, sha256: #{sha256}"
      end

      CSV.open(inventory_file, 'a') { |csv| csv << [file.name, file.mime_type, extension, sha256] }
    end
  end
end
