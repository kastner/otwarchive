class CommentsController < ApplicationController 
  before_filter :load_commentable, :only => [ :index, :new ]
  
  # Get the parent of the desired comment(s) 
  # Just covering all the bases here for now
  def load_commentable
    if params[:work_id]
      @commentable = Work.find(params[:work_id])
    elsif params[:chapter_id]
      @commentable = Chapter.find(params[:chapter_id])
    elsif params[:comment_id]
      @commentable = Comment.find(params[:comment_id])
    elsif params[:user_id]
      @commentable = User.find(params[:user_id])
    elsif params[:pseud_id]
      @commentable = Pseud.find(params[:pseud_id])
    end    
  end
  
  # GET /comments
  # GET /comments.xml
  def index 
    @comments = @commentable.find_all_comments
  end
  
  # GET /comments/1
  # GET /comments/1.xml
  def show
    comment = Comment.find(params[:id])
    @comments = comment.full_set
  end
  
  # GET /comments/new
  # GET /comments/new.xml
  def new
    @comment = Comment.new
  end
  
  # GET /comments/1/edit
  def edit
    @comment = Comment.find(params[:id])
  end
  
  # POST /comments
  # POST /comments.xml
  def create
    @comment = Comment.new(params[:comment])
    @comment.update_attribute(:user_agent,request.env['HTTP_USER_AGENT'])
    
    if @comment.set_and_save
      if @comment.approved?
        flash[:notice] = 'Comment was successfully created.'
        redirect_to(@comment.commentable)
      else
        flash[:notice] = 'Comment was marked as spam by Akismet.'
        redirect_to(comments_url)
      end
    else
      render :action => "new", :locals => {:commentable => @comment.commentable, :button_name => 'Create'}
    end
  end
  
  # PUT /comments/1
  # PUT /comments/1.xml
  def update
    @comment = Comment.find(params[:id])
    
    if @comment.update_attributes(params[:comment])
      flash[:notice] = 'Comment was successfully updated.'
      redirect_to(@comment.commentable)
    else
      render :action => "edit" 
    end
  end
  
  # DELETE /comments/1
  # DELETE /comments/1.xml
  def destroy
    @comment = Comment.find(params[:id])
    @comment.destroy_or_mark_delete
    redirect_to(comments_url)
  end
  

  def approve
    @comment = Comment.find(params[:id])
    @comment.mark_as_ham!
    redirect_to(comments_url)
  end

  def reject
   @comment = Comment.find(params[:id])
   @comment.mark_as_spam!
   redirect_to(comments_url)
  end
  
end
