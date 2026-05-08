//
//  ArgusService.swift
//  argusd
//
//  XPC server: listener delegate + ArgusHelperProtocol implementation.
//  All state mutations are serialized on `queue` so concurrent app
//  requests cannot race on StateStore writes or pmset spawns.
//

import Foundation

final class ArgusService: NSObject, ArgusHelperProtocol, NSXPCListenerDelegate {
    private let queue = DispatchQueue(label: "argusd.state", qos: .userInitiated)

    // MARK: NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.setCodeSigningRequirement(ArgusHelper.appRequirement)
        newConnection.exportedInterface = NSXPCInterface(with: ArgusHelperProtocol.self)
        newConnection.exportedObject = self

        newConnection.invalidationHandler = {
            log("xpc: connection invalidated")
        }
        newConnection.interruptionHandler = {
            log("xpc: connection interrupted")
        }

        newConnection.resume()
        log("xpc: accepted new connection")
        return true
    }

    // MARK: ArgusHelperProtocol

    func ping(reply: @escaping (String) -> Void) {
        reply(ArgusHelper.protocolVersion)
    }

    func currentState(reply: @escaping (Bool) -> Void) {
        queue.async {
            reply(StateStore.load().enabled)
        }
    }

    func setEnabled(_ enabled: Bool, reply: @escaping (NSError?) -> Void) {
        queue.async {
            var state = StateStore.load()
            state.enabled = enabled
            state.lastChangedAt = Date()

            do {
                try StateStore.save(state)
            } catch {
                log("setEnabled: state save failed: \(error)")
                reply(error as NSError)
                return
            }

            let pmsetExit = runPmset(enabled ? "1" : "0")
            log("setEnabled(\(enabled)): pmset exit=\(pmsetExit)")

            if pmsetExit != 0 {
                let err = NSError(
                    domain: ArgusHelper.errorDomain,
                    code: Int(pmsetExit),
                    userInfo: [NSLocalizedDescriptionKey: "pmset exited with code \(pmsetExit)"]
                )
                reply(err)
                return
            }

            reply(nil)
        }
    }
}
