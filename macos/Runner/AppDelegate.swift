import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

@main
class AppDelegate: FlutterAppDelegate {
  private var pendingFile: [String: String]?
  private var methodChannel: FlutterMethodChannel?
  private var flutterReady = false

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    let args = CommandLine.arguments.dropFirst()
    if let firstArg = args.first, FileManager.default.fileExists(atPath: firstArg) {
      pendingFile = makeFileInfo(url: URL(fileURLWithPath: firstArg))
    }
  }

  func setupFileChannel(_ flutterVC: FlutterViewController) {
    methodChannel = FlutterMethodChannel(
      name: "com.jtsworkshop.mdViewer/file",
      binaryMessenger: flutterVC.engine.binaryMessenger
    )
    methodChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getInitialFile":
        self?.flutterReady = true
        result(self?.pendingFile)
        self?.pendingFile = nil

      case "createBookmark":
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "path required", details: nil))
          return
        }
        let url = URL(fileURLWithPath: path)
        do {
          let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          )
          result(data.base64EncodedString())
        } catch {
          result(FlutterError(code: "BOOKMARK_FAILED", message: error.localizedDescription, details: nil))
        }

      case "readWithBookmark":
        guard let base64 = call.arguments as? String,
              let data = Data(base64Encoded: base64) else {
          result(FlutterError(code: "INVALID_ARGS", message: "base64 bookmark required", details: nil))
          return
        }
        do {
          var isStale = false
          let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
          )
          guard url.startAccessingSecurityScopedResource() else {
            result(FlutterError(code: "ACCESS_DENIED", message: "Could not access security-scoped resource", details: nil))
            return
          }
          defer { url.stopAccessingSecurityScopedResource() }
          let content = (try? String(contentsOf: url, encoding: .utf8))
            ?? (try? String(contentsOf: url, encoding: .isoLatin1))
            ?? ""
          var info: [String: String] = ["path": url.path, "content": content]
          // Refresh stale bookmark while we still have access
          if isStale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            info["bookmark"] = fresh.base64EncodedString()
          }
          result(info)
        } catch {
          result(FlutterError(code: "BOOKMARK_ERROR", message: error.localizedDescription, details: nil))
        }

      case "showSavePanel":
        let args = call.arguments as? [String: Any]
        let suggestedName = args?["suggestedName"] as? String ?? "export"
        let utTypeStrings = args?["utTypes"] as? [String] ?? []
        DispatchQueue.main.async {
          let panel = NSSavePanel()
          panel.nameFieldStringValue = suggestedName
          if #available(macOS 12, *) {
            panel.allowedContentTypes = utTypeStrings.compactMap { UTType($0) }
          } else {
            panel.allowedFileTypes = utTypeStrings
          }
          panel.begin { response in
            result(response == .OK ? panel.url?.path : nil)
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    guard let url = urls.first else { return }
    deliver(makeFileInfo(url: url))
  }

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
    var info: [String: String] = ["path": url.path, "content": content]
    if let bookmarkData = try? url.bookmarkData(
      options: .withSecurityScope,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    ) {
      info["bookmark"] = bookmarkData.base64EncodedString()
    }
    return info
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
