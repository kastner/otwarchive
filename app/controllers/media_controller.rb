class MediaController < ApplicationController
  
  def index
    @fandom_listing = Fandom.canonical.group_by(&:media).sort_by{|array| array[1].size}.reverse
  end
  
  def show
    if params[:id] == "0"
      @medium_name = "Uncategorized Fandoms".t
      @fandoms = Fandom.canonical.find(:all, :order => :name, :conditions => {:media_id => nil}).paginate(:page => params[:page])
    else
      medium = Media.find(params[:id])
      @medium_name = medium.name
      @fandoms = medium.fandoms.canonical.find(:all, :order => :name).paginate(:page => params[:page])
    end
  end
end
