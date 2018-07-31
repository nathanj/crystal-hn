# Hacker News Command Line Client

This is a command line viewer for Hacker News.

[![asciicast](https://asciinema.org/a/wkwEDmFQg5tfYnl7cfr5289Fc.png)](https://asciinema.org/a/wkwEDmFQg5tfYnl7cfr5289Fc)

## Installation

First you must have the termbox library installed. Arch Linux users can install
from the AUR:

    trizen -S termbox-git

After that you can build and run:

    git clone https://github.com/nathanj/crystal-hn
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
| `1`                   | Switch to top stories          |
| `2`                   | Switch to ask                  |
| `3`                   | Switch to show                 |

### Comments Screen

| **Key**                    | **Action**      |
|----------------------------|-----------------|
| `h`, `q`, `Escape`, `Left` | Back to stories |
| `j`, `Down`                | Move Down       |
| `k`, `Up`                  | Move Up         |
| `Space`, `PageDown`        | Page Down       |
| `Backspace`, `PageUp`      | Page Up         |
