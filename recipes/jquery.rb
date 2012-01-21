require 'docs_on_kindle'

class Jquery < DocsOnKindle

  def get_source_files

    @start_url = "http://docs.jquery.com/Main_Page"
    @base_url = "http://docs.jquery.com"
    @start_doc = Nokogiri::HTML run_shell_command("curl -s #{@start_url}")

    sections = extract_sections

    File.open("#{output_dir}/sections.yml", 'w') {|f|
      f.puts sections.to_yaml
    }

  end

   def document 
    # download cover image
    if !File.size?("cover.gif")
      `curl -s 'http://static.jquery.com/files/rocker/images/logo_jquery_215x53.gif' > cover.gif`
    end
    {
      'title' => 'jQuery',
      'author' => 'jQuery',
      'cover' => 'cover.gif',
      'masthead' => 'cover.gif'
    }
  end

 
  def extract_sections
    first_section = {
      title: "Getting Started",
      articles: @start_doc.search('#jq-p-Getting-Started li').map {|li|
        a = li.at("a")
        title = a.inner_text
        next if title == 'Main Page'
        href = a[:href]
        $stderr.puts("  " + title)
        {
          title: a.inner_text,
          path: save_article_and_return_path(a[:href])
        }
      }.compact
    }
    [first_section] + @start_doc.search('#jq-p-API-Reference li a').map {|a|
      title = a.inner_text
      href = "/category#{a[:href]}".downcase # the url is slightly misleading
      href += "/" if href =~ %r{\w$}
      puts "  " + title
      cmd = "curl -sL http://api.jquery.com#{href}"
      articles = Nokogiri::HTML(run_shell_command(cmd)).
        search('a.title-link').map {|a|
          puts "  article: #{a.inner_text} -> #{a[:href]}"
          {
            title: a.inner_text,
            path: save_article_and_return_path(a[:href])
          }
        }
      { title: title, articles: articles }
    }.compact
  end
 
  def save_article_and_return_path href, filename=nil
    path = filename || "articles/" + href[%r{([^/]+)/?$}, 1]
    outpath = "#{output_dir}/#{path}"

    # jQuery's articles are often repeated across sections, so no need to
    # download a second time

    if File.size?(outpath) 
      puts "  #{outpath} already downloaded"
    else
      
      full_url = href =~ /^http/ ? href : (@base_url + href)
      html = run_shell_command "curl -sL #{full_url}"
      if html.nil?
        raise "no html"
      end

      article_doc = Nokogiri::HTML html

      content  = ( article_doc.at('#bodyContent') || article_doc.at('#content') )

      # images have relative paths, so fix them
      content.search("img[@src]").each {|img|
        if img['src'] =~ %r{^/}
          img['src'] = "http://progit.org" + img['src']
        end
      }

      # strip javascript
      content.search("script").each(&:remove)

      # strip comments
      h1 = content.at("#comments")
      if h1
        h1.xpath("./following-sibling::*").each(&:remove)
        h1.remove
      end

      # strip demos (TODO?)
      # h = content.at("h4[contains(text(), 'Demo:')]")

      `mkdir -p #{output_dir}/articles`
      File.open(outpath, 'w') {|f| f.puts content.inner_html}

    end
    path
  end
end

Jquery.generate

