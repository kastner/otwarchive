require File.dirname(__FILE__) + '/../test_helper'

class TagWranglingsControllerTest < ActionController::TestCase
  context "when not logged in" do
    setup do
      get :index, :locale => 'en'
    end
    should_redirect_to "{:controller => :session, :action => 'new'}"
    should_set_the_flash_to /log in/      
  end
  
  context "when logged in" do
    setup do
      @user = create_user
      @request.session[:user] = @user
      get :index, :locale => 'en'
    end
    should_redirect_to "{:controller => :works, :action => 'index'}"
    should_set_the_flash_to /tag wranglers only/      
  end
  
  context "when logged in as a tag_wrangler" do
    setup do
      @user = create_user
      @user.is_tag_wrangler
      @request.session[:user] = @user
    end
    context "when looking at tag wranglings" do
      setup do
        get :index, :locale => 'en'
      end
      should_render_template :index
    end
  end
end