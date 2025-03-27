require 'spec_helper'
require 'checken/schema'
require 'checken/permission_group'

describe Checken::PermissionGroup do

  subject(:schema) { Checken::Schema.new }

  context "#add_group" do
    it "should be able to add a group" do
      added_group = schema.root_group.add_group(:test1)
      expect(added_group).to be_a(Checken::PermissionGroup)
    end

    it "should not be able to add a group which has been added" do
      added_group = schema.root_group.add_group(:test1)
      expect { schema.root_group.add_group(:test1) }.to raise_error(Checken::Error, /already exists/)
    end
  end

  context "#add_permission" do
    it "should be able to add a permission" do
      added_group = schema.root_group.add_permission(:test1)
      expect(added_group).to be_a(Checken::Permission)
      expect(added_group.path).to eq "test1"
    end

    it "should not be able to add a permission which has been added" do
      added_group = schema.root_group.add_permission(:test1)
      expect { schema.root_group.add_permission(:test1) }.to raise_error(Checken::Error, /already exists/)
    end
  end

  context "#define_rule" do
    it "should be able to define a global rule" do
      rule = schema.root_group.define_rule(:some_global_rule, 'Account') { |user| user == 1234 }
      expect(rule).to be_a Checken::Rule
    end

    it "should not be able to define a permission that exists" do
      rule = schema.root_group.define_rule(:some_global_rule, 'Account') { |user| user == 1234 }
      expect do
        schema.root_group.define_rule(:some_global_rule, 'Account')
      end.to raise_error Checken::Error, /already been defined/
    end

    it "should not be able to define a permission that exists in a parent group" do
      group1 = schema.root_group.add_group(:group1)
      group1.define_rule(:some_global_rule, 'Account') { |user| user == 1234 }
      group2 = group1.add_group(:group2)
      expect do
        group2.define_rule(:some_global_rule, 'Account') { |user| user == 1234 }
      end.to raise_error Checken::Error, /already been defined/
    end
  end

  context "#find_permissions_from_path" do
    it "should return a top level permission" do
      permission = schema.root_group.add_permission(:change_password)
      expect(schema.root_group.find_permissions_from_path('change_password').first).to eq permission
    end

    it "should return a permission in a top level group" do
      group = schema.root_group.add_group(:user)
      permission = group.add_permission(:change_password)
      expect(schema.root_group.find_permissions_from_path('user.change_password').first).to eq permission
    end

    it "should return a permission in a second level group" do
      group1 = schema.root_group.add_group(:users)
      group2 = group1.add_group(:manage)
      permission = group2.add_permission(:edit)
      expect(schema.root_group.find_permissions_from_path('users.manage.edit').first).to eq permission
    end

    it "should raise an error if no permission is found" do
      expect { schema.root_group.find_permissions_from_path('some.invalid.permission') }.to raise_error(Checken::PermissionNotFoundError)
    end

    it "should raise an error if a permission is found early in the path" do
      permission = schema.root_group.add_permission(:change_password)
      expect { schema.root_group.find_permissions_from_path('change_password.something') }.to raise_error(Checken::Error, /too early/)
    end

    it "should raise an error if the final return is not a permission" do
      group1 = schema.root_group.add_group(:users)
      group2 = group1.add_group(:manage)
      expect { schema.root_group.find_permissions_from_path('users.manage') }.to raise_error(Checken::Error, /Last part of path was not a permission/)
    end

    it "should raise an error if the given permission is blank or nil" do
      expect { schema.root_group.find_permissions_from_path('') }.to raise_error(Checken::PermissionNotFoundError)
      expect { schema.root_group.find_permissions_from_path(nil) }.to raise_error(Checken::PermissionNotFoundError)
    end

    it "should work with a trailing wildcard" do
      group = schema.root_group.add_group(:users)
      p1 = group.add_permission(:add)
      p2 = group.add_permission(:edit)
      p3 = group.add_permission(:delete)

      found_permissions = schema.root_group.find_permissions_from_path("users.*")
      expect(found_permissions.size).to eq 3
      expect(found_permissions[0]).to eq p1
      expect(found_permissions[1]).to eq p2
      expect(found_permissions[2]).to eq p3
    end

    it "should include all sub group permissions with a double wildcard" do
      group = schema.root_group.add_group(:users)
      p1 = group.add_permission(:add)
      group2 = group.add_group(:subgroup)
      p2 = group2.add_permission(:edit)
      p3 = group2.add_permission(:delete)

      found_permissions = schema.root_group.find_permissions_from_path("users.**.*")
      expect(found_permissions.size).to eq 3
      expect(found_permissions).to include p1
      expect(found_permissions).to include p2
      expect(found_permissions).to include p3
    end

    context "when the schema config has a namespace specified" do
      let!(:group) { schema.root_group.add_group(:users) }
      let!(:p1) { group.add_permission(:add) }
      let!(:group2) { group.add_group(:subgroup) }
      let!(:p2) { group2.add_permission(:edit) }
      let!(:p3) { group2.add_permission(:delete) }

      before do
        schema.config.namespace = "test"
      end

      context "when the namespace matches the schema namespace" do
        it "should return the permission with the namespace" do
          expect(schema.root_group.find_permissions_from_path("test:users.add")).to eq([p1])
          expect(schema.root_group.find_permissions_from_path("test:users.subgroup.edit")).to eq([p2])
          expect(schema.root_group.find_permissions_from_path("test:users.subgroup.delete")).to eq([p3])
        end
      end

      context "when the namespace is omitted" do
        it "raises a Checken::Error" do
          expect { schema.root_group.find_permissions_from_path("users.add") }.to raise_error(Checken::Error, /Namespace: 'test' is missing in path/)
          expect { schema.root_group.find_permissions_from_path("users.subgroup.edit") }.to raise_error(Checken::Error, /Namespace: 'test' is missing in path/)
          expect { schema.root_group.find_permissions_from_path("users.subgroup.delete") }.to raise_error(Checken::Error, /Namespace: 'test' is missing in path/)
        end
      end

      context "when the namespace does not match the schema namespace" do
        it "raises a Checken::Error" do
          expect { schema.root_group.find_permissions_from_path("foo:users.add") }.to raise_error(Checken::Error, /does not match the schema namespace/)
          expect { schema.root_group.find_permissions_from_path("foo:users.subgroup.edit") }.to raise_error(Checken::Error, /does not match the schema namespace/)
          expect { schema.root_group.find_permissions_from_path("foo:users.subgroup.delete") }.to raise_error(Checken::Error, /does not match the schema namespace/)
        end
      end

      context "when the namespace is optional" do
        before do
          schema.config.namespace_optional = true
        end

        context "when the namespace is omitted" do
          it "should return the permission without the namespace" do
            expect(schema.root_group.find_permissions_from_path("users.add")).to eq([p1])
            expect(schema.root_group.find_permissions_from_path("users.subgroup.edit")).to eq([p2])
            expect(schema.root_group.find_permissions_from_path("users.subgroup.delete")).to eq([p3])
          end
        end

        context "when the namespace matches the schema namespace" do
          it "should return the permission with the namespace" do
            expect(schema.root_group.find_permissions_from_path("test:users.add")).to eq([p1])
            expect(schema.root_group.find_permissions_from_path("test:users.subgroup.edit")).to eq([p2])
            expect(schema.root_group.find_permissions_from_path("test:users.subgroup.delete")).to eq([p3])
          end
        end

        context "when the namespace does not match the schema namespace" do
          it "raises a Checken::Error" do
            expect { schema.root_group.find_permissions_from_path("foo:users.add") }.to raise_error(Checken::Error, /does not match the schema namespace/)
            expect { schema.root_group.find_permissions_from_path("foo:users.subgroup.edit") }.to raise_error(Checken::Error, /does not match the schema namespace/)
            expect { schema.root_group.find_permissions_from_path("foo:users.subgroup.delete") }.to raise_error(Checken::Error, /does not match the schema namespace/)
          end
        end
      end
    end
  end

  context "#all_permissions" do
    it "should return all the groups own permissions" do
      permission = schema.root_group.add_permission(:change_password)
      expect(schema.root_group.all_permissions.size).to eq 1
      expect(schema.root_group.all_permissions).to include permission
    end

    it "should return all permissions within any sub groups" do
      group1 = schema.root_group.add_group(:group1)
      p1 = group1.add_permission(:perm1)
      group2 = group1.add_group(:group1)
      p2 = group2.add_permission(:perm2)
      group3 = group2.add_group(:group3)
      p3 = group2.add_permission(:perm3)
      expect(group1.all_permissions.size).to eq 3
      expect(group1.all_permissions).to include p1
      expect(group1.all_permissions).to include p2
      expect(group1.all_permissions).to include p3
    end
  end

  it "should raise an error if a group is created without a key" do
    pg1 = Checken::PermissionGroup.new(schema, nil)
    expect { Checken::PermissionGroup.new(schema, pg1) }.to raise_error(Checken::Error, /without a key/)
  end

  it "should raise an error if a key is given for a root group" do
    expect { Checken::PermissionGroup.new(schema, nil, :test) }.to raise_error(Checken::Error, /with a key/)
  end

  describe "#update_schema" do
    context "when the group has no path" do
      it "does not update the schema" do
        group = Checken::PermissionGroup.new(schema, nil)
        group.update_schema
        expect(schema.schema).to eq({})
      end
    end

    context "when the group is a sub-group of the root group" do
      it "updates the schema" do
        group = Checken::PermissionGroup.new(schema, schema.root_group, :test).tap do |g|
          g.name = "Group name"
          g.description = "Group description"
        end
        group.update_schema
        expect(schema.schema).to eq(
          {
            'test' => {
              description: "Group description",
              group: nil,
              name: "Group name",
              type: :group
            }
          }
        )
      end
    end

    context "when the group is a sub-group of another group" do
      it "updates the schema" do
        group = Checken::PermissionGroup.new(schema, schema.root_group, :test).tap do |g|
          g.name = "Group name"
          g.description = "Group description"
        end


        sub_group = Checken::PermissionGroup.new(schema, group, :sub_group).tap do |g|
          g.name = "Sub-group name"
          g.description = "Sub-group description"
        end
        sub_group.update_schema
        expect(schema.schema).to eq(
          {
            'test.sub_group' => {
              description: "Sub-group description",
              group: 'test',
              name: "Sub-group name",
              type: :group
            }
          }
        )
      end
    end
  end

end
