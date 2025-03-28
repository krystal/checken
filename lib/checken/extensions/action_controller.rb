module Checken
  module Extensions
    module ActionController

      def self.included(base)
        base.extend ClassMethods
        base.helper_method :granted_checken_permissions
        base.class_eval do
          private :checken_user_proxy
          private :restrict
          private :granted_checken_permissions
        end
      end

      def checken_user_proxy
        # Can be overriden to return the user proxy class which can be used
        # when performing permission checks using `restrict`.
      end

      def restrict(permission_path, object = nil, options = {}, strict: true)
        if checken_user_proxy.nil?
          user = send(Checken.current_schema.config.current_user_method_name)
          user_proxy = Checken.current_schema.config.user_proxy_class.new(user)
        else
          user_proxy = checken_user_proxy
        end
        granted_permissions = Checken.current_schema.check_permission!(permission_path, user_proxy, object, strict: strict)
        granted_permissions.each do |permission|
          granted_checken_permissions << permission
        end
      end

      def granted_checken_permissions
        @granted_checken_permissions ||= []
      end

      module ClassMethods
        def restrict(permission_path, object_or_options = {}, options_if_object_provided = {}, strict: true)
          if object_or_options.is_a?(Hash)
            object = nil
            options = object_or_options
          else
            object = object_or_options
            options = options_if_object_provided
          end

          restrict_options = options.delete(:restrict_options)

          before_action(options) do
            if object.is_a?(Proc)
              # If a proc is given, resolve manually
              resolved_object = object.call
            elsif object.is_a?(Symbol)
              if object.to_s =~ /\A@/
                resolved_object = instance_variable_get(object.to_s)
              else
                resolved_object = send(object)
              end
            else
              # Otherwise, the object is nil
              resolved_object = nil
            end

            restrict(permission_path, resolved_object, restrict_options, strict: strict)
          end

        end
      end

    end
  end
end
