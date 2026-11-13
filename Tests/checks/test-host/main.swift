import Foundation
import Security

// Checks AppIdentity (Sources/DuoDeckMenuBar/AppIdentity.swift): which launches are DuoDeck.app itself, and
// so take no test hook, and which are the bare DuoDeckMenuBar binary (the security scan of 2026-10-18,
// finding 1; fixed 2026-10-29). With IdentityStorePlan, what that means for the finding's own path:
// the test directory's trust list (DUODECK_TEST_REMOTE_DIR) read by a renamed copy of DuoDeck.app.
//
// 1. The rule: DuoDeck.app as built, released and copied in every way the scan and the fix found
//    (renamed DuoDeck.bin, flat, through a hard link or a symlink, re-signed), the bare binary as
//    `swift build` makes it on Apple silicon and on Intel, near misses, then every combination of the
//    four facts against an oracle written apart from the rule.
// 2. The note line DuoDeck.app prints from a folder that is not a .app.
// 3. The reader, run for real: this check's own binary is what .build/release/DuoDeckMenuBar is (linker
//    signed ad hoc, no Info.plist), and copies of it are made here as the scan's attacker would make
//    copies of DuoDeck.app: signed again as DuoDeck, in a DuoDeck.bin bundle that says it is DuoDeck, started
//    through a hard link and a symlink to a bundle's executable, and replaced on disk after it started
//    (the kernel's identifier stands). Each copy is started with --facts under sandbox-exec with the
//    network denied, reads its own facts and prints them; nothing else runs. The signature reader
//    also reads files: an Apple app (a certificate), this binary (ad hoc), an unsigned copy; and its
//    mapping, pure, every answer (the two that fail closed, which no file here gives, among them).
//
// `--facts` and `--facts-wait` are the copies' modes: print this process's facts on one line (after a
// line on stdin, for --facts-wait) and exit.

func factsLine(_ f: AppIdentity.Facts) -> String {
    [f.signingIdentifier ?? "-", "\(f.signature)", f.bundleIdentifier ?? "-", f.bundlePath,
     AppIdentity.isDuoDeckApp(f) ? "duodeck" : "test"].joined(separator: "\t")
}
if CommandLine.arguments.contains("--facts-wait") {
    print("ready"); fflush(stdout)
    _ = readLine()
    print(factsLine(.current())); exit(0)
}
if CommandLine.arguments.contains("--facts") { print(factsLine(.current())); exit(0) }

var failures = 0, passed = 0
func check(_ desc: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    if ok { passed += 1; return }
    failures += 1
    let d = detail()
    print("FAIL: \(desc)\(d.isEmpty ? "" : ": \(d)")")
}

typealias F = AppIdentity.Facts
let duodeck = "com.agentsai.duodeck.host"
let build = "/Users/x/duodeck/.build/arm64-apple-macosx/release"
func facts(_ id: String?, _ sig: AppIdentity.Signature, _ bundle: String?, _ path: String) -> F {
    F(signingIdentifier: id, signature: sig, bundleIdentifier: bundle, bundlePath: path)
}

// MARK: 1. The rule

