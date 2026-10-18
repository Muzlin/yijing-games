import Cocoa
import FlutterMacOS
import ApplicationServices
import Darwin

class MainFlutterWindow: NSWindow {
  private var mouseChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setFrame(NSRect(x: 0, y: 0, width: 1080, height: 840), display: true)
    self.minSize = NSSize(width: 720, height: 640)
    self.title = "弈境 · 棋牌合集"
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    mouseChannel = FlutterMethodChannel(
      name: "yijing/mouse",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    mouseChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "window", message: "window unavailable", details: nil))
        return
      }
      switch call.method {
      case "isTrusted":
        result(AXIsProcessTrusted())
      case "requestTrust":
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        result(AXIsProcessTrustedWithOptions(options))
      case "click":
        guard let args = call.arguments as? [String: Any],
              let x = args["x"] as? Double,
              let y = args["y"] as? Double else {
          result(FlutterError(code: "bad-args", message: "x/y required", details: nil))
          return
        }
        result(self.postClick(x: x, y: y))
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    self.setContentSize(NSSize(width: 1080, height: 840))
    self.center()
    self.makeKeyAndOrderFront(nil)
  }

  /// Flutter reports coordinates in the content view (origin top-left).
  /// Convert to the primary display's CGEvent coordinate space.
  private func postClick(x: Double, y: Double) -> Bool {
    guard AXIsProcessTrusted() else { return false }
    guard let content = self.contentView else { return false }
    let viewPoint = NSPoint(x: x, y: content.bounds.height - y)
    let windowPoint = content.convert(viewPoint, to: nil)
    let screenPoint = self.convertPoint(toScreen: windowPoint)
    guard let primary = NSScreen.screens.first else { return false }
    let cgPoint = CGPoint(x: screenPoint.x, y: primary.frame.height - screenPoint.y)

    NSApp.activate(ignoringOtherApps: true)
    usleep(120_000)
    guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
    let move = CGEvent(
      mouseEventSource: source,
      mouseType: .mouseMoved,
      mouseCursorPosition: cgPoint,
      mouseButton: .left
    )
    let down = CGEvent(
      mouseEventSource: source,
      mouseType: .leftMouseDown,
      mouseCursorPosition: cgPoint,
      mouseButton: .left
    )
    let up = CGEvent(
      mouseEventSource: source,
      mouseType: .leftMouseUp,
      mouseCursorPosition: cgPoint,
      mouseButton: .left
    )
    move?.post(tap: .cghidEventTap)
    usleep(30_000)
    down?.post(tap: .cghidEventTap)
    usleep(30_000)
    up?.post(tap: .cghidEventTap)
    return true
  }
}
