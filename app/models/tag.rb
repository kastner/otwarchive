class Tag < ActiveRecord::Base

  # Note: the order of this array is important.
  # It is the order that tags are shown in the header of a work
  # (ambiguous tags are grouped with freeform tags)
  # (banned tags are not shown)
  TYPES = ['Rating', 'Warning', 'Category', 'Media', 'Fandom', 'Pairing', 'Character', 'Freeform', 'Ambiguity', 'Banned' ]

  # these tags can be filtered on
  FILTERS = TYPES - ['Banned', 'Media']

  # these tags show up on works
  VISIBLE = TYPES - ['Media', 'Banned']

  # these are tags which have been created by users
  USER_DEFINED = ['Fandom', 'Pairing', 'Character', 'Freeform', 'Ambiguity']

  has_many :mergers, :foreign_key => 'merger_id', :class_name => 'Tag'
  belongs_to :merger, :class_name => 'Tag'
  belongs_to :fandom
  belongs_to :media
  
  has_many :filter_taggings, :foreign_key => 'filter_id'
  has_many :filtered_works, :through => :filter_taggings, :source => :filterable, :source_type => 'Work'
  has_one :filter_count, :foreign_key => 'filter_id'

  has_many :common_taggings, :foreign_key => 'common_tag_id'
  has_many :child_taggings, :class_name => 'CommonTagging', :as => :filterable
  has_many :children, :through => :child_taggings, :source => :common_tag 
  has_many :parents, :through => :common_taggings, :source => :filterable, :source_type => 'Tag'
  has_many :ambiguities, :through => :common_taggings, :source => :filterable, :source_type => 'Ambiguity'
  #has_many :filtered_works, :through => :common_taggings, :source => :filterable, :source_type => 'Work'

  has_many :taggings, :as => :tagger
  has_many :works, :through => :taggings, :source => :taggable, :source_type => 'Work'
  has_many :bookmarks, :through => :taggings, :source => :taggable, :source_type => 'Bookmark'
  has_many :external_works, :through => :taggings, :source => :taggable, :source_type => 'ExternalWork'

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name,
    :maximum => ArchiveConfig.TAG_MAX,
    :message => "is too long -- try using less than #{ArchiveConfig.TAG_MAX} characters or using commas to separate your tags."
  validates_format_of :name,
    :with => /\A[-a-zA-Z0-9 \/?.!''"":;\|\]\[}{=~!@#\$%^&()_+]+\z/,
    :message => "can only be made up of letters, numbers, spaces and basic punctuation, but not commas, asterisks or angle brackets."

  def before_validation
    self.name = name.squish if self.name
  end

  named_scope :canonical, {:conditions => {:canonical => true}, :order => 'name ASC'}
  named_scope :nonsynonymous, {:conditions => {:merger_id => nil, :canonical => false}, :order => 'name ASC'}
  named_scope :unwrangled, {:conditions => {:canonical => false, :merger_id => nil}, :order => 'name ASC'}
  named_scope :visible, {:conditions => ['type in (?)', VISIBLE], :order => 'name ASC' }

  named_scope :by_popularity, {:order => 'taggings_count DESC'}
  named_scope :by_name, {:order => 'name ASC'}
  named_scope :by_date, {:order => 'created_at DESC'}

  named_scope :by_fandom, lambda{|fandom| {:conditions => {:fandom_id => fandom.id}}}
  named_scope :no_parent, :conditions => {:fandom_id => nil}

  named_scope :by_pseud, lambda {|pseud|
    {
      :joins => [{:works => :pseuds}],
      :conditions => {:pseuds => {:id => pseud.id}}
    }
  }

  named_scope :by_type, lambda {|*types| {:conditions => (types.first.blank? ? {} : {:type => types.first})}}

  # enigel Feb 09
  named_scope :starting_with, lambda {|letter| {:conditions => ['SUBSTR(name,1,1) = ?', letter]}}

  named_scope :visible_to_user, lambda { |user_id|
    {
      :select => "DISTINCT works.*",
      :joins => "INNER JOIN creatorships ON (creatorships.creation_id = works.id AND creatorships.creation_type = 'Work')
                 INNER JOIN pseuds ON creatorships.pseud_id = pseuds.id
                 INNER JOIN users ON pseuds.user_id = users.id",
      :conditions => ['works.posted = ? AND (works.hidden_by_admin = ? OR users.id = ?)', true, false, user_id]
    }
  }
  
  named_scope :filters_with_count, lambda { |work_ids|
    {
      :select => "tags.*, count(distinct works.id) as count",
      :joins => :filtered_works,
      :conditions => ['works.id IN (?)', work_ids],
      :order => :name,
      :group => :id
    }     
  }
  
  named_scope :public_top, lambda { |count|
    {
      :select => "tags.*, filter_counts.public_works_count as count",
      :joins => :filter_count,
      :order => 'filter_counts.public_works_count DESC',
      :conditions => 'filter_counts.public_works_count > 0',
      :limit => count
    }     
  }
  
  named_scope :unhidden_top, lambda { |count|
    {
      :select => "tags.*, filter_counts.unhidden_works_count as count",
      :joins => :filter_count,
      :order => 'filter_counts.unhidden_works_count DESC',
      :conditions => 'filter_counts.unhidden_works_count > 0',
      :limit => count
    }     
  } 
  
  # Class methods

  def self.string
    all.map(&:name).join(ArchiveConfig.DELIMITER)
  end

  def to_param
    name
  end

  def self.find_or_create_by_name(string)
    return if !string.is_a?(String) || string.blank?
    string.squish!
    # try to find the tag
    tag = self.find_by_name(string)
    return tag if tag
    # try to create the tag
    tag = self.create(:name => string) rescue nil
    return tag if tag.andand.valid?
    # it wasn't valid, which probably means it already exists in another category
    old_tag = Tag.find_by_name(string)
    if old_tag # so create this one with the category appended
      new_tag = self.find_or_create_by_name(string + " - " + self.to_s)
      return new_tag if new_tag
    else
      # other tag validation errors - wasn't saved
      return tag
    end
  end

  def self.for_tag_cloud
    if fandom_no_tag_name = Fandom.find_by_name(ArchiveConfig.FANDOM_NO_TAG_NAME)
      if freeform = Freeform.find(:all, :conditions => {:fandom_id => fandom_no_tag_name.id, :canonical => true})
        freeform.sort
      end
    end
  end

  # Instance methods that are common to all subclasses (may be overridden in the subclass)

  # sort tags by name
  def <=>(another_tag)
    name.downcase <=> another_tag.name.downcase
  end
  
  #### FILTERING ####
  
  before_save :update_filters_for_canonical_change
  before_save :update_filters_for_merger_change
  
  # If a tag was not canonical but is now, it needs new filter_taggings
  # If it was canonical but isn't anymore, we need to change or remove
  # the filter_taggings as appropriate
  def update_filters_for_canonical_change
    if self.canonical_changed?
      if self.canonical?
        self.add_filter_taggings
      elsif self.merger && self.merger.canonical?
        self.filter_taggings.update_all(["filter_id = ?", self.merger_id])
      else
        self.remove_filter_taggings
      end
    end      
  end
  
  # If a tag has a new merger, add to the filter_taggings for that merger
  # If a tag has a new merger but had an old merger, add new filter_taggings
  # and get rid of the old filter_taggings as appropriate 
  def update_filters_for_merger_change
    if self.merger_id_changed?
      if self.merger && self.merger.canonical?
        self.add_filter_taggings
      end
      old_merger = Tag.find_by_id(self.merger_id_was)
      if old_merger && old_merger.canonical?
        self.remove_filter_taggings(old_merger)
      end
    end    
  end
  
  # Add filter taggings for a given tag
  def add_filter_taggings
    filter = self.canonical? ? self : self.merger
    if filter
      Work.with_any_tags([self, filter]).each do |work|
        work.filter_taggings.find_or_create_by_filter_id(filter.id)
      end
    end
  end
  
  # Remove filter taggings for a given tag
  # If an old_filter value is given, remove filter_taggings from it with due regard
  # for potential duplication (ie, works tagged with more than one synonymous tag)
  def remove_filter_taggings(old_filter=nil)
    if old_filter
      potential_duplicate_filters = [old_filter] + old_filter.mergers - [self]
      self.works.each do |work|
        if (work.tags & potential_duplicate_filters).empty?
          filter_tagging = work.filter_taggings.find_by_filter_id(old_filter.id)
          filter_tagging.destroy if filter_tagging
        end
      end      
    else
      self.filter_taggings.destroy_all
    end    
  end
  
  def reset_filter_count
    filter = self.canonical? ? self : self.merger
    if filter && filter.reload
      attributes = {:public_works_count => filter.filtered_works.posted.unhidden.unrestricted.count, 
                    :unhidden_works_count => filter.filtered_works.posted.unhidden.count}
      if filter.filter_count
        filter.filter_count.update_attributes(attributes)        
      else
        filter.create_filter_count(attributes)
      end
      filter.filter_count.reload
    end
  end
  
  #### END FILTERING ####


  def update_common_tags
    self.works.each do |work|
      work.update_common_tags
    end
  end

  def wrangle_canonical(update_works=true)
    self.update_attribute(:canonical, true)
    self.update_common_tags if update_works
  end

  def wrangle_not_canonical(update_works=true)
    self.update_attribute(:canonical, false)
    self.update_common_tags if update_works
  end

  def wrangle_merger(merger, update_works=true)
    return unless merger.canonical? && merger.is_a?(self.class)
    self.update_attribute(:merger_id, merger.id)
    self.parents << merger.parents rescue nil
    merger.parents << self.parents rescue nil
    self.update_attribute(:fandom_id, merger.fandom_id)
    self.update_attribute(:media_id, merger.media_id)
    self.ensure_correct_fandom_id
    self.ensure_correct_media_id
    self.mergers.each do |synonym|
      synonym.wrangle_merger(merger)
    end
    self.update_common_tags if update_works
  end

  def remove_merger(update_works=true)
    self.update_attribute(:merger_id, nil)
    self.update_common_tags if update_works
  end

  def wrangle_parent(parent, update_works=true)
    return unless parent.is_a?(Tag) && parent.canonical?
    self.parents << parent unless self.parents.include?(parent)
    self.add_fandom(parent.fandom) unless self.fandom == parent.fandom
    self.add_media(parent.media) unless self.media == parent.media
    self.update_common_tags if update_works
  end

  # all tags which have given tag as a parent
  #def children
  #  CommonTagging.find_all_by_filterable_id_and_filterable_type(self.id, 'Tag').map(&:common_tag).uniq.compact.sort
  #end

  # parents children and self
  def family
    ([self] + self.children + self.parents + self.mergers + [self.merger]).compact
  end

  # Tag       Tag_to_add    Relationship
  #  All        Media         Parent
  #  All        Fandom        Parent
  #  All        Freeform      Child
  #  Fandom     Character     Child
  #  Character  Character     Child
  #  Pairing    Character     Parent
  #  Freeform   Character     Parent
  #  Fandom     Pairing       Child
  #  Character  Pairing       Child
  #  Pairing    Pairing       Child
  #  Freeform   Pairing       Parent

  # a pairing character or freeform tag which has been wrangled
  # should have a fandom_id so it no longer shows up on the mass
  # assign page. This should only be "No Fandom" if it has no others.
  def ensure_correct_fandom_id
    # only pairing character and freeform tags must have fandoms
    return unless ['Pairing', 'Character', 'Freeform'].include?(self[:type])

    # get the nofandom tag
    nofandom = Fandom.find_by_name(ArchiveConfig.FANDOM_NO_TAG_NAME)

    # get the first fandom of the current tag which is not nofandom
    fandom = (self.fandoms - [nofandom]).first

    # if we have a fandom, we don't need "No Fandom" as a fandom
    if fandom && self.fandoms.include?(nofandom)
      self.remove_fandom(nofandom)
    end

    # make sure the tag has a fandom id
    if !self.fandom_id # we don't have a fandom id
      if !fandom # and we don't have a fandom
        # we don't have anything, but we're being wrangled, so add "No Fandom"
        self.update_attribute(:fandom_id, nofandom.id)
        self.parents << nofandom unless self.parents.include?(nofandom)
      else # we do have a fandom
        # use the one for our first fandom
        self.update_attribute(:fandom_id, fandom.id)
      end
    end

    # make sure the fandom_id is only for "No Fandom" if we don't have any other fandoms
    if self.fandom_id == nofandom.id
      if fandom
        self.update_attribute(:fandom_id, fandom.id)
      else
        # ensure No Fandom is actually one of its fandoms
        self.parents << nofandom unless self.parents.include?(nofandom)
      end
    end

    # if the fandom id isn't for our first fandom or nofandom, verify that it's a real fandom
    if !(self.fandom_id == nofandom.id || (fandom && self.fandom_id == fandom.id))
      listed_fandom = Fandom.find_by_id(self.fandom_id)
      # it's not a real fandom or it's been removed
      if !listed_fandom.is_a?(Fandom) || !self.fandoms.include?(listed_fandom)
        if fandom
          self.update_attribute(:fandom_id, fandom.id)
        else
          self.update_attribute(:fandom_id, nofandom.id)
        end
      end
    end

    # now that we know we have a good fandom_id, propagate it to our mergers
    self.mergers.each do |merger|
      merger.update_attribute(:fandom_id, self.fandom_id)
    end
  end

  # a fandom tag which has been wrangled should have a media_id
  # so it no longer shows up on the mass assign page. If it doesn't,
  # give it the "No Media" media
  # If it has any media besides "no Media" make sure "No Media" is removed
  def ensure_correct_media_id
    # only fandoms tags must have medias
    return unless self[:type] == 'Fandom'

    uncategorized = Media.uncategorized

    # get the first media of the current tag which is not "Uncategorized Fandoms"
    current_media = ([self.media] + self.medias).compact
    media = (current_media - [uncategorized]).first

    # if we have a media, we don't need "Uncategorized Fandoms" as a media
    if media 
      self.remove_media(uncategorized) if self.medias.include?(uncategorized)
      self.update_attribute(:media_id, media.id) if self.media == uncategorized
    end

    # make sure the tag has a media id
    if !self.media_id # we don't have a media id
      if !media # and we don't have a media
        # we don't have anything, but we're being wrangled, so add "Uncategorized Fandoms"
        self.update_attribute(:media_id, uncategorized.id)
        self.parents << uncategorized unless self.parents.include?(uncategorized)
      else # we do have a media
        # use the one for our first media
        self.update_attribute(:media_id, media.id)
      end
    end

    # if the media id isn't for our first media or "Uncategorized Fandoms", verify that it's a real media
    if !(self.media_id == uncategorized.id || (media && self.media_id == media.id))
      listed_media = Media.find(self.media_id)
      # it's not a real media or it's been removed
      if !listed_media.is_a?(Media) || !self.medias.include?(listed_media)
        if media
          self.update_attribute(:media_id, media.id)
        else
          self.update_attribute(:media_id, uncategorized.id)
        end
      end
    end

  end

  def add_parent_by_id(parent_id)
    if self.is_a?(Fandom)
      add_media(Media.find_by_id(parent_id))
    elsif Tag::USER_DEFINED.include?(self[:type])
      add_fandom(Fandom.find_by_id(parent_id))
    end
  end

  def add_disambiguator(tag)
    return unless self.is_a?(Ambiguity)
    return false unless tag.is_a? Tag
    tag.ambiguities << self unless tag.ambiguities.include?(self)
  end
  def remove_disambiguator(tag)
    return unless self.is_a?(Ambiguity)
    return false unless tag.is_a? Tag
    tag.ambiguities.delete(self)
  end

  def add_media(media_to_add)
    return unless self.is_a?(Fandom)
    return false unless media_to_add.is_a? Media
    self.wrangle_parent(media_to_add)
    if self.media == Media.uncategorized || self.media.nil?
      self.media = media_to_add
      self.save  
    end
    self.ensure_correct_media_id
  end
  def remove_media(media_to_remove)
    return unless self.is_a?(Fandom)
    return false unless media_to_remove.is_a? Media
    self.parents.delete(media_to_remove)
    if self.media == media_to_remove
      uncategorized = Media.uncategorized
      other_media = self.medias - [uncategorized]
      new_media = other_media.empty? ? uncategorized : other_media.first
      self.update_attribute(:media_id, new_media.id)
    end 
    self.ensure_correct_media_id
  end

  def add_fandom(fandom)
    return unless Tag::USER_DEFINED.include?(self[:type])
    return false unless fandom.is_a? Fandom
    self.wrangle_parent(fandom)
    self.ensure_correct_fandom_id
  end

  def remove_fandom(fandom)
    return unless Tag::USER_DEFINED.include?(self[:type])
    return false unless fandom.is_a? Fandom
    self.parents.delete(fandom)
    self.ensure_correct_fandom_id
  end

  def add_freeform(freeform)
    return unless Tag::USER_DEFINED.include?(self[:type])
    return false unless freeform.is_a? Freeform
    freeform.wrangle_parent(self)
  end
  def remove_freeform(freeform)
    return unless Tag::USER_DEFINED.include?(self[:type])
    return false unless freeform.is_a? Freeform
    freeform.parents.delete(self)
  end

  def add_pairing(pairing)
    return unless Tag::USER_DEFINED.include?(self[:type])
    return false unless pairing.is_a? Pairing
    if self.is_a?(Freeform)
      self.wrangle_parent(pairing)
    else
      pairing.wrangle_parent(self)
    end
    if self.is_a?(Character)
      pairing.update_attribute(:has_characters, true)
    end
  end
  def remove_pairing(pairing)
    return unless Tag::USER_DEFINED.include?(self[:type])
    return false unless pairing.is_a? Pairing
    if self.is_a?(Freeform)
      self.parents.delete(pairing)
    else
      pairing.parents.delete(self)
    end
    if self.is_a?(Character)
      pairing.update_attribute(:has_characters, false) if pairing.characters.blank?
    end
  end

  def add_character(character)
    return unless Tag::USER_DEFINED.include?(self[:type])
    return false unless character.is_a? Character
    if self.is_a?(Fandom) || self.is_a?(Character)
      character.wrangle_parent(self)
    else
      self.wrangle_parent(character)
    end
    if self.is_a?(Pairing)
      self.update_attribute(:has_characters, true)
    end
  end
  def remove_character(character)
    return unless Tag::USER_DEFINED.include?(self[:type])
    return false unless character.is_a? Character
    if self.is_a?(Fandom) || self.is_a?(Character)
      character.parents.delete(self)
    else
      self.parents.delete(character)
    end
    if self.is_a?(Pairing)
      self.update_attribute(:has_characters, false) if self.characters.blank?
    end
  end

  def add_synonym(synonym)
    return false unless synonym.is_a?(self.class)
    synonym.wrangle_merger(self)
  end
  def remove_synonym(synonym)
    return false unless synonym.is_a?(self.class)
    self.mergers.delete(synonym)
  end

  def update_type(type, admin=false)
    if type=="Ambiguity" || admin
      self.update_attribute("type", type)
    else
      return false
    end
  end

  def update_disambiguators(new=[])
    return unless self[:type] == 'Ambiguity'
    current = self.disambiguators.map(&:name)
    current = [] unless current
    new = [] unless new
    remove = current - new
    add = new - current
    remove.each do |disambiguator_name|
      self.remove_disambiguator(Tag.find_by_name(disambiguator_name))
    end
    add.each do |disambiguator_name|
      self.add_disambiguator(Tag.find_by_name(disambiguator_name))
    end
    disambiguators
  end

  def update_characters(new=[])
    return unless Tag::USER_DEFINED.include?(self[:type])
    current = self.characters.map(&:name)
    current = [] unless current
    new = [] unless new
    remove = current - new
    add = new - current
    remove.each do |character_name|
      self.remove_character(Character.find_by_name(character_name))
    end
    add.each do |character_name|
      self.add_character(Character.find_by_name(character_name))
    end
    characters
  end

  def update_pairings(new=[])
    return unless Tag::USER_DEFINED.include?(self[:type])
    current = self.pairings.map(&:name)
    current = [] unless current
    new = [] unless new
    remove = current - new
    add = new - current
    remove.each do |pairing_name|
      self.remove_pairing(Pairing.find_by_name(pairing_name))
    end
    add.each do |pairing_name|
      self.add_pairing(Pairing.find_by_name(pairing_name))
    end
    pairings
  end

  def update_fandoms(new=[])
    return unless Tag::USER_DEFINED.include?(self[:type])
    current = self.fandoms.map(&:name)
    current = [] unless current
    new = [] unless new
    remove = current - new
    add = new - current
    remove.each do |fandom_name|
      self.remove_fandom(Fandom.find_by_name(fandom_name))
    end
    add.each do |fandom_name|
      self.add_fandom(Fandom.find_by_name(fandom_name))
    end
    self.ensure_correct_fandom_id
    fandoms
  end

  def update_medias(new_medias=[])
    return unless self[:type] == 'Fandom'
    current = self.medias.map(&:name)
    current = [] unless current
    new_medias = [] unless new_medias
    remove = current - new_medias
    add = new_medias - current
    remove.each do |media_name|
      self.remove_media(Media.find_by_name(media_name))
    end
    add.each do |media_name|
      self.add_media(Media.find_by_name(media_name))
    end
    self.ensure_correct_media_id
    medias
  end

  def update_freeforms(new_freeforms=[])
    return unless Tag::USER_DEFINED.include?(self[:type])
    current = self.freeforms.map(&:name)
    remove = current - new_freeforms
    add = new_freeforms - current
    remove.each do |freeform_name|
      self.remove_freeform(Freeform.find_by_name(freeform_name))
    end
    add.each do |freeform_name|
      self.add_freeform(Freeform.find_by_name(freeform_name))
    end
    freeforms
  end

  def update_synonyms(new=[])
    current = self.mergers.map(&:name)
    current = [] unless current
    new = [] unless new
    remove = current - new
    add = new - current
    remove.each do |tag_name|
      self.remove_synonym(Tag.find_by_name(tag_name))
    end
    add.each do |tag_name|
      self.add_synonym(Tag.find_by_name(tag_name))
    end
    mergers
  end

  # return an array of all the common_tags which tagging with self should add
  def common_tags_to_add
    common_tags = []
    common_tags << self.merger
    common_tags << self if self.canonical
    common_tags << self.parents
    common_tags.flatten.uniq.compact
  end

  # methods for counting visible

  def visible_works_count
    if User.current_user && User.current_user.kind_of?(Admin)
      self.works.count(:all,
          :conditions => {:posted => true})
    elsif User.current_user.is_a? User
      self.works.visible_to_user(User.current_user.id).size
    else
      self.works.count(:all,
          :conditions => {:posted => true, :restricted => false, :hidden_by_admin => false})
    end
  end

  def visible_synonyms_works_count
    if self.canonical
      total = self.visible_works_count
      self.mergers.each do |merger|
        total += merger.visible_works_count
      end
      return total
    elsif self.merger
      return self.merger.visible_synonyms_works_count
    else
      return self.visible_works_count
    end
  end
  
  def visible_bookmarks_count
    if User.current_user && User.current_user.kind_of?(Admin)
      conditions = {:private => false}
    elsif User.current_user.is_a? User
      conditions = ['bookmarks.private = ? AND bookmarks.hidden_by_admin = ? OR bookmarks.pseud_id in (?)', false, false, User.current_user.pseuds.collect(&:id)]
    else
      conditions = {:private => false, :hidden_by_admin => false}
    end
    self.bookmarks.count(:all, :conditions => conditions )
  end

  def visible_external_works_count
    if User.current_user && User.current_user.kind_of?(Admin)
      conditions = {}
    else
      conditions = {:hidden_by_admin => false}
    end
    self.external_works.count(:all, :conditions => conditions )
  end

  def visible_taggables_count
    visible_works_count + visible_bookmarks_count + visible_external_works_count
  end

  def banned
    return self if self.is_a?(Banned)
  end

  def ambiguous
    return self if self.is_a?(Ambiguity)
  end

  def unwrangled
    return self unless (self.canonical || self.merger || ['Ambiguity', 'Banned'].include?(self.class) )
  end

  def find_similar
    Tag.find(:all, :conditions => ["name like ? and canonical = ?", "%" + self.name + "%", true])
  end
  
  def synonyms
    self.canonical? ? self.mergers : [self.merger] + self.merger.mergers - [self]
  end

end
