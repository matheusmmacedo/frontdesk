# frozen_string_literal: true

# Uploads media files to Meta's Resumable Upload API for use in template headers.
# Returns a handle that can be used in template component example.header_handle.
#
# Meta Resumable Upload flow:
#   1. POST /{app-id}/uploads → { id: "upload:..." }
#   2. POST /{upload-id} with file binary → { h: "4::aW1..." }
#
# Reference: https://developers.facebook.com/docs/graph-api/guides/upload
module WhatsappConnections
  module Meta
    class MediaUploadService
      ALLOWED_MIME_TYPES = {
        'image' => %w[image/jpeg image/png],
        'video' => %w[video/mp4 video/3gpp],
        'document' => %w[application/pdf]
      }.freeze

      MAX_FILE_SIZES = {
        'image' => 5.megabytes,
        'video' => 16.megabytes,
        'document' => 100.megabytes
      }.freeze

      class UploadError < StandardError; end

      def initialize(connection)
        @connection = connection
        @api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
        @base_url = GlobalConfigService.load('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
        @app_id = GlobalConfigService.load('WHATSAPP_CLOUD_APP_ID', '')
      end

      # Upload a file and return Meta's handle for use in template creation.
      # file: ActionDispatch::Http::UploadedFile or similar (responds to .read, .content_type, .original_filename, .size)
      # media_type: 'image', 'video', or 'document'
      def upload(file, media_type)
        validate!(file, media_type)

        # Step 1: Create upload session
        session = create_upload_session(
          file_length: file.size,
          file_type: file.content_type,
          file_name: file.original_filename
        )

        upload_id = session['id']
        raise UploadError, 'Meta did not return upload session ID' if upload_id.blank?

        # Step 2: Upload file data
        result = upload_file_data(upload_id, file.read, file.content_type)
        handle = result['h']
        raise UploadError, 'Meta did not return file handle' if handle.blank?

        { handle: handle, upload_id: upload_id }
      end

      # Alternative: upload from a public URL (Meta downloads it)
      # Returns handle for template creation
      def upload_from_url(url, media_type)
        # For URL-based headers, Meta accepts the URL directly in the example
        # No upload needed — return URL as-is for use in example.header_url
        { url: url, media_type: media_type }
      end

      private

      def validate!(file, media_type)
        raise UploadError, "Invalid media type '#{media_type}'" unless ALLOWED_MIME_TYPES.key?(media_type)

        allowed = ALLOWED_MIME_TYPES[media_type]
        unless allowed.include?(file.content_type)
          raise UploadError, "Invalid file type '#{file.content_type}' for #{media_type}. Allowed: #{allowed.join(', ')}"
        end

        max_size = MAX_FILE_SIZES[media_type]
        if file.size > max_size
          raise UploadError, "File too large (#{(file.size / 1.megabyte.to_f).round(1)}MB). Maximum for #{media_type}: #{(max_size / 1.megabyte.to_f).round}MB"
        end

        raise UploadError, 'WHATSAPP_CLOUD_APP_ID not configured' if @app_id.blank?
      end

      def create_upload_session(file_length:, file_type:, file_name:)
        response = HTTParty.post(
          "#{@base_url}/#{@api_version}/#{@app_id}/uploads",
          headers: auth_headers,
          body: {
            file_length: file_length,
            file_type: file_type,
            file_name: file_name
          }.to_json
        )
        handle_response(response, 'Create upload session failed')
        response.parsed_response
      end

      def upload_file_data(upload_id, file_data, content_type)
        response = HTTParty.post(
          "#{@base_url}/#{@api_version}/#{upload_id}",
          headers: {
            'Authorization' => "OAuth #{@connection.access_token}",
            'Content-Type' => content_type,
            'file_offset' => '0'
          },
          body: file_data
        )
        handle_response(response, 'Upload file data failed')
        response.parsed_response
      end

      def auth_headers
        {
          'Authorization' => "Bearer #{@connection.access_token}",
          'Content-Type' => 'application/json'
        }
      end

      def handle_response(response, error_prefix)
        return if response.success?

        error_body = response.parsed_response
        error_msg = error_body&.dig('error', 'message') || response.body
        raise UploadError, "#{error_prefix}: #{error_msg}"
      end
    end
  end
end
