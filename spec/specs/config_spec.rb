require 'spec_helper'
require 'checken/config'

RSpec.describe Checken::Config do

  subject(:config) { Checken::Config.new }

  describe "#namespace_delimiter" do
    it "should return the default namespace delimiter" do
      expect(config.namespace_delimiter).to eq ":"
    end

    context "when a custom delimiter is set" do
      it "should return the custom delimiter" do
        config.namespace_delimiter = "/"
        expect(config.namespace_delimiter).to eq "/"
      end
    end
  end

  describe "#namespace" do
    it "should return nil by default" do
      expect(config.namespace).to be_nil
    end

    context "when a custom namespace is set" do
      it "should return the custom namespace" do
        config.namespace = "custom"
        expect(config.namespace).to eq "custom"
      end
    end
  end

end