// The bundle identifier make-app.sh puts in DuoDeck.app (run.sh and the mutants run from the repository).
let packaged = (NSDictionary(contentsOfFile: "Packaging/Info.plist")?["CFBundleIdentifier"] as? String) ?? "unread"
check("DuoDeck's identifier is Packaging/Info.plist's", AppIdentity.duoDeck == packaged && packaged == "com.agentsai.duodeck.host", packaged)
let cases: [(String, F, Bool)] = [
    // The bare binary: the one test host.
    ("the bare binary as swift build makes it (Apple silicon: the linker's ad hoc signature)",
     facts("DuoDeckMenuBar", .adHoc, nil, build), false),
    ("the bare binary on Intel (x86_64: no signature)",
     facts(nil, .unsigned, nil, "/Users/x/duodeck/.build/x86_64-apple-macosx/release"), false),
    ("the bare binary built by Xcode (Sign to Run Locally)",
     facts("DuoDeckMenuBar", .adHoc, nil, "/Users/x/Library/Developer/Xcode/DerivedData/DuoDeck-abc/Build/Products/Release"), false),
    // DuoDeck.app where it belongs.
    ("DuoDeck.app as make-app.sh builds it (Apple Development)", facts(duodeck, .certificate, duodeck, "/Applications/DuoDeck.app"), true),
    ("DuoDeck.app's Developer ID release", facts(duodeck, .certificate, duodeck, "/Applications/DuoDeck.app"), true),
    ("DuoDeck.app signed ad hoc (no Apple Development identity; CI's verify job)", facts(duodeck, .adHoc, duodeck, "/Users/x/duodeck/.build/DuoDeck.app"), true),
    // The scan's copy, and the other ways to start DuoDeck.app's code where the folder says nothing.
    ("the scan's copy: DuoDeck.app renamed DuoDeck.bin", facts(duodeck, .certificate, duodeck, "/Users/x/x/DuoDeck.bin"), true),
    ("DuoDeck.app's executable through a symlink (Foundation finds no bundle around it)", facts(duodeck, .certificate, nil, "/tmp/x"), true),
    ("DuoDeck.app's executable through a hard link", facts(duodeck, .certificate, nil, "/tmp/x"), true),
    ("a flat copy of DuoDeck.app's executable", facts(duodeck, .certificate, nil, "/Users/x/x"), true),
    ("DuoDeck.app copied without its Info.plist", facts(duodeck, .certificate, nil, "/Users/x/x/DuoDeck.bin"), true),
    ("DuoDeck.app copied to a folder with no extension", facts(duodeck, .certificate, duodeck, "/Users/x/x/DuoDeck"), true),
    ("an ad hoc DuoDeck.app renamed (its grants are its cdhash, which a copy keeps)", facts(duodeck, .adHoc, duodeck, "/tmp/DuoDeck.bin"), true),
    ("an ad hoc DuoDeck.app's executable through a link", facts(duodeck, .adHoc, nil, "/tmp"), true),
    ("DuoDeck's code signed again under another identifier, in its renamed bundle (its bundle still says DuoDeck)",
     facts("other", .adHoc, duodeck, "/tmp/DuoDeck.bin"), true),
    ("DuoDeck's code signed again ad hoc under another identifier, alone (no grant left, nothing says DuoDeck)",
     facts("other", .adHoc, nil, "/tmp"), false),
    // The bare binary where DuoDeck.app's facts are.
    ("the bare binary in a bundle that says it is DuoDeck (DuoDeck's Info.plist)", facts("DuoDeckMenuBar", .adHoc, duodeck, "/tmp/DuoDeck.bin"), true),
    ("the bare binary in a .app of another ID (the rule before 2026-10-29)", facts("DuoDeckMenuBar", .adHoc, "com.agentsai.duodeck.test", "/tmp/Test.app"), true),
    ("the bare binary in a bundle of another ID that is not a .app", facts("DuoDeckMenuBar", .adHoc, "com.agentsai.duodeck.test", "/tmp/Test.bin"), false),
    ("the bare binary signed with a certificate (a developer's own)", facts("DuoDeckMenuBar", .certificate, nil, build), true),
    ("the bare binary on Intel in a .app (the rule before)", facts(nil, .unsigned, "com.agentsai.duodeck.test", "/tmp/Test.app"), true),
    ("a signature that could not be read", facts(nil, .unreadable, nil, build), true),
    ("an identifier that could not be read, ad hoc", facts(nil, .adHoc, nil, build), false),
    // In any case.
    ("DuoDeck's identifier in capitals", facts("COM.AGENTSAI.DUODECK.HOST", .adHoc, nil, "/tmp"), true),
    ("DuoDeck's bundle identifier in mixed case", facts("DuoDeckMenuBar", .adHoc, "Com.AgentsAI.DuoDeck.Host", "/tmp/DuoDeck.bin"), true),
    ("a .APP folder", facts("DuoDeckMenuBar", .adHoc, nil, "/tmp/DuoDeck.APP"), true),
    // Near misses.
    ("an identifier that only starts with DuoDeck's", facts("com.agentsai.duodeck.host.helper", .adHoc, nil, build), false),
    ("an identifier DuoDeck's starts with", facts("com.agentsai.duodeck", .adHoc, nil, build), false),
    ("a bundle identifier that only starts with DuoDeck's", facts("DuoDeckMenuBar", .adHoc, "com.agentsai.duodeck.host2", "/tmp/DuoDeck.bin"), false),
    ("an empty bundle identifier", facts("DuoDeckMenuBar", .adHoc, "", "/tmp/DuoDeck.bin"), false),
    ("a folder named app", facts("DuoDeckMenuBar", .adHoc, nil, "/tmp/app"), false),
    ("a .apps folder", facts("DuoDeckMenuBar", .adHoc, nil, "/tmp/x.apps"), false),
    ("a .app folder above the binary's folder", facts("DuoDeckMenuBar", .adHoc, nil, "/tmp/x.app/release"), false),
]
for (desc, f, want) in cases {
    check("rule: \(desc) → \(want ? "DuoDeck.app" : "a test host")", AppIdentity.isDuoDeckApp(f) == want, factsLine(f))
}

