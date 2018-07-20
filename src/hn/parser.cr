require "xml"

module HackerNews
  class Story
    property id : Int32
    property title : String
    property link : String
    property url : String
    property comments : Int32
    property points : Int32
    property viewed : Bool

    def initialize(@id, @title, @link, @url, @comments, @points, @viewed)
    end

    def open_in_browser
      browser = ENV["BROWSER"]? || "firefox"
      `#{browser} "#{link}"`
    end
  end

  record Comment,
    text : String,
    author : String,
    time : String,
    indent : Int32

  class Parser
    private def self.parse_top_stories(xml)
      stories = [] of Story
      links = xml.xpath_nodes("//a[@class='storylink']")
      links.each do |v|
        vv = v.xpath_nodes("../../following-sibling::*[1]//span[@class='score']")
        points = 0
        if vv.size > 0
          if /(\d+) points/ =~ vv[0].content
            points = $~[1].to_i
          end
        end

        vv = v.xpath_nodes("../../following-sibling::*[1]//a")[-1]
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

    private def self.open_db
      path = ENV["XDG_CACHE_HOME"]? || "#{ENV["HOME"]}/.cache/hn"
      Dir.mkdir_p(path, 0o755)
      db = DB.open "sqlite3://#{path}/db"
      db.exec "create table if not exists viewed (id integer unique)"
      db
    end

    def self.get_viewed_status(stories)
      db = open_db
      stories.each do |v|
        data = db.query_one? "select id from viewed where id = ?", v.id, as: Int32
        v.viewed = true if data
      end
      db.close
    end

    def self.mark_viewed(story)
      db = open_db
      db.exec "insert or ignore into viewed values (?)", story.id
      story.viewed = true
      db.close
    end

    def self.mark_all_viewed(stories)
      db = open_db
      db.exec "begin transaction"
      stories.each do |v|
        db.exec "insert or ignore into viewed values (?)", v.id
        v.viewed = true
      end
      db.exec "commit"
      db.close
    end

    def self.top_stories_fn(fn)
      f = File.open(fn)
      xml = XML.parse(f)
      f.close
      parse_top_stories(xml)
    end

    def self.top_stories
      xml = XML.parse(HTTP::Client.get("https://news.ycombinator.com/").body)
      parse_top_stories(xml)
    end

    private def self.parse_comments(xml)
      comments = [] of Comment

      ind = xml.xpath_nodes("//td[@class='ind']")
      xx = xml.xpath_nodes("//span[@class='c00']")
      indents = ind.map { |v| v.xpath_node("img").not_nil!["width"].to_i / 40 }
      comment_stack = [] of Comment
      comments = [] of Comment
      xx.to_a.zip(indents) do |node, indent|
        # puts "content = \n".colorize.yellow.to_s + node.parent.not_nil!.parent.to_s + "\n\n"
        author = node.xpath_node("../../..//a[@class='hnuser']").try(&.content) || ""
        time = node.xpath_node("../../..//span[@class='age']/a").try(&.content) || ""
        asdf = node.to_s
          .gsub(/<span>.*/m, "")
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
        comments << Comment.new(asdf, author, time, indent)
      end
      comments
    end

    def self.comments_fn(fn)
      f = File.open(fn)
      xml = XML.parse(f)
      f.close
      parse_comments(xml)
    end

    def self.comments(id : Int32)
      xml = XML.parse(HTTP::Client.get("https://news.ycombinator.com/item?id=#{id}").body)
      parse_comments(xml)
    end
  end
end
