# This controller handles the login/logout function of the site.  
class SessionController < ApplicationController
  
  # Prevents multiple logins for people with both user and admin accounts
  before_filter :admin_logout_required
  
  def new
    if logged_in?
      redirect_to current_user
    end
    @restricted = true if params[:restricted]
  end
  
  def create
    if ArchiveConfig.USE_OPENID && using_open_id?
      open_id_authentication(params[:openid_url])
    else
      password_authentication(params[:login], params[:password])
    end
  end
  
  def destroy
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    reset_session
    flash[:notice] = "You have been logged out.".t
    # During testing, logout redirects to the feedback page.
    # Code commented out below would be default when out of testing. 
    ##   redirect_back_or_default('/')
    redirect_to :controller => "feedbacks", :action => "new"
  end

  # switches to the openid version of the login form
  def openid
  end
 
  # switches to the password version of the login form
  def passwd
  end

  # switches to the openid version of the mini login box
  def openid_small
  end
 
  # switches to the password version of the mini login box
  def passwd_small
  end

  protected
  
  def open_id_authentication(openid_url)
    authenticate_with_open_id(openid_url) do |result, identity_url, registration|
      if result.successful?
        @user = User.find_by_identity_url(identity_url)
        if @user
          self.current_user = @user
          successful_login
        else
          failed_login "We couldn't find that url in our database. Please try again.".t
        end
      else
        failed_login result.message
      end
    end
  end
  
  def password_authentication(login, password)
    self.current_user = User.authenticate(login, password)
    if logged_in?
      successful_login
    else
      message = User.find_by_login(login) ? "The password you entered doesn't match our records. Please try again or click the 'forgot password' link below.".t : 
                                            "We couldn't find that name in our database. Please try again.".t
      failed_login(message)
    end
  end
  
  def failed_login(message = "Sorry, something went wrong! Please try again.".t)
    flash.now[:error] = message
    render :action => 'new'
  end
  
  def successful_login
    if params[:remember_me] == "1"
      self.current_user.remember_me
      cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
    end
    self.current_user.recently_reset? ? 
        (redirect_to :controller => 'users', :action => 'after_reset', :id => self.current_user.login) : 
        redirect_back_or_default(current_user)
    flash[:notice] = "Logged in successfully".t
  end
end
