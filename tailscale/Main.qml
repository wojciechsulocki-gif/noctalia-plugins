import QtQuick
import Quickshell
import qs.Commons
import Quickshell.Io
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  onPluginApiChanged: {
    if (pluginApi) {
      Logger.i("Tailscale", "pluginApi available, loading settings")
      settingsVersion++
    }
  }

  property int settingsVersion: 0

  property int refreshInterval: _computeRefreshInterval()
  property bool compactMode: _computeCompactMode()
  property bool showIpAddress: _computeShowIpAddress()
  property bool showPeerCount: _computeShowPeerCount()

  function _computeRefreshInterval() { return pluginApi?.pluginSettings?.refreshInterval ?? 5000; }
  function _computeCompactMode() { return pluginApi?.pluginSettings?.compactMode ?? false; }
  function _computeShowIpAddress() { return pluginApi?.pluginSettings?.showIpAddress ?? true; }
  function _computeShowPeerCount() { return pluginApi?.pluginSettings?.showPeerCount ?? true; }

  onSettingsVersionChanged: {
    refreshInterval = _computeRefreshInterval()
    compactMode = _computeCompactMode()
    showIpAddress = _computeShowIpAddress()
    showPeerCount = _computeShowPeerCount()
    updateTimer.interval = refreshInterval
    Logger.i("Tailscale", "Settings updated: refreshInterval=" + refreshInterval + ", compactMode=" + compactMode)
  }

  property bool tailscaleInstalled: false
  property bool tailscaleRunning: false
  property string tailscaleIp: ""
  property string tailscaleStatus: ""
  property int peerCount: 0
  property bool isRefreshing: false
  property string lastToggleAction: ""
  property var peerList: []

  Process {
    id: whichProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode, exitStatus) {
      Logger.d("Tailscale", "whichProcess exited with code: " + exitCode)
      root.tailscaleInstalled = (exitCode === 0)
      root.isRefreshing = false
      updateTailscaleStatus()
    }
  }

  Process {
    id: statusProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode, exitStatus) {
      root.isRefreshing = false
      var stdout = String(statusProcess.stdout.text || "").trim()
      var stderr = String(statusProcess.stderr.text || "").trim()

      Logger.d("Tailscale", "statusProcess exited with code: " + exitCode)
      Logger.d("Tailscale", "stdout length: " + stdout.length)
      if (stdout.length > 0) {
        Logger.d("Tailscale", "Status output: " + stdout.substring(0, 300))
      }
      if (stderr.length > 0) {
        Logger.d("Tailscale", "stderr: " + stderr)
      }

      if (exitCode === 0 && stdout && stdout.length > 0) {
        try {
          var data = JSON.parse(stdout)
          root.tailscaleRunning = data.BackendState === "Running"
          Logger.d("Tailscale", "BackendState: " + data.BackendState + ", tailscaleRunning: " + root.tailscaleRunning)

          if (root.tailscaleRunning && data.Self && data.Self.TailscaleIPs && data.Self.TailscaleIPs.length > 0) {
            root.tailscaleIp = data.Self.TailscaleIPs[0]
            root.tailscaleStatus = "Connected"

            var peers = []
            if (data.Peer) {
              for (var peerId in data.Peer) {
                var peer = data.Peer[peerId]
                peers.push({
                  "HostName": peer.HostName,
                  "DNSName": peer.DNSName,
                  "TailscaleIPs": peer.TailscaleIPs,
                  "Online": peer.Online
                })
              }
            }
            root.peerList = peers
            root.peerCount = peers.length
          } else {
            root.tailscaleIp = ""
            root.tailscaleStatus = root.tailscaleRunning ? "Connected" : "Disconnected"
            root.peerCount = 0
            root.peerList = []
          }
        } catch (e) {
          Logger.e("Tailscale", "Failed to parse status: " + e)
          root.tailscaleRunning = false
          root.tailscaleStatus = "Error"
          root.peerList = []
        }
      } else {
        root.tailscaleRunning = false
        root.tailscaleStatus = "Disconnected"
        root.tailscaleIp = ""
        root.peerCount = 0
        root.peerList = []
      }
    }
  }

  Process {
    id: toggleProcess
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        var message = root.lastToggleAction === "connect" ?
          pluginApi?.tr("toast.connected") || "Tailscale connected" :
          pluginApi?.tr("toast.disconnected") || "Tailscale disconnected"
        ToastService.showNotice(
          pluginApi?.tr("toast.title") || "Tailscale",
          message,
          "network"
        )
      }

      statusDelayTimer.start()
    }
  }

  Timer {
    id: statusDelayTimer
    interval: 500
    repeat: false
    onTriggered: {
      root.isRefreshing = false
      updateTailscaleStatus()
    }
  }

  function checkTailscaleInstalled() {
    root.isRefreshing = true
    whichProcess.command = ["which", "tailscale"]
    whichProcess.running = true
  }

  function updateTailscaleStatus() {
    if (!root.tailscaleInstalled) {
      root.tailscaleRunning = false
      root.tailscaleIp = ""
      root.tailscaleStatus = "Not installed"
      root.peerCount = 0
      return
    }

    root.isRefreshing = true
    statusProcess.command = ["tailscale", "status", "--json"]
    statusProcess.running = true
  }

  function toggleTailscale() {
    if (!root.tailscaleInstalled) return

    Logger.d("Tailscale", "toggleTailscale called, current status: " + root.tailscaleRunning)
    root.isRefreshing = true
    if (root.tailscaleRunning) {
      root.lastToggleAction = "disconnect"
      toggleProcess.command = ["tailscale", "down"]
    } else {
      root.lastToggleAction = "connect"
      toggleProcess.command = ["tailscale", "up"]
    }
    toggleProcess.running = true
  }

  Timer {
    id: updateTimer
    interval: refreshInterval
    repeat: true
    running: true
    triggeredOnStart: true

    onTriggered: {
      if (root.tailscaleInstalled === false) {
        checkTailscaleInstalled()
      } else {
        updateTailscaleStatus()
      }
    }
  }

  Component.onCompleted: {
    checkTailscaleInstalled()
  }

  IpcHandler {
    target: "plugin:tailscale"

    function toggle() {
      toggleTailscale()
    }

    function status() {
      return {
        "installed": root.tailscaleInstalled,
        "running": root.tailscaleRunning,
        "ip": root.tailscaleIp,
        "status": root.tailscaleStatus,
        "peers": root.peerCount
      }
    }

    function refresh() {
      updateTailscaleStatus()
    }
  }
}
