class TagsController < ApplicationController

  before_filter :check_user_status, :except => [ :show, :index, :show_hidden ]
  before_filter :login_required, :except => [ :show, :index, :show_hidden ]
  def authorized?
    logged_in_as_admin? || permit?("tag_wrangler")
  end

  # GET /tags
  # GET /tags.xml
  def index
    @tags = Tag.for_tag_cloud

    respond_to do |format|
      format.html # index.html.erb
      format.js
    end
  end

  def show
    @tag = Tag.find_by_name(params[:id])
    if !@tag.canonical && !@tag.merger
      if current_user.is_a?User
        @works = @tag.works.visible_to_user.paginate(:page => params[:page])
      else
        @works = @tag.works.visible_to_all.paginate(:page => params[:page])
      end
    end
  end

  def show_hidden
    unless params[:work_id].blank?
      @display_work = Work.find(params[:work_id])
      @display_tags = @display_work.warnings
      @display_category = @display_tags.first.type.downcase  # Enigel Dec 13 08 quick 'n dirty fix
    end
    if request.xml_http_request?
      respond_to do |format|
        format.js
      end
    else
      # This is just a quick fix to avoid script barf if JavaScript is disabled
      flash[:error] = "Sorry, you need to have JavaScript enabled for this.".t
      redirect_to :back
    end

  end

  # GET /tags/new
  # GET /tags/new.xml
  def new
    @tag = Tag.new

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # POST /tags
  # POST /tags.xml
  def create
    type = params[:tag][:type] if params[:tag]
    if type
      @tag = type.constantize.find_or_create_by_name(params[:tag][:name])
    else
      flash[:error] = "Please provide a category.".t
      @tag = Tag.new(:name => params[:tag][:name])
      render :action => "new" and return
    end
    if @tag.valid?
      @tag.update_attribute(:canonical, params[:tag][:canonical])
      flash[:notice] = 'Tag was successfully created.'.t
      redirect_to edit_tag_path(@tag)
    else
      render :action => "new" and return
    end
  end

  def edit
    @tag = Tag.find_by_name(params[:id])
  end

  def update
    @tag = Tag.find_by_name(params[:id])
    if @tag.blank?
      flash[:error] = "Tag not found"
      redirect_to root_path and return
    end
    @tag.update_attribute(:name, params[:tag][:name]) if (params[:tag][:name] && logged_in_as_admin?)
    @tag.update_type(params[:tag][:type], logged_in_as_admin?) if params[:tag][:type]
    @tag.update_attribute("canonical", params[:tag][:canonical]) if params[:tag][:canonical]
    if @tag.merger_id
      unless params[:keep_synonym]
        @tag.update_attribute("merger_id", "")
      else
        @tag.update_attribute("merger_id", params[:tag][:merger_id]) if params[:tag][:merger_id]
      end
    else
      @tag.update_attribute("merger_id", params[:tag][:merger_id]) if params[:tag][:merger_id]
    end
    @tag.update_freeforms(params[:freeforms])
    @tag.update_characters(params[:characters])
    @tag.update_pairings(params[:pairings])
    @tag.update_fandoms(params[:fandoms])
    @tag.update_medias(params[:medias])
    @tag.add_freeform(params[:freeform][:freeform_id]) if params[:freeform]
    @tag.add_character(params[:character][:character_id]) if params[:character]
    @tag.add_pairing(params[:pairing][:pairing_id]) if params[:pairing]
    @tag.add_fandom(params[:fandom][:fandom_id]) if params[:fandom]
    @tag.add_media(params[:media][:media_id]) if params[:media]
    @tag.add_synonym(params[:synonym][:synonym_id]) if params[:synonym]
    flash[:notice] = 'Tag was updated.'.t
    redirect_to edit_tag_path(@tag.name)
  end
end
