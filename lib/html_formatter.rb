# note, if you modify this file you have to restart the server or console
module HtmlFormatter
  include SanitizeParams

  # clean up the break tags and convert them into newlines
  def cleanup_break_tags(text)
    text.gsub!(/<br>/, "<br />")
    while text.gsub!(/<br\s*\/>\s*<br\s*\/><br\s*\/>/, "<br /><br />")
      # keep going
    end
    text.gsub!(/<br\s*\/>/i, "\n")
    
    return text
  end

  # clean up tags
  def cleanup_and_format(text)
    text = cleanup_paragraph_tags(close_tags(strip_comments(text)))
    return text
  end
  
  def sanitize_and_format_for_display(text, options = {})
    text = add_paragraph_tags_for_display(sanitize_whitelist(text, options))
  end
  
  def sanitize_title_for_display(text, options = {:tags => %w(a href, b, br, p, i, em, strong, strike, u, ins, q, del, cite, blockquote, pre, code, small, sup, sub)})
    sanitize_whitelist(text, options)
  end
 
  # A more limited display option which strips obtrusive tags for index views.
  def sanitize_limit_and_format_for_display(text, options = {:tags => %w(a href, b, br, p, i, em, strong, strike, u, ins, q, del, cite, blockquote, pre, code, small, sup, sub)})
    text = add_paragraph_tags_for_display(sanitize_whitelist(text, options))
  end

  # cleans up doubled paragraph/newline tags
  def cleanup_paragraph_tags(text)
    # Now we want to replace any cases where these have been doubled -- ie, 
    # where a new paragraph tag is opened before an old one is closed
    text.gsub!(/<p>\s*<p>/, "<p>")
    text.gsub!(/<\/p>\s*<\/p>/, "</p>")
    text.gsub!(/<br\s*\/>\s*<p>/, "<p>")
    
    # and where there are empty paragraphs
    text.gsub!(/<p>\s*<\/p>/, "")
    
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