require "json"
require "http"
require "colorize"
require "termbox"
require "sqlite3"

require "./hn/*"

include Termbox

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
    descendants: Int32?,
  )

  property indent : Int32 = 0
  property viewed : Bool = false
end

db = DB.open "sqlite3://./db.db"
db.exec "create table if not exists cache (id integer, time integer, viewed integer, data text)"

def wrap(s, width = 78)
  if s.starts_with? '>'
    s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n> ")
  else
    s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
  end
end

class HackerNewsApi
  def self.topstories(db, limit : Int32 = 10)
    JSON.parse(HTTP::Client.get("https://hacker-news.firebaseio.com/v0/topstories.json").body)
      .as_a[0..limit]
      .map { |v| v.as_i64 }
  end

  def self.get_item(db, id : Int64)
    data = db.query_one? "select data from cache where id = ?", id, as: String
    if data
      item = Item.from_json(data)
      viewed = db.query_one? "select viewed from cache where id = ?", id, as: Int32
      item.viewed = viewed == 1
      return item
    else
      data = HTTP::Client.get("https://hacker-news.firebaseio.com/v0/item/#{id}.json").body
      item = Item.from_json(data)
      db.exec "insert into cache values (?, ?, ?, ?)", id, item.time.to_i, false, data
      return item
    end
  end

  def self.mark_viewed(db, id : Int64)
    db.exec "update cache set viewed = 1 where id = ?", id
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

draw w, top, position

def draw_item(w, db, item)
  if item.kids
    kids = item.kids.not_nil!.map { |id| HackerNewsApi.get_item db, id }
    w.clear
    line_num = 0
    kids.each do |kid|
      text = kid.text || ""
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
          w.set_primary_colors(8, 0)
          w.write_string(Position.new(2, line_num), line)
          line_num += 1
        end
      end
      t = Time.epoch(kid.time)
      w.set_primary_colors(3, 0)
      w.write_string(Position.new(1, line_num - 1), " - #{kid.by} @ #{to_pretty(t)}")
      line_num += 1
    end
    w.render
  end
end

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
      draw w, top, position
    end
    if ev.ch == 'k'.ord || ev.key == KEY_ARROW_UP
      position -= 1
      draw w, top, position
    end
    if ev.ch == 'l'.ord || ev.key == KEY_ENTER || ev.key == KEY_ARROW_RIGHT
      viewing_item = top[position]
      viewing_item.viewed = true
      HackerNewsApi.mark_viewed db, viewing_item.id
      draw_item w, db, viewing_item
    end
    if ev.ch == 'h'.ord || ev.key == KEY_ARROW_LEFT
      draw w, top, position
    end
  end
end

w.shutdown
