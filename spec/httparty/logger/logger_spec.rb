require 'spec_helper'

RSpec.describe HTTParty::Logger do
  describe ".build" do
    subject { HTTParty::Logger }

    it "defaults level to :info" do
      logger_double = double
      expect(subject.build(logger_double, nil, nil).level).to eq(:info)
    end

    it "defaults format to :apache" do
      logger_double = double
      expect(subject.build(logger_double, nil, nil)).to be_an_instance_of(HTTParty::Logger::ApacheFormatter)
    end

    it "builds :curl style logger" do
      logger_double = double
      expect(subject.build(logger_double, nil, :curl)).to be_an_instance_of(HTTParty::Logger::CurlFormatter)
    end

    it "builds :logstash style logger" do
      logger_double = double
      expect(subject.build(logger_double, nil, :logstash)).to be_an_instance_of(HTTParty::Logger::LogstashFormatter)
    end

    it "builds :custom style logger" do
      CustomFormatter = Class.new(HTTParty::Logger::CurlFormatter)
      HTTParty::Logger.add_formatter(:custom, CustomFormatter)

      logger_double = double
      expect(subject.build(logger_double, nil, :custom)).
        to be_an_instance_of(CustomFormatter)
    end
    it "raises error when formatter exists" do
      CustomFormatter2= Class.new(HTTParty::Logger::CurlFormatter)
      HTTParty::Logger.add_formatter(:custom2, CustomFormatter2)

      expect{ HTTParty::Logger.add_formatter(:custom2, CustomFormatter2) }.
        to raise_error HTTParty::Error
    end

    it "raises error and keeps the built-in when the String 'curl' is added" do
      # Input: the String form of the built-in :curl name.
      original = HTTParty::Logger.formatters[:curl]
      custom = Class.new(HTTParty::Logger::CurlFormatter)
      begin
        expect { HTTParty::Logger.add_formatter('curl', custom) }.
          to raise_error HTTParty::Error
        expect(HTTParty::Logger.formatters[:curl]).to eq(HTTParty::Logger::CurlFormatter)
      ensure
        HTTParty::Logger.formatters[:curl] = original
      end
    end

    it "raises error when the same String name is added twice" do
      formatter = Class.new(HTTParty::Logger::CurlFormatter)
      HTTParty::Logger.add_formatter('string_dup_formatter_spec', formatter)

      expect { HTTParty::Logger.add_formatter('string_dup_formatter_spec', formatter) }.
        to raise_error HTTParty::Error
    end

    it "raises error when a String name matches a registered Symbol" do
      formatter = Class.new(HTTParty::Logger::CurlFormatter)
      HTTParty::Logger.add_formatter(:symbol_then_string_formatter_spec, formatter)

      expect { HTTParty::Logger.add_formatter('symbol_then_string_formatter_spec', formatter) }.
        to raise_error HTTParty::Error
    end

    it "stores a String name under its Symbol key" do
      formatter = Class.new(HTTParty::Logger::CurlFormatter)
      HTTParty::Logger.add_formatter('string_stored_as_symbol_formatter_spec', formatter)

      expect(HTTParty::Logger.formatters[:string_stored_as_symbol_formatter_spec]).to eq(formatter)
    end
  end
end
