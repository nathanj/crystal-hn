require "termbox"
require "sqlite3"

require "./hn/*"

include Termbox
include HackerNews

db = DB.open "sqlite3://./db.db"
db.exec "create table if not exists cache (id integer, time integer, viewed integer, data text)"

item = HackerNews::Api.get_item(db, 17506753)
num_fetching = 0
ch3 = Channel(Item | Nil).new
ch4 = Channel(Nil).new

f = File.open("asdf", "w")

f.puts("starting thing")
if item.kids
  item.kids.not_nil!.each do |id|
    f.puts("spawning thread for sending #{id}")
    num_fetching += 1
    spawn do
      f.puts("fetching #{id}")
      begin
        item = HackerNews::Api.get_item(db, id)
        f.puts("fetched #{id}")
        ch3.send(item)
      rescue
        f.puts("could not fetch #{id}")
        ch3.send(nil)
      end
    end
  end
end

f.puts("spawning thread for receving")
spawn do
  pp num_fetching
  while num_fetching > 0
    item = ch3.receive
    if item
      f.puts("received #{item.not_nil!.id}")
      num_fetching -= 1
      pp num_fetching
    else
      f.puts("receive dnil")
      num_fetching -= 1
      pp num_fetching
    end
  end
  ch4.send(nil)
end

ch4.receive
f.close
# exit

w = Window.new
w.set_output_mode(OUTPUT_256)
w.clear

w.write_string(Position.new(0, 0), "Loading stories...")
w.render

# pp stories

channel = Channel(Nil).new
ch = Channel(Nil).new

f = File.open "log22", "w"
f.puts("starting thing")
f.close

windows = [TopStoriesWindow.new(db, ch)] of UiWindow

spawn do
  loop do
    windows[-1].draw(w)
    ev = w.poll
    if windows[-1].handle_event(ev, windows) == false
      windows.pop
    end
    if windows.size == 0
      channel.send(nil)
      break
    end
  end
end

spawn do
  loop do
    ch.receive
    windows[-1].draw(w)
  end
end

channel.receive

w.shutdown
