class CommentObserver < ActiveRecord::Observer
  
  # Add new comments to the inbox of the person to whom they're directed
  # Send that user a notification email
  def after_create(comment)
    # eventually we will set the locale to the user's stored language of choice
    #Locale.set ArchiveConfig.SUPPORTED_LOCALES[ArchiveConfig.DEFAULT_LOCALE]    
    users = []
    
    # notify the commenter
    if comment.comment_owner && notify_user_of_own_comments?(comment.comment_owner)
      users << comment.comment_owner
    end
    if notify_user_by_email?(comment.comment_owner) && notify_user_of_own_comments?(comment.comment_owner)
      UserMailer.deliver_comment_sent_notification(comment)
    end
    
    if comment.reply_comment?
      # send notification to the owner of the original comment if not
      # the commenter
      parent_comment = comment.commentable
      parent_comment_owner = parent_comment.comment_owner # will be nil if not a user      
      if (!parent_comment_owner && parent_comment.comment_owner_email && parent_comment.comment_owner_name) || 
          (parent_comment_owner && (parent_comment_owner != comment.comment_owner)) 
        if !parent_comment_owner || notify_user_by_email?(parent_comment_owner)
          UserMailer.deliver_comment_reply_notification(parent_comment, comment)
        end
        if parent_comment_owner && notify_user_by_inbox?(parent_comment_owner)
          add_feedback_to_inbox(parent_comment_owner, comment)
        end
        if parent_comment_owner              
          users << parent_comment_owner
        end    
      end

      # if I'm replying to a comment you left for me, mark your comment as replied to in my inbox
      if comment.comment_owner
        if (inbox_comment = comment.comment_owner.inbox_comments.find_by_feedback_comment_id(parent_comment.id))
          inbox_comment.update_attributes(:replied_to => true, :read => true)
        end
      end
    end

    # send notification to the owner(s) of the ultimate parent 
    if users.empty?
      users = comment.ultimate_parent.commentable_owners
    else
      users = comment.ultimate_parent.commentable_owners - users
    end
    
    users.each do |user|
      unless user == comment.comment_owner && !notify_user_of_own_comments?(user)
        if notify_user_by_email?(user)
          UserMailer.deliver_comment_notification(user, comment)
        end
        if notify_user_by_inbox?(user)
          add_feedback_to_inbox(user, comment)
        end
      end
    end
  end

  def after_update(comment)
    if comment.edited_at_changed?
      users = []
      
      # notify the commenter
      if comment.comment_owner && notify_user_of_own_comments?(comment.comment_owner)
        users << comment.comment_owner
      end
      if notify_user_by_email?(comment.comment_owner) && notify_user_of_own_comments?(comment.comment_owner)
        UserMailer.deliver_comment_sent_notification(comment)
      end
      
      if comment.reply_comment?
        # send notification to the owner of the original comment if not the commenter
        parent_comment = comment.commentable
        parent_comment_owner = parent_comment.comment_owner # will be nil if not a user      
        if (!parent_comment_owner && parent_comment.comment_owner_email && parent_comment.comment_owner_name) || 
            (parent_comment_owner && (parent_comment_owner != comment.comment_owner)) 
          if !parent_comment_owner || notify_user_by_email?(parent_comment_owner)
            UserMailer.deliver_edited_comment_reply_notification(parent_comment, comment)
          end
          if parent_comment_owner && notify_user_by_inbox?(parent_comment_owner)
            update_feedback_in_inbox(parent_comment_owner, comment)
          end
          if parent_comment_owner              
            users << parent_comment_owner
          end    
        end

        # if I'm replying to a comment you left for me, mark your comment as replied to in my inbox
        if comment.comment_owner
          if (inbox_comment = comment.comment_owner.inbox_comments.find_by_feedback_comment_id(parent_comment.id))
            inbox_comment.update_attribute(:replied_to, true)
          end
        end
      end

      # send notification to the owner(s) of the ultimate parent 
      if users.empty?
        users = comment.ultimate_parent.commentable_owners
      else
        users = comment.ultimate_parent.commentable_owners - users
      end
      
      users.each do |user|
        unless user == comment.comment_owner && !notify_user_of_own_comments?(user)
          if notify_user_by_email?(user)
            UserMailer.deliver_edited_comment_notification(user, comment)
          end
          if notify_user_by_inbox?(user)
            update_feedback_in_inbox(user, comment)
          end
        end
      end
    end
  end

  protected
    def add_feedback_to_inbox(user, comment)
      new_feedback = user.inbox_comments.build
      new_feedback.feedback_comment_id = comment.id
      new_feedback.save
    end
    
    def update_feedback_in_inbox(user, comment)
      if (edited_feedback = user.inbox_comments.find_by_feedback_comment_id(comment.id))
        edited_feedback.update_attribute(:read, false)
      else # original inbox comment was deleted
        add_feedback_to_inbox(user, comment)
      end
    end

    # notify the user unless 
    # - they aren't a user :>
    # - they are the orphan user
    # - they have preferences set not to be notified
    def notify_user_by_email?(user)
      user.nil? ? false : 
        !(user == User.orphan_account || user.preference.comment_emails_off?)      
    end
    
    def notify_user_by_inbox?(user)
      user.nil? ? false :
        !(user == User.orphan_account || user.preference.comment_inbox_off?)       
    end
    
    def notify_user_of_own_comments?(user)
      user.nil? ? false :
        !(user == User.orphan_account || user.preference.comment_copy_to_self_off?)       
    end

end
