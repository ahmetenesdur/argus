//
//  ContentView.swift
//  Argus
//
//  Created by Ahmet Enes Dur on 06/05/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var helper = HelperManager.shared
    @StateObject private var xpc = XPCClient.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Argus")
                .font(.headline)

            HStack(spacing: 4) {
                Text("Helper:")
                    .foregroundStyle(.secondary)
                Text(helper.status.displayName)
            }
            .font(.caption)

            Toggle("Prevent Sleep", isOn: Binding(
                get: { xpc.enabled ?? false },
                set: { newValue in
                    Task { await xpc.setEnabled(newValue) }
                }
            ))
            .toggleStyle(.switch)
            .disabled(xpc.connectionState != .connected)

            if let caption = connectionCaption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Install") {
                    Task { await helper.install() }
                }
                .disabled(helper.status == .installed || helper.isWorking)

                Button("Uninstall") {
                    Task { await helper.uninstall() }
                }
                .disabled(helper.status == .notInstalled || helper.isWorking)

                Spacer()

                Button("Refresh") {
                    helper.refresh()
                    xpc.connect()
                }
                .disabled(helper.isWorking)
            }

            if let error = helper.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button("Quit Argus") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
        .onAppear {
            helper.refresh()
            // Re-attempt the XPC connection every time the popover opens.
            // Idempotent when already healthy; recovers from prior
            // invalidation (e.g. the helper crashed and KeepAlive restarted
            // it, leaving our side stuck on "Helper not responding").
            xpc.connect()
        }
        .onChange(of: helper.status) { newStatus in
            switch newStatus {
            case .installed:
                xpc.connect()
            case .notInstalled, .unknown:
                xpc.disconnect()
            }
        }
    }

    private var connectionCaption: String? {
        switch (helper.status, xpc.connectionState) {
        case (.notInstalled, _):
            return "Install helper to control sleep"
        case (.installed, .connecting):
            return "Connecting…"
        case (.installed, .failed):
            return "Helper not responding"
        case (.installed, .disconnected):
            return "Helper not responding"
        default:
            return nil
        }
    }
}

#Preview {
    ContentView()
}
