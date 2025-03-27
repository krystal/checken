require 'spec_helper'
require 'checken/permission'
require 'checken/schema'

describe Checken::Permission do

  subject(:schema) { Checken::Schema.new }
  subject(:group) { schema.root_group }
  subject(:permission) { schema.root_group.add_permission(:change_password) }

  context "#initialize" do
    it "should not be able to created without a group" do
      expect { Checken::Permission.new(nil, :change_password) }.to raise_error Checken::Error
    end
  end

  context "#path" do
    it "should return the path" do
      expect(permission.path).to eq 'change_password'
    end

    it "should include the groups path" do
      another_group = schema.root_group.add_group(:user)
      permission = another_group.add_permission(:change_password)
      expect(permission.path).to eq 'user.change_password'
    end
  end

  context "#add_rule" do
    it "should be able to add a rule" do
      rule = permission.add_rule(:must_belong_to_account) { |user| user == 1234}
      expect(rule).to be_a(Checken::Rule)
    end

    it "should raise an error when a rule already exists on this permission" do
      rule = permission.add_rule(:must_belong_to_account) { |user| user == 1234}
      expect { permission.add_rule(:must_belong_to_account) { |user| user == 1234 } }.to raise_error Checken::Error, /already exists/
    end
  end

  context "#include_rule" do
    it "should be able to include a rule" do
      rule = permission.include_rule(:a_global_rule)
      expect(rule).to be_a Checken::IncludedRule
    end

    it "should be able to specify a condition" do
      condition = proc { true }
      rule = permission.include_rule(:a_global_rule, :if => condition)
      expect(rule.condition).to eq condition
    end

    it "should raise an error if already included" do
      rule = permission.include_rule(:a_global_rule)
      expect { permission.include_rule(:a_global_rule)}.to raise_error Checken::Error, /already been included/
    end
  end

  context "#add_context" do
    it "should be able to add a context" do
      permission.add_context(:admin)
      expect(permission.contexts).to include :admin
    end

    it "should return false if a context already exists" do
      expect(permission.add_context(:admin)).to eq :admin
      expect(permission.add_context(:admin)).to be false
    end
  end

  context "#remove_all_contexts" do
    it "should be able to remove all contexts" do
      expect(permission.contexts.size).to eq 0
      permission.add_context(:admin)
      expect(permission.contexts.size).to eq 1
      permission.remove_all_contexts
      expect(permission.contexts.size).to eq 0
    end
  end


  context "#add_dependency" do
    it "should be able to add a dependency" do
      permission.add_dependency("view.thing")
      expect(permission.dependencies).to include "view.thing"
    end

    it "should return false if a dependency already exists" do
      expect(permission.add_dependency("view.thing")).to eq "view.thing"
      expect(permission.add_dependency("view.thing")).to be false
    end
  end

  context "#add_required_object_type" do
    it "should be able to add a required object type" do
      permission.add_required_object_type("Account")
      expect(permission.required_object_types).to include "Account"
    end

    it "should return false if a context already exists" do
      expect(permission.add_required_object_type("Account")).to eq "Account"
      expect(permission.add_required_object_type("Account")).to be false
    end
  end

  context "#parents" do
    it "should include the root group" do
      expect(permission.parents.size).to eq 1
      expect(permission.parents.first.key).to eq nil
    end

    it "should include other groups in order" do
      another_group = schema.root_group.add_group(:user)
      permission = another_group.add_permission(:change_password)
      expect(permission.parents.size).to eq 2
      expect(permission.parents[0].key).to eq nil
      expect(permission.parents[1].key).to eq :user
    end

    it "should include other groups in order" do
      another_group1 = schema.root_group.add_group(:user)
      another_group2 = another_group1.add_group(:subgroup)
      permission = another_group2.add_group(:change_password)
      expect(permission.parents.size).to eq 3
      expect(permission.parents[0].key).to eq nil
      expect(permission.parents[1].key).to eq :user
      expect(permission.parents[2].key).to eq :subgroup
    end

  end

  context "#required_object_types" do
    it "should be settable after initialization" do
      permission = schema.root_group.add_permission(:change_password)
      expect(permission.required_object_types).to be_a Array
      permission.required_object_types << 'FakeUser'
      expect(permission.required_object_types).to include 'FakeUser'
    end
  end

  context "#check!" do
    subject(:user) { FakeUser.new(['change_password']) }

    it "should return an array if there are no rules and is granted" do
      permission = schema.root_group.add_permission(:change_password)
      expect(permission.check!(user)).to be_a Array
      expect(permission.check!(user).size).to eq 1
    end

    it "should return an array if all the rules are satisified" do
      permission = schema.root_group.add_permission(:change_password)
      permission.add_rule(:must_be_called_adam) { |user| user.name == "Adam" }
      user.name = "Adam"
      expect(permission.check!(user)).to be_a Array
      expect(permission.check!(user).size).to eq 1
    end

    it "should raise an error if the user is not granted the permission" do
      permission = schema.root_group.add_permission(:two_factor_auth)
      expect { permission.check!(user) }.to raise_error Checken::PermissionDeniedError do |e|
        expect(e.code).to eq 'PermissionNotGranted'
        expect(e.permission).to eq permission
      end
    end

    it "should raise an error if an invalid object is provided" do
      permission = schema.root_group.add_permission(:change_password)
      permission.required_object_types << 'Array'
      expect { permission.check!(user, Hash.new) }.to raise_error(Checken::InvalidObjectError)
    end

    it "should raise an error if any rule is not satisfied" do
      permission = schema.root_group.add_permission(:change_password)
      rule = permission.add_rule(:must_be_called_adam) { |user| user.name == "Adam" }
      user.name = "Dan"
      expect { permission.check!(user) }.to raise_error Checken::PermissionDeniedError do |e|
        expect(e.code).to eq 'RuleNotSatisifed'
        expect(e.permission).to eq permission
        expect(e.rule.rule).to eq rule
      end
    end

    it "should invoke dependent permissions" do
      permission1 = group.add_permission(:change_password)
      permission2 = group.add_permission(:change_to_insecure_password)
      permission2.dependencies << 'change_password'

      user = FakeUser.new(['change_password', 'change_to_insecure_password'])
      expect(permission2.check!(user)).to be_a Array
      expect(permission2.check!(user).size).to eq 2
      expect(permission2.check!(user)).to include permission1
      expect(permission2.check!(user)).to include permission2
    end

    it "should invoke dependent permissions (with error)" do
      permission1 = group.add_permission(:change_password)
      permission2 = group.add_permission(:change_to_insecure_password)
      permission2.dependencies << 'change_password'

      user = FakeUser.new(['change_to_insecure_password'])
      expect { permission1.check!(user) }.to raise_error Checken::PermissionDeniedError
      expect { permission2.check!(user) }.to raise_error Checken::PermissionDeniedError do |e|
        expect(e.code).to eq 'PermissionNotGranted'
        expect(e.permission).to eq permission1
      end
    end

    it "should raise an error if not in the correct context" do
      permission1 = group.add_permission(:change_password)
      permission1.contexts << :admin
      user = FakeUser.new(['change_password'])
      user.checken_contexts << :reseller
      expect { permission1.check!(user) }.to raise_error Checken::PermissionDeniedError do |e|
        expect(e.code).to eq 'NotInContext'
        expect(e.permission).to eq permission1
      end
    end

    it "should be granted in the corrext context" do
      permission1 = group.add_permission(:change_password)
      permission1.contexts << :admin
      user = FakeUser.new(['change_password'])
      user.checken_contexts << :admin
      expect { permission1.check!(user) }.to_not raise_error
    end

    it "should be granted in the corrext context when given an array" do
      permission1 = group.add_permission(:change_password)
      permission1.contexts << :admin
      user = FakeUser.new(['change_password'])
      user.checken_contexts << :reseller
      user.checken_contexts << :admin
      expect { permission1.check!(user) }.to_not raise_error
    end

    it "should include the user with the error" do
      permission1 = group.add_permission(:change_password)
      user = FakeUser.new([])
      expect { permission1.check!(user) }.to raise_error Checken::PermissionDeniedError do |e|
        expect(e.user).to eq user
      end
    end

    it "should include the object with the error" do
      permission1 = group.add_permission(:change_password)
      permission1.required_object_types << 'FakeProject'
      user = FakeUser.new([])
      object = FakeProject.new(:test)
      expect { permission1.check!(user, object) }.to raise_error Checken::PermissionDeniedError do |e|
        expect(e.object).to eq object
      end
    end

    it "should include allow rules to garnish the error" do
      permission1 = group.add_permission(:change_password)
      permission1.add_rule(:some_rule) do |user, object, re|
        re.memo[:in_error] = 12345
        false
      end
      expect { permission1.check!(FakeUser.new(['change_password'])) }.to raise_error Checken::PermissionDeniedError do |e|
        expect(e.rule).to be_a Checken::RuleExecution
        expect(e.rule.memo[:in_error]).to eq 12345
      end
    end

    it "should raise an error if included rules are invalid" do
      rule = group.define_rule(:global_rule) { |user, object| object == "Hello!" }
      permission = group.add_permission(:change_password)
      permission.include_rule(:global_rule)
      expect { permission.check!(user, 'Goodbye') }.to raise_error Checken::PermissionDeniedError do |e|
        expect(e.code).to eq 'IncludedRuleNotSatisifed'
        expect(e.rule.rule).to eq rule
      end
    end
  end

  context "#first_unsatisfied_included_rule" do
    subject(:permission) { schema.root_group.add_permission(:edit_project) }
    subject(:user_proxy) { Checken::UserProxy.new(FakeUser.new([permission.path])) }

    it "should return nil when no included rules" do
      expect(permission.first_unsatisfied_included_rule(user_proxy, nil)).to be nil
    end

    it "should return the first included rule which isn't valid" do
      included_rule = schema.root_group.define_rule(:global_rule) { false }
      permission.include_rule(:global_rule)
      fake_project = FakeProject.new('Example', true)
      rule = permission.first_unsatisfied_included_rule(user_proxy, fake_project)
      expect(rule).to be_a Checken::RuleExecution
      expect(rule.rule.key).to eq :global_rule
      expect(rule.rule).to eq included_rule
    end

    it "should translate objects on included rules as appropriate" do
      included_rule = schema.root_group.define_rule(:global_rule) { |user, object| object == "12345" }
      permission.include_rule(:global_rule) { |object| object.to_i }
      rule = permission.first_unsatisfied_included_rule(user_proxy, "12345")
      expect(rule).to be_a Checken::RuleExecution
      expect(rule.rule.key).to eq :global_rule
      expect(rule.object).to eq 12345
    end

    it "should raise an error if an included rule isn't present" do
      permission.include_rule(:global_rule)
      expect do
        permission.first_unsatisfied_included_rule(user_proxy, "12345")
      end.to raise_error Checken::Error, /No defined rule/
    end

    it "should raise an error with invalid objects" do
      schema.root_group.define_rule(:global_rule, 'String') { true }
      permission.include_rule(:global_rule)
      expect { permission.first_unsatisfied_included_rule(user_proxy, 1234) }.to raise_error Checken::InvalidObjectError
      expect { permission.first_unsatisfied_included_rule(user_proxy, Array.new) }.to raise_error Checken::InvalidObjectError
      expect { permission.first_unsatisfied_included_rule(user_proxy, "A String") }.to_not raise_error
    end

    it "should not check included rules where the condition isn't valid" do
      included_rule = schema.root_group.define_rule(:global_rule) { |user, object| object == 12345 }
      permission.include_rule(:global_rule, :if => proc { |user, object| object.is_a?(Integer) })
      # Rule should be OK because it matches
      expect(permission.first_unsatisfied_included_rule(user_proxy, 12345)).to be nil
      # Rule should be invoked
      expect(permission.first_unsatisfied_included_rule(user_proxy, 55555).rule).to eq included_rule
      # The rule should not be used because this is a string.
      expect(permission.first_unsatisfied_included_rule(user_proxy, "12345")).to be nil
    end

  end

  context "#first_unsatisfied_rule" do
    subject(:permission) { schema.root_group.add_permission(:edit_project) }

    subject(:user_proxy) { Checken::UserProxy.new(FakeUser.new([permission.path])) }

    it "should return nil if all rules are satisifed" do
      permission.required_object_types << 'FakeProject'
      permission.add_rule(:must_be_archived) { |u, o| o.archived? }

      fake_project = FakeProject.new('Example', true)
      expect(permission.first_unsatisfied_rule(user_proxy, fake_project)).to be nil
    end

    it "should return the errored rule object" do
      permission.required_object_types << 'FakeProject'
      permission.add_rule(:must_be_archived) { |u, o| o.archived? }

      fake_project = FakeProject.new('Example', false)
      rule = permission.first_unsatisfied_rule(user_proxy, fake_project)
      expect(rule).to be_a Checken::RuleExecution
      expect(rule.rule).to be_a Checken::Rule
      expect(rule.rule.key).to eq :must_be_archived
    end
  end

  describe "#update_schema" do
    context "when the permission has no path" do
      it "should not update the schema" do
        permission = Checken::Permission.new(group, nil)
        permission.update_schema
        expect(permission.group.schema.schema).to eq({})
      end
    end

    context "when a permission is added to the root group" do
      it "should update the schema" do
        permission = schema.root_group.add_permission(:change_password)
        permission.description = "Change password"
        permission.update_schema
        expect(permission.group.schema.schema).to eq(
          {
            'change_password' => {
              description: 'Change password',
              group: nil,
              type: :permission
            }
          }
        )
      end
    end

    context 'when a permission is added to a sub-group of the root group' do
      it 'should update the schema' do
        group1 = schema.root_group.add_group(:group1)
        permission = group1.add_permission(:change_password)
        permission.description = "Change password"
        permission.update_schema
        expect(permission.group.schema.schema).to eq(
          {
            'group1.change_password' => {
              description: 'Change password',
              group: 'group1',
              type: :permission
            }
          }
        )
      end
    end

    context 'when a permission is added to a sub-group of a sub-group' do
      it 'should update the schema' do
        group1 = schema.root_group.add_group(:group1)
        group2 = group1.add_group(:group2)
        permission = group2.add_permission(:change_password)
        permission.description = "Change password"
        permission.update_schema
        expect(permission.group.schema.schema).to eq(
          {
            'group1.group2.change_password' => {
              description: 'Change password',
              group: 'group1.group2',
              type: :permission
            }
          }
        )
      end
    end
  end

end
