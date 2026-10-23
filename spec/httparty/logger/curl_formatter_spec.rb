require 'spec_helper'

RSpec.describe HTTParty::Logger::CurlFormatter do
  describe "#format" do
    let(:logger)          { double('Logger') }
    let(:response_object) { Net::HTTPOK.new('1.1', 200, 'OK') }
    let(:parsed_response) { lambda { {"foo" => "bar"} } }

    let(:response) do
      HTTParty::Response.new(request, response_object, parsed_response)
    end

    let(:request) do
      HTTParty::Request.new(Net::HTTP::Get, 'http://foo.bar.com/')
    end

    let(:request_raw_body) { 'content' }
    let(:response_body)    { "{foo:'bar'}" }

    subject { described_class.new(logger, :info) }

    before do
      allow(logger).to receive(:info)
      allow(request).to receive(:raw_body).and_return(request_raw_body)
      allow(response_object).to receive_messages(body: response_body)
      response_object['header-key'] = 'header-value'

      subject.format request, response
    end

    context 'when request is logged' do
      context "and request's option 'base_uri' is not present" do
        it 'logs url' do
          expect(logger).to have_received(:info).with(/\[HTTParty\] \[\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\ [+-]\d{4}\] > GET http:\/\/foo.bar.com/)
        end
      end

      context "and request's option 'base_uri' is present" do
        let(:request) do
          HTTParty::Request.new(Net::HTTP::Get, '/path', base_uri: 'http://foo.bar.com')
        end

        it 'logs url' do
          expect(logger).to have_received(:info).with(/\[HTTParty\] \[\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\ [+-]\d{4}\] > GET http:\/\/foo.bar.com\/path/)
        end
      end

      context 'and headers are not present' do
        it 'not log Headers' do
          expect(logger).not_to have_received(:info).with(/Headers/)
        end
      end

      context 'and headers are present' do
        let(:request) do
          HTTParty::Request.new(Net::HTTP::Get, '/path', base_uri: 'http://foo.bar.com', headers: { key: 'value' })
        end

        it 'logs Headers' do
          expect(logger).to have_received(:info).with(/Headers/)
        end

        it 'logs headers keys' do
          expect(logger).to have_received(:info).with(/key: value/)
        end
      end

      context 'and query is not present' do
        it 'not logs Query' do
          expect(logger).not_to have_received(:info).with(/Query/)
        end
      end

      context 'and query is present' do
        let(:request) do
          HTTParty::Request.new(Net::HTTP::Get, '/path', query: { key: 'value' })
        end

        it 'logs Query' do
          expect(logger).to have_received(:info).with(/Query/)
        end

        it 'logs query params' do
          expect(logger).to have_received(:info).with(/key: value/)
        end
      end

      context 'when request raw_body is present' do
        it 'not logs request body' do
          expect(logger).to have_received(:info).with(/content/)
        end
      end
    end

    context 'when response is logged' do
      it 'logs http version and response code' do
        expect(logger).to have_received(:info).with(/HTTP\/1.1 200/)
      end

      it 'logs headers' do
        expect(logger).to have_received(:info).with(/Header-key: header-value/)
      end

      it 'logs body' do
        expect(logger).to have_received(:info).with(/{foo:'bar'}/)
      end
    end

    # Binary test data is built from escapes in code for Hyrax's push screen.
    context 'when response body is binary and another line is non-ASCII UTF-8' do
      # Input: an ASCII-8BIT PNG-like body with high bytes, while the request
      # body holds a UTF-8 "e" with an acute accent.
      let(:request_raw_body) { "caf\u00e9" }
      let(:response_body)    { "\x89PNG\r\n\x1A\n\xFF\xD8".b }

      it 'logs both lines in one UTF-8 message' do
        expect(logger).to have_received(:info) do |message|
          expect(message.encoding).to eq(Encoding::UTF_8)
          expect(message).to be_valid_encoding
          expect(message).to include("caf\u00e9")
          expect(message).to include("\uFFFDPNG")
        end
      end
    end

    context 'when request body is binary and response body is non-ASCII UTF-8' do
      # Input: an ASCII-8BIT request body with high bytes (as a multipart file
      # upload can produce) and a UTF-8 response body with an accented letter.
      let(:request_raw_body) { "file:\xFF\xFE".b }
      let(:response_body)    { "caf\u00e9" }

      it 'logs both lines in one UTF-8 message' do
        expect(logger).to have_received(:info) do |message|
          expect(message.encoding).to eq(Encoding::UTF_8)
          expect(message).to be_valid_encoding
          expect(message).to include("file:\uFFFD")
          expect(message).to include("caf\u00e9")
        end
      end
    end

    context 'when response body is in a non-ASCII-compatible encoding' do
      # Input: a UTF-16LE response body, as a charset=utf-16 response can yield.
      let(:response_body) { "caf\u00e9".encode(Encoding::UTF_16LE) }

      it 'logs the body converted to UTF-8' do
        expect(logger).to have_received(:info) do |message|
          expect(message.encoding).to eq(Encoding::UTF_8)
          expect(message).to include("caf\u00e9")
        end
      end
    end

    it "formats a response in a style that resembles a -v curl" do
      logger_double = double
      expect(logger_double).to receive(:info).with(
          /\[HTTParty\] \[\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\ [+-]\d{4}\] > GET http:\/\/localhost/)

      subject = described_class.new(logger_double, :info)

      stub_http_response_with("example.html")

      response = HTTParty::Request.new.perform
      subject.format(response.request, response)
    end
  end
end
