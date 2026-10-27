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
  end

  describe "#format with a binary response body" do
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

    # Kept outside the "#format" describe so its before block, which calls
    # format with an ASCII-only body, does not run first.
    # The input is a body of high bytes (ASCII-8BIT, as a JPEG header) logged
    # together with a request body that holds a non-ASCII UTF-8 character.
    before do
      allow(logger).to receive(:info)
      allow(request).to receive(:raw_body).and_return('café')
      allow(response_object).to receive_messages(body: "\xFF\xD8\xFF\xE0".b)
      response_object['header-key'] = 'header-value'
    end

    it 'logs a valid UTF-8 message without raising' do
      expect { subject.format request, response }.not_to raise_error

      expect(logger).to have_received(:info).with(
        satisfy { |message|
          message.include?('café') &&
            message.encoding == Encoding::UTF_8 &&
            message.valid_encoding?
        }
      )
    end
  end
end
