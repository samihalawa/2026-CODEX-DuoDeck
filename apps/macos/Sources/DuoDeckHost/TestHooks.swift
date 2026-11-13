import Foundation

/// The TEST ONLY variables that bear on who gets in or what pairing needs
/// (docs/home-pairing-plan.md §4.3). Each is read where it acts, and honoured only on a test host
/// (DoorPolicy.isTestHost: one that does not advertise and is not DuoDeck.app's own code, by its
/// signature and bundle wherever it runs from): any process of this user can start DuoDeck.app's own
/// executable, or a copy of it, with an environment, and it then runs with DuoDeck's Screen Recording
/// and Accessibility grants. Anywhere else each one set is ignored with one line, here. The
/// encoder's variables and the test tone's (SyntheticAudio: only a synthetic host has the tone) let
/// nobody in and are not among them; DUODECK_TEST_REMOTE_DIR is read, and refused, where the identity
/// store is chosen (the CLI and the app).
enum TestHooks {
    static let doorAndPairing = [
        "DUODECK_TEST_SERVICE_TYPE", "DUODECK_TEST_SWAP_FAIL", "DUODECK_TEST_PEER_TO_PEER_INTERFACE", "DUODECK_TEST_ORIGIN",
        "DUODECK_TEST_REMOTE_ORIGIN",
        "DUODECK_TEST_LOOPBACK", "DUODECK_TEST_BACKOFF_SECONDS", "DUODECK_TEST_PAIRING_TTL", "DUODECK_TEST_NO_ROUTER",
        "DUODECK_TEST_CABLE_INTERFACE", "DUODECK_TEST_LOCKED", "DUODECK_TEST_ASK_FROM_THIS_MAC", "DUODECK_TEST_ASK_QUIET",
        // SessionLock's (LockPolicy, docs/locked-mac-plan.md): the file (1 screen locked, 2 off console),
        // the screen's lock state from a notify name of the test's own, notifications delivered on cue,
        // and each look's witnesses printed.
        "DUODECK_TEST_LOCKED_FILE", "DUODECK_TEST_LOCK_NOTIFY", "DUODECK_TEST_LOCK_NOTE", "DUODECK_TEST_LOCK_IGNORE_MAC", "DUODECK_TEST_LOCK_LOG",
        // The CLI's (main.swift): "0" turns Require pairing off at --pairing's TLS home door.
        "DUODECK_TEST_REQUIRE_PAIRING",
        // The device gate's (DeviceGate): a floor above "0" refuses devices.
        "DUODECK_TEST_MIN_DEVICE_VERSION", "DUODECK_TEST_GOODBYE",
    ]

    /// One line for each such variable set on a host that does not honour them; nothing on a test
    /// host, and nothing when none is set (so every existing output stays as it was).
    static func reportIgnored(testHost: Bool, environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard !testHost else { return }
        for name in doorAndPairing where !(environment[name] ?? "").isEmpty {
            print("\(name) ignored: only a test host takes it (one that does not advertise and is not DuoDeck.app itself).")
        }
    }
}
