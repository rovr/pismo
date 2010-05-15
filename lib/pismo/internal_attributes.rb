module Pismo
  # Internal attributes are different pieces of data we can extract from a document's content
  module InternalAttributes
    # Returns the title of the page/content - attempts to strip site name, etc, if possible
    def title(all = false)
      # TODO: Memoizations
      title = @doc.match( 
                          [
                            '.entryheader h1',                                                # Ruby Inside/Kubrick
                            '.entry-title a',                                               # Common Blogger/Blogspot rules
                            '.post-title a',
                            '.post_title a',
                            '.posttitle a',
                            '.entry-title',
                            '.post-title',
                            '.posttitle',
                            '.post_title',
                            '.pageTitle',
                            '.title h1',                          
                            '.post h2',
                            'h2.title',
                            '.entry h2',                                                      # Common style
                            '.boite_titre a',
                            ['meta[@name="title"]', lambda { |el| el.attr('content') }],
                            '#pname a',                                                       # Google Code style
                            'h1.headermain',
                            'h1.title',
                            '.mxb h1',                                                        # BBC News
                            '#content h1',
                            '#content h2',
                            'a[@rel="bookmark"]'
                          ],
                          all
                        )
      
      # If all else fails, go to the HTML title
      if all
        return [html_title] if !title
        return ([*title] + [html_title]).uniq
      else
        return html_title if !title
        return title
      end
    end
    
    def titles
      title(true)
    end
    
    
    # HTML title
    def html_title
      title = @doc.match('title')
      return unless title

      # Strip off any leading or trailing site names - a scrappy way to try it out..
      title = title.split(/\s+(\-|\||\:)\s+/).sort_by { |i| i.length }.last.to_s.strip
    end
    
    # Return an estimate of when the page/content was created
    # As clients of this library should be doing HTTP retrieval themselves, they can fall to the
    # Last-Updated HTTP header if they so wish. This method is just rough and based on content only.
    def datetime
      # TODO: Clean all this mess up
      
      mo = %r{(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)}i
      
      regexen = [
        /#{mo}\b\s+\d+\D{1,10}\d{4}/i,
        /(on\s+)?\d+\s+#{mo}\s+\D{1,10}\d+/i,
        /(on[^\d+]{1,10})\d+(th|st|rd)?.{1,10}#{mo}\b[^\d]{1,10}\d+/i,
        /\b\d{4}\-\d{2}\-\d{2}\b/i,
        /\d+(th|st|rd).{1,10}#{mo}\b[^\d]{1,10}\d+/i,
        /\d+\s+#{mo}\b[^\d]{1,10}\d+/i,
        /on\s+#{mo}\s+\d+/i,
        /#{mo}\s+\d+/i,
        /\d{4}[\.\/\-]\d{2}[\.\/\-]\d{2}/,
        /\d{2}[\.\/\-]\d{2}[\.\/\-]\d{4}/
      ]
      
      datetime = 10
      
      regexen.each do |r|
        datetime = @doc.to_html[r]
        # p datetime
        break if datetime
      end
      
      return unless datetime && datetime.length > 4
      
      # Clean up the string for use by Chronic
      datetime.strip!
      datetime.gsub!(/(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)[^\w]*/i, '')
      datetime.gsub!(/(mon|tues|tue|weds|wed|thurs|thur|thu|fri|sat|sun)[^\w]*/i, '')
      datetime.sub!(/on\s+/, '')
      datetime.gsub!(/\,/, '')
      datetime.sub!(/(\d+)(th|st|rd)/, '\1')
      
      Chronic.parse(datetime) || datetime
    end
    
    # TODO: Attempts to work out what type of site or page the page is from the provided URL
    # def site_type
    # end
    
    # Returns the author of the page/content
    def author(all = false)
      author = @doc.match([
                          '.post-author .fn',
                          '.wire_author',
                          '.cnnByline b',
                          '.editorlink',
                          '.authors p',
                          ['meta[@name="author"]', lambda { |el| el.attr('content') }],     # Traditional meta tag style
                          ['meta[@name="AUTHOR"]', lambda { |el| el.attr('content') }],     # CNN style
                          '.byline a',                                                      # Ruby Inside style
                          '.post_subheader_left a',                                         # TechCrunch style
                          '.byl',                                                           # BBC News style
                          '.meta a',
                          '.articledata .author a',
                          '#owners a',                                                      # Google Code style
                          '.author a',
                          '.author',
                          '.auth a',
                          '.auth',
                          '.cT-storyDetails h5',                                            # smh.com.au - worth dropping maybe..
                          ['meta[@name="byl"]', lambda { |el| el.attr('content') }],
                          '.timestamp a',
                          '.fn a',
                          '.fn',
                          '.byline-author',
                          '.ArticleAuthor a',
                          '.blog_meta a',
                          'cite a',
                          'cite'
                          ], all)
                          
      return unless author
    
      # Strip off any "By [whoever]" section
      if String === author
        author.sub!(/^(post(ed)?\s)?by\W+/i, '')
      elsif Array === author
        author.map! { |a| a.sub(/^(post(ed)?\s)?by\W+/i, '') }.uniq!
      end
      
      author
    end
    
    def authors
      author(true)
    end
    
    
    # Returns the "description" of the page, usually comes from a meta tag
    def description
      @doc.match([
                  ['meta[@name="description"]', lambda { |el| el.attr('content') }],
                  ['meta[@name="Description"]', lambda { |el| el.attr('content') }],
                  'rdf:Description[@name="dc:description"]',
                  '.description'
       ])
    end
    
    # Returns the "lede(s)" or first paragraph(s) of the story/page
    def lede(all = false)
      lede = @doc.match([ 
                  '.post-text p',
                  '#blogpost p',
                  '.subhead',
                  '//div[@class="entrytext"]//p[string-length()>10]',                      # Ruby Inside / Kubrick style
                  'section p',
                  '.entry .text p',
                  '.entry-content p',
                  '#wikicontent p',                                                        # Google Code style
                  '//td[@class="storybody"]/p[string-length()>10]',                        # BBC News style
                  '//div[@class="entry"]//p[string-length()>100]',
                  # The below is a horrible, horrible way to pluck out lead paras from crappy Blogspot blogs that
                  # don't use <p> tags..
                  ['.entry-content', lambda { |el| el.inner_html[/(#{el.inner_text[0..4].strip}.*?)\<br/, 1] }],
                  ['.entry', lambda { |el| el.inner_html[/(#{el.inner_text[0..4].strip}.*?)\<br/, 1] }],
                  '.entry',
                  '#content p',
                  '#article p',
                  '.post-body',
                  '.entry-content',
                  '.body p',
                  '.document_description_short p',    # Scribd
                  '.single-post p',
                  'p'
                  ], all)
       
      if lede && String === lede
        return lede[/^(.*?\.\s){2}/m] || lede
      elsif lede && Array === lede
        return lede.map { |l| l.to_s[/^(.*?\.\s){2}/m] || l }.uniq
      else
        return body ? body[/^(.*?\.\s){2}/m] : nil
      end
    end
    
    def ledes
      lede(true)
    end
    
    # Returns the "keywords" in the document (not the meta keywords - they're next to useless now)
    def keywords(options = {})
      options = { :stem_at => 10, :word_length_limit => 15, :limit => 20 }.merge(options)
      
      words = {}
      
      # Convert doc to lowercase, scrub out most HTML tags, then keep track of words
      cached_title = title
      content_to_use = body.to_s.downcase + description.to_s.downcase
      
      content_to_use.downcase.gsub(/\<[^\>]{1,100}\>/, '').gsub('. ', ' ').gsub(/\&\w+\;/, '').scan(/\b[a-z][a-z\+\.\'\+\#\-]*\b/).each do |word|
        next if word.length > options[:word_length_limit]
        word.gsub!(/\'\w+/, '')
        words[word] ||= 0
        words[word] += (cached_title =~ /#{word}/i ? 5 : 1)
      end

      # Stem the words and stop words if necessary
      d = words.keys.uniq.map { |a| a.length > options[:stem_at] ? a.stem : a }
      s = File.read(File.dirname(__FILE__) + '/stopwords.txt').split.map { |a| a.length > options[:stem_at] ? a.stem : a }
            
      w = words.delete_if { |k1, v1| s.include?(k1) || (v1 < 2 && words.size > 80) }.sort_by { |k2, v2| v2 }.reverse.first(options[:limit])
      return w
    end
    
    # Returns body text as determined by Arc90's Readability algorithm
    def body
      @body ||= Readability::Document.new(@doc.to_s).content.strip
      
      # HACK: Remove annoying DIV that readability leaves around
      @body.sub!(/\A\<div\>/, '')
      @body.sub!(/\<\/div\>\Z/, '')
      
      return @body
    end
    
    # Returns URL to the site's favicon
    def favicon
      url = @doc.match([['link[@rel="fluid-icon"]', lambda { |el| el.attr('href') }],      # Get a Fluid icon if possible..
                        ['link[@rel="shortcut icon"]', lambda { |el| el.attr('href') }],
                        ['link[@rel="icon"]', lambda { |el| el.attr('href') }]])
      if url && url !~ /^http/ && @url
        url = URI.join(@url , url).to_s
      end
      
      url
    end
    
    # Returns URL(s) of Web feed(s)
    def feed(all = false)
      url = @doc.match([['link[@type="application/rss+xml"]', lambda { |el| el.attr('href') }],
                        ['link[@type="application/atom+xml"]', lambda { |el| el.attr('href') }]], all
      )
      
      if url && String === url && url !~ /^http/ && @url
        url = URI.join(@url , url).to_s
      elsif url && Array === url
        url.map! do |u|
          if u !~ /^http/ && @url
            URI.join(@url, u).to_s
          else
            u
          end
        end
        url.uniq!
      end
      
      url
    end
    
    def feeds
      feed(true)
    end
  end
end