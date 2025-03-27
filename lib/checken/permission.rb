require 'checken/concerns/has_parents'
require 'checken/dsl/permission_dsl'
require 'checken/rule'
require 'checken/rule_execution'
require 'checken/included_rule'

module Checken
  class Permission

    include Checken::Concerns::HasParents

    attr_reader :group
    attr_reader :key

    # A description of this permission
    #
    # @return [String]
    attr_accessor :description

    # A list of permission paths that this permission depends on
    #
    # @return [Array<String>]
    attr_reader :dependencies

    # An array of object type names (as Strings) that the object passed to this
    # permission must be one of. If empty, any object is permitted.
    #
    # @return [Array<String>]
    attr_reader :required_object_types

    # The name of the contexts that apply to this permission
    #
    # @return [Array<Symbol>]
    attr_reader :contexts

    # Create a new permission group
    #
    # @param group [Checken::PermissionGroup, nil]
    # @param key [Symbol]
    def initialize(group, key)
      if group.nil?
        raise Error, "Group must be provided when creating a permission"
      end

      @group = group
      @key = key
      @required_object_types = []
      @dependencies = []
      @contexts = []
    end

    # Return a description
    #
    # @return [String]
    def description
      @description || "#{path}"
    end

    # Check this permission and raises an error if not permitted.
    #
    # @param user [Object]
    # @param object [Object]
    # @raises [Checken::PermissionDeniedError]
    # @raises [Checken::InvalidObjectError]
    # @return true
    def check!(user_proxy, object = nil)
      # If we havent' been given a user proxy here, we need to make one. This
      # shouldn't happen very often in production because everything would be
      # encapsulated by the User#can? method.
      unless user_proxy.is_a?(Checken::UserProxy)
        user_proxy = @group.schema.config.user_proxy_class.new(user_proxy)
      end

      # If we're asking about this permission and we aren't in the correct
      # context, it should be denied always.
      unless @contexts.empty?
        unless @contexts.any? { |c| user_proxy.contexts.include?(c) }
          @group.schema.logger.info "`#{self.path}` not granted to #{user_proxy.description} because not in context."
          error = PermissionDeniedError.new('NotInContext', "Permission '#{self.path}' cannot be granted in the #{user_proxy.contexts.join(',')} context(s). Only allowed for #{@contexts.join(', ')}.", self)
          error.user = user_proxy.user
          error.object = object
          raise error
        end
      end

      # Check the user has this permission
      unless user_proxy.granted_permissions.include?(self.path)
        @group.schema.logger.info "`#{self.path}` not granted to #{user_proxy.description}"
        error = PermissionDeniedError.new('PermissionNotGranted', "User has not been granted the '#{self.path}' permission", self)
        error.user = user_proxy.user
        error.object = object
        raise error
      end

      # Check other dependent rules once we've established this
      # user has the base rule. The actual rules won't be checked
      # until we've checked other rules.
      dependencies_as_permissions.each do |dependency_permission|
        @group.schema.logger.info "`#{self.path}` has a dependency of `#{dependency_permission.path}`..."
        dependency_permission.check!(user_proxy, object)
      end

      # Check any included rules too
      if unsatisifed_rule = self.first_unsatisfied_included_rule(user_proxy, object)
        @group.schema.logger.info "`#{self.path} not granted to #{user_proxy.description} because rule `#{unsatisifed_rule.rule.key}` on `#{self.path}` was not satisified."
        error = PermissionDeniedError.new('IncludedRuleNotSatisifed', "Rule #{unsatisifed_rule.rule.key} (on #{self.path}) was not satisified.", self)
        error.rule = unsatisifed_rule
        error.user = user_proxy.user
        error.object = object
        raise error
      end

      # Check rules
      if self.required_object_types.empty? || self.required_object_types.include?(object.class.name)
        if unsatisifed_rule = self.first_unsatisfied_rule(user_proxy, object)
          @group.schema.logger.info "`#{self.path} not granted to #{user_proxy.description} because rule `#{unsatisifed_rule.rule.key}` on `#{self.path}` was not satisified."
          error = PermissionDeniedError.new('RuleNotSatisifed', "Rule #{unsatisifed_rule.rule.key} (on #{self.path}) was not satisified.", self)
          error.rule = unsatisifed_rule
          error.user = user_proxy.user
          error.object = object
          raise error
        else
          @group.schema.logger.info "`#{self.path}` granted to #{user_proxy.description}"
          [self, *dependencies_as_permissions]
        end
      else
        # If one of the permission doesn't have the right object type, raise an error
        raise InvalidObjectError, "The #{object.class.name} object provided to permission check for #{self.path} was not valid. Valid object types are: #{self.required_object_types.join(', ')}"
      end
    end

    # Return a hash of all configured rules
    #
    # @return [Hash]
    def rules
      @rules ||= {}
    end

    # Add a new rule to this permission
    #
    # @param key [String]
    # @return [Checken::Rule]
    def add_rule(key, rule = nil, &block)
      key = key.to_sym
      if rules[key].nil?
        rule ||= Rule.new(key, &block)
        rules[key] = rule
      else
        raise Error, "Rule with key '#{key}' already exists on this permission"
      end
    end

    # Return a hash of all configured included rules
    #
    # @return [Hash]
    def included_rules
      @included_rules ||= {}
    end

    # Add a new rule to this permission
    #
    # @param key [String]
    # @return [Checken::Rule]
    def include_rule(key_or_existing_rule, options = {}, &block)
      if key_or_existing_rule.is_a?(IncludedRule)
        key = key_or_existing_rule.key
        included_rule = key_or_existing_rule
      else
        key = key_or_existing_rule.to_sym
        included_rule = nil
      end

      if included_rules[key].nil?
        included_rule ||= begin
          new_rule = IncludedRule.new(key, &block)
          new_rule.condition = options[:if]
          new_rule
        end
        included_rules[key] = included_rule
      else
        raise Error, "Rule with key '#{key}' already been included on this permission"
      end
    end

    # Add a new context to this permission
    #
    # @param context [Symbol]
    # @return [Symbol, false]
    def add_context(context)
      context = context.to_sym
      if self.contexts.include?(context)
        false
      else
        self.contexts << context
        context
      end
    end

    # Remove all context from this permission
    #
    # @return [Integer]
    def remove_all_contexts
      previous_size = @contexts.size
      @contexts = []
      previous_size
    end

    # Add a new dependency to this permission
    #
    # @param path [String]
    # @return [String, false]
    def add_dependency(path)
      path = path.to_s
      if dependencies.include?(path)
        false
      else
        dependencies << path
        path
      end
    end

    # Add a new dependency to this permission
    #
    # @param path [String]
    # @return [String, false]
    def add_required_object_type(type)
      type = type.to_s
      if required_object_types.include?(type)
        false
      else
        required_object_types << type
        type
      end
    end

    # Check all the rules for this permission and ensure they are compliant.
    #
    # @param [Checken::UserProxy]
    # @param [Object]
    # @return [Checken::Rule, false] false if all rules are satisified
    def first_unsatisfied_rule(user_proxy, object)
      self.rules.values.each do |rule|
        rule_execution = RuleExecution.new(rule, user_proxy.user, object)
        unless rule_execution.satisfied?
          return rule_execution
        end
      end
      nil
    end

    def first_unsatisfied_included_rule(user_proxy, object)
      self.included_rules.values.each do |included_rule|

        if included_rule.condition && !included_rule.condition.call(user_proxy.user, object)
          # If the inclusion has a condition, check that and skip this
          # included rule if it's not valid.
          next
        end

        if included_rule.block
          translated_object = included_rule.block.call(object)
        else
          translated_object = object
        end

        rule = @group.all_defined_rules[included_rule.key]
        if rule.nil?
          raise Error, "No defined rule with key #{included_rule.key} is available for #{self.path}"
        end

        unless rule.required_object_types.empty? || rule.required_object_types.include?(translated_object.class.name)
          raise InvalidObjectError, "The #{translated_object.class.name} object provided to included rule (#{rule.key}) for #{self.path} was not valid. Valid object types are: #{rule.required_object_types.join(', ')}"
        end

        rule_execution = RuleExecution.new(rule, user_proxy.user, translated_object)
        unless rule_execution.satisfied?
          return rule_execution
        end
      end
      nil
    end

    def dsl(&block)
      dsl = DSL::PermissionDSL.new(self)
      dsl.instance_eval(&block) if block_given?
      dsl
    end

    # Return an array of all dependencies as permissions
    #
    # @return [Array<Checken::Permission>]
    def dependencies_as_permissions
      @dependencies_as_permissions ||= dependencies.map do |path|
        @group.schema.root_group.find_permissions_from_path(path)
      end.flatten
    end

    def update_schema
      return if path.nil?

      group.schema.update_schema(
        {
          path => {
            type: :permission,
            description: description,
            group: group.path
          }
        }
      )
    end

  end
end
