class SerialWork < ActiveRecord::Base
  belongs_to :series
  belongs_to :work
  
  before_create :set_position
  before_destroy :adjust_positions
  
  # Sets the position of a work in a series
  def set_position
    self.position = self.series.serial_works.count + 1
  end
  
  # Adjust positions of other serial works down when one is deleted
  def adjust_positions
    serials = self.series.serial_works.find(:all, :conditions => "position > #{self.position}")
    serials.each {|s| s.update_attribute(:position, (s.position - 1))}
  end
  
end
