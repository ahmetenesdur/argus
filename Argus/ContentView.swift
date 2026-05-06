//
//  ContentView.swift
//  Argus
//
//  Created by Ahmet Enes Dur on 06/05/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Argus")
                .font(.headline)
            Text("Pre-alpha. Controls coming soon.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

#Preview {
    ContentView()
}