// Every combination of the facts against an oracle written apart from the rule: a test host is
// unsigned or ad hoc, signed under another identifier, in no bundle that says DuoDeck, not in a .app.
let identifiers: [String?] = [nil, "", "DuoDeckMenuBar", duodeck, "COM.agentsai.DUODECK.host", "com.agentsai.duodeck.host.helper", "other"]
let signatures: [AppIdentity.Signature] = [.unsigned, .adHoc, .certificate, .unreadable]
let bundles: [String?] = [nil, "", duodeck, "Com.AgentsAI.DuoDeck.Host", "com.agentsai.duodeck.test", "com.agentsai.duodeck.host2"]
let paths = [build, "/Applications/DuoDeck.app", "/tmp/DuoDeck.APP", "/tmp/DuoDeck.bin", "/tmp/DuoDeck", "/tmp/x.apps", "/tmp/app", "/"]
func oracleTestHost(_ f: F) -> Bool {
    let signedAsDuoDeck = f.signingIdentifier.map { $0.caseInsensitiveCompare(duodeck) == .orderedSame } ?? false
    let bundleDuoDeck = f.bundleIdentifier.map { $0.caseInsensitiveCompare(duodeck) == .orderedSame } ?? false
    let appFolder = URL(fileURLWithPath: f.bundlePath).pathExtension.caseInsensitiveCompare("app") == .orderedSame
    let noCertificate = f.signature == .unsigned || f.signature == .adHoc
    return noCertificate && !signedAsDuoDeck && !bundleDuoDeck && !appFolder
}
var grid = 0, gridWrong = 0
for id in identifiers { for sig in signatures { for b in bundles { for p in paths {
    let f = facts(id, sig, b, p)
    grid += 1
    if AppIdentity.isDuoDeckApp(f) == oracleTestHost(f) {
        gridWrong += 1
        if gridWrong <= 5 { check("grid: \(factsLine(f)) against the oracle", false) }
    }
}}}}
check("grid: \(grid) combinations agree with the oracle", gridWrong == 0, "\(gridWrong) disagree")

// The finding's path: a renamed copy started with --synthetic and DUODECK_TEST_REMOTE_DIR would have
// trusted a paired.json its caller wrote. DuoDeck.app's code never takes the test directory, whatever
// it is started with; the bare binary still does.
let trustDir = "/tmp/attacker/trust"
for (desc, f, want) in cases where want {
    for synthetic in [true, false] {
        let choice = IdentityStorePlan.choose(bundled: AppIdentity.isDuoDeckApp(f), synthetic: synthetic,
                                              entitledAccessGroup: nil, testRemoteDir: trustDir)
        check("store: \(desc), synthetic \(synthetic): never the test directory", choice != .testDirectory(trustDir), "\(choice)")
    }
}
check("store: the scan's copy with --synthetic keeps its identity in memory, pairing required",
      IdentityStorePlan.choose(bundled: AppIdentity.isDuoDeckApp(facts(duodeck, .certificate, duodeck, "/Users/x/x/DuoDeck.bin")), synthetic: true,
                               entitledAccessGroup: nil, testRemoteDir: trustDir) == .memory)
check("store: the bare binary with --synthetic still takes the test directory",
      IdentityStorePlan.choose(bundled: AppIdentity.isDuoDeckApp(facts("DuoDeckMenuBar", .adHoc, nil, build)), synthetic: true,
                               entitledAccessGroup: nil, testRemoteDir: trustDir) == .testDirectory(trustDir))

