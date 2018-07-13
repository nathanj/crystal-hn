module HackerNews
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
  end
end