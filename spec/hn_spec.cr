require "./spec_helper"

describe HackerNews::Parser do
  it "parses and finds top stories" do
    parser = HackerNews::Parser.new "index.html"
    stories = parser.top_stories
    stories.size.should eq(30)
    stories[0].title.should eq("Show HN: Markdown New Tab – A new tab replacement to jot down notes in Markdown")
    stories[0].comments.should eq(18)
  end
end