// MARK: 2. The note

func note(_ f: F) -> String? { AppIdentity.note(f) }
check("note: none for DuoDeck.app in its .app", note(facts(duodeck, .certificate, duodeck, "/Applications/DuoDeck.app")) == nil)
check("note: none for the bare binary", note(facts("DuoDeckMenuBar", .adHoc, nil, build)) == nil)
check("note: none for the bare binary in a .app of another ID (as before)", note(facts("DuoDeckMenuBar", .adHoc, "com.agentsai.duodeck.test", "/tmp/Test.app")) == nil)
check("note: none for a .APP folder", note(facts(duodeck, .certificate, duodeck, "/tmp/DuoDeck.APP")) == nil)
check("note: the scan's copy",
      note(facts(duodeck, .certificate, duodeck, "/Users/x/x/DuoDeck.bin"))
        == "Running from /Users/x/x/DuoDeck.bin, which is not a .app, as DuoDeck.app itself (signed com.agentsai.duodeck.host): it takes no test hook.",
      note(facts(duodeck, .certificate, duodeck, "/Users/x/x/DuoDeck.bin")) ?? "nil")
check("note: a link to DuoDeck.app's executable",
      note(facts(duodeck, .certificate, nil, "/tmp/x"))
        == "Running from /tmp/x, which is not a .app, as DuoDeck.app itself (signed com.agentsai.duodeck.host): it takes no test hook.")
check("note: a certificate alone",
      note(facts("DuoDeckMenuBar", .certificate, nil, build))
        == "Running from \(build), which is not a .app, as DuoDeck.app itself (signed with a certificate): it takes no test hook.")
check("note: an unreadable signature",
      note(facts(nil, .unreadable, nil, build))
        == "Running from \(build), which is not a .app, as DuoDeck.app itself (its signature could not be read): it takes no test hook.")
check("note: a bundle that says DuoDeck alone",
      note(facts("DuoDeckMenuBar", .adHoc, "Com.AgentsAI.DuoDeck.Host", "/tmp/DuoDeck.bin"))
        == "Running from /tmp/DuoDeck.bin, which is not a .app, as DuoDeck.app itself (its bundle says Com.AgentsAI.DuoDeck.Host): it takes no test hook.")
for (desc, f, want) in cases {
    let n = note(f)
    let folderSaysApp = URL(fileURLWithPath: f.bundlePath).pathExtension.lowercased() == "app"
    check("note: \(desc): a line exactly for DuoDeck.app's code where the folder does not say so", (n != nil) == (want && !folderSaysApp), n ?? "nil")
}

// MARK: 3. The reader, for real

let fm = FileManager.default
guard let me = Bundle.main.executablePath else { print("FAIL: no executable path"); exit(1) }
let scratch = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("duodeck-test-host-\(getpid())")
try? fm.removeItem(at: scratch)
try! fm.createDirectory(at: scratch, withIntermediateDirectories: true)
func path(_ name: String) -> String { scratch.appendingPathComponent(name).path }

