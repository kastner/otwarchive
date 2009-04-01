module InboxHelper
  # Describes commentable - used on inbox show page
  def commentable_description_link(comment)
    name = comment.ultimate_parent.title
    link_to name, work_comment_path(comment.ultimate_parent, comment)
  end
  
  def commentable_owner_link(comment)
    if comment.pseud.nil?
      return comment.name
    else
      return link_to(comment.pseud.name, [comment.pseud.user, comment.pseud])
    end
  end
  
  #TODO: change to a proper ajax link
  def inbox_reply_link(comment)
    link_to("Reply", fallback_url_for_comment(comment, {:add_comment_reply_id => comment.id}))
  end
  
end
