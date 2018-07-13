require "termbox"
require "xml"

include Termbox

module HackerNews
  abstract class UiWindow
    abstract def draw(w)
    abstract def handle_event(ev, windows)
    abstract def close
  end

  def wrap(s, width = 78)
    if s.starts_with? '>'
      s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n> ")
    else
      s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
    end
  end

  def to_pretty(t)
    a = (Time.now - t).to_i

    case a
    when               0 then "just now"
    when               1 then "a second ago"
    when 2..59           then a.to_s + " seconds ago"
    when 60..119         then "a minute ago" # 120 = 2 minutes
    when 120..3540       then (a/60).to_i.to_s + " minutes ago"
    when 3541..7100      then "an hour ago" # 3600 = 1 hour
    when 7101..82800     then ((a + 99)/3600).to_i.to_s + " hours ago"
    when 82801..172000   then "a day ago" # 86400 = 1 day
    when 172001..518400  then ((a + 800)/(60*60*24)).to_i.to_s + " days ago"
    when 518400..1036800 then "a week ago"
    else                      ((a + 180000)/(60*60*24*7)).to_i.to_s + " weeks ago"
    end
  end

  REPLY_COLORS = [1, 2, 3, 4, 5, 6, 7]

  record Comment,
    text : String,
    indent : Int32

  class CommentsWindow < UiWindow
    def initialize(@db : DB::Database, @item : Item, @ch : Channel(Nil))
      @position = 0
      @comments = [] of Comment

      html = HTTP::Client.get("https://news.ycombinator.com/item?id=#{@item.id}").body
      x = XML.parse(html)
      # f = File.open("spec/data/17517285.html")
      # x = XML.parse(f)
      # f.close

      ind = x.xpath_nodes("//td[@class='ind']")
      xx = x.xpath_nodes("//span[@class='c00']")
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
        @comments << Comment.new(asdf, indent)
      end
    end

    def close
    end

    private def get_reply_color(indent)
      REPLY_COLORS[indent % REPLY_COLORS.size]
    end

    def draw(w)
      top = @position
      bottom = @position + w.height
      w.clear
      line_num = 0
      @comments.each do |comment|
        text = comment.text
        paragraphs = text.split("<p>").map { |v| wrap(v, width: 78 - comment.indent) }
        paragraphs.each do |text|
          text.split("\n").each do |line|
            if line_num >= top && line_num <= bottom
              w.set_primary_colors(get_reply_color(comment.indent), 0)
              w.write_string(Position.new(comment.indent, line_num - @position), "│")
              w.set_primary_colors(7, 0)
              if line.starts_with? ">"
                w.set_primary_colors(9, 0)
              end
              w.write_string(Position.new(comment.indent + 2, line_num - @position), line)
            end
            line_num += 1
          end
        end
        if line_num >= top && line_num <= bottom
          # t = Time.epoch(comment.time)
          w.set_primary_colors(3, 0)
          w.write_string(Position.new(comment.indent + 1, line_num - 1 - @position), " - by @ time")
        end
        line_num += 1
      end
      w.render
    end

    def handle_event(ev, windows)
      if ev.type == EVENT_KEY
        if ev.key == KEY_ESC || ev.ch == 'q'.ord || ev.ch == 'h'.ord || ev.key == KEY_ARROW_LEFT
          return false
        end
        if ev.key == KEY_ARROW_DOWN || ev.ch == 'j'.ord
          @position += 1
        end
        if ev.key == KEY_ARROW_UP || ev.ch == 'k'.ord
          @position -= 1
        end
        if ev.key == KEY_PGDN
          @position += 20
        end
        if ev.key == KEY_PGUP
          @position -= 20
        end
        @position = 0 if @position < 0
      end
      return true
    end
  end

  class TopStoriesWindow < UiWindow
    @stories : Array(Item)

    def initialize(@db : DB::Database, @ch : Channel(Nil))
      @position = 0
      @stories = HackerNews::Api.topstories(@db, 30).map { |id| HackerNews::Api.get_item(@db, id) }
      @stories.sort! { |a, b| (b.score || 0) <=> (a.score || 0) }
    end

    def close
    end

    def draw(w)
      w.clear
      @stories.each_with_index do |item, i|
        # pp item
        # puts item.title.colorize.blue
        # `$BROWSER "#{item.url}"`
        attrs = i == @position ? ATTR_BOLD : 0
        w.set_primary_colors(9 | attrs, 0)
        if i == @position
          w.write_string(Position.new(1, i), ">")
        end
        w.set_primary_colors(10 | attrs, 0)
        w.write_string(Position.new(3, i), sprintf("[%4d]", item.score))
        w.set_primary_colors(11 | attrs, 0)
        w.write_string(Position.new(9, i), sprintf("[%4d]", item.descendants || 0))
        w.set_primary_colors((item.viewed ? 1 : 9) | attrs, 0)
        w.write_string(Position.new(16, i), item.title || "No title")
        w.set_primary_colors(9, 0)
        # w.write_string(Position.new(0, i + 1), "Fetching...")
        # sleep 0.5
      end
      w.render
    end

    def handle_event(ev, windows)
      if ev.type == EVENT_KEY
        if [KEY_ESC, KEY_CTRL_C, KEY_CTRL_D].includes? ev.key
          return false
        end
        if ev.ch == 'q'.ord
          return false
        end
        if ev.ch == 'j'.ord || ev.key == KEY_ARROW_DOWN
          @position += 1
        end
        if ev.ch == 'k'.ord || ev.key == KEY_ARROW_UP
          @position -= 1
        end
        if ev.ch == 'b'.ord
          @stories[@position].open_in_browser
        end
        if ev.ch == 'l'.ord || ev.key == KEY_ENTER || ev.key == KEY_ARROW_RIGHT
          viewing_item = @stories[@position]
          viewing_item.viewed = true
          HackerNews::Api.mark_viewed(@db, viewing_item.id)
          windows << CommentsWindow.new(@db, viewing_item, @ch)
        end
      end
      return true
    end
  end
end
