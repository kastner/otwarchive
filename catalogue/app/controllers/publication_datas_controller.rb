class PublicationDatasController < ApplicationController
   before_filter :load_book  

  def load_book
    @book = Book.find(params[:book_id])
  end
  # GET /publication_datas
  # GET /publication_datas.xml
  def index
    @publication_datas = PublicationData.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @publication_datas }
    end
  end

  # GET /publication_datas/1
  # GET /publication_datas/1.xml
  def show
    @publication_data = PublicationData.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @publication_data }
    end
  end

  # GET /publication_datas/new
  # GET /publication_datas/new.xml
  def new
    @publication_data = PublicationData.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @publication_data }
    end
  end

  # GET /publication_datas/1/edit
  def edit
    @publication_data = PublicationData.find(params[:id])
  end

  # POST /publication_datas
  # POST /publication_datas.xml
  def create
    @publication_data = PublicationData.new(params[:publication_data])

    respond_to do |format|
      if @publication_data.save
        flash[:notice] = 'PublicationData was successfully created.'
        format.html { redirect_to(@publication_data) }
        format.xml  { render :xml => @publication_data, :status => :created, :location => @publication_data }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @publication_data.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /publication_datas/1
  # PUT /publication_datas/1.xml
  def update
    @publication_data = PublicationData.find(params[:id])

    respond_to do |format|
      if @publication_data.update_attributes(params[:publication_data])
        flash[:notice] = 'PublicationData was successfully updated.'
        format.html { redirect_to(@publication_data) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @publication_data.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /publication_datas/1
  # DELETE /publication_datas/1.xml
  def destroy
    @publication_data = PublicationData.find(params[:id])
    @publication_data.destroy

    respond_to do |format|
      format.html { redirect_to(publication_datas_url) }
      format.xml  { head :ok }
    end
  end
end
