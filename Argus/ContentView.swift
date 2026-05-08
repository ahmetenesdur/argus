//
//  ContentView.swift
//  Argus
//
//  Created by Ahmet Enes Dur on 06/05/2026.
//

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
        .onAppear { helper.refresh() }
    }
}

#Preview {
    ContentView()
}
