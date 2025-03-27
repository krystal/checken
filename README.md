# Checken 🐓

Checken (like chicken) is an authorization framework for Ruby/Rails applications to allow you to build a complete permission & access control system for your users. The goals of the project are:

* To allow you easily to verify whether a user is authorized to perform an action.
* Support any number of different actions.
* Allow actions to be associated with an object.
* Allow actions to have additional rules which can be applied to them.

This is an example of the DSL required to get started:

```ruby
# At its most basic, you can define a simple permission
permission :change_password, 'Change own password'

# and then check whether a user has a permission
current_user.can?('change_password')

# or raise an error if the user does not have the permission
current_user.can!('change_password') # => Checken::PermissionDeniedError
```

Things can, however, get more complicated when you want to start checking whether a user has access to view or make changes to a specific resource. In this example, we're going to look at using groups and rules to determine.

```ruby
group :projects do
  # If the user has the permission AND the rule is satisifes
  # this permission will be granted. If either fail, the
  # permission will be denied.
  permission :list, 'List projects' do
    rule(:must_be_active) { |user| user.active? }
  end

  # You can also use an additional object to help with verifying
  # whether a user should be authorized. You need to define the
  # type of object that you wish to pass and a rule.
  permission :show, 'View project information' do
    requires_object 'Project'
    rule(:must_belong_to_projects_account) { |user, project| user.account == project.account }
  end
end

# We can use this in an action or view to determine if a user can perform an action.
# We pass the objects required by the permission as arguments.
current_user.can?('projects.show', @project)

# We can also use this project an action at the controller class level. The
# second argument is, optionally, the object to provide. A symbol will be called
# as a method, instance variable or you can provide a proc. The user must be available as
# current_user (this can be changed).
restrict 'projects.show', :@project, only: [:index]
restrict 'projects.show', proc { @project }, only: [:index]
```

Next up, you might need to add dependencies to avoid needing further complexity to your ruleset.

```ruby
group :projects do
  permission :view, 'Can view a project', 'Project' do
    rule(:project_must_belong_to_account) { |user, project| user.account == project.account }
  end

  permission :edit, 'Can edit a project', 'Project' do
    depends_on "projects.view"
    rule(:must_be_admin_user) { |user, project| user.admin? }
  end
end

# In this case you can use a single can statement which will check that the user
# satisifes all dependent rules as well as itself before granting permission.
current_user.can?('projects.edit', @project)
```

If you have multiple permissions that all need the same treatment with regards to dependencies or rules, you can put them in a set. The rules and dependencies that you define in the set will apply to all permissions in the set. Here's an example:

```ruby
group :projects do
  group :delete do
    set do
      requires_object 'Project' do
      rule(:must_belong_to_projects_account) { |user, project| user.account == project.account }

      permission :any, 'Can delete any projects'
      permission :archived_only, 'Can only delete archived projects' do
        rule(:must_be_archived) { |user, project| project.archived? }
      end
    end
  end
end
```

Wildcards can be useful if you want to check to see whether the user has ANY of the permissions matched by the wildcard.

```ruby
# Using a wildcard in the permission will allow allow any permission role through
# but will check that all rules for all assigned permissions are satisifed before
# allowing the request through.
current_user.can?('projects.delete.*', @project)
```

Dependencies can also be added in sets level to apply the dependency to all permissions within this group and all subsequent groups.

```ruby
group :projects do
  group :update do
    set do
      depends_on 'projects.view'

      # [...] Additional permissions in here which will all depend on the
      #       projects.view permission.
    end
  end
end
```

## Releasing a new version

[Release Please](https://github.com/googleapis/release-please) is configured. The [convential commits](https://www.conventionalcommits.org/en/v1.0.0/) format should be used and upon merging to main, Release Please will open a new PR following semver rules. When that Release Please PR is merged, a new version of the gem will be created and published to RubyGems.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/krystal/checken.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
