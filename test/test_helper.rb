ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
include FixtureReplacement

class ActionController::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  #
  # The only drawback to using transactional fixtures is when you actually 
  # need to test transactions.  Since your test is bracketed by a transaction,
  # any transactions started in your code will be automatically rolled back.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  #fixtures :all
  
  # For the Translator plugin - if you don't disable strict mode, it causes an error
  # every time it comes across a missing translation, which includes months, dates, etc.
  # in English, so that's kind of a pain in the neck --elz
  ScopeTranslator::Translator.strict_mode(false)

  # Add more helper methods to be used by all tests here...
  
  def login_setup
    #@request    = ActionController::TestRequest.new
    #@response   = ActionController::TestResponse.new
  end
  
  # Sets the current user in the session from the user fixtures.
  def login_as_user(user)
    login_setup
    @request.session[:user] = user ? users(user).id : nil
  end

  # Sets the current user in the session from the user fixtures.
  def login_as_admin(admin)
    login_setup
    @request.session[:admin] = admin ? admins(admin).id : nil
  end

end
