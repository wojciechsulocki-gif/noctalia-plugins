import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Popup {
  id: root

  property var selectedModifiers: []
  property string selectedKey: ""
  property string resultKeys: ""
  property string resultRawKeys: ""
  property bool keyboardMode: true
  property string compositor: ""  // "hyprland" or "niri"
  property bool passthroughActive: false

  // For duplicate detection
  property var existingBinds: []
  property var duplicateBind: null

  signal keyCaptured(string formattedKeys, string rawKeys, var modifiers, string key)

  width: 520
  height: 580
  modal: true
  closePolicy: Popup.CloseOnEscape
  anchors.centerIn: parent

  background: Rectangle {
    color: Color.mSurface
    radius: Style.radiusL
    border.color: Color.mOutline
    border.width: 1
  }

  onOpened: {
    selectedModifiers = [];
    selectedKey = "";
    resultKeys = "";
    resultRawKeys = "";
    superCheck.checked = false;
    ctrlCheck.checked = false;
    altCheck.checked = false;
    shiftCheck.checked = false;
    keyInput.text = "";
    keyboardMode = true;
    duplicateBind = null;
    captureArea.forceActiveFocus();
  }

  onClosed: {
    // Always restore compositor binds when closing
    if (passthroughActive) {
      disablePassthrough();
    }
  }

  // Compositor passthrough control
  function enablePassthrough() {
    if (compositor === "hyprland") {
      // Enter empty submap - effectively disables all binds
      passthroughProcess.command = ["hyprctl", "dispatch", "submap", "__keycapture_passthrough__"];
      passthroughProcess.running = true;
    } else if (compositor === "niri") {
      // Niri doesn't have direct submap, but we can try to use debug options
      // For now, just set flag - user will need to use manual mode for bound keys
      passthroughActive = true;
      console.log("[KeyCapture] Niri passthrough not fully supported, using manual mode for bound keys");
    }
  }

  function disablePassthrough() {
    if (compositor === "hyprland") {
      restoreProcess.command = ["hyprctl", "dispatch", "submap", "reset"];
      restoreProcess.running = true;
    }
    passthroughActive = false;
  }

  Process {
    id: passthroughProcess
    running: false
    onExited: function(code) {
      if (code === 0) {
        root.passthroughActive = true;
        console.log("[KeyCapture] Passthrough mode enabled");
      } else {
        console.log("[KeyCapture] Failed to enable passthrough");
      }
    }
  }

  Process {
    id: restoreProcess
    running: false
    onExited: function(code) {
      root.passthroughActive = false;
      console.log("[KeyCapture] Compositor binds restored");
    }
  }

  function checkDuplicate() {
    if (resultKeys === "") return;

    for (var i = 0; i < existingBinds.length; i++) {
      var bind = existingBinds[i];
      if (bind.keys && bind.keys.toUpperCase() === resultKeys.toUpperCase()) {
        duplicateBind = bind;
        return;
      }
    }
    duplicateBind = null;
  }

  function updateResultFromManual() {
    var mods = [];
    var rawMods = [];

    if (superCheck.checked) { mods.push("Super"); rawMods.push("$mainMod"); }
    if (ctrlCheck.checked) { mods.push("Ctrl"); rawMods.push("CTRL"); }
    if (altCheck.checked) { mods.push("Alt"); rawMods.push("ALT"); }
    if (shiftCheck.checked) { mods.push("Shift"); rawMods.push("SHIFT"); }

    selectedModifiers = mods;
    var keyVal = keyInput.text.trim().toUpperCase();
    selectedKey = keyVal;

    if (keyVal.length > 0) {
      var allKeys = mods.concat([keyVal]);
      resultKeys = allKeys.join(" + ");
      resultRawKeys = rawMods.join(" ") + ", " + keyVal;
    } else {
      resultKeys = mods.join(" + ");
      resultRawKeys = rawMods.join(" ");
    }

    checkDuplicate();
  }

  function handleKeyPress(event) {
    var mods = [];
    var rawMods = [];

    if (event.modifiers & Qt.ControlModifier) { mods.push("Ctrl"); rawMods.push("CTRL"); }
    if (event.modifiers & Qt.AltModifier) { mods.push("Alt"); rawMods.push("ALT"); }
    if (event.modifiers & Qt.ShiftModifier) { mods.push("Shift"); rawMods.push("SHIFT"); }
    if (event.modifiers & Qt.MetaModifier) { mods.push("Super"); rawMods.push("$mainMod"); }

    var keyName = getKeyName(event.key);
    if (keyName && !isModifierKey(event.key)) {
      selectedModifiers = mods;
      selectedKey = keyName;
      var allKeys = mods.concat([keyName]);
      resultKeys = allKeys.join(" + ");
      var rawKeyName = getRawKeyName(event.key);
      resultRawKeys = rawMods.length > 0 ? (rawMods.join(" ") + ", " + rawKeyName) : rawKeyName;

      checkDuplicate();
    }
  }

  function isModifierKey(key) {
    return key === Qt.Key_Control || key === Qt.Key_Alt || key === Qt.Key_Shift ||
           key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R;
  }

  function getKeyName(key) {
    var m = {
      [Qt.Key_A]: "A", [Qt.Key_B]: "B", [Qt.Key_C]: "C", [Qt.Key_D]: "D", [Qt.Key_E]: "E", [Qt.Key_F]: "F",
      [Qt.Key_G]: "G", [Qt.Key_H]: "H", [Qt.Key_I]: "I", [Qt.Key_J]: "J", [Qt.Key_K]: "K", [Qt.Key_L]: "L",
      [Qt.Key_M]: "M", [Qt.Key_N]: "N", [Qt.Key_O]: "O", [Qt.Key_P]: "P", [Qt.Key_Q]: "Q", [Qt.Key_R]: "R",
      [Qt.Key_S]: "S", [Qt.Key_T]: "T", [Qt.Key_U]: "U", [Qt.Key_V]: "V", [Qt.Key_W]: "W", [Qt.Key_X]: "X",
      [Qt.Key_Y]: "Y", [Qt.Key_Z]: "Z",
      [Qt.Key_0]: "0", [Qt.Key_1]: "1", [Qt.Key_2]: "2", [Qt.Key_3]: "3", [Qt.Key_4]: "4",
      [Qt.Key_5]: "5", [Qt.Key_6]: "6", [Qt.Key_7]: "7", [Qt.Key_8]: "8", [Qt.Key_9]: "9",
      [Qt.Key_F1]: "F1", [Qt.Key_F2]: "F2", [Qt.Key_F3]: "F3", [Qt.Key_F4]: "F4", [Qt.Key_F5]: "F5", [Qt.Key_F6]: "F6",
      [Qt.Key_F7]: "F7", [Qt.Key_F8]: "F8", [Qt.Key_F9]: "F9", [Qt.Key_F10]: "F10", [Qt.Key_F11]: "F11", [Qt.Key_F12]: "F12",
      [Qt.Key_Space]: "Space", [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Enter", [Qt.Key_Escape]: "Escape",
      [Qt.Key_Tab]: "Tab", [Qt.Key_Backspace]: "Backspace", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert",
      [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "PgUp", [Qt.Key_PageDown]: "PgDn",
      [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down", [Qt.Key_Print]: "Print",
      [Qt.Key_Minus]: "Minus", [Qt.Key_Equal]: "Equal", [Qt.Key_BracketLeft]: "BracketLeft", [Qt.Key_BracketRight]: "BracketRight",
      [Qt.Key_Semicolon]: "Semicolon", [Qt.Key_Apostrophe]: "Apostrophe", [Qt.Key_Comma]: "Comma", [Qt.Key_Period]: "Period",
      [Qt.Key_Slash]: "Slash", [Qt.Key_Backslash]: "Backslash", [Qt.Key_QuoteLeft]: "Grave"
    };
    return m[key] || "";
  }

  function getRawKeyName(key) {
    var r = { [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Print]: "Print" };
    return r[key] || getKeyName(key);
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginS

    // Header
    NText {
      text: "Configure Key Combination"
      font.pointSize: Style.fontSizeL
      font.weight: Font.Bold
      color: Color.mPrimary
    }

    // Mode toggle
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      Rectangle {
        Layout.fillWidth: true
        height: 36
        color: root.keyboardMode ? Color.mPrimary : Color.mSurfaceVariant
        radius: Style.radiusS

        NText {
          anchors.centerIn: parent
          text: "Keyboard Capture"
          color: root.keyboardMode ? Color.mOnPrimary : Color.mOnSurface
          font.weight: root.keyboardMode ? Font.Bold : Font.Normal
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.keyboardMode = true;
            if (root.compositor === "hyprland") {
              root.enablePassthrough();
            }
            captureArea.forceActiveFocus();
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 36
        color: !root.keyboardMode ? Color.mPrimary : Color.mSurfaceVariant
        radius: Style.radiusS

        NText {
          anchors.centerIn: parent
          text: "Manual Selection"
          color: !root.keyboardMode ? Color.mOnPrimary : Color.mOnSurface
          font.weight: !root.keyboardMode ? Font.Bold : Font.Normal
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.keyboardMode = false;
            if (root.passthroughActive) {
              root.disablePassthrough();
            }
          }
        }
      }
    }

    // Keyboard capture mode
    Rectangle {
      visible: root.keyboardMode
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Color.mSurfaceVariant
      radius: Style.radiusM
      border.color: captureArea.activeFocus ? Color.mPrimary : Color.mOutline
      border.width: captureArea.activeFocus ? 2 : 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        NText {
          text: "Press any key combination"
          font.weight: Font.Bold
          color: Color.mOnSurface
          Layout.alignment: Qt.AlignHCenter
        }

        // Passthrough status
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 28
          color: root.passthroughActive ? Qt.alpha(Color.mSuccess || "#4CAF50", 0.2) : Qt.alpha(Color.mWarning || "#FF9800", 0.2)
          radius: Style.radiusS
          visible: root.compositor === "hyprland"

          NText {
            anchors.centerIn: parent
            text: root.passthroughActive ?
                  "✓ Passthrough active - all keys captured" :
                  "⚠ Click 'Enable Capture' to capture bound keys"
            font.pointSize: Style.fontSizeXS
            color: Color.mOnSurface
          }
        }

        NButton {
          text: root.passthroughActive ? "Disable Capture" : "Enable Capture"
          Layout.alignment: Qt.AlignHCenter
          visible: root.compositor === "hyprland" && !root.passthroughActive
          onClicked: root.enablePassthrough()
        }

        NText {
          visible: root.compositor === "niri"
          text: "Note: Niri doesn't support passthrough mode.\nUse Manual Selection for already bound keys."
          font.pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
          horizontalAlignment: Text.AlignHCenter
          Layout.alignment: Qt.AlignHCenter
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }

        // Key display area
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 60
          color: Color.mSurface
          radius: Style.radiusS

          Flow {
            anchors.centerIn: parent
            spacing: 6
            visible: root.resultKeys !== ""

            Repeater {
              model: root.resultKeys.split(" + ")
              Rectangle {
                width: capturedKeyText.implicitWidth + 16
                height: 32
                color: Color.mPrimary
                radius: 6
                NText {
                  id: capturedKeyText
                  anchors.centerIn: parent
                  text: modelData
                  font.pointSize: Style.fontSizeM
                  font.weight: Font.Bold
                  color: Color.mOnPrimary
                }
              }
            }
          }

          NText {
            anchors.centerIn: parent
            visible: root.resultKeys === ""
            text: "Waiting for key press..."
            font.italic: true
            color: Color.mOnSurfaceVariant
          }
        }

        Item { Layout.fillHeight: true }

        Item {
          id: captureArea
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          focus: true
          Keys.onPressed: function(event) { root.handleKeyPress(event); event.accepted = true; }
          Keys.onReleased: function(event) { event.accepted = true; }
        }
      }
    }

    // Manual selection mode
    ColumnLayout {
      visible: !root.keyboardMode
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.marginS

      // Modifiers
      Rectangle {
        Layout.fillWidth: true
        height: modCol.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        ColumnLayout {
          id: modCol
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginXS

          NText { text: "Modifiers:"; font.weight: Font.Bold; color: Color.mOnSurface }

          RowLayout {
            spacing: Style.marginM
            CheckBox { id: superCheck; text: "Super"; onCheckedChanged: root.updateResultFromManual() }
            CheckBox { id: ctrlCheck; text: "Ctrl"; onCheckedChanged: root.updateResultFromManual() }
            CheckBox { id: altCheck; text: "Alt"; onCheckedChanged: root.updateResultFromManual() }
            CheckBox { id: shiftCheck; text: "Shift"; onCheckedChanged: root.updateResultFromManual() }
          }
        }
      }

      // Key input
      Rectangle {
        Layout.fillWidth: true
        height: keyCol.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        ColumnLayout {
          id: keyCol
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginXS

          NText { text: "Key:"; font.weight: Font.Bold; color: Color.mOnSurface }

          NTextInput {
            id: keyInput
            Layout.fillWidth: true
            placeholderText: "Type key name (e.g., Return, T, F1)"
            onTextChanged: root.updateResultFromManual()
          }

          NText { text: "Quick select:"; font.pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant }

          Flow {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
              model: ["Return", "Space", "Tab", "Escape", "Delete", "Backspace",
                      "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
                      "Left", "Right", "Up", "Down", "Home", "End", "PgUp", "PgDn", "Print"]

              Rectangle {
                width: qkText.implicitWidth + 10
                height: 22
                color: Color.mSurface
                radius: 3

                NText {
                  id: qkText
                  anchors.centerIn: parent
                  text: modelData
                  font.pointSize: Style.fontSizeXS
                  color: Color.mPrimary
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { keyInput.text = modelData; root.updateResultFromManual(); }
                }
              }
            }
          }
        }
      }
    }

    // Duplicate warning
    Rectangle {
      visible: root.duplicateBind !== null
      Layout.fillWidth: true
      height: duplicateCol.implicitHeight + Style.marginS * 2
      color: Qt.alpha(Color.mError, 0.15)
      radius: Style.radiusM
      border.color: Color.mError
      border.width: 1

      ColumnLayout {
        id: duplicateCol
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginXS

        RowLayout {
          spacing: Style.marginS
          NText {
            text: "⚠ Duplicate detected!"
            font.weight: Font.Bold
            color: Color.mError
          }
        }

        NText {
          text: root.duplicateBind ?
                "This key combination is already used for:\n\"" + (root.duplicateBind.description || root.duplicateBind.action || "Unknown") + "\"" :
                ""
          color: Color.mOnSurface
          font.pointSize: Style.fontSizeS
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }

        NText {
          text: "You can still use this combination - it will create a duplicate bind."
          color: Color.mOnSurfaceVariant
          font.pointSize: Style.fontSizeXS
          font.italic: true
        }
      }
    }

    // Preview (always visible)
    Rectangle {
      Layout.fillWidth: true
      height: 50
      color: Color.mSurfaceVariant
      radius: Style.radiusM

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginS

        NText { text: "Result:"; color: Color.mOnSurfaceVariant; font.weight: Font.Bold }

        Flow {
          Layout.fillWidth: true
          spacing: 4
          visible: root.resultKeys !== ""

          Repeater {
            model: root.resultKeys.split(" + ")
            Rectangle {
              width: prevText.implicitWidth + 12
              height: 26
              color: Color.mPrimary
              radius: 4
              NText {
                id: prevText
                anchors.centerIn: parent
                text: modelData
                font.pointSize: Style.fontSizeS
                font.weight: Font.Bold
                color: Color.mOnPrimary
              }
            }
          }
        }

        NText {
          visible: root.resultKeys === ""
          text: "(no key selected)"
          font.italic: true
          color: Color.mOnSurfaceVariant
        }
      }
    }

    // Buttons
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NButton {
        text: "Clear"
        onClicked: {
          superCheck.checked = false;
          ctrlCheck.checked = false;
          altCheck.checked = false;
          shiftCheck.checked = false;
          keyInput.text = "";
          selectedModifiers = [];
          selectedKey = "";
          resultKeys = "";
          resultRawKeys = "";
          duplicateBind = null;
          if (root.keyboardMode) captureArea.forceActiveFocus();
        }
      }

      Item { Layout.fillWidth: true }

      NButton { text: "Cancel"; onClicked: root.close() }

      NButton {
        text: root.duplicateBind ? "Use Anyway" : "OK"
        enabled: root.selectedKey !== ""
        onClicked: {
          keyCaptured(resultKeys, resultRawKeys, selectedModifiers, selectedKey);
          root.close();
        }
      }
    }
  }
}
