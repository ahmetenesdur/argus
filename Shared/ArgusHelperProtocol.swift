//
//  ArgusHelperProtocol.swift
//
//  Shared XPC interface compiled into both Argus.app and argusd.
//  Members must stay @objc-compatible (NSXPC ObjC bridge): no Swift-only
//  types, no async (use completion handlers), errors via NSError.
//

import Foundation

enum ArgusHelper {
    static let machServiceName = "com.ahmetenesdur.Argus.argusd"
    static let errorDomain = "com.ahmetenesdur.Argus.helperError"
    static let protocolVersion = "argusd/2.0"

    /// Apple Developer Team ID. Both binaries are signed under this team
    /// (free Apple ID development cert; subject.OU on the leaf cert is the
    /// Team ID). XPC peer validation pins on this + the bundle identifier.
    static let teamID = "D685QL56G9"

    /// Requirement string the helper checks against an incoming app connection.
    static let appRequirement =
        "identifier \"com.ahmetenesdur.Argus\" and anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""

    /// Requirement string the app checks against the helper it dialed.
    static let helperRequirement =
        "identifier \"com.ahmetenesdur.Argus.argusd\" and anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""
}

@objc protocol ArgusHelperProtocol {
    func ping(reply: @escaping (String) -> Void)
    func currentState(reply: @escaping (Bool) -> Void)
    func setEnabled(_ enabled: Bool, reply: @escaping (NSError?) -> Void)
}
