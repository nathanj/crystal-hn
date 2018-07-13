require "xml"

module HackerNews
  record Story,
    id : Int32,
    title : String,
    link : String,
    url : String,
    comments : Int32,
    points : Int32,
    viewed : Bool do
    def open_in_browser
      `$BROWSER "#{link}"`
    end

    def viewed=(v)
      viewed = v
    end
  end

  record Comment,
    text : String,
    indent : Int32

  class Parser
    def self.top_stories
      xml = XML.parse(HTTP::Client.get("https://news.ycombinator.com/").body)

      stories = [] of Story
      links = xml.xpath("//a[@class='storylink']").as(XML::NodeSet)
      links.each do |v|
        vv = v.xpath("../../following-sibling::*[1]//span[@class='score']").as(XML::NodeSet)
        points = 0
        if vv.size > 0
          if /(\d+) points/ =~ vv[0].content
            points = $~[1].to_i
          end
        end

        vv = v.xpath("../../following-sibling::*[1]//a").as(XML::NodeSet)[-1]
        url = "https://news.ycombinator.com/" + vv["href"]
        vv["href"] =~ /id=(\d+)/
        id = $~[1].to_i
        if /(\d+)comment/ =~ vv.content
          comments = $~[1].to_i
        else
          comments = 0
        end

        stories << Story.new id, v.content, v["href"], url, comments, points, false
      end
      stories
    end

    def self.comments(id : Int32)
      xml = XML.parse(HTTP::Client.get("https://news.ycombinator.com/item?id=#{id}").body)
      comments = [] of Comment

      ind = xml.xpath_nodes("//td[@class='ind']")
      xx = xml.xpath_nodes("//span[@class='c00']")
      indents = ind.map { |v| v.xpath_node("img").not_nil!["width"].to_i / 40 }
      comment_stack = [] of Comment
      comments = [] of Comment
      xx.to_a.zip(indents) do |node, indent|
        # puts "content = \n".colorize.yellow.to_s + node.parent.not_nil!.parent.to_s + "\n\n"
        asdf = node.to_s.gsub(/<span>.*/m, "")
          .gsub(/<a href="([^"]+)" rel="nofollow">[^<]+<\/a>/, "\\1")
          .gsub("<span class=\"c00\">", "")
          .gsub("&#x27;", "'")
          .gsub("&#x2F;", "/")
          .gsub("&quot;", "\"")
          .gsub("&gt;", ">")
          .gsub("&lt;", "<")
          .gsub("&amp;", "&")
          .gsub("&#x2019;", "'")
          .gsub("&#x201C;", "\"")
          .gsub("&#x201D;", "\"")
        # puts "asdf = ".colorize.green.to_s + wrap(asdf.to_s, width: 120)
        # puts "indent = ".colorize.blue.to_s + indent.to_s
        comments << Comment.new(asdf, indent)
      end
      comments
    end
  end
end
