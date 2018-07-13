require "termbox"
require "sqlite3"

require "./hn/*"

include Termbox
include HackerNews

db = DB.open "sqlite3://./db.db"
db.exec "create table if not exists cache (id integer, time integer, viewed integer, data text)"

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
    # Fiber.yield
    ev = w.poll
    if windows[-1].handle_event(ev, w, windows) == false
      windows.pop.close
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
