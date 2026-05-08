//
//  main.swift
//  argusd
//
//  Argus helper daemon. On launch, sets `pmset disablesleep=1` (system-wide
//  prevent sleep on lid close). On SIGTERM, restores `disablesleep=0` and
//  exits cleanly.
//
//  This is the Faz 1.5 minimal proof: helper actually exercises pmset under
//  root privileges. Faz 2 will replace the body with an NSXPCListener so the
//  app can toggle on/off on demand.
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

let setStatus = runPmset("1")
log("set disablesleep=1 (exit \(setStatus))")

// Catch SIGTERM (delivered by `launchctl bootout`) so we can restore the
// system state before exiting. Default action would just kill us instantly.
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
