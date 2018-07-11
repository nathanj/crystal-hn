require "./hn/*"

require "termbox"

include Termbox

f = File.open("spec/data/17506753.html")
x = XML.parse(f)
f.close

xx = x.xpath("//span[@class='c00']").as(XML::NodeSet)
xx.each do |v|
  puts v
end

exit

w = Window.new
w.set_output_mode(OUTPUT_256)
w.set_primary_colors(9, 0)
w.clear

w.write_string(Position.new(0, 0), "Fetching top stories...")
w.render

position = 0
viewing_item = 0

hn = HackerNews::Parser.new "spec/data/index.html"
stories = hn.top_stories
stories.sort! { |a, b| b.points <=> a.points }

# stories.each do |v|
#  puts "#{sprintf("%4d", v.points).colorize.green}p #{sprintf("%4d", v.comments).colorize.yellow}c #{v.title}"
# end

def draw(w, stories, position)
  w.clear
  stories.each_with_index do |item, i|
    # pp item
    # puts item.title.colorize.blue
    # `$BROWSER "#{item.url}"`
    attrs = i == position ? ATTR_BOLD : 0
    w.set_primary_colors(9 | attrs, 0)
    if i == position
      w.write_string(Position.new(1, i), ">")
    end
    w.set_primary_colors(10 | attrs, 0)
    w.write_string(Position.new(3, i), sprintf("[%4d]", item.points))
    w.set_primary_colors(11 | attrs, 0)
    w.write_string(Position.new(9, i), sprintf("[%4d]", item.comments))
    w.set_primary_colors((item.viewed ? 1 : 9) | attrs, 0)
    w.write_string(Position.new(16, i), item.title)
    w.set_primary_colors(9, 0)
  end
  w.render
end

draw w, stories, position

loop do
  ev = w.poll
  if ev.type == EVENT_KEY
    if [KEY_ESC, KEY_CTRL_C, KEY_CTRL_D].includes? ev.key
      break
    end
    if ev.ch == 'q'.ord
      break
    end
    if ev.ch == 'j'.ord || ev.key == KEY_ARROW_DOWN
      position += 1
      draw w, stories, position
    end
    if ev.ch == 'k'.ord || ev.key == KEY_ARROW_UP
      position -= 1
      draw w, stories, position
    end
    if ev.ch == 'b'.ord
      stories[position].open_in_browser
    end
    if ev.ch == 'l'.ord || ev.key == KEY_ENTER || ev.key == KEY_ARROW_RIGHT
      # viewing_item = top[position]
      # viewing_item.viewed = true
      # HackerNewsApi.mark_viewed db, viewing_item.id
      # draw_item w, db, viewing_item
    end
    if ev.ch == 'h'.ord || ev.key == KEY_ARROW_LEFT
      # draw w, top, position
    end
  end
end

w.shutdown
