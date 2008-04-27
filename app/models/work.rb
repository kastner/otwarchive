class Work < ActiveRecord::Base
  has_many :chapters, :dependent => :destroy
  validates_associated :chapters, :message => nil

  has_one :metadata, :as => :described, :dependent => :destroy
  validates_presence_of :metadata
  validates_associated :metadata, :message => nil

  acts_as_commentable
  
  attr_reader :pseud 
  
  def number_of_chapters
     Chapter.maximum(:position, :conditions => ['work_id = ?', self.id])
  end
  
  # Change the position of multiple chapters when one is deleted or moved
  def adjust_chapters(position, method = "subtract")
    if method == "subtract"
      Chapter.update_all("position = (position - 1)", ["work_id = (?) AND position > (?)", self.id, position])
    elsif method == "add"
      Chapter.update_all("position = (position + 1)", ["work_id = (?) AND position > (?)", self.id, position])
    end
  end

end
