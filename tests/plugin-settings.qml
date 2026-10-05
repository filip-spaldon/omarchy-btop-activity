import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root
  property var settings: null
  property int step: 0

  function check(condition, message) {
    if (!condition) throw new Error(message)
  }

  Component.onCompleted: {
    var component = Qt.createComponent("file:"
      + Quickshell.env("BTOP_PLUGIN_ROOT") + "/PluginSettings.qml")
    if (component.status !== Component.Ready) {
      console.error(component.errorString())
      Qt.exit(1)
      return
    }
    settings = component.createObject(root, { path: Quickshell.env("BTOP_TEST_SETTINGS") })
    if (!settings) Qt.exit(1)
  }

  property FileView writer: FileView {
    path: Quickshell.env("BTOP_TEST_SETTINGS")
    blockWrites: true
    onSaveFailed: Qt.exit(1)
  }

  property Process removeFile: Process {
    command: ["rm", "--", Quickshell.env("BTOP_TEST_SETTINGS")]
  }

  property Timer progress: Timer {
    interval: 20
    repeat: true
    running: root.settings !== null
    onTriggered: {
      try {
        var current = root.settings
        switch (root.step) {
        case 0:
          if (!current.settingsFile.loaded) return
          root.check(current.error === "", "shipped template was rejected")
          root.check(current.values.leftClick === "toggle", "wrong default click action")
          root.check(JSON.stringify(current.values.pollIntervals) === "[250,500,1000,2000,5000]",
                     "wrong default presets")
          root.writer.setText('left_click = "open"\npoll_intervals = [750, 1500]\n')
          break
        case 1:
          if (current.values.leftClick !== "open") return
          root.check(JSON.stringify(current.values.pollIntervals) === "[750,1500]",
                     "custom presets were not applied together with click action")
          root.writer.setText('left_click = "toggle"\npoll_intervals = [99]\n')
          break
        case 2:
          if (current.error === "") return
          root.check(current.values.leftClick === "open", "invalid edit changed click action")
          root.check(JSON.stringify(current.values.pollIntervals) === "[750,1500]",
                     "invalid edit changed presets")
          root.writer.setText("# use defaults again\n")
          break
        case 3:
          if (current.error !== "" || current.values.leftClick !== "toggle") return
          root.check(JSON.stringify(current.values.pollIntervals) === "[250,500,1000,2000,5000]",
                     "removing overrides did not restore defaults")
          current.creationDismissed = true
          root.removeFile.running = true
          break
        case 4:
          if (!current.missing) return
          root.check(!current.creationDismissed, "deletion did not allow another prompt")
          root.check(current.error === "", "missing file should use built-in defaults")
          current.creationDismissed = true
          break
        case 5:
          root.check(current.missing, "declining creation unexpectedly made a file")
          root.check(current.creationDismissed, "declined prompt did not stay dismissed")
          root.check(current.values.leftClick === "toggle", "missing file lost default click action")
          current.run("create")
          break
        case 6:
          if (current.missing || current.busy) return
          root.check(current.error === "", "approved file creation failed")
          root.check(current.values.leftClick === "toggle", "created file lost default click action")
          root.check(JSON.stringify(current.values.pollIntervals) === "[250,500,1000,2000,5000]",
                     "created file lost default presets")
          console.log("ok - plugin settings live reload and optional creation")
          Qt.quit()
          return
        }
        root.step++
      } catch (error) {
        console.error(error.message)
        Qt.exit(1)
      }
    }
  }

  property Timer timeout: Timer {
    interval: 5000
    running: true
    onTriggered: {
      console.error("settings reload timed out at step " + root.step)
      Qt.exit(1)
    }
  }
}
