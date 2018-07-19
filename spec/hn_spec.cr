require "./spec_helper"

describe HackerNews::Parser do
  it "parses and finds top stories" do
    stories = HackerNews::Parser.top_stories_fn "spec/data/index.html"
    stories.size.should eq(30)
    stories[0].title.should eq("Show HN: Markdown New Tab – A new tab replacement to jot down notes in Markdown")
    stories[0].comments.should eq(18)
    stories[0].id.should eq(17506753)
    stories[0].link.should eq("https://github.com/plibither8/markdown-new-tab")
    stories[0].url.should eq("https://news.ycombinator.com/item?id=17506753")
  end

  it "parses comments" do
    comments = HackerNews::Parser.comments_fn "spec/data/17506753.html"
    comments.size.should eq(37)
    comments[0].text[0..10].should eq("I just use ")
    comments[0].author.should eq("soared")
    comments[0].time.should eq("48 minutes ago")
    comments[0].indent.should eq(0)
    comments[1].text[0..10].should eq("Not open so")
    comments[1].author.should eq("vanderZwan")
    comments[1].time.should eq("21 minutes ago")
    comments[1].indent.should eq(1)
  end
end
