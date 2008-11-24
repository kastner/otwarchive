require File.dirname(__FILE__) + '/../test_helper'

class HomeControllerTest < ActionController::TestCase
  context "a database with a restricted and an unrestricted work" do
    setup do
      @work1 = create_work
      @work2 = create_work(:restricted => true)
    end
    context "if you are not logged in" do
      setup do
        get :index, :locale => 'en'
      end
      should_assign_to :work_count, :equal => 1
    end
    context "when logged in" do
      setup do
        @user = create_user
        @request.session[:user] = @user 
        get :index, :locale => 'en'
      end
      should_assign_to :work_count, :equal => 2
    end
  end

  # manual testing runthrough of Home Page  
  context "a Get" do
    setup do
      get :index, :locale => 'en'
    end
    should_respond_with :success
    should_render_template :index
    should_not_set_the_flash
    should "have a title" do
      assert_tag :title, :content => ArchiveConfig.TITLE
    end
    should "have a login" do
      assert_tag :div, :attributes =>{ :id => "signin" }, :child => { :tag => "form" }
    end
    should "have a people link" do
      assert_tag :a, :content => "People", :attributes => { :href => "/en/users" }
    end
    should "have a fandom link" do
      assert_tag :a, :content => "Fandoms", :attributes => { :href => "/en/media" }
    end
    should "have a works link" do
      assert_tag :a, :content => "Works", :attributes => { :href => "/en/works" }
    end
  end
end
