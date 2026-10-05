.pragma library
.import "UpdateInterval.js" as UpdateInterval

var defaults = { leftClick: "toggle", pollIntervals: UpdateInterval.presets }

function intervals(text) {
  var match = /^\[(.*)\]$/.exec(text)
  if (!match) throw new Error("poll_intervals must be a single-line list")
  var items = match[1].split(",")
  if (items.length && items[items.length - 1].trim() === "") items.pop()
  if (!items.length) throw new Error("poll_intervals must not be empty")
  var values = []
  for (var i = 0; i < items.length; i++) {
    var value = UpdateInterval.parse(items[i])
    if (value === null)
      throw new Error("poll_intervals must contain whole milliseconds from "
        + UpdateInterval.minimum + " to " + UpdateInterval.maximum)
    if (values.indexOf(value) < 0) values.push(value)
  }
  return values.sort(function (a, b) { return a - b })
}

// These settings need only flat keys, a fixed string choice and an integer list.
function parse(text) {
  var settings = {
    leftClick: defaults.leftClick,
    pollIntervals: defaults.pollIntervals.slice()
  }
  var seen = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/#.*/, "").trim()
    if (!line) continue
    var pair = /^(left_click|poll_intervals)\s*=\s*(.+)$/.exec(line)
    if (!pair) throw new Error("Unknown or malformed setting on line " + (i + 1))
    var key = pair[1]
    if (seen[key]) throw new Error("Duplicate setting: " + key)
    seen[key] = true
    if (key === "poll_intervals") {
      settings.pollIntervals = intervals(pair[2].trim())
    } else {
      var word = /^(["'])(open|toggle)\1$/.exec(pair[2].trim())
      if (!word) throw new Error('left_click must be "open" or "toggle"')
      settings.leftClick = word[2]
    }
  }
  return settings
}
