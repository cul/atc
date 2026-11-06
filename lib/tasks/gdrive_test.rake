require 'google/apis/drive_v3'

namespace :atc do
  def list_files_recursively(drive_service, folder_id, &block)
    page_token = nil
    
    loop do
      response = drive_service.list_files(
        q: "'#{folder_id}' in parents and trashed = false",
        fields: 'nextPageToken, files(id, name, mimeType, md5Checksum, sha256Checksum)',
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

    # https://docs.cloud.google.com/ruby/docs/reference/googleauth/latest/Google-Auth-ServiceAccountCredentials#Google__Auth__ServiceAccountCredentials_make_creds_class_
    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(GCP_CONFIG[:credentials].to_h.to_json),
      scope: Google::Apis::DriveV3::AUTH_DRIVE_READONLY
    )

    drive = Google::Apis::DriveV3::DriveService.new
    drive.authorization = credentials

    list_files_recursively(drive, folder_id) do |file|
      # ! Docs Editors files (like Google Spreadsheet) don't have checksums
      # https://developers.google.com/workspace/drive/api/reference/rest/v3/files#File
      puts "File: #{file.name} (id: #{file.id}), type: #{file.mime_type}, md5: #{file.md5_checksum}, sha256: #{file.sha256_checksum}"
    end
  end
end
