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
  end

  class Parser
    def initialize(filename : String)
      f = File.open(filename)
      @x = XML.parse(f)
      f.close
    end

    def top_stories
      stories = [] of Story
      links = @x.xpath("//a[@class='storylink']").as(XML::NodeSet)
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
  end
end
