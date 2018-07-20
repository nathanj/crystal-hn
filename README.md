# hn

This is a command line viewer for Hacker News.

todo: asciinema

## Installation

	git clone https://github.com/nathanj/hn
	shards update
	shards build
	./bin/hn

## Usage

### Stories Screen

| **Key**               | **Action**                     |
|-----------------------|--------------------------------|
| `q`, `Escape`         | Quit                           |
| `j`, `Down`           | Move Down                      |
| `k`, `Up`             | Move Up                        |
| `l`, `Enter`, `Right` | View comments                  |
| `b`                   | Open story link using $BROWSER |
| `m`                   | Mark all stories as viewed     |

### Comments Screen

| **Key**                    | **Action**      |
|----------------------------|-----------------|
| `h`, `q`, `Escape`, `Left` | Back to stories |
| `j`, `Down`                | Move Down       |
| `k`, `Up`                  | Move Up         |
| `Space`, `PageDown`        | Page Down       |
| `Backspace`, `PageUp`      | Page Up         |
