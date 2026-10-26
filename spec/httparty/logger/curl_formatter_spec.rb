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

  describe "#format with binary bodies" do
    let(:logger_double)   { double('Logger') }
    let(:response_object) { Net::HTTPOK.new('1.1', 200, 'OK') }
    let(:parsed_response) { lambda { {"foo" => "bar"} } }

    subject { described_class.new(logger_double, :info) }

    it "logs a binary response body next to a non-ASCII UTF-8 header as valid UTF-8" do
      # Input: an ASCII-8BIT response body with high bytes (some invalid as
      # UTF-8, plus the UTF-8 bytes of "café"), and a request header whose
      # value is UTF-8 with a non-ASCII character. Binary data is built at run
      # time rather than stored as a fixture file.
      binary_body = "\xFF\xD8\xFF\xE0 caf\xC3\xA9".b
      request = HTTParty::Request.new(
        Net::HTTP::Get, 'http://foo.bar.com/', headers: { 'X-Name' => "caf\u00e9" }
      )
      allow(request).to receive(:raw_body).and_return(nil)
      response = HTTParty::Response.new(request, response_object, parsed_response, body: binary_body)

      logged = nil
      allow(logger_double).to receive(:info) { |message| logged = message }

      expect { subject.format(request, response) }.not_to raise_error
      expect(logged.encoding).to eq(Encoding::UTF_8)
      expect(logged).to be_valid_encoding
      expect(logged).to include("X-Name: caf\u00e9")
      expect(logged).to include("caf\u00e9")
      expect(logged).to include("\uFFFD")
      expect(binary_body.encoding).to eq(Encoding::ASCII_8BIT)
      expect(response.body).to equal(binary_body)
    end

    it "logs a binary request raw_body next to a non-ASCII UTF-8 response body as valid UTF-8" do
      # Input: an ASCII-8BIT multipart-style request raw_body with high bytes,
      # and a UTF-8 response body with a non-ASCII character. Binary data is
      # built at run time rather than stored as a fixture file.
      raw_body = "--boundary\r\nContent-Type: image/jpeg\r\n\r\n\xFF\xD8\xFF\xE0\r\n--boundary--\r\n".b
      request = HTTParty::Request.new(Net::HTTP::Post, 'http://foo.bar.com/')
      allow(request).to receive(:raw_body).and_return(raw_body)
      response = HTTParty::Response.new(
        request, response_object, parsed_response, body: "{\"name\":\"caf\u00e9\"}"
      )

      logged = nil
      allow(logger_double).to receive(:info) { |message| logged = message }

      expect { subject.format(request, response) }.not_to raise_error
      expect(logged.encoding).to eq(Encoding::UTF_8)
      expect(logged).to be_valid_encoding
      expect(logged).to include("caf\u00e9")
      expect(logged).to include("\uFFFD")
      expect(logged).to include("Content-Type: image/jpeg")
      expect(raw_body.encoding).to eq(Encoding::ASCII_8BIT)
    end
  end

  describe "#format with UTF-16 strings" do
    let(:logger_double)   { double('Logger') }
    let(:response_object) { Net::HTTPOK.new('1.1', 200, 'OK') }
    let(:parsed_response) { lambda { {"foo" => "bar"} } }

    subject { described_class.new(logger_double, :info) }

    it "logs a response body relabelled UTF-16LE by its charset as valid UTF-8" do
      # Input: a response with Content-Type charset=utf-16 and a body of
      # UTF-16LE bytes (with a little endian BOM) spelling "café", performed
      # with log_format: :curl so Request#perform relabels the body before
      # the formatter logs it. Bytes are built at run time rather than stored
      # as a fixture file.
      logged = nil
      allow(logger_double).to receive(:info) { |message| logged = message }
      @request = HTTParty::Request.new(
        Net::HTTP::Get, 'http://foo.bar.com/', logger: logger_double, log_format: :curl
      )
      stubbed = stub_response "\xFF\xFEc\x00a\x00f\x00\xE9\x00".b
      stubbed.initialize_http_header("Content-Type" => "text/plain;charset=utf-16")

      resp = nil
      expect { resp = @request.perform }.not_to raise_error
      expect(resp.body.encoding).to eq(Encoding::UTF_16LE)
      expect(logged.encoding).to eq(Encoding::UTF_8)
      expect(logged).to be_valid_encoding
      expect(logged).to include("caf\u00e9")
    end

    it "logs a UTF-16LE query value as valid UTF-8" do
      # Input: a request whose query hash has a value encoded as UTF-16LE.
      request = HTTParty::Request.new(
        Net::HTTP::Get, 'http://foo.bar.com/', query: { name: "caf\u00e9".encode(Encoding::UTF_16LE) }
      )
      allow(request).to receive(:raw_body).and_return(nil)
      response = HTTParty::Response.new(request, response_object, parsed_response, body: "ok")

      logged = nil
      allow(logger_double).to receive(:info) { |message| logged = message }

      expect { subject.format(request, response) }.not_to raise_error
      expect(logged.encoding).to eq(Encoding::UTF_8)
      expect(logged).to be_valid_encoding
      expect(logged).to include("name: caf\u00e9")
    end
  end

  describe "#format with encodings Ruby cannot convert to UTF-8" do
    let(:logger_double)   { double('Logger') }
    let(:response_object) { Net::HTTPOK.new('1.1', 200, 'OK') }
    let(:parsed_response) { lambda { {"foo" => "bar"} } }

    subject { described_class.new(logger_double, :info) }

    it "logs a response body relabelled UTF-7 by its charset as valid UTF-8" do
      # Input: a response with Content-Type charset=utf-7, performed with
      # log_format: :curl so Request#perform relabels the body as the dummy
      # UTF-7 encoding, which has no converter to UTF-8. The body holds the
      # UTF-7 spelling of "café" and one high byte. Bytes are built at run
      # time rather than stored as a fixture file.
      logged = nil
      allow(logger_double).to receive(:info) { |message| logged = message }
      @request = HTTParty::Request.new(
        Net::HTTP::Get, 'http://foo.bar.com/', logger: logger_double, log_format: :curl
      )
      stubbed = stub_response "caf+AOk- \xFF".b
      stubbed.initialize_http_header("Content-Type" => "text/plain;charset=utf-7")

      resp = nil
      expect { resp = @request.perform }.not_to raise_error
      expect(resp.body.encoding).to eq(Encoding::UTF_7)
      expect(logged.encoding).to eq(Encoding::UTF_8)
      expect(logged).to be_valid_encoding
      expect(logged).to include("caf+AOk- \uFFFD")
    end

    it "logs an Emacs-Mule query value with non-ASCII bytes as valid UTF-8" do
      # Input: a request whose query hash has a value labelled Emacs-Mule
      # that holds non-ASCII bytes; Ruby has no Emacs-Mule to UTF-8
      # converter. Bytes are built at run time rather than stored as a
      # fixture file.
      value = "caf\x81\xE9".b.force_encoding(Encoding.find('Emacs-Mule'))
      request = HTTParty::Request.new(
        Net::HTTP::Get, 'http://foo.bar.com/', query: { name: value }
      )
      allow(request).to receive(:raw_body).and_return(nil)
      response = HTTParty::Response.new(request, response_object, parsed_response, body: "ok")

      logged = nil
      allow(logger_double).to receive(:info) { |message| logged = message }

      expect { subject.format(request, response) }.not_to raise_error
      expect(logged.encoding).to eq(Encoding::UTF_8)
      expect(logged).to be_valid_encoding
      expect(logged).to include("name: caf\uFFFD")
      expect(value.encoding).to eq(Encoding.find('Emacs-Mule'))
    end
  end
end
