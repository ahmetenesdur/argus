//
//  StateStore.swift
//  argusd
//
//  Persists the user's last toggle preference at
//  /Library/Application Support/Argus/state.json so the helper can restore
//  it across reboots and KeepAlive restarts.
//
//  Root-only writer. The app does not read this file directly; it queries
//  the helper over XPC.
//

import Foundation

struct ArgusState: Codable {
    var version: Int
    var enabled: Bool
    var lastChangedAt: Date

    static var defaultValue: ArgusState {
        ArgusState(version: 1, enabled: false, lastChangedAt: Date())
    }
}

enum StateStore {
    static let directoryURL = URL(fileURLWithPath: "/Library/Application Support/Argus", isDirectory: true)
    static let fileURL = directoryURL.appendingPathComponent("state.json")

    /// Returns the persisted state, or `.defaultValue` (enabled=false) if
    /// the file is missing or unreadable. Never throws — the helper must
    /// boot even if state is corrupt.
    static func load() -> ArgusState {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .defaultValue
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ArgusState.self, from: data)) ?? .defaultValue
    }

    /// Atomic JSON write. Creates the directory on demand so the very
    /// first save after a fresh install succeeds even if the install
    /// script hasn't pre-created it.
    static func save(_ state: ArgusState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}
