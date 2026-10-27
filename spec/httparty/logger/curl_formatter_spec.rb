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

    subject { described_class.new(logger, :info) }

    before do
      allow(logger).to receive(:info)
      allow(request).to receive(:raw_body).and_return('content')
      allow(response_object).to receive_messages(body: "{foo:'bar'}")
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

    it "formats a response in a style that resembles a -v curl" do
      logger_double = double
      expect(logger_double).to receive(:info).with(
          /\[HTTParty\] \[\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\ [+-]\d{4}\] > GET http:\/\/localhost/)

      subject = described_class.new(logger_double, :info)

      stub_http_response_with("example.html")

      response = HTTParty::Request.new.perform
      subject.format(response.request, response)
    end

    it "logs a binary (ASCII-8BIT) response body alongside UTF-8 log lines without raising" do
      # Input: a request header whose value is non-ASCII UTF-8, paired with an
      # ASCII-8BIT response body that holds invalid bytes (\xFF\xD8) followed by
      # the valid UTF-8 bytes of "caf\u00E9". Joining those two lines raised before.
      logger_double = double('Logger')
      logged = nil
      allow(logger_double).to receive(:info) { |message| logged = message }

      binary_request = HTTParty::Request.new(
        Net::HTTP::Get, 'http://foo.bar.com/', headers: { 'x-note' => "caf\u00E9" }
      )
      allow(binary_request).to receive(:raw_body).and_return(nil)
      binary_response_object = Net::HTTPOK.new('1.1', 200, 'OK')
      binary_body = "\xFF\xD8 ok caf\xC3\xA9".b
      binary_response = HTTParty::Response.new(
        binary_request, binary_response_object, parsed_response, body: binary_body
      )

      formatter = described_class.new(logger_double, :info)

      expect { formatter.format(binary_request, binary_response) }.not_to raise_error
      expect(logged.encoding).to eq(Encoding::UTF_8)
      expect(logged).to be_valid_encoding
      expect(logged).to include("> x-note: caf\u00E9")
      expect(logged).to include("ok caf\u00E9")
      expect(logged).to include("\uFFFD")
    end

    it "scrubs a UTF-8-tagged response body that holds invalid bytes" do
      # Input: a response body tagged UTF-8 (as after a charset=utf-8 force
      # encode) whose bytes start with the invalid sequence \xFF\xD8 and end
      # with the valid UTF-8 bytes of "caf\u00E9".
      logger_double = double('Logger')
      logged = nil
      allow(logger_double).to receive(:info) { |message| logged = message }

      utf8_request = HTTParty::Request.new(Net::HTTP::Get, 'http://foo.bar.com/')
      allow(utf8_request).to receive(:raw_body).and_return(nil)
      utf8_response_object = Net::HTTPOK.new('1.1', 200, 'OK')
      invalid_utf8_body = "\xFF\xD8 ok caf\xC3\xA9".b.force_encoding(Encoding::UTF_8)
      utf8_response = HTTParty::Response.new(
        utf8_request, utf8_response_object, parsed_response, body: invalid_utf8_body
      )

      described_class.new(logger_double, :info).format(utf8_request, utf8_response)

      expect(logged.encoding).to eq(Encoding::UTF_8)
      expect(logged).to be_valid_encoding
      expect(logged).to include("\uFFFD\uFFFD ok caf\u00E9")
    end
  end
end
