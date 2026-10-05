import QtQuick
import Quickshell
import Quickshell.Io
import "lib/Settings.js" as Settings

QtObject {
  id: root

  property string path: (Quickshell.env("XDG_CONFIG_HOME")
    || Quickshell.env("HOME") + "/.config") + "/omarchy/ilyazar.btop/settings.toml"
  property var values: Settings.defaults
  property string error: ""
  property bool missing: false
  property bool creationDismissed: false
  readonly property bool busy: settingsProcess.running

  function loadSettings(text) {
    try {
      var next = Settings.parse(text)
      values = next
      error = ""
    } catch (exception) {
      error = "Settings not applied: " + exception.message
    }
  }

  function run(action) {
    if (busy) return
    settingsProcess.command = ["bash", decodeURIComponent(String(
      Qt.resolvedUrl("helpers/plugin-settings.sh")).substring(7)), path, action]
    settingsProcess.running = true
  }

  property FileView settingsFile: FileView {
    path: root.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.missing = false
      root.loadSettings(text())
    }
    onLoadFailed: function(fileError) {
      if (fileError === FileViewError.FileNotFound) {
        root.values = Settings.defaults
        root.error = ""
        if (!root.missing) root.creationDismissed = false
        root.missing = true
      } else {
        root.error = "Could not read plugin settings: "
          + FileViewError.toString(fileError)
      }
    }
  }

  property Process settingsProcess: Process {
    stderr: StdioCollector { id: settingsErrors; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.error = settingsErrors.text.trim() || "Could not prepare plugin settings"
      else
        root.settingsFile.reload()
    }
  }
}
