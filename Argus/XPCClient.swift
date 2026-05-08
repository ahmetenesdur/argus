//
//  XPCClient.swift
//  Argus
//
//  Wraps NSXPCConnection to argusd. Exposes the helper's state as
//  @Published properties so SwiftUI can drive the popover off it.
//

import Combine
import Foundation

@MainActor
final class XPCClient: ObservableObject {
    static let shared = XPCClient()

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var enabled: Bool?
    @Published private(set) var protocolVersion: String?

    private var connection: NSXPCConnection?

    private init() {}

    func connect() {
        // Skip only when an existing connection is verifiably healthy.
        // Earlier versions guarded on `connection == nil`, but interruption
        // and per-call error handlers leave the connection object in place
        // even though it can no longer talk to the peer — the popover then
        // sits on "Helper not responding" forever.
        if case .connected = connectionState, connection != nil {
            return
        }
        connection?.invalidate()
        connection = nil

        let conn = NSXPCConnection(
            machServiceName: ArgusHelper.machServiceName,
            options: .privileged
        )
        conn.setCodeSigningRequirement(ArgusHelper.helperRequirement)
        conn.remoteObjectInterface = NSXPCInterface(with: ArgusHelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.handleInvalidation() }
        }
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in self?.handleInterruption() }
        }
        conn.resume()
        connection = conn
        connectionState = .connecting

        Task { await self.bootstrap() }
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
        connectionState = .disconnected
        enabled = nil
        protocolVersion = nil
    }

    private func bootstrap() async {
        let version = await ping()
        let state = await currentState()

        protocolVersion = version
        enabled = state

        if version == nil {
            connectionState = .failed("ping returned nil")
        } else {
            connectionState = .connected
        }
    }

    private func proxy() -> ArgusHelperProtocol? {
        connection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            Task { @MainActor in
                self?.handleConnectionError(error)
            }
        } as? ArgusHelperProtocol
    }

    private func handleConnectionError(_ error: Error) {
        connectionState = .failed(error.localizedDescription)
        connection?.invalidate()
        connection = nil
        enabled = nil
    }

    private func ping() async -> String? {
        guard let proxy = proxy() else { return nil }
        return await withCheckedContinuation { continuation in
            proxy.ping { version in
                continuation.resume(returning: version)
            }
        }
    }

    private func currentState() async -> Bool? {
        guard let proxy = proxy() else { return nil }
        return await withCheckedContinuation { continuation in
            proxy.currentState { state in
                continuation.resume(returning: state)
            }
        }
    }

    /// Optimistically updates `enabled` so SwiftUI's Toggle rebinds
    /// immediately, then dispatches the XPC call. If the helper reports
    /// an error we re-fetch the authoritative state.
    func setEnabled(_ newValue: Bool) async {
        enabled = newValue
        guard let proxy = proxy() else { return }
        let error: NSError? = await withCheckedContinuation { continuation in
            proxy.setEnabled(newValue) { err in
                continuation.resume(returning: err)
            }
        }
        if let error {
            connectionState = .failed(error.localizedDescription)
            enabled = await currentState()
        }
    }

    private func handleInvalidation() {
        connection = nil
        connectionState = .disconnected
        enabled = nil
        protocolVersion = nil
    }

    private func handleInterruption() {
        connection?.invalidate()
        connection = nil
        connectionState = .disconnected
        enabled = nil
    }
}
