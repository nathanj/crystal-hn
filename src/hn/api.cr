require "http"
require "json"

module HackerNews
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

    def open_in_browser
      `$BROWSER #{url}`
    end
  end

  class Api
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
end
