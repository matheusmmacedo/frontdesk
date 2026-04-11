# frozen_string_literal: true

# Validates WhatsApp template components before sending to Meta Graph API.
# Enforces Meta's rules: component types, field limits, button constraints, etc.
module WhatsappConnections
  module Meta
    class TemplateValidatorService
      VALID_CATEGORIES = %w[MARKETING UTILITY AUTHENTICATION].freeze
      VALID_COMPONENT_TYPES = %w[HEADER BODY FOOTER BUTTONS].freeze
      VALID_HEADER_FORMATS = %w[TEXT IMAGE VIDEO DOCUMENT].freeze
      VALID_BUTTON_TYPES = %w[QUICK_REPLY URL PHONE_NUMBER COPY_CODE].freeze

      MAX_BODY_LENGTH = 1024
      MAX_FOOTER_LENGTH = 60
      MAX_BUTTON_TEXT_LENGTH = 25
      MAX_BUTTONS = 10
      MAX_QUICK_REPLY_BUTTONS = 10
      MAX_URL_BUTTONS = 2
      MAX_PHONE_BUTTONS = 1
      TEMPLATE_NAME_REGEX = /\A[a-z0-9_]+\z/

      class ValidationError < StandardError; end

      def initialize(params, is_update: false)
        @params = params.to_h.deep_symbolize_keys
        @is_update = is_update
        @errors = []
      end

      def validate!
        validate_name unless @is_update
        validate_category unless @is_update
        validate_language unless @is_update
        validate_components
        raise ValidationError, @errors.join('; ') if @errors.any?
      end

      private

      def validate_name
        name = @params[:name]
        @errors << 'Name is required' if name.blank?
        @errors << 'Name must contain only lowercase letters, numbers, and underscores' if name.present? && !TEMPLATE_NAME_REGEX.match?(name)
        @errors << 'Name must be between 1 and 512 characters' if name.present? && (name.length < 1 || name.length > 512)
      end

      def validate_category
        category = @params[:category]
        @errors << 'Category is required' if category.blank?
        @errors << "Invalid category '#{category}'. Must be one of: #{VALID_CATEGORIES.join(', ')}" if category.present? && !VALID_CATEGORIES.include?(category.to_s.upcase)
      end

      def validate_language
        @errors << 'Language is required' if @params[:language].blank?
      end

      def validate_components
        components = @params[:components]
        return @errors << 'Components are required' if components.blank?

        # Handle both array and hash formats from params
        component_list = components.is_a?(Hash) ? components.values : Array(components)

        has_body = false
        component_list.each do |comp|
          comp = comp.deep_symbolize_keys if comp.respond_to?(:deep_symbolize_keys)
          type = comp[:type]&.to_s&.upcase

          unless VALID_COMPONENT_TYPES.include?(type)
            @errors << "Invalid component type '#{type}'. Must be one of: #{VALID_COMPONENT_TYPES.join(', ')}"
            next
          end

          case type
          when 'HEADER' then validate_header(comp)
          when 'BODY' then has_body = true; validate_body(comp)
          when 'FOOTER' then validate_footer(comp)
          when 'BUTTONS' then validate_buttons(comp)
          end
        end

        @errors << 'BODY component is required' unless has_body
      end

      def validate_header(comp)
        format = comp[:format]&.to_s&.upcase
        return if format.blank? # Text header without explicit format is OK

        unless VALID_HEADER_FORMATS.include?(format)
          @errors << "Invalid header format '#{format}'. Must be one of: #{VALID_HEADER_FORMATS.join(', ')}"
        end

        # Text headers must have text
        if format == 'TEXT' && comp[:text].blank?
          @errors << 'Header TEXT format requires text field'
        end

        # Media headers need example with handle or URL
        if %w[IMAGE VIDEO DOCUMENT].include?(format)
          example = comp[:example]
          unless example.present? && (example[:header_handle].present? || example[:header_url].present?)
            # Allow creation without example (Meta will prompt for it in review)
          end
        end
      end

      def validate_body(comp)
        text = comp[:text].to_s
        @errors << 'Body text is required' if text.blank?
        @errors << "Body text exceeds maximum length of #{MAX_BODY_LENGTH} characters (got #{text.length})" if text.length > MAX_BODY_LENGTH
      end

      def validate_footer(comp)
        text = comp[:text].to_s
        @errors << "Footer text exceeds maximum length of #{MAX_FOOTER_LENGTH} characters (got #{text.length})" if text.present? && text.length > MAX_FOOTER_LENGTH
      end

      def validate_buttons(comp)
        buttons = comp[:buttons]
        return @errors << 'Buttons component requires buttons array' if buttons.blank?

        button_list = buttons.is_a?(Hash) ? buttons.values : Array(buttons)
        @errors << "Maximum #{MAX_BUTTONS} buttons allowed (got #{button_list.size})" if button_list.size > MAX_BUTTONS

        url_count = 0
        phone_count = 0

        button_list.each_with_index do |btn, idx|
          btn = btn.deep_symbolize_keys if btn.respond_to?(:deep_symbolize_keys)
          type = btn[:type]&.to_s&.upcase

          unless VALID_BUTTON_TYPES.include?(type)
            @errors << "Button #{idx + 1}: invalid type '#{type}'. Must be one of: #{VALID_BUTTON_TYPES.join(', ')}"
            next
          end

          text = btn[:text].to_s
          @errors << "Button #{idx + 1}: text is required" if text.blank? && type != 'COPY_CODE'
          @errors << "Button #{idx + 1}: text exceeds #{MAX_BUTTON_TEXT_LENGTH} characters" if text.length > MAX_BUTTON_TEXT_LENGTH

          case type
          when 'URL'
            url_count += 1
            url = btn[:url].to_s
            @errors << "Button #{idx + 1}: URL is required for URL button" if url.blank?
            @errors << "Button #{idx + 1}: URL must start with https://" if url.present? && !url.start_with?('https://')
          when 'PHONE_NUMBER'
            phone_count += 1
            phone = btn[:phone_number].to_s
            @errors << "Button #{idx + 1}: Phone number is required" if phone.blank?
            @errors << "Button #{idx + 1}: Phone number must start with +" if phone.present? && !phone.start_with?('+')
          when 'COPY_CODE'
            @errors << "Button #{idx + 1}: example is required for COPY_CODE" if btn[:example].blank?
          end
        end

        @errors << "Maximum #{MAX_URL_BUTTONS} URL buttons allowed (got #{url_count})" if url_count > MAX_URL_BUTTONS
        @errors << "Maximum #{MAX_PHONE_BUTTONS} PHONE_NUMBER button allowed (got #{phone_count})" if phone_count > MAX_PHONE_BUTTONS
      end
    end
  end
end
