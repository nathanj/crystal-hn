require "termbox"

include Termbox

module HackerNews
  abstract class UiWindow
    abstract def draw(w)
    abstract def handle_event(ev, windows)
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

  class CommentsWindow < UiWindow
    def initialize(@db : DB::Database, @item : Item, @ch : Channel(Nil))
      @channel = Channel(Item).new
      @num_fetching = 0
      @need_redraw = false
      @comments = [] of Item
      f = File.open "whee22", "w"
      f.puts("starting thing")
      if @item.kids
        @item.kids.not_nil!.each do |id|
          f.puts("spawning thread for sending #{id}")
          @num_fetching += 1
          spawn do
            nil.not_nil!
            f.puts("fetching #{id}")
            f.flush
            item = HackerNews::Api.get_item(@db, id)
            f.puts("fetched #{id}")
            f.flush
            @channel.send(item)
          end
        end
      end

      f.puts("spawning thread for receving")
      f.flush
      spawn do
        while @num_fetching > 0
          @comments << @channel.receive
          f.puts("received #{@comments[-1].id}")
          f.flush
          @need_redraw = true
          @num_fetching -= 1
          @ch.send(nil)
        end
      end
    end

    def draw(w)
      w.clear
      w.write_string(Position.new(0, 0), "comments here")
      line_num = 0
      @comments.each do |comment|
        text = comment.text || ""
        text = text.gsub("&#x27;", "'")
        text = text.gsub("&#x2F;", "/")
        text = text.gsub("&quot;", "\"")
        text = text.gsub("&gt;", ">")
        text = text.gsub("&lt;", "<")
        paragraphs = text.split("<p>").map { |v| wrap(v) }
        paragraphs.each do |text|
          text.split("\n").each do |line|
            w.set_primary_colors(2, 0)
            w.write_string(Position.new(0, line_num), "│")
            w.set_primary_colors(7, 0)
            if line.starts_with? ">"
              w.set_primary_colors(9, 0)
            end
            w.write_string(Position.new(2, line_num), line)
            line_num += 1
          end
        end
        t = Time.epoch(comment.time)
        w.set_primary_colors(3, 0)
        w.write_string(Position.new(1, line_num - 1), " - #{comment.by} @ #{to_pretty(t)}")
        line_num += 1
      end
      w.render
    end

    def handle_event(ev, windows)
      if ev.type == EVENT_KEY
        if ev.key == KEY_ESC || ev.ch == 'q'.ord || ev.ch == 'h'.ord
          return false
        end
      end
      return true
    end
  end

  class TopStoriesWindow < UiWindow
    @stories : Array(Item)

    def initialize(@db : DB::Database, @ch : Channel(Nil))
      @position = 0
      @f = File.open "log33", "w"
      @f.puts("starting thing")
      @stories = HackerNews::Api.topstories(@db, 30).map { |id| HackerNews::Api.get_item(@db, id) }
      @stories.sort! { |a, b| (b.score || 0) <=> (a.score || 0) }
      @f.puts("got stories")
      @f.close
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
