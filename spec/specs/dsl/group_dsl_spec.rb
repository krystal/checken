require 'spec_helper'
require 'checken/schema'

describe Checken::DSL::GroupDSL do

  subject(:schema) { Checken::Schema.new }

  it "should allow sub groups to be added" do
    schema.root_group.dsl do
      group :test1 do
        group :test2
      end
    end
    expect(schema.root_group[:test1]).to be_a Checken::PermissionGroup
    expect(schema.root_group[:test1].path).to eq "test1"
    expect(schema.root_group[:test1][:test2]).to be_a Checken::PermissionGroup
    expect(schema.root_group[:test1][:test2].path).to eq "test1.test2"
  end

  it "should allow permissions to be added" do
    schema.root_group.dsl do
      permission :change_password
    end
    expect(schema.root_group[:change_password]).to be_a Checken::Permission
  end

  it "should allow permissions to be added with a description" do
    schema.root_group.dsl do
      permission :change_password, "Can change password"
    end
    expect(schema.root_group[:change_password]).to be_a Checken::Permission
    expect(schema.root_group[:change_password].description).to eq "Can change password"
  end

  it "should allow rules to be defined" do
    schema.root_group.dsl do
      define_rule(:global_rule) { 1234 }
    end
    expect(schema.root_group.defined_rules[:global_rule]).to be_a Checken::Rule
  end

  it "should be able set dependencies to all permissions within a group" do
    schema.root_group.dsl do
      permission :view, "Can view thing"
      group :edit do
        set do
          depends_on "view"
          permission :any, "Can edit any details"
          permission :archived, "Can edit archived things"
          set do
            depends_on "view.any"
            permission :something, "Can do something"
          end
          permission :something_else, "Can do something else"
        end
      end
      permission :delete, "Can delete"
    end

    expect(schema.root_group[:edit][:any].dependencies).to include("view")
    expect(schema.root_group[:edit][:archived].dependencies).to include("view")
    expect(schema.root_group[:edit][:something].dependencies).to include("view")
    expect(schema.root_group[:edit][:something].dependencies).to include("view.any")
    expect(schema.root_group[:edit][:something_else].dependencies).to include("view")
    expect(schema.root_group[:edit][:something_else].dependencies).to_not include("view.any")
    expect(schema.root_group[:delete].dependencies).to be_empty
  end

  context 'when reopening groups' do
    before do
      schema.root_group.dsl do
        group :projects do
          permission :list
          group :edit do
            permission :details
          end
        end
        group :projects do
          permission :view
          group :edit do
            permission :icon
          end
        end
      end
    end

    it "should reopen groups if they already have been defined" do
      expect(schema.root_group[:projects][:list]).to be_a Checken::Permission
      expect(schema.root_group[:projects][:view]).to be_a Checken::Permission
      expect(schema.root_group[:projects][:edit][:details]).to be_a Checken::Permission
      expect(schema.root_group[:projects][:edit][:icon]).to be_a Checken::Permission
    end

    it "should not add duplicate entries to the schema" do
      expect(schema.schema).to eq(
        {
        "projects" => {description: nil, group: nil, name: nil, type: :group},
        "projects.edit" => {description: nil, group: "projects", name: nil, type: :group},
        "projects.edit.details" => {description: "projects.edit.details", group: "projects.edit", type: :permission},
        "projects.edit.icon" => {description: "projects.edit.icon", group: "projects.edit", type: :permission},
        "projects.list" => {description: "projects.list", group: "projects", type: :permission},
        "projects.view" => {description: "projects.view", group: "projects", type: :permission},
        }
      )
    end
  end

end
