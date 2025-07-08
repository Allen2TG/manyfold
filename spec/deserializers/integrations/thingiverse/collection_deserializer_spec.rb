require "rails_helper"

RSpec.describe Integrations::Thingiverse::CollectionDeserializer, :thingiverse_api_key do
  context "when creating from URI" do
    it "accepts collection URIs" do
      deserializer = described_class.new(uri: "https://www.thingiverse.com/floppy_uk/collections/16696069/things")
      expect(deserializer).to be_valid
    end

    it "rejects non-collection URIs" do
      deserializer = described_class.new(uri: "https://www.thingiverse.com/floppy_uk")
      expect(deserializer).not_to be_valid
    end

    it "extracts collection id" do
      deserializer = described_class.new(uri: "https://www.thingiverse.com/floppy_uk/collections/16696069/things")
      expect(deserializer.collection_id).to eq "16696069"
    end
  end

  context "when pulling data from API", vcr: {cassette_name: "Integrations_Thingiverse_CollectionDeserializer/success"} do
    subject(:deserializer) { described_class.new(uri: uri) }

    let(:uri) { "https://www.thingiverse.com/floppy_uk/collections/16696069/things" }

    it "extracts name" do
      expect(deserializer.deserialize[:name]).to eq "Printer Upgrades"
    end

    it "extracts description" do
      expect(deserializer.deserialize[:notes]).to include "Ender 3 Pro"
    end
  end

  context "with a valid configuration" do
    subject(:deserializer) { described_class.new(uri: uri) }

    let(:uri) { "https://www.thingiverse.com/floppy_uk/collections/16696069/things" }

    it "deserializes to a Collection" do
      expect(deserializer.send(:target_class)).to eq Collection
    end

    it "is valid for deserialization to Collection" do
      expect(deserializer.valid?(for_class: Collection)).to be true
    end

    it "is not valid for deserialization to Model" do
      expect(deserializer.valid?(for_class: Model)).to be false
    end

    it "is created for this URI by a link object" do # rubocop:disable RSpec/MultipleExpectations
      des = create(:link, url: uri, linkable: create(:collection)).deserializer
      expect(des).to be_a(described_class)
      expect(des).to be_valid
    end
  end
end
