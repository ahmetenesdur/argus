//
//  HelperManager.swift
//  Argus
//
//  Installs and manages the argusd LaunchDaemon via an AppleScript-driven
//  privileged launchctl bootstrap.
//
//  Why not SMAppService.daemon: it requires a paid Apple Developer ID for
//  client-side validation (embedded provisioning profile, notarization).
//  An "Apple Development" certificate from a free Apple ID is rejected with
//  "Operation not permitted" before the request even reaches smappserviced.
//  This implementation works with free signing and can be swapped back to
//  SMAppService.register() once a paid identity is in place — the embedded
//  plist is already in BundleProgram form.
//

import Combine
import Foundation

@MainActor
final class HelperManager: ObservableObject {
    static let shared = HelperManager()

    enum InstallStatus: Equatable {
        case notInstalled
        case installed
        case unknown

        var displayName: String {
            switch self {
            case .notInstalled: return "Not installed"
            case .installed: return "Installed"
            case .unknown: return "Unknown"
            }
        }
    }

    private let label = "com.ahmetenesdur.Argus.argusd"
    private let plistName = "com.ahmetenesdur.Argus.argusd.plist"
    private let installedPlistPath = "/Library/LaunchDaemons/com.ahmetenesdur.Argus.argusd.plist"

    @Published private(set) var status: InstallStatus = .unknown
    @Published private(set) var lastError: String?
    @Published private(set) var isWorking: Bool = false

    private init() {
        // Intentionally empty. Calling refresh() here spawns a synchronous
        // Process on the main thread which can re-enter the static `shared`
        // dispatch_once and crash with EXC_BREAKPOINT (dispatch_once_wait).
        // ContentView's .onAppear calls refresh() once the view is mounted.
    }

    /// Asks launchctl whether the daemon is currently loaded in the system domain.
    /// Exit code 0 from `launchctl print` means the service exists.
    func refresh() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["print", "system/\(label)"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            status = task.terminationStatus == 0 ? .installed : .notInstalled
        } catch {
            status = .unknown
        }
    }

    /// Installs the helper:
    ///   1. boot out any existing copy (idempotent)
    ///   2. copy the bundled plist to /Library/LaunchDaemons
    ///   3. swap BundleProgram for an absolute Program path so launchd can
    ///      load it without going through SMAppService
    ///   4. fix ownership & permissions
    ///   5. bootstrap into the system domain
    /// Triggers one macOS authentication prompt (Touch ID or password).
    func install() async {
        let appBundle = Bundle.main.bundleURL.path

        guard appBundle.hasPrefix("/Applications/") else {
            lastError = "Argus must live in /Applications/ to install its helper. Currently at: \(appBundle)"
            return
        }

        let bundledPlist = appBundle + "/Contents/Library/LaunchDaemons/" + plistName
        let helperBinary = appBundle + "/Contents/MacOS/argusd"

        let script = [
            "set -e",
            "/bin/launchctl bootout system/\(label) > /dev/null 2>&1 || true",
            "/bin/cp '\(bundledPlist)' '\(installedPlistPath)'",
            "/usr/bin/plutil -remove BundleProgram '\(installedPlistPath)' > /dev/null 2>&1 || true",
            "/usr/bin/plutil -insert Program -string '\(helperBinary)' '\(installedPlistPath)'",
            "/usr/sbin/chown root:wheel '\(installedPlistPath)'",
            "/bin/chmod 644 '\(installedPlistPath)'",
            "/bin/launchctl bootstrap system '\(installedPlistPath)'"
        ].joined(separator: " && ")

        await runAdmin(script: script)
    }

    /// Uninstalls the helper: boot it out and remove the system-side plist.
    /// The daemon receives SIGTERM and restores disablesleep=0 before exiting.
    func uninstall() async {
        let script = [
            "/bin/launchctl bootout system/\(label) > /dev/null 2>&1 || true",
            "/bin/rm -f '\(installedPlistPath)'"
        ].joined(separator: " && ")

        await runAdmin(script: script)
    }

    /// Runs a shell script with administrator privileges via NSAppleScript.
    /// macOS shows the standard authentication dialog (Touch ID / password).
    private func runAdmin(script: String) async {
        isWorking = true
        defer { isWorking = false }

        // Escape backslashes and double quotes for the AppleScript string literal.
        let escaped = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let source = "do shell script \"\(escaped)\" with administrator privileges"

        let result = await Task.detached { () -> Result<Void, NSError> in
            var errorInfo: NSDictionary?
            guard let appleScript = NSAppleScript(source: source) else {
                return .failure(NSError(
                    domain: "argus.helper",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to compile AppleScript"]
                ))
            }
            _ = appleScript.executeAndReturnError(&errorInfo)
            if let info = errorInfo {
                let code = (info["NSAppleScriptErrorNumber"] as? Int) ?? -1
                let message = (info["NSAppleScriptErrorMessage"] as? String) ?? "Unknown AppleScript error"
                let display = code == -128 ? "Cancelled by user" : "\(message) (code \(code))"
                return .failure(NSError(
                    domain: "argus.helper",
                    code: code,
                    userInfo: [NSLocalizedDescriptionKey: display]
                ))
            }
            return .success(())
        }.value

        switch result {
        case .success:
            lastError = nil
        case .failure(let err):
            lastError = err.localizedDescription
        }

        refresh()
    }
}
