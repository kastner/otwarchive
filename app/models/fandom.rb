class Fandom < Tag

  NAME = ArchiveConfig.FANDOM_CATEGORY_NAME

  named_scope :by_media, lambda{|media| {:conditions => {:media_id => media.id}}}
  named_scope :no_parent, :conditions => {:media_id => Media.uncategorized.andand.id}
  
  before_save :add_media_for_uncategorized
  def add_media_for_uncategorized
    if self.media_id.nil?
      uncategorized = Media.uncategorized
      other_media = self.medias - [uncategorized]
      if !other_media.empty?
        self.media = other_media.first
      else
        self.media = uncategorized
      end
    end    
  end

  def characters
    children.by_type('Character').by_name
  end

  def pairings
    children.by_type('Pairing').by_name
  end

  def freeforms
    children.by_type('Freeform').by_name
  end

  def fandoms
    (children + parents).select {|t| t.is_a? Fandom}.sort
  end

  def medias
    parents.by_type('Media').by_name
  end

end


