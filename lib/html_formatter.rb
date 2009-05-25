# note, if you modify this file you have to restart the server or console
module HtmlFormatter
  include SanitizeParams

  # clean up the break tags and convert them into newlines
  # before saving
  def cleanup_break_tags_before_adding(text)
    text.gsub!(/<br\s*?\/?>/i, "\n")
    return text
  end
  
  # clean up the break tags after they have been added for display
  def cleanup_break_tags(text)
    text.gsub!(/<br\s*\/?>/i, "<br />")
    while text.gsub!(/<br \/><br \/><br \/>/im, "<br /><br />")
      # keep going
    end
    
    return text
  end

  # clean up tags
  def cleanup_and_format(text)
    text = cleanup_paragraph_tags(cleanup_break_tags_before_adding(close_tags(strip_comments(text))))
    return text
  end
  
  def sanitize_and_format_for_display(text, options = {})
    text = add_paragraph_tags_for_display(sanitize_whitelist(text, options))
  end
  
  # This is future-planning - titles are currently stripped of all html in order to make sort and search simpler, so there should be no tags in titles which need sanitize in the view. 
  def sanitize_title_for_display(text, options = {:tags => %w(a href, b, br, p, i, em, strong, strike, u, ins, q, del, cite, blockquote, pre, code, small, sup, sub)})
    sanitize_whitelist(text, options)
  end
 
  # A more limited display option for comments and summaries
  def sanitize_limit_and_format_for_display(text, options = {:tags => %w(a href, b, big, blockquote, br, center, cite, code, del, em, i, img, ins, p, pre, q, small, strike, strong,  sub, sup, u)})
    text = add_paragraph_tags_for_display(sanitize_whitelist(text, options))
  end
  
    # A more limited display option which strips obtrusive tags for index views.
  def sanitize_strip_images_and_format_for_display(text, options = {:tags => %w(a href, b, big, blockquote, br, center, cite, code, del, em, i, ins, p, pre, q, small, strike, strong,  sub, sup, u)})
    text = add_paragraph_tags_for_display(sanitize_whitelist(text, options))
  end

  # cleans up doubled paragraph/newline tags
  def cleanup_paragraph_tags(text)
    # make sure there are paragraphs inside blockquotes
    text.gsub!(/<blockquote>/, '<blockquote><p>')
    text.gsub!(/<\/blockquote>/, '</p></blockquote>')
    
    # Now we want to replace any cases where these have been doubled -- ie, 
    # where a new paragraph tag is opened before an old one is closed
    text.gsub!(/<p>\s*<p>/im, "<p>")
    text.gsub!(/<\/p>\s*<\/p>/im, "</p>")
    while text.gsub!(/<br\s*\/>\s*<p>/im, "<p>")
    end

    while text.gsub!(/<p>\s*<br\s*\/>/im, "<p>")
    end

    #<pre> blocks shouldn't contain any linebreak markup
    a = text.scan(/<pre>.*?<\/pre>/im) 
    a.each do |pre|
      text = text.sub(pre.to_s(), pre.to_s().gsub(/<(\/)?(br|p)(\s)?(\/)?>/, "")) 
    end

    # and where there are empty paragraphs
    text.gsub!(/<p>\s*<\/p>/im, "")
    
    # also get rid of blank paragraphs inserted by tinymce
    text.gsub!(/<p>&nbsp;<\/p>/, "")
    
    return cleanup_break_tags(text)
  end

  # adds paragraphs and newlines, then gets rid of doubled ones
  def add_paragraph_tags_for_display(text)
    # Here's the stuff basically stolen from simple_format
    start_tag = "<p>"
    text = text.to_s.dup
    text.gsub!(/\r\n?/, "\n")                    # \r\n and \r -> \n
    text.gsub!(/\n\n+/, "</p>\n\n#{start_tag}")  # 2+ newline  -> paragraph
    text.gsub!(/([^\n]\n)(?=[^\n])/, '\1<br />') # 1 newline   -> br
    text.insert 0, start_tag
    text << "</p>"    

    text = cleanup_paragraph_tags(text)
    
    return text
  end

  #closes tags in html (uses http://snippets.dzone.com/posts/show/3822, but
  #modified)
  def close_tags(html)

    # no closing tag necessary for these
    soloTags = ["br","hr"]

    # Analyze all <> elements
    stack = Array.new
    result = html.gsub( /(<.*?>)/m ) do | element |
      if element =~ /\A<\/(\w+)/ then
        # </tag>
        tag = $1.downcase
        if stack.include?(tag) then
          # If allowed and on the stack
          # Then pop down the stack
          top = stack.pop
          out = "</#{top}>"
          until top == tag do
            top = stack.pop
            out << "</#{top}>"
          end
          out
        end
      elsif element =~ /\A<(\w+)\s*\/>/
        # <tag />
        tag = $1.downcase
        "<#{tag} />"
      elsif element =~ /\A<(\w+)/ then
        # <tag ...>
        tag = $1.downcase
        if ! soloTags.include?(tag) then
          stack.push(tag)
        end
        out = "<#{tag}"
        tag = $1.downcase
        while ( $' =~ /(\w+)=("[^"]+")/ )
          attr = $1.downcase
          valu = $2
          out << " #{attr}=#{valu}"
        end
        out << ">"
      end
    end
    
    # eat up unmatched leading >
    while result.sub!(/\A([^<]*)>/m) { $1 } do end
    
    # eat up unmatched trailing <
    while result.sub!(/<([^>]*)\Z/m) { $1 } do end
    
    # clean up the stack
    if stack.length > 0 then
      result << "</#{stack.reverse.join('></')}>"
    end
    
    result
  end
    
end
