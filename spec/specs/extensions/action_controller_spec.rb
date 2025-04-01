require 'spec_helper'
require 'rails_helper'
require 'checken/schema'
require 'checken/extensions/action_controller'

RSpec.describe Checken::Extensions::ActionController, type: :controller do
  let(:schema) { Checken::Schema.new }

  before do
    allow(controller).to receive(:current_user).and_return(current_user)
    allow(Checken).to receive(:current_schema).and_return(schema)
  end

  describe ".restrict" do
    context "with strict checks" do
      controller(ActionController::Base) do
        include Checken::Extensions::ActionController
        restrict 'change_password', only: [:index]

        def index
          head :no_content
        end

        def new
          head :no_content
        end

        def current_user
          nil
        end
      end

      before do
        schema.root_group.add_permission(:change_password)
      end

      context "when the user does not have the required permission" do
        let(:current_user) { FakeUser.new(['create_account']) }

        it "restricts access to the restricted action" do
          expect { get :index }.to raise_error(Checken::PermissionDeniedError)
        end

        it "allows access to the unrestricted action" do
          expect { get :new }.not_to raise_error
          expect(response).to have_http_status(:no_content)
        end
      end

      context "when the user does have the required permission" do
        let(:current_user) { FakeUser.new(['change_password']) }

        it "allows access to the restricted action" do
          expect { get :index }.not_to raise_error
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    context "with strict checks and the controller tries to use an unknown permission" do
      controller(ActionController::Base) do
        include Checken::Extensions::ActionController
        restrict 'unknown_permission'

        def index
          head :no_content
        end

        def current_user
          nil
        end
      end

      let(:current_user) { FakeUser.new(['change_password']) }

      before do
        schema.root_group.add_permission(:change_password)
      end

      it "raises a permission not found error" do
        expect { get :index }.to raise_error(Checken::PermissionNotFoundError)
      end
    end

    # strict: false means the permission does not need to exist in the schema
    context "with strict: false" do
      controller(ActionController::Base) do
        include Checken::Extensions::ActionController
        restrict 'new_user', except: :index, strict: false

        def index
          head :no_content
        end

        def new
          head :no_content
        end

        def current_user
          nil
        end
      end

      context "when the user does not have the required permission" do
        let(:current_user) { FakeUser.new(['create_account']) }

        it "restricts access to the restricted action" do
          expect { get :new }.to raise_error(Checken::PermissionDeniedError)
        end

        it "does not restrict access to the unrestricted action" do
          expect { get :index }.not_to raise_error
          expect(response).to have_http_status(:no_content)
        end
      end

      context "when the user does have the required permission" do
        let(:current_user) { FakeUser.new(['new_user']) }

        it "allows access to the restricted action" do
          expect { get :new }.not_to raise_error
          expect(response).to have_http_status(:no_content)
        end

        it "does not restrict access to the unrestricted action" do
          expect { get :index }.not_to raise_error
          expect(response).to have_http_status(:no_content)
        end
      end
    end
  end
end
