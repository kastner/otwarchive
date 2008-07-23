class CreationObserver < ActiveRecord::Observer
  observe Chapter, Work # + Series?

  # Notify new co-authors that they've been added to a work
  def before_save(creation)
    work = creation.class == Work ? creation : creation.work
    unless creation.authors.blank? || work.poster.blank?
      new_authors = (creation.authors - (work.pseuds + work.poster.pseuds)).uniq
      unless new_authors.blank?
        for pseud in new_authors
          UserMailer.deliver_coauthor_notification(pseud.user, work)
        end
      end
    end
  end
  
end