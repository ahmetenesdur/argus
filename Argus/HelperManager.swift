//
//  HelperManager.swift
//  Argus
//
//  Wraps SMAppService.daemon registration for the argusd helper.
//

import Combine
import Foundation
import ServiceManagement

@MainActor
final class HelperManager: ObservableObject {
    static let shared = HelperManager()

    private let plistName = "com.ahmetenesdur.Argus.argusd.plist"
    private let service: SMAppService

    @Published private(set) var status: SMAppService.Status
    @Published private(set) var lastError: String?

    private init() {
        self.service = SMAppService.daemon(plistName: plistName)
        self.status = service.status
    }

    func register() {
        do {
            try service.register()
            status = service.status
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func unregister() async {
        do {
            try await service.unregister()
            status = service.status
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refresh() {
        status = service.status
    }
}

extension SMAppService.Status {
    var displayName: String {
        switch self {
        case .notRegistered: return "Not registered"
        case .enabled: return "Enabled"
        case .requiresApproval: return "Needs approval (System Settings)"
        case .notFound: return "Not found"
        @unknown default: return "Unknown"
        }
    }
}
