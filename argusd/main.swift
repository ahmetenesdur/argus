//
//  main.swift
//  argusd
//
//  Argus helper daemon. Boots, restores the user's last toggle preference
//  from StateStore, and (in Faz 3+) serves XPC requests from Argus.app.
//  On SIGTERM it always restores `disablesleep=0` so that uninstall or
//  `launchctl bootout` leaves the system in a clean state — regardless
//  of the persisted preference.
//

import Dispatch
import Foundation

func log(_ message: String) {
    print("argusd: \(message)")
    fflush(stdout)
}

@discardableResult
func runPmset(_ value: String) -> Int32 {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    task.arguments = ["-a", "disablesleep", value]
    do {
        try task.run()
        task.waitUntilExit()
        return task.terminationStatus
    } catch {
        log("pmset spawn error: \(error)")
        return -1
    }
}

log("starting (pid \(getpid()))")

let initialState = StateStore.load()
log("loaded state: enabled=\(initialState.enabled)")

if initialState.enabled {
    let setStatus = runPmset("1")
    log("restored disablesleep=1 (exit \(setStatus))")
}

let service = ArgusService()
let listener = NSXPCListener(machServiceName: ArgusHelper.machServiceName)
listener.delegate = service
listener.resume()
log("xpc listener resumed on \(ArgusHelper.machServiceName)")

// SIGTERM cleanup: drop pmset back to 0 unconditionally, even if the
// persisted state was disabled. This guarantees `launchctl bootout` (or
// uninstall) cannot leave the system in a wedged "won't sleep" state.
signal(SIGTERM, SIG_IGN)
let sigSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigSource.setEventHandler {
    log("SIGTERM received, restoring disablesleep=0")
    runPmset("0")
    log("exiting")
    exit(0)
}
sigSource.resume()

dispatchMain()
