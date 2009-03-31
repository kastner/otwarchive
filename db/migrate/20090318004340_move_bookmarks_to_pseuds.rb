class MoveBookmarksToPseuds < ActiveRecord::Migration
  def self.up
    add_column :bookmarks, :pseud_id, :integer, :null => false
<<<<<<< .working
    #remove_column :bookmarks, :user_id
=======
    # remove later after bookmarks have been migrated
    # but make null okay
    #remove_column :bookmarks, :user_id
    change_column :bookmarks, :user_id, :integer, :null => true
>>>>>>> .merge-right.r1193
  end

  def self.down
<<<<<<< .working
    #add_column :bookmarks, :user_id, :integer, :null => false
    Bookmark.all.each do |bookmark|
=======
    add_column :bookmarks, :user_id, :integer, :null => false
    Bookmark.all.each do |bookmark|
>>>>>>> .merge-right.r1193
      bookmark.update_attribute(:user_id, bookmark.pseud.user.id)
    end
    remove_column :bookmarks, :pseud_id
  end
end
