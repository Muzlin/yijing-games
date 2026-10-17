import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setFrame(NSRect(x: 0, y: 0, width: 1080, height: 840), display: true)
    self.minSize = NSSize(width: 720, height: 640)
    self.title = "弈境 · 棋牌合集"
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    self.setContentSize(NSSize(width: 1080, height: 840))
    self.center()
    self.makeKeyAndOrderFront(nil)
  }
}
