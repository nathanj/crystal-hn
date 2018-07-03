require "json"
require "http"
require "colorize"
require "termbox"
require "sqlite3"

require "./hn/*"

include Termbox

class Item
  JSON.mapping(
    id: Int64,
    title: String?,
    text: String?,
    type: String,
    time: UInt64,
    score: Int32?,
    kids: Array(Int64)?,
    url: String?,
    by: String?,
    deleted: Bool?,
  )
end

db = DB.open "sqlite3://./db.db"
db.exec "create table if not exists cache (id integer, data text)"

def wrap(s, width = 78)
  s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
end

class HackerNewsApi
  def self.topstories(db, limit : Int32 = 10)
    JSON.parse(HTTP::Client.get("https://hacker-news.firebaseio.com/v0/topstories.json").body)
      .as_a[0..limit]
      .map { |v| v.as_i64 }
  end

  def self.get_item(db, id : Int64)
    data = db.query_one? "select data from cache where id = ?", id, as: String
    if data.nil?
      data = HTTP::Client.get("https://hacker-news.firebaseio.com/v0/item/#{id}.json").body
      db.exec "insert into cache values (?, ?)", id, data
    end
    Item.from_json(data)
  end
end

w = Window.new
w.set_output_mode(OUTPUT_256)
w.set_primary_colors(9, 0)
w.clear

w.write_string(Position.new(0, 0), "Fetching top stories...")
w.render

position = 0
viewing_item = 0
top = HackerNewsApi.topstories(db, 20).map { |id| HackerNewsApi.get_item db, id }

# pp top

def draw(w, top, position)
  w.clear
  top.each_with_index do |item, i|
    # pp item
    # puts item.title.colorize.blue
    # `$BROWSER "#{item.url}"`
    attrs = i == position ? ATTR_BOLD : 0
    w.set_primary_colors(9 | attrs, 0)
    if i == position
      w.write_string(Position.new(1, i), ">")
    end
    w.set_primary_colors(10 | attrs, 0)
    w.write_string(Position.new(3, i), "[ #{item.score} ]")
    w.set_primary_colors(9 | attrs, 0)
    w.write_string(Position.new(13, i), item.title || "No title")
    w.set_primary_colors(9, 0)
    # w.write_string(Position.new(0, i + 1), "Fetching...")
    # sleep 0.5
  end
  w.render
end

draw w, top, position

def draw_item(w, db, item)
  if item.kids
    kids = item.kids.not_nil!.map { |id| HackerNewsApi.get_item db, id }
    w.clear
    text = kids[0].text.not_nil!
    text = text.gsub("&#x27;", "'")
    paragraphs = text.split("<p>").map { |v| wrap(v) }
    line_num = 0
    paragraphs.each do |text|
      text.split("\n").each do |line|
        w.set_primary_colors(2, 0)
        w.write_string(Position.new(0, line_num), "│")
        w.set_primary_colors(8, 0)
        w.write_string(Position.new(2, line_num), line)
        line_num += 1
      end
    end
    w.render
  end
end

loop do
  ev = w.poll
  if ev.type == EVENT_KEY
    w.write_string(Position.new(20, 20), "          ")
    w.write_string(Position.new(20, 20), ev.key.to_s)
    w.write_string(Position.new(21, 21), "        ")
    w.write_string(Position.new(21, 21), ev.ch.to_s)
    w.render
    if [KEY_ESC, KEY_CTRL_C, KEY_CTRL_D].includes? ev.key
      break
    end
    if ev.ch == 'q'.ord
      break
    end
    if ev.ch == 'j'.ord || ev.key == KEY_ARROW_DOWN
      position += 1
      draw w, top, position
    end
    if ev.ch == 'k'.ord || ev.key == KEY_ARROW_UP
      position -= 1
      draw w, top, position
    end
    if ev.ch == 'l'.ord || ev.key == KEY_ENTER || ev.key == KEY_ARROW_RIGHT
      viewing_item = top[position]
      draw_item w, db, viewing_item
    end
    if ev.ch == 'h'.ord || ev.key == KEY_ARROW_LEFT
      draw w, top, position
    end
  end
end

w.shutdown
