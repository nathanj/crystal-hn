module HackerNews
  # print style debugging does not work well with a TUI app, so log messages to
  # a file instead
  class Logger
    @@f : File?

    private def self.open
      @@f = File.open("log", "w")
    end

    def self.log(msg)
      if !@@f
        self.open
      end
      @@f.try do |f|
        f.puts(msg)
        f.flush
      end
    end

    def self.inspect(obj)
      log(obj.pretty_inspect)
    end
  end
end
