require "./hn/*"

require "termbox"
require "colorize"

include Termbox

def wrap(s, width = 78)
  if s.starts_with? '>'
    s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n> ")
  else
    s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
  end
end

# f = File.open("spec/data/17506753.html")
f = File.open("spec/data/17517285.html")
x = XML.parse(f)
f.close

record Comment,
  text : String,
  kids : Array(Comment)

ind = x.xpath_nodes("//td[@class='ind']")
xx = x.xpath_nodes("//span[@class='c00']")
indents = ind.map { |v| v.xpath_node("img").not_nil!["width"].to_i / 40 }
comment_stack = [] of Comment
comments = [] of Comment
xx.to_a.zip(indents) do |x, y|
  # puts "content = \n".colorize.yellow.to_s + x.parent.not_nil!.parent.to_s + "\n\n"
  asdf = x.to_s.gsub(/<span>.*/m, "").gsub(/<p>/, "\n")
  puts "asdf = ".colorize.green.to_s + wrap(asdf.to_s, width: 120)
  puts "indent = ".colorize.blue.to_s + y.to_s
  c = Comment.new asdf, Array(Comment).new
  if y == 0
    comments << c
  else
    comments[-1].kids << c
  end
end

def print_comments(comments, indent = 0)
  comments.each do |v|
    indent.times { |i| print " " }
    puts v.text
    print_comments(v.kids, indent + 2)
  end
end

print_comments(comments)

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
