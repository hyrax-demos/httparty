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

    context 'when the response body is binary' do
      let(:logger_double)        { double('Logger') }
      let(:binary_request)       { HTTParty::Request.new(Net::HTTP::Get, 'http://foo.bar.com/') }
      let(:binary_response_obj)  { Net::HTTPOK.new('1.1', 200, 'OK') }
      let(:binary_response)      { HTTParty::Response.new(binary_request, binary_response_obj, parsed_response) }

      def format_with(raw_body:, body:)
        allow(binary_request).to receive(:raw_body).and_return(raw_body)
        allow(binary_response_obj).to receive_messages(body: body)
        binary_response_obj['header-key'] = 'header-value'

        described_class.new(logger_double, :info).format(binary_request, binary_response)
      end

      # Input: a non-ASCII UTF-8 request body logged together with an
      # ASCII-8BIT response body holding bytes that are not valid UTF-8.
      it 'does not raise when the response body is binary and another line is non-ASCII UTF-8' do
        logged = nil
        expect(logger_double).to receive(:info) { |message| logged = message }

        format_with(raw_body: "name=J\u00f6hn", body: "\xFF\xD8\xFF\xE0".b)

        expect(logged).to be_valid_encoding
        expect(logged).to include("J\u00f6hn")
        expect(logged).to include("\uFFFD")
      end

      # Input: an ASCII-8BIT response body whose bytes are valid UTF-8 text.
      it 'logs a binary-tagged body holding valid UTF-8 bytes as readable text' do
        logged = nil
        expect(logger_double).to receive(:info) { |message| logged = message }

        format_with(raw_body: 'content', body: "caf\u00e9".b)

        expect(logged).to be_valid_encoding
        expect(logged).to include("caf\u00e9")
      end
    end
  end
end