@discardableResult
func run(_ tool: String, _ args: [String], input: String? = nil) -> (status: Int32, out: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = args
    let out = Pipe(); p.standardOutput = out; p.standardError = out
    let inp = Pipe(); p.standardInput = inp
    do { try p.run() } catch { return (-1, "\(error)") }
    if let input { inp.fileHandleForWriting.write(Data(input.utf8)) }
    try? inp.fileHandleForWriting.close()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(decoding: data, as: UTF8.self))
}
func codesign(_ args: [String]) -> Bool {
    let r = run("/usr/bin/codesign", args)
    if r.status != 0 { print("FAIL: codesign \(args.joined(separator: " ")): \(r.out)"); failures += 1 }
    return r.status == 0
}
func copy(_ from: String, _ to: String) {
    try? fm.createDirectory(atPath: (to as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    do { try fm.copyItem(atPath: from, toPath: to) } catch { print("FAIL: copy to \(to): \(error)"); failures += 1 }
}
func bundle(_ folder: String, id: String) -> String {
    let exe = "\(folder)/Contents/MacOS/check"
    copy(me, exe)
    let plist: [String: Any] = ["CFBundleIdentifier": id, "CFBundleExecutable": "check", "CFBundleInfoDictionaryVersion": "6.0"]
    try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        .write(to: URL(fileURLWithPath: "\(folder)/Contents/Info.plist"))
    return exe
}

// The copies start under sandbox-exec with the network denied (nothing else changes for them); where
// sandbox-exec can't apply (a sandbox already around this check), they start as they are, and say so.
let profile = "(version 1)(allow default)(deny network*)"
let sandboxed = run("/usr/bin/sandbox-exec", ["-p", profile, "/usr/bin/true"]).status == 0
if !sandboxed { print("note: sandbox-exec could not apply here; the copies start without it (they read their own identity, nothing else)") }
func start(_ exe: String, _ args: [String] = ["--facts"]) -> (tool: String, args: [String]) {
    sandboxed ? ("/usr/bin/sandbox-exec", ["-p", profile, exe] + args) : (exe, args)
}
struct Read: CustomStringConvertible {
    var id, signature, bundle, path, verdict: String
    var description: String { [id, signature, bundle, path, verdict].joined(separator: " | ") }
}
func readFacts(_ exe: String) -> Read? {
    let s = start(exe)
    let r = run(s.tool, s.args)
    let fields = r.out.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\t")
    guard r.status == 0, fields.count == 5 else { print("FAIL: \(exe) --facts: exit \(r.status): \(r.out)"); failures += 1; return nil }
    return Read(id: fields[0], signature: fields[1], bundle: fields[2], path: fields[3], verdict: fields[4])
}
func expect(_ desc: String, _ exe: String, id: String? = nil, signature: String, bundle: String, pathSuffix: String, verdict: String) {
    guard let r = readFacts(exe) else { return }
    let idOK = id.map { r.id == $0 } ?? (r.id != "-" && r.id.lowercased() != duodeck)
    check("reader: \(desc)", idOK && r.signature == signature && r.bundle == bundle && r.path.hasSuffix(pathSuffix) && r.verdict == verdict, "\(r)")
}

// The bare binary: this check itself, as the linker leaves it: signed ad hoc on Apple silicon, not at
// all in an x86_64 build.
#if arch(x86_64)
let linkerSignature = AppIdentity.Signature.unsigned
#else
let linkerSignature = AppIdentity.Signature.adHoc
#endif
let selfFacts = AppIdentity.Facts.current()
check("reader: this check, read in place, is the bare binary's kind: the linker's signature, no bundle, a test host",
      selfFacts.signature == linkerSignature && selfFacts.bundleIdentifier == nil
        && (selfFacts.signingIdentifier != nil) == (linkerSignature == .adHoc)
        && selfFacts.signingIdentifier?.lowercased() != duodeck && !AppIdentity.isDuoDeckApp(selfFacts), factsLine(selfFacts))
expect("this check as a process: a test host", me, id: selfFacts.signingIdentifier ?? "-", signature: "\(linkerSignature)", bundle: "-",
       pathSuffix: (me as NSString).deletingLastPathComponent, verdict: "test")

// A flat copy signed again as DuoDeck: the signing identifier alone says DuoDeck.
copy(me, path("flat-duodeck"))
if codesign(["-s", "-", "-f", "-i", duodeck, path("flat-duodeck")]) {
    expect("a flat copy signed ad hoc as DuoDeck: DuoDeck.app by its signing identifier", path("flat-duodeck"),
           id: duodeck, signature: "adHoc", bundle: "-", pathSuffix: scratch.lastPathComponent, verdict: "duodeck")
}
// The scan's folder: DuoDeck.bin, whose Info.plist says DuoDeck, the executable keeping the linker's signature.
let duodeckBin = bundle(path("DuoDeck.bin"), id: duodeck)
expect("a DuoDeck.bin bundle that says it is DuoDeck: DuoDeck.app by its bundle identifier, whatever the folder's name", duodeckBin,
       signature: "adHoc", bundle: duodeck, pathSuffix: "/DuoDeck.bin", verdict: "duodeck")
// The same with another bundle identifier: the reader does not say yes to any bundle.
let otherBin = bundle(path("Other.bin"), id: "com.agentsai.duodeck.test-host")
expect("a bundle of another identifier, not a .app: a test host", otherBin,
       signature: "adHoc", bundle: "com.agentsai.duodeck.test-host", pathSuffix: "/Other.bin", verdict: "test")
// A bundle signed as a whole, as make-app.sh signs DuoDeck.app (ad hoc here), then its executable started
// from outside it: through a hard link and a symlink Foundation finds no bundle, the signature stands.
let signedExe = bundle(path("Signed.bin"), id: duodeck)
if codesign(["-s", "-", "-f", path("Signed.bin")]) {
    expect("a bundle signed as DuoDeck: both say so", signedExe, id: duodeck, signature: "adHoc", bundle: duodeck, pathSuffix: "/Signed.bin", verdict: "duodeck")
    do {
        try fm.linkItem(atPath: signedExe, toPath: path("hardlink"))
        expect("its executable through a hard link: no bundle, DuoDeck.app by its signing identifier", path("hardlink"),
               id: duodeck, signature: "adHoc", bundle: "-", pathSuffix: scratch.lastPathComponent, verdict: "duodeck")
    } catch { print("FAIL: hard link: \(error)"); failures += 1 }
    do {
        try fm.createSymbolicLink(atPath: path("symlink"), withDestinationPath: signedExe)
        expect("its executable through a symlink: no bundle, DuoDeck.app by its signing identifier", path("symlink"),
               id: duodeck, signature: "adHoc", bundle: "-", pathSuffix: scratch.lastPathComponent, verdict: "duodeck")
    } catch { print("FAIL: symlink: \(error)"); failures += 1 }
}
// Replaced on disk once started: the identifier is the kernel's, read from the running code.
copy(me, path("swap")); copy(me, path("swap-other"))
if codesign(["-s", "-", "-f", "-i", duodeck, path("swap")]), codesign(["-s", "-", "-f", "-i", "com.agentsai.duodeck.test-other", path("swap-other")]) {
    let s = start(path("swap"), ["--facts-wait"])
    let p = Process()
    p.executableURL = URL(fileURLWithPath: s.tool); p.arguments = s.args
    let out = Pipe(), inp = Pipe()
    p.standardOutput = out; p.standardError = out; p.standardInput = inp
    do {
        try p.run()
        var got = Data()
        while !String(decoding: got, as: UTF8.self).contains("ready\n") {
            let chunk = out.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            got.append(chunk)
        }
        _ = rename(path("swap-other"), path("swap"))
        inp.fileHandleForWriting.write(Data("\n".utf8)); try? inp.fileHandleForWriting.close()
        got.append(out.fileHandleForReading.readDataToEndOfFile())
        p.waitUntilExit()
        let line = String(decoding: got, as: UTF8.self).components(separatedBy: "\n").first { $0.contains("\t") } ?? ""
        let fields = line.components(separatedBy: "\t")
        check("reader: replaced on disk after it started, it still reads DuoDeck's identifier (the kernel's) and is DuoDeck.app",
              fields.count == 5 && fields[0] == duodeck && fields[4] == "duodeck", line.isEmpty ? String(decoding: got, as: UTF8.self) : line)
        let now = run("/usr/bin/codesign", ["-dv", path("swap")]).out
        check("reader: the file on disk is now the other one", now.contains("Identifier=com.agentsai.duodeck.test-other"), now)
    } catch { print("FAIL: swap: \(error)"); failures += 1 }
}

// The signature reader on files.
func signatureOf(_ file: String) -> (identifier: String?, signature: AppIdentity.Signature)? {
    var code: SecStaticCode?
    guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: file) as CFURL, [], &code) == errSecSuccess, let code else { return nil }
    return AppIdentity.signature(of: code)
}
let apple = ["/System/Applications/Calculator.app", "/System/Applications/TextEdit.app", "/System/Library/CoreServices/Finder.app"]
    .first { fm.fileExists(atPath: $0) }
