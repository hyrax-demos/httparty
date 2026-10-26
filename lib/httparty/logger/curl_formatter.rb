# frozen_string_literal: true

module HTTParty
  module Logger
    class CurlFormatter #:nodoc:
      TAG_NAME = HTTParty.name
      OUT      = '>'
      IN       = '<'

      attr_accessor :level, :logger

      def initialize(logger, level)
        @logger   = logger
        @level    = level.to_sym
        @messages = []
      end

      def format(request, response)
        @request  = request
        @response = response

        log_request
        log_response

        logger.public_send level, messages.join("\n")
      end

      private

      attr_reader :request, :response
      attr_accessor :messages

      def log_request
        log_url
        log_headers
        log_query
        log OUT, request.raw_body if request.raw_body
        log OUT
      end

      def log_response
        log IN, "HTTP/#{response.http_version} #{response.code}"
        log_response_headers
        log IN, "\n#{utf8_safe(response.body)}"
        log IN
      end

      def log_url
        http_method = request.http_method.name.split('::').last.upcase
        uri = if request.options[:base_uri]
                request.options[:base_uri] + request.path.path
              else
                request.path.to_s
              end

        log OUT, "#{http_method} #{uri}"
      end

      def log_headers
        return unless request.options[:headers] && request.options[:headers].size > 0

        log OUT, 'Headers: '
        log_hash request.options[:headers]
      end

      def log_query
        return unless request.options[:query]

        log OUT, 'Query: '
        log_hash request.options[:query]
      end

      def log_response_headers
        # Iterate the headers object rather than calling each_header on an
        # HTTParty::Response: that goes through method_missing, which parses
        # the body first, so logging would raise for a body the parser
        # cannot handle.
        headers = response.respond_to?(:headers) ? response.headers : response
        headers.each_header do |response_header|
          log IN, "#{response_header.capitalize}: #{headers[response_header]}"
        end
      end

      def log_hash(hash)
        hash.each { |k, v| log(OUT, "#{utf8_safe(k)}: #{utf8_safe(v)}") }
      end

      def log(direction, line = '')
        messages << "[#{TAG_NAME}] [#{current_time}] #{direction} #{utf8_safe(line)}"
      end

      # Returns +str+ as valid UTF-8 so that lines carrying binary bodies can be
      # joined with UTF-8 lines. Invalid or unconvertible bytes become U+FFFD.
      # The caller's string is never modified.
      def utf8_safe(str)
        str = str.to_s

        if str.encoding == Encoding::ASCII_8BIT
          str.dup.force_encoding(Encoding::UTF_8).scrub
        elsif str.encoding == Encoding::UTF_8
          str.valid_encoding? ? str : str.scrub
        else
          begin
            str.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
          rescue Encoding::ConverterNotFoundError
            str.dup.force_encoding(Encoding::UTF_8).scrub
          end
        end
      end

      def current_time
        Time.now.strftime("%Y-%m-%d %H:%M:%S %z")
      end
    end
  end
end
