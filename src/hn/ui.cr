require "termbox"
require "xml"

include Termbox

module HackerNews
  abstract class UiWindow
    abstract def draw(w)
    abstract def handle_event(ev, w, windows)
    abstract def close
  end

  def wrap(s, width = 78)
    if s.starts_with? '>'
      s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n> ")
    else
      s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
    end
  end

  REPLY_COLORS = [2, 3, 4, 5, 6]

  class CommentsWindow < UiWindow
    @comments = [] of Comment

    def initialize(@item : Story, @ch : Channel(Nil))
      @position = 0
      @comments = Parser.comments(@item.id)
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
          w.write_string(Position.new(comment.indent + 1, line_num - 1 - @position), " - by #{comment.author} @ #{comment.time}")
        end
        line_num += 1
      end
      w.render
    end

    def handle_event(ev, w, windows)
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
          @position += w.height
        end
        if ev.key == KEY_PGUP
          @position -= w.height
        end
        @position = 0 if @position < 0
      end
      return true
    end
  end

  class TopStoriesWindow < UiWindow
    @stories : Array(Story)

    def initialize(@ch : Channel(Nil))
      @position = 0
      @stories = Parser.top_stories
      @stories.sort! { |a, b| (b.points || 0) <=> (a.points || 0) }
      Parser.get_viewed_status(@stories)
    end

    def close
    end

    def draw(w)
      w.clear
      @stories.each_with_index do |item, i|
        attrs = i == @position ? ATTR_UNDERLINE : 0
        w.set_primary_colors(9 | attrs, 0)
        if i == @position
          w.write_string(Position.new(1, i), ">")
        end
        w.set_primary_colors(10 | attrs, 0)
        w.write_string(Position.new(3, i), sprintf("[%4d]", item.points))
        w.set_primary_colors(11 | attrs, 0)
        w.write_string(Position.new(9, i), sprintf("[%4d]", item.comments))
        w.set_primary_colors(((item.viewed && i != @position) ? 241 : 0) | attrs, 0)
        w.write_string(Position.new(16, i), item.title || "No title")
        w.set_primary_colors(9, 0)
      end
      w.render
    end

    def handle_event(ev, w, windows)
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
          Parser.mark_viewed(viewing_item.id)
          windows << CommentsWindow.new(viewing_item, @ch)
        end
      end
      return true
    end
  end
end