if let apple, let s = signatureOf(apple) {
    check("signature: \(apple) is signed with a certificate", s.signature == .certificate && s.identifier?.hasPrefix("com.apple.") == true, "\(s)")
} else {
    print("FAIL: no Apple app to read"); failures += 1
}
if let s = signatureOf(me) {
    check("signature: this check carries the linker's signature (ad hoc on Apple silicon, none on x86_64)",
          s.signature == linkerSignature && (s.identifier != nil) == (linkerSignature == .adHoc) && s.identifier != duodeck, "\(s)")
}
copy(me, path("unsigned"))
if linkerSignature == .unsigned || codesign(["--remove-signature", path("unsigned")]), let s = signatureOf(path("unsigned")) {
    check("signature: a copy with no signature (as an x86_64 build) is unsigned, with no identifier", s.signature == .unsigned && s.identifier == nil, "\(s)")
}
if let s = signatureOf(path("flat-duodeck")) {
    check("signature: the flat copy signed as DuoDeck is ad hoc under DuoDeck's identifier", s.signature == .adHoc && s.identifier == duodeck, "\(s)")
}

// The signature's information, pure (`signature(read:)`): every answer, the two that fail closed
// too, which no file on this Mac gives (Security read a copy with a damaged signature, and one deleted
// once opened, without an error).
let idKey = kSecCodeInfoIdentifier as String, certKey = kSecCodeInfoCertificates as String, flagsKey = kSecCodeInfoFlags as String
let adhocFlag = SecCodeSignatureFlags.adhoc.rawValue
let linkerFlags = NSNumber(value: adhocFlag | 0x20000)   // flags=0x20002(adhoc,linker-signed), the bare binary's
func pureSig(_ d: [String: Any]?) -> String {
    let r = AppIdentity.signature(read: d)
    return "\(r.identifier ?? "-") \(r.signature)"
}
let pure: [(String, [String: Any]?, String)] = [
    ("no information at all (the read failed): unreadable", nil, "- unreadable"),
    ("information without an identifier: unsigned", [:], "- unsigned"),
    ("information without an identifier, the ad hoc flag and all: unsigned", [flagsKey: linkerFlags], "- unsigned"),
    ("the linker's signature (adhoc, linker-signed): ad hoc", [idKey: "DuoDeckMenuBar", flagsKey: linkerFlags], "DuoDeckMenuBar adHoc"),
    ("codesign -s - (adhoc): ad hoc", [idKey: duodeck, flagsKey: NSNumber(value: adhocFlag)], "\(duodeck) adHoc"),
    ("ad hoc with an empty certificate list: ad hoc", [idKey: "x", certKey: [Any](), flagsKey: linkerFlags], "x adHoc"),
    ("a certificate chain, the hardened runtime: certificate", [idKey: duodeck, certKey: ["leaf", "intermediate", "root"], flagsKey: NSNumber(value: 0x10000)], "\(duodeck) certificate"),
    ("a certificate and the ad hoc flag: certificate (any chain at all)", [idKey: "x", certKey: ["leaf"], flagsKey: linkerFlags], "x certificate"),
    ("an identifier with no certificate and no flags: unreadable", [idKey: "x"], "x unreadable"),
    ("an identifier with no certificate, only the hardened runtime: unreadable", [idKey: "x", flagsKey: NSNumber(value: 0x10000)], "x unreadable"),
]
for (desc, d, want) in pure { check("signature, pure: \(desc)", pureSig(d) == want, pureSig(d)) }
check("signature, pure: a read that failed makes DuoDeck.app, never a test host (the bare binary's identifier and path)",
      AppIdentity.isDuoDeckApp(facts("DuoDeckMenuBar", AppIdentity.signature(read: nil).signature, nil, build)))
check("signature, pure: an identifier with neither a certificate nor the ad hoc flag makes DuoDeck.app",
      AppIdentity.isDuoDeckApp(facts("DuoDeckMenuBar", AppIdentity.signature(read: [idKey: "DuoDeckMenuBar"]).signature, nil, build)))

try? fm.removeItem(at: scratch)
if failures == 0 {
    print("test-host: every case passed (\(passed) checks: AppIdentity's rule, \(grid) combinations, the note, IdentityStorePlan, the reader \(sandboxed ? "under sandbox-exec" : "without sandbox-exec"))")
    exit(0)
} else {
    print("test-host: \(failures) FAILED (\(passed) passed)")
    exit(1)
}
