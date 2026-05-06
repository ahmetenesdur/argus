//
//  ContentView.swift
//  Argus
//
//  Created by Ahmet Enes Dur on 06/05/2026.
//

import ServiceManagement
import SwiftUI

struct ContentView: View {
    @StateObject private var helper = HelperManager.shared

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

            HStack {
                Button("Install") {
                    helper.register()
                }
                .disabled(helper.status == .enabled)

                Button("Uninstall") {
                    Task { await helper.unregister() }
                }
                .disabled(helper.status == .notRegistered)

                Spacer()

                Button("Refresh") {
                    helper.refresh()
                }
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
        .onAppear { helper.refresh() }
    }
}

#Preview {
    ContentView()
}
