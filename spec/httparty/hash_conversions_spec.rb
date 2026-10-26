require 'spec_helper'

RSpec.describe HTTParty::HashConversions do
  describe ".to_params" do
    it "creates a params string from a hash" do
      hash = {
        name: "bob",
        address: {
          street: '111 ruby ave.',
          city: 'ruby central',
          phones: ['111-111-1111', '222-222-2222']
        }
      }
      expect(HTTParty::HashConversions.to_params(hash)).to eq("name=bob&address%5Bstreet%5D=111%20ruby%20ave.&address%5Bcity%5D=ruby%20central&address%5Bphones%5D%5B%5D=111-111-1111&address%5Bphones%5D%5B%5D=222-222-2222")
    end

    context "nested params" do
      it 'creates a params string from a hash' do
        hash = { marketing_event: { marketed_resources: [ {type:"product", id: 57474842640 } ] } }
        expect(HTTParty::HashConversions.to_params(hash)).to eq("marketing_event%5Bmarketed_resources%5D%5B%5D%5Btype%5D=product&marketing_event%5Bmarketed_resources%5D%5B%5D%5Bid%5D=57474842640")
      end

      # Input: an empty array one level inside a hash.
      it "keeps an empty array nested in a hash as an empty key[] param" do
        expect(HTTParty::HashConversions.to_params(filters: { tags: [] })).to eq("filters%5Btags%5D%5B%5D=")
      end

      # Input: an empty array two levels inside nested hashes.
      it "keeps an empty array nested two hashes deep as an empty key[] param" do
        expect(HTTParty::HashConversions.to_params(a: { b: { c: [] } })).to eq("a%5Bb%5D%5Bc%5D%5B%5D=")
      end
    end
  end

  describe ".normalize_param" do
    context "value is an array" do
      it "creates a params string" do
        expect(
          HTTParty::HashConversions.normalize_param(:people, ["Bob Jones", "Mike Smith"])
        ).to eq("people%5B%5D=Bob%20Jones&people%5B%5D=Mike%20Smith&")
      end
    end

    context "value is an empty array" do
      it "creates a params string" do
        expect(
          HTTParty::HashConversions.normalize_param(:people, [])
        ).to eq("people%5B%5D=&")
      end
    end

    context "value is hash" do
      it "creates a params string" do
        expect(
          HTTParty::HashConversions.normalize_param(:person, { name: "Bob Jones" })
        ).to eq("person%5Bname%5D=Bob%20Jones&")
      end
    end

    context "value is a string" do
      it "creates a params string" do
        expect(
          HTTParty::HashConversions.normalize_param(:name, "Bob Jones")
        ).to eq("name=Bob%20Jones&")
      end
    end
  end
end
