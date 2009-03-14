class WorksController < ApplicationController 
  include HtmlFormatter  
  
  cache_sweeper :work_sweeper, :only => [:create, :update, :destroy]
    
  # only registered users and NOT admin should be able to create new works
  before_filter :users_only, :only => [ :new, :create, :upload_work, :drafts, :preview ]
  # only authors of a work should be able to edit it
  before_filter :is_author, :only => [ :edit, :update, :destroy, :preview ]
  before_filter :set_instance_variables, :only => [ :new, :create, :edit, :update, :manage_chapters, :preview, :show, :upload_work ]
  before_filter :update_or_create_reading, :only => [ :show ]
  before_filter :check_user_status, :only => [:new, :create, :edit, :update, :preview]
  
  # For the auto-complete field in the works form
  def auto_complete_for_pseud_byline
    byline = request.raw_post.to_s.strip
    if byline.include? "["
      split = byline.split('[', 2)
      pseud_name = split.first.strip
      user_login = split.last.strip.chop
      conditions = [ 'LOWER(users.login) LIKE ? AND LOWER(name) LIKE ?','%' + user_login + '%',  '%' + pseud_name + '%' ]
    else
      conditions = [ 'LOWER(name) LIKE ?', '%' + byline + '%' ]
    end
    @pseuds = Pseud.find(:all, :include => :user, :conditions => conditions, :limit => 10)
    render :inline => "<%= auto_complete_result(@pseuds, 'byline')%>"
  end
  
  def access_denied
    store_location 
    redirect_to new_session_path(:restricted => true)
    false
  end
  
  # Sets values for @work, @chapter, @coauthor_results, @pseuds, and @selected_pseuds
  # and @tags[category]
  def set_instance_variables

    # if we don't have author_attributes[:ids], which shouldn't be allowed to happen
    # (this can happen if a user with multiple pseuds decides to unselect *all* of them)
    sorry = "Sorry, you cannot remove yourself entirely as an author of the work!<br />
             <br />Please use Remove Me As Author or consider orphaning your work instead if you do not wish to be associated with it anymore."
    if params[:work] && params[:work][:author_attributes] && !params[:work][:author_attributes][:ids]
      flash.now[:notice] = t('notices.works.needs_author', :default => sorry)
      params[:work][:author_attributes][:ids] = [current_user.default_pseud]
    end
    if params[:work] && !params[:work][:author_attributes]
      flash.now[:notice] = t('notices.works.needs_author', :default => sorry)
      params[:work][:author_attributes] = {:ids => [current_user.default_pseud]}
    end
    
    # stuff new bylines into author attributes to be parsed by the work model
    if params[:work] && params[:pseud] && params[:pseud][:byline] && params[:pseud][:byline] != ""
      params[:work][:author_attributes][:byline] = params[:pseud][:byline]
      params[:pseud][:byline] = ""
    end
    
    # stuff co-authors into author attributes too so we won't lose them
    if params[:work] && params[:work][:author_attributes] && params[:work][:author_attributes][:coauthors]
      params[:work][:author_attributes][:ids].concat(params[:work][:author_attributes][:coauthors]).uniq!
    end

    begin    
      if params[:id] # edit, update, preview, manage_chapters
        @work = Work.find(params[:id])
        @previous_published_at = @work.published_at
        if params[:work]  # editing, save our changes
          @work.attributes = params[:work]
        end
      elsif params[:work] # create
         @work = Work.new(params[:work])
      else # new
          @work = Work.new
          @work.chapters.build
      end

      @serial_works = @work.serial_works
      @tags_by_category = {}
      categories = Tag::VISIBLE
      categories.each {|type| @tags_by_category[type] = type.constantize.canonical}
      
      @chapters = (@work.chapters.in_order != []) ? @work.chapters.in_order : @work.chapters
      @chapter = @chapters.first
      if params[:work] && params[:work][:chapter_attributes]
        @chapter.content = params[:work][:chapter_attributes][:content]
        @chapter.title = params[:work][:chapter_attributes][:title]
      end

      unless current_user == :false
        load_pseuds
        @series = current_user.series.uniq 
      end
    rescue
    end
  end
  
  # Only authors of the work should be able to edit it
  def is_author
    @work = Work.find(params[:id])
    unless current_user.is_a?(User) && current_user.is_author_of?(@work)
      flash[:error] = t('errors.no_permission_to_edit', :default => 'Sorry, but you don\'t have permission to make edits.')
     redirect_to(@work)     
    end
  end
  
  # GET /works
  def index
    # what we're getting for the view
    @works = []
    @filters = {}
    @pseuds = []

    # default values for our inputs
    @query = nil
    @user = nil
    @selected_tags = []
    @selected_pseuds = []
    @sort_column = params[:sort_column] || 'revised_at'
    @sort_direction = params["sort_direction_for_#{@sort_column}".to_sym] || 'DESC'

    unless params[:selected_pseuds].blank?
      begin
        @selected_pseuds = Pseud.find(params[:selected_pseuds])
      rescue
        flash[:error] = t('errors.works.pseuds_not_found', :default => "Sorry, we couldn't find one or more of the authors you selected. Please try again.")
      end
    end
    
    # if the user is filtering with tags, let's see what they're giving us    
    unless params[:selected_tags].blank?
      @selected_tags = params[:selected_tags]
    end

    # if we have a query, we are searching with sphinx, which will
    # paginate for us automatically
    if params[:query]
      @query = params[:query]
      begin
        @works = Work.search_with_sphinx(params)
      rescue ThinkingSphinx::ConnectionError
        flash[:error] = t('errors.search_engine_down', :default => "The search engine seems to be down at the moment, sorry!")
       redirect_to :action => :index and return
      end
      
      unless @works.empty?
        @filters = Work.get_filters(@works)      
      end
    else
      # we're browsing instead
      # if we're browsing by a particular tag, just add that
      # tag to the selected_tags list.
      unless params[:tag_id].blank?
        @tag = Tag.find_by_name(params[:tag_id])
        if @tag
          @tag = @tag.merger if @tag.merger
          redirect_to tag_path(@tag) and return unless @tag.canonical
          @selected_tags << @tag.id.to_s unless @selected_tags.include?(@tag.id.to_s)
        else
          flash[:error] = t('errors.works.tag_not_found', :default => "Sorry, there's no tag by that name in our system.")
          redirect_to works_path
          return
        end
      end
      
      # if we're browsing by a particular user get works by that user      
      unless params[:user_id].blank?
        @user = User.find_by_login(params[:user_id])
        if @user
          if params[:pseud] and !params[:pseud].blank?
            @author = @user.pseuds.find(params[:pseud])
          end
        else
          flash[:error] = t('errors.works.user_not_found', :default => "Sorry, there's no user by that name in our system.")
          redirect_to works_path
          return
        end
      end
      
      # Now let's build the query
      page_args = {:page => params[:page], :per_page => (params[:per_page] || ArchiveConfig.ITEMS_PER_PAGE)}
      @works, @filters, @pseuds = Work.find_with_options(:user => @user, :selected_tags => @selected_tags, 
                                                    :selected_pseuds => @selected_pseuds, 
                                                    :sort_column => @sort_column, :sort_direction => @sort_direction,
                                                    :page_args => page_args)              
    end

    # we now have @works found
    
    if @works.empty? && !@selected_tags.empty?
      begin
        # build filters so we can go back
        flash.now[:notice] = t('notices.works.results_not_found', :default => "We couldn't find any results using all those filters, sorry! You can unselect some and filter again to get more matches.") 
        filters_array = Tag.find(@selected_tags, :select => "tags.type as tag_type, tags.id as tag_id, tags.name as tag_name")
        @filters = Work.build_filters_hash(filters_array)
      rescue
        # do we need more than the regular flash notice?
      end
    end

    # clean out the filters 
    if @filters && !@filters.empty?
      @filters.keys.each do |category|
        @filters[category].reject! {|filter| (!@selected_tags.include?(filter[:id]) && (filter[:count].to_i < 2))}
      end
    end
  end
  
  def drafts
    unless params[:user_id]
      flash[:error] = t('errors.works.whose_drafts', :default => "Whose drafts did you want to look at?")
     redirect_to :controller => :users, :action => :index
    else
      @user = User.find_by_login(params[:user_id])
      unless current_user == @user
        flash[:error] = t('errors.works.not_your_drafts', :default => "You can only see your own drafts, sorry!")
       redirect_to current_user
      else
        current_user.cleanup_unposted_works
        if params[:pseud]
          @author = @user.pseuds.find(params[:pseud])
          @works = @author.unposted_works.paginate(:page => params[:page])
        else
          @works = @user.unposted_works.paginate(:page => params[:page])
        end
      end
    end
  end 
  
  # GET /works/1
  # GET /works/1.xml
  def show
    unless @work
  	  flash[:error] = t('errors.works.work_not_found', :default => "Sorry, we couldn't find the story you were looking for.")
      redirect_to works_path and return
    end
    unless @work.visible || is_admin?
      if !current_user.is_a?(User)
        store_location 
        redirect_to new_session_path and return        
      elsif !current_user.is_author_of?(@work)
  	    flash[:error] = 'This page is unavailable.'
       redirect_to works_path and return
      end
    end
    # Users must explicitly okay viewing of adult content
    if params[:view_adult]
      session[:adult] = true
    elsif @work.adult? && !see_adult? 
      render :partial => "adult", :layout => "application"
    end	   
    unless @work.series.blank?
      @series_previous = {}
      @series_next = {}
      for series in @work.series
        serial = series.serial_works.find(:first, :conditions => {:work_id => @work.id})
        sw_previous = series.serial_works.find(:first, :conditions => {:position => (serial.position - 1)})
        sw_next = series.serial_works.find(:first, :conditions => {:position => (serial.position + 1)})
        @series_previous[series.id] = sw_previous.work if sw_previous && sw_previous.work.visible
        @series_next[series.id] = sw_next.work if sw_next && sw_next.work.visible
      end
    end
    @tag_categories_limited = Tag::VISIBLE - ["Warning"]
    
    @page_title = ""
    if logged_in? && !current_user.preference.work_title_format.blank?
      @page_title = current_user.preference.work_title_format
      @page_title.gsub!(/FANDOM/, @work.fandoms.string)
      @page_title.gsub!(/AUTHOR/, @work.pseuds.collect(&:name).join(','))
      @page_title.gsub!(/TITLE/, @work.title)
    else 
      @page_title = @work.title + " - " + @work.pseuds.collect(&:name).join(',') + " - " + @work.fandom_string
    end
    @page_title += " [#{ArchiveConfig.APP_NAME}]"
  end
  
  # GET /works/new
  def new
    current_user.cleanup_unposted_works
    if params[:load_unposted] && current_user.unposted_work
      @work = current_user.unposted_work
    elsif params[:upload_work]
      @use_upload_form = true
    end
  end

  # POST /works
  def create
    load_pseuds
    @series = current_user.series.uniq

    if !@work.invalid_pseuds.blank? || !@work.ambiguous_pseuds.blank?
      @work.valid? ? (render :partial => 'choose_coauthor', :layout => 'application') : (render :action => :new)
    elsif params[:edit_button]
      render :action => :new
    elsif params[:cancel_button]
      flash[:notice] = t('notices.works.posting_canceled', :default => "New work posting canceled.")
      redirect_to current_user    
    else # now also treating the cancel_coauthor_button case, bc it should function like a preview, really
      saved = @work.save
      unless saved && @work.has_required_tags? && @work.set_revised_at(@work.published_at)
        unless @work.has_required_tags?
          @work.errors.add(:base, "Creating: Required tags are missing.")          
        end
        render :action => :new 
      else        
        flash[:notice] = t('notices.works.draft_created', :default => 'Draft was successfully created.')
        redirect_to preview_work_path(@work)
      end
    end
  end
  
  # GET /works/1/edit
  def edit
    if params["remove"] == "me"
      pseuds_with_author_removed = @work.pseuds - current_user.pseuds
      if pseuds_with_author_removed.empty? 
        redirect_to :controller => 'orphans', :action => 'new', :work_id => @work.id    
      else
        @work.pseuds = pseuds_with_author_removed
        @work.save
        @work.chapters.each do |c| 
          c.pseuds = c.pseuds - current_user.pseuds
          if c.pseuds.empty?
            c.pseuds = @work.pseuds
          end
          c.save
        end
        flash[:notice] = t('errors.works.pseuds_not_found', :default => "You have been removed as an author from the work")
        redirect_to current_user
      end
    end
  end
  
  # PUT /works/1
  def update
    unless @work.errors.empty?      
      render :action => :edit and return
    end

    # Need to update @pseuds and @selected_pseuds values so we don't lose new co-authors if the form needs to be rendered again
    load_pseuds
    @series = current_user.series.uniq 
    
    if !@work.invalid_pseuds.blank? || !@work.ambiguous_pseuds.blank? 
      @work.valid? ? (render :partial => 'choose_coauthor', :layout => 'application') : (render :action => :new)
    elsif params[:preview_button] || params[:cancel_coauthor_button]
      @preview_mode = true
      @chapters = (@work.chapters.in_order != []) ? @work.chapters.in_order : @work.chapters
      if !@chapter
        @chapter = @chapters.first
      end
      if params[:work] && params[:work][:chapter_attributes]
        @chapter.content = params[:work][:chapter_attributes][:content]
        @chapter.title = params[:work][:chapter_attributes][:title]
      end
      
      #flash[:notice] = "DEBUG: in UPDATE preview:  " + "all: " + @allpseuds.flatten.collect {|ap| ap.id}.inspect + " selected: " + @selected_pseuds.inspect + " co-authors: " + @coauthors.flatten.collect {|ap| ap.id}.inspect + " pseuds: " + @pseuds.flatten.collect {|ap| ap.id}.inspect + "  @work.authors: " + @work.authors.collect {|au| au.id}.inspect + "  @work.pseuds: " + @work.pseuds.collect {|ps| ps.id}.inspect
      
      if @work.has_required_tags?
        render :action => "preview"
      else
        @work.errors.add_to_base("Updating: Please add all required tags.")
        render :action => :edit
      end
    elsif params[:cancel_button]
      cancel_posting_and_redirect
    elsif params[:edit_button]
    
      #flash[:notice] = "DEBUG: in UPDATE edit:  " + "all: " + @allpseuds.flatten.collect {|ap| ap.id}.inspect + " selected: " + @selected_pseuds.inspect + " co-authors: " + @coauthors.flatten.collect {|ap| ap.id}.inspect + " pseuds: " + @pseuds.flatten.collect {|ap| ap.id}.inspect + "  @work.authors: " + @work.authors.collect {|au| au.id}.inspect + "  @work.pseuds: " + @work.pseuds.collect {|ps| ps.id}.inspect
      
      render :partial => 'work_form', :layout => 'application'
    else
      saved = true
      @chapter.save || saved = false
      @work.has_required_tags? || saved = false
      if saved 
        # If the work is being posted for the first time, or 
        # the user has changed the published_at date, update the revised_at date. 
        if params[:post_button] || defined?(@previous_published_at) && @previous_published_at != @work.published_at
          @work.set_revised_at(@work.published_at)
        end  
        @work.posted = true
        
        #bleep = "BEFORE SAVE: author attr: " + params[:work][:author_attributes][:ids].collect {|a| a}.inspect + "  @work.authors: " + @work.authors.collect {|au| au.id}.inspect + "  @work.pseuds: " + @work.pseuds.collect {|ps| ps.id}.inspect
        
        saved = @work.save
        @work.update_minor_version
      end
      if saved
        if params[:post_button]
          flash[:notice] = t('notices.works.successfully_posted', :default => 'Work was successfully posted.')
       elsif params[:update_button]
          flash[:notice] = t('notices.works.successfully_updated', :default => 'Work was successfully updated.')
       end
        
        #bleep += "  AFTER SAVE: author attr: " + params[:work][:author_attributes][:ids].collect {|a| a}.inspect + "  @work.authors: " + @work.authors.collect {|au| au.id}.inspect + "  @work.pseuds: " + @work.pseuds.collect {|ps| ps.id}.inspect
        #flash[:notice] = "DEBUG: in UPDATE save:  " + bleep
        
        redirect_to(@work)
      else
        unless @chapter.valid?
          @chapter.errors.each {|err| @work.errors.add(:base, err)}
        end
        unless @work.has_required_tags?
          @work.errors.add(:base, "Updating: Required tags are missing.")          
        end
        render :action => :edit
      end
    end 
  end
 
  # GET /works/1/preview
  def preview
    @preview_mode = true
  end
    
  # DELETE /works/1
  def destroy
    @work = Work.find(params[:id])
    begin
      @work.destroy
    rescue
      flash[:error] = t('errors.works.deletion_failed', :default => "We couldn't delete that right now, sorry! Please try again later.")
   end
    redirect_to(user_works_url(current_user))
  end

  # POST /works/upload_work
  def upload_work
    storyparser = StoryParser.new
    # Do stuff with params[:uploaded_file]
    # parse the existing work 
    if params[:uploaded_work]
      @work = storyparser.parse_story(params[:uploaded_work])
      render :action => "new"
    elsif params[:work_url]
      url = params[:work_url].to_s
      if url.empty? 
        flash.now[:error] = t('errors.works.enter_an_url', :default => "Did you want to enter a URL?")
     else
        begin
          @work = storyparser.download_and_parse_story(url)
        rescue Timeout::Error
          flash.now[:error] = t('errors.works.timed_out', :default => "Sorry, but we timed out trying to get that URL.")
       rescue
          flash.now[:error] = t('errors.works.upload_failed', :default => "Sorry, but we couldn't find a story at that URL. You can still copy-and-paste the contents into our standard form, though!")
       end
        begin
          @chapter = @work.chapters.first
          @work.pseuds << current_user.default_pseud
          @chapter.pseuds << current_user.default_pseud
          if (work_saved = @work.save) && @chapter.save
            flash[:notice] = t('notices.works.successfully_uploaded', :default => "Work successfully uploaded!<br />
              (You will want to check the results over carefully before posting, though, because the poor computer can only figure out so much.)")
           redirect_to edit_work_path(@work) and return
          else
            render :action => :new and return
          end
        rescue
          flash.now[:error] = t('notices.works.partially_downloaded', :default => "We managed to partially download the work, but there are problems 
            preventing us from saving it as a draft. Please look over the results very carefully!")
         render :action => :new and return
        end
      end
      @use_upload_form = true
      render :action => :new
    else
      @use_upload_form = true
      render :action => :new
    end
  end
      
  protected

    def load_pseuds
        @allpseuds = (current_user.pseuds + (@work.authors ||= []) + @work.pseuds).uniq
        @pseuds = current_user.pseuds
        @coauthors = @allpseuds.select{ |p| p.user.id != current_user.id}
        to_select = @work.authors.blank? ? @work.pseuds.blank? ? [current_user.default_pseud] : @work.pseuds : @work.authors 
        @selected_pseuds = to_select.collect {|pseud| pseud.id.to_i }
    end

    # create a reading object when showing a work, but only if the user has reading 
    # history enabled and is not the author of the work
    def update_or_create_reading
      return unless @work
      if logged_in? && current_user.preference.history_enabled
        unless current_user.is_author_of?(@work)
          reading = Reading.find_or_initialize_by_work_id_and_user_id(@work.id, current_user.id)
          reading.major_version_read, reading.minor_version_read = @work.major_version, @work.minor_version
          reading.save
        end
      end
      true
    end

    def cancel_posting_and_redirect
      if @work and @work.posted
        flash[:notice] = t('notices.works.not_updated', :default => "<p>The work was not updated.</p>")
        redirect_to user_works_path(current_user)    
      else
        flash[:notice] = t('notices.works.not_posted', :default => "<p>This work was not posted.</p>
        <p>It will be saved here in your drafts for one week, then cleaned up.</p>")
        begin
          current_user.cleanup_unposted_works
        rescue ThinkingSphinx::ConnectionError
        end
        redirect_to drafts_user_works_path(current_user)    
      end
    end

end
