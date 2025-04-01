# Checken 🐓

Checken (like chicken) is an authorization framework for Ruby/Rails applications to allow you to build a complete permission & access control system for your users. The goals of the project are:

- To allow you easily to verify whether a user is authorized to perform an action.
- Support any number of different actions.
- Allow actions to be associated with an object.
- Allow actions to have additional rules which can be applied to them.

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

### Namespace

An optional namespace can be set as part of the config in the initializer in the Rails application.

```ruby
Checken::Schema.instance.configure do |config|
  config.namespace = 'app1'
end
```

This will prefix all group and permissions paths with the namespace.
By default `:` will be used as the delimiter but that can be configured:

```ruby
Checken::Schema.instance.configure do |config|
  config.namespace = 'app1'
  config.namespace_delimiter = '-'
end
```

When defining the permission path with `restrict` or checking with `can?`, you need to include the namespace:

```ruby
restrict 'app1:users.edit'
current_user.can?('app1:users.edit')
```

And it means the permissions granted to your users should also include that namespace prefix.

It is possible to allow the namespace to be omitted from both where you declare `restrict` and
also in the permissions granted to users. In the Rails initializer set the `namespace_optional` config option to true.

```ruby
Checken::Schema.instance.configure do |config|
  config.namespace = 'app1'
  config.namespace_optional = true
end
```

Now you can define the permission path with or without the namespace:

```ruby
restrict 'users.edit'
current_user.can?('app1:users.edit')
```

Setting `namespace_optional` is primarily for the purpose of migrating existing non-namespaced permissions to a namespaced system.
With this configuration, a user with either "app1:users.edit" or "users.edit" will be matched when checking permissions.

The migration would follow these steps:

1. Update the Rails initializer to set the Checken config with the `namespace` and `namespace_optional` as true.
2. Update all places permissions are checked with Checken (e.g. `restrict` or `can?`) to include the namespace.
3. Deploy the application (to avoid issues with rolling deploys).
4. Migrate the permissions in the database to include the namespace.
5. Update the Rails initializer to remove `namespace_optional` (default is false).
6. Deploy the application.

### Strictness

By default all permission checks are 'strict' which means the permission(s) must exist in the defined Checken schema.

However it can be useful to use Checken along side permissions that are defined outside the schema, perhaps with a different namespace. These can be checked by specifying `strict: false`:

```ruby
current_user.can?("billing:payment_cards.edit", strict: false)
restrict 'myapp:admin.ui', strict: false
```

The `UserProxy` is expected to have the permission path exactly as-is, within the array returned by `granted_permissions`.

## Releasing a new version

[Release Please](https://github.com/googleapis/release-please) is configured. The [convential commits](https://www.conventionalcommits.org/en/v1.0.0/) format should be used and upon merging to main, Release Please will open a new PR following semver rules. When that Release Please PR is merged, a new version of the gem will be created and published to RubyGems.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/krystal/checken.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
