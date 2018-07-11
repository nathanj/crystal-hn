require "./spec_helper"

describe HackerNews::Parser do
  it "parses and finds top stories" do
    parser = HackerNews::Parser.new "spec/data/index.html"
    stories = parser.top_stories
    stories.size.should eq(30)
    stories[0].title.should eq("Show HN: Markdown New Tab – A new tab replacement to jot down notes in Markdown")
    stories[0].comments.should eq(18)
    stories[0].id.should eq(17506753)
    stories[0].link.should eq("https://github.com/plibither8/markdown-new-tab")
    stories[0].url.should eq("https://news.ycombinator.com/item?id=17506753")
  end
end
