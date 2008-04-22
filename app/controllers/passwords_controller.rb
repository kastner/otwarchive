# Use for resetting lost passwords
class PasswordsController < ApplicationController      
  
  def new
  end
  
  def create
    @user = User.find_by_login(params[:login])
    @user.reset_user_password
    
    if @user.save
      UserMailer.deliver_reset_password(@user)
      flash[:notice] = 'Check your email for your new password.'
      redirect_to login_path 
    else
      render :action => "new"
    end
  end    
  
end
