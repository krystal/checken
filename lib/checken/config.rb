require 'logger'
require 'checken/user_proxy'

module Checken
  class Config

    # The class that should be used to create user proxies.
    #
    # @return [Class]
    def user_proxy_class
      @user_proxy_class ||= UserProxy
    end
    attr_writer :user_proxy_class

    # A logger class that will be used to log all activities
    #
    # @return [Logger]
    def logger
      @logger ||= Logger.new("/dev/null")
    end
    attr_writer :logger

    # The method name which will return the current user object in any
    # controller action.
    #
    # @return [Symbol]
    def current_user_method_name
      @current_user_method_name || :current_user
    end

  end
end
