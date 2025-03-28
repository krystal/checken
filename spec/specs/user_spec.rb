require 'spec_helper'

describe Checken::User do

  subject(:schema) do
    schema = Checken::Schema.new
    schema.root_group.add_permission('change_password')
    schema
  end
  before(:each) { Checken.current_schema = schema }
  after(:each) { Checken.current_schema = nil }

  context "#can?" do
    it "should return true when permission is granted" do
      user = FakeUser.new(['change_password'])
      expect(user.can?('change_password')).to be true
    end

    it "should return false when permission is denied" do
      user = FakeUser.new(['other'])
      expect(user.can?('change_password')).to be false
    end

    it "should allow a schema to be provided as an option" do
      other_schema = Checken::Schema.new
      other_schema.root_group.add_permission 'logout'
      user = FakeUser.new(['logout'])
      expect(user.can?('logout', :schema => other_schema)).to be true
    end

    # strict: false means the permission does not need to exist in the schema
    context "when checking a permission with strict false" do
      it "should return true when permission is granted" do
        user = FakeUser.new(['change_password'])
        expect(user.can?('change_password', strict: false)).to be true
      end

      it "should return true when permission is granted with a namespace" do
        user = FakeUser.new(['app:change_password'])
        expect(user.can?('app:change_password', strict: false)).to be true
      end

      it "should return false when the namespace is omitted" do
        user = FakeUser.new(['app1:change_password', 'app2:change_password'])
        expect(user.can?('change_password', strict: false)).to be false
      end
    end
  end

  context "check_permission!" do
    it "should return an array  when permission is granted" do
      user = FakeUser.new(['change_password'])
      expect(user.check_permission!('change_password')).to be_a Array
      expect(user.check_permission!('change_password')[0].key).to eq :change_password
    end

    it "should raise an error when permission is denied" do
      user = FakeUser.new([])
      expect { user.check_permission!('change_password') }.to raise_error(Checken::PermissionDeniedError)
    end
  end
end
