import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property var bind: ({})
  property string compositor: ""
  property var categories: []  // All categories for move dropdown
  property bool isFirst: false  // Is this the first bind in category?
  property bool isLast: false   // Is this the last bind in category?

  signal editRequested()
  signal deleteRequested()
  signal moveRequested(string targetCategoryId)
  signal moveUpRequested()
  signal moveDownRequested()

  implicitHeight: 40
  Layout.preferredHeight: 40
  color: getStatusColor()
  radius: Style.radiusS
  border.color: getBorderColor()
  border.width: bind.status === "modified" || bind.status === "new" ? 2 : 0

  function getStatusColor() {
    switch(bind.status) {
      case "modified": return Qt.alpha(Color.mWarning || "#FFA726", 0.1);
      case "new": return Qt.alpha(Color.mSuccess || "#66BB6A", 0.1);
      case "deleted": return Qt.alpha(Color.mError, 0.1);
      default: return Color.mSurface;
    }
  }

  function getBorderColor() {
    switch(bind.status) {
      case "modified": return Color.mWarning || "#FFA726";
      case "new": return Color.mSuccess || "#66BB6A";
      default: return "transparent";
    }
  }

  function getKeyColor(keyName) {
    if (keyName === "Super") return Color.mPrimary;
    if (keyName === "Ctrl") return Color.mSecondary;
    if (keyName === "Shift") return Color.mTertiary;
    if (keyName === "Alt") return "#FF6B6B";
    if (keyName.startsWith("XF86")) return "#4ECDC4";
    if (keyName === "PRINT" || keyName === "Print" || keyName === "PrtSc") return "#95E1D3";
    if (keyName.match(/^[0-9]$/)) return "#A8DADC";
    if (keyName.includes("MOUSE") || keyName.includes("Wheel")) return "#F38181";
    return Color.mPrimaryContainer || "#6C757D";
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.marginS
    anchors.rightMargin: Style.marginS
    spacing: Style.marginS

    // Status indicator
    Rectangle {
      visible: bind.status !== "unchanged"
      width: 8
      height: 8
      radius: 4
      color: {
        switch(bind.status) {
          case "modified": return Color.mWarning || "#FFA726";
          case "new": return Color.mSuccess || "#66BB6A";
          case "deleted": return Color.mError;
          default: return "transparent";
        }
      }
    }

    // Key badges
    Flow {
      Layout.preferredWidth: 200
      Layout.alignment: Qt.AlignVCenter
      spacing: 3

      Repeater {
        model: (bind.keys || "").split(" + ")

        Rectangle {
          width: keyText.implicitWidth + 12
          height: 22
          color: root.getKeyColor(modelData)
          radius: 4

          NText {
            id: keyText
            anchors.centerIn: parent
            text: modelData
            font.pointSize: modelData.length > 12 ? 8 : 9
            font.weight: Font.Bold
            color: Color.mOnPrimary
          }
        }
      }
    }

    // Description
    NText {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: bind.description || "No description"
      font.pointSize: Style.fontSizeS
      color: Color.mOnSurface
      elide: Text.ElideRight
    }

    // Source file indicator
    NText {
      visible: bind.sourceFile && bind.sourceFile !== ""
      text: {
        if (!bind.sourceFile) return "";
        var parts = bind.sourceFile.split('/');
        return parts[parts.length - 1] + ":" + (bind.lineNumber || "?");
      }
      font.pointSize: Style.fontSizeXS
      color: Color.mOnSurfaceVariant
      Layout.alignment: Qt.AlignVCenter
    }

    // Reorder buttons (up/down within category)
    NIconButton {
      icon: "chevron-up"
      baseSize: Style.baseWidgetSize * 0.6
      tooltipText: "Move up"
      enabled: !root.isFirst
      opacity: root.isFirst ? 0.3 : 1.0
      onClicked: root.moveUpRequested()
    }

    NIconButton {
      icon: "chevron-down"
      baseSize: Style.baseWidgetSize * 0.6
      tooltipText: "Move down"
      enabled: !root.isLast
      opacity: root.isLast ? 0.3 : 1.0
      onClicked: root.moveDownRequested()
    }

    // Move button with category dropdown
    ComboBox {
      id: moveCombo
      Layout.preferredWidth: 120
      Layout.preferredHeight: Style.baseWidgetSize * 0.7
      model: root.categories.filter(function(cat) { return cat.id !== bind.categoryId; })
      textRole: "title"
      displayText: "Move to..."
      font.pointSize: Style.fontSizeXS

      background: Rectangle {
        color: Color.mSurface || "#1e1e1e"
        radius: Style.radiusS
        border.color: moveCombo.hovered ? (Color.mPrimary || "#6750A4") : (Color.mOutline || "#79747E")
        border.width: 1
      }

      contentItem: NText {
        text: moveCombo.displayText
        font.pointSize: Style.fontSizeXS
        color: Color.mOnSurface || "#e6e1e5"
        verticalAlignment: Text.AlignVCenter
        leftPadding: 8
      }

      delegate: ItemDelegate {
        width: moveCombo.width
        height: 30
        contentItem: NText {
          text: modelData.title
          font.pointSize: Style.fontSizeXS
          color: Color.mOnSurface || "#e6e1e5"
        }
        background: Rectangle {
          color: highlighted ? (Color.mPrimaryContainer || "#4F378B") : "transparent"
        }
        onClicked: {
          root.moveRequested(modelData.id);
          moveCombo.currentIndex = -1;
        }
      }

      onActivated: function(index) {
        if (index >= 0) {
          var targetCat = model[index];
          root.moveRequested(targetCat.id);
          currentIndex = -1;
        }
      }
    }

    // Edit button
    NIconButton {
      icon: "edit"
      baseSize: Style.baseWidgetSize * 0.7
      tooltipText: "Edit keybind"
      onClicked: root.editRequested()
    }

    // Delete button
    NIconButton {
      icon: "trash"
      baseSize: Style.baseWidgetSize * 0.7
      tooltipText: "Delete keybind"
      onClicked: root.deleteRequested()
    }
  }

  // Hover effect
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    propagateComposedEvents: true
    onEntered: parent.color = Qt.lighter(getStatusColor(), 1.1)
    onExited: parent.color = getStatusColor()
    onClicked: function(event) { event.accepted = false; }
    onPressed: function(event) { event.accepted = false; }
    onReleased: function(event) { event.accepted = false; }
  }
}
