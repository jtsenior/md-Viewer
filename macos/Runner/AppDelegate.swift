import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var pendingFile: [String: String]?
  private var methodChannel: FlutterMethodChannel?
  private var flutterReady = false

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    // File path passed as a CLI argument — read content while we have OS access
    let args = CommandLine.arguments.dropFirst()
    if let firstArg = args.first, FileManager.default.fileExists(atPath: firstArg) {
      pendingFile = makeFileInfo(url: URL(fileURLWithPath: firstArg))
    }
  }

  // Called from MainFlutterWindow.awakeFromNib() where the FlutterViewController is known
  func setupFileChannel(_ flutterVC: FlutterViewController) {
    methodChannel = FlutterMethodChannel(
      name: "com.jtsworkshop.mdViewer/file",
      binaryMessenger: flutterVC.engine.binaryMessenger
    )
    methodChannel?.setMethodCallHandler { [weak self] call, result in
      if call.method == "getInitialFile" {
        self?.flutterReady = true
        result(self?.pendingFile)
        self?.pendingFile = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // Modern URL-based handler — "Open With", Dock drops, double-click
  override func application(_ application: NSApplication, open urls: [URL]) {
    guard let url = urls.first else { return }
    deliver(makeFileInfo(url: url))
  }

  // Legacy string-based fallback
  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    deliver(makeFileInfo(url: URL(fileURLWithPath: filename)))
    return true
  }

  private func deliver(_ info: [String: String]) {
    if flutterReady, let channel = methodChannel {
      channel.invokeMethod("openFile", arguments: info)
    } else {
      pendingFile = info
    }
  }

  private func makeFileInfo(url: URL) -> [String: String] {
    let content = (try? String(contentsOf: url, encoding: .utf8))
      ?? (try? String(contentsOf: url, encoding: .isoLatin1))
      ?? ""
    return ["path": url.path, "content": content]
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}