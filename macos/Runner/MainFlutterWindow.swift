import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Set up the file channel here — we definitively have the FlutterViewController
    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.setupFileChannel(flutterViewController)
    }

    super.awakeFromNib()
  }
}