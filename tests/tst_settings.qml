import QtQuick
import QtTest
import "../lib/Settings.js" as Settings

TestCase {
  name: "Settings"

  function test_defaults() {
    compare(Settings.defaults.leftClick, "toggle")
    compare(Settings.parse(""), Settings.defaults)
    compare(Settings.parse("# omitted settings use defaults"), Settings.defaults)
  }

  function test_valid_data() {
    return [
      { tag: "open", input: 'left_click = "open"', click: "open", intervals: [250, 500, 1000, 2000, 5000] },
      { tag: "toggle", input: 'left_click = "toggle" # close too', click: "toggle", intervals: [250, 500, 1000, 2000, 5000] },
      { tag: "single quotes", input: "left_click = 'toggle'", click: "toggle", intervals: [250, 500, 1000, 2000, 5000] },
      { tag: "custom", input: 'left_click = "toggle"\npoll_intervals = [750, 1500]', click: "toggle", intervals: [750, 1500] },
      { tag: "sorted unique", input: "poll_intervals = [2000, 250, 250, 500,]", click: "toggle", intervals: [250, 500, 2000] },
      { tag: "bounds", input: "poll_intervals = [ 100, 86400000 ]", click: "toggle", intervals: [100, 86400000] }
    ]
  }

  function test_valid(data) {
    var settings = Settings.parse(data.input)
    compare(settings.leftClick, data.click)
    compare(settings.pollIntervals, data.intervals)
  }

  function test_invalid_data() {
    return [
      { tag: "unknown click", input: 'left_click = "flip"' },
      { tag: "unquoted", input: 'left_click = toggle' },
      { tag: "hash inside string", input: 'left_click = "toggle#"' },
      { tag: "unknown key", input: 'left_clik = "toggle"' },
      { tag: "duplicate", input: 'left_click = "open"\nleft_click = "toggle"' },
      { tag: "duplicate intervals", input: 'poll_intervals = [250]\npoll_intervals = [500]' },
      { tag: "section", input: '[other]\nleft_click = "toggle"' },
      { tag: "empty value", input: 'left_click =' },
      { tag: "empty list", input: 'poll_intervals = []' },
      { tag: "not a list", input: 'poll_intervals = 250' },
      { tag: "non-integer", input: 'poll_intervals = [250, fast]' },
      { tag: "decimal", input: 'poll_intervals = [250, 500.5]' },
      { tag: "negative", input: 'poll_intervals = [250, -1, 1000]' },
      { tag: "too small", input: 'poll_intervals = [99, 250]' },
      { tag: "too large", input: 'poll_intervals = [250, 86400001]' },
      { tag: "empty item", input: 'poll_intervals = [250,,500]' },
      { tag: "multiline", input: 'poll_intervals = [\n250,\n500\n]' }
    ]
  }

  function test_invalid(data) {
    var message = ""
    try {
      Settings.parse(data.input)
    } catch (error) {
      message = error.message
    }
    verify(message.length > 0)
  }

  function test_omitted_keys_reset_to_defaults() {
    Settings.parse('left_click = "open"\npoll_intervals = [750]')
    compare(Settings.parse(""), Settings.defaults)
  }
}
