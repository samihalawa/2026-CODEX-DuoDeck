import Foundation

var checks = 0
var failures = 0
func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    checks += 1
    if !condition() { failures += 1; print("FAIL \(label)") }
}
let a = ParameterSets(nalUnitHeaderLength: 4, sets: [Data([1,2]), Data([3]), Data([4])])
let b = ParameterSets(nalUnitHeaderLength: 4, sets: [Data([5,6]), Data([7]), Data([8])])
var cache = VideoFrameReplayCache()
check(cache.replayable == nil, "no frame before a format")
cache.receive(Data([10]), isKeyframe: true)
check(cache.keyframe == nil, "keyframe without format cannot replay")
cache.apply(a)
cache.receive(Data([11]), isKeyframe: false)
check(cache.replayable == nil, "delta cannot bootstrap decoder")
cache.receive(Data([12]), isKeyframe: true)
check(cache.replayable?.frame == Data([12]), "late view receives static first keyframe")
check(cache.replayable?.parameterSets.encoded() == a.encoded(), "format and frame stay paired")
cache.apply(a)
check(cache.replayable != nil, "repeated format keeps usable frame")
cache.receive(Data([13]), isKeyframe: false)
check(cache.replayable == nil, "missed dependent deltas require fresh keyframe")
check(cache.keyframe?.frame == Data([12]), "preview is separate from decoder eligibility")
cache.receive(Data([14]), isKeyframe: true)
check(cache.replayable?.frame == Data([14]), "fresh keyframe repairs references")
cache.apply(b)
check(cache.keyframe == nil, "format replacement rejects stale source")
cache.receive(Data([15]), isKeyframe: true)
cache.invalidateFrame()
check(cache.replayable == nil && cache.keyframe == nil, "request or lock discards private pixels")
check(cache.parameterSets?.encoded() == b.encoded(), "blank can keep format")
cache.receive(Data([16]), isKeyframe: true)
cache.reset()
check(cache.parameterSets == nil && cache.keyframe == nil, "disconnect forgets pixels and format")
cache.apply(a)
check(cache.replayable == nil, "new session cannot replay old Mac")

let encoder = JSONEncoder(), decoder = JSONDecoder()
let oldData = Data(#"{"macName":"Mac","windows":[],"active":{"none":{}}}"#.utf8)
let old = try decoder.decode(WindowList.self, from: oldData)
check(old.captureIssue == nil, "new client accepts absent optional field")
let omitted = try JSONSerialization.jsonObject(with: encoder.encode(old)) as! [String:Any]
check(omitted["captureIssue"] == nil, "nil issue omitted from wire")
var list = WindowList(macName: "Mac", windows: [
    WindowInfo(id: 42, title: "private", appName: "App", bundleID: "example.app", width: 900, height: 600)
], active: .window(42))
list.captureIssue = .permission
let payload = try encoder.encode(list)
struct LegacyWindowList: Decodable { var macName: String; var windows: [WindowInfo]; var active: StreamSource }
let legacy = try decoder.decode(LegacyWindowList.self, from: payload)
check(legacy.active == .window(42) && legacy.windows.count == 1, "old02 decoder ignores new field")
let decoded = try decoder.decode(WindowList.self, from: payload)
check(decoded.captureIssue == .permission, "new issue roundtrips")
list.captureIssue = CaptureIssue(code: "futureReason")
let future = try decoder.decode(WindowList.self, from: encoder.encode(list))
check(future.captureIssue?.title == "Your Mac’s picture is unavailable", "future reason leaves catalog decodable")
for reading in [LockPolicy.Reading.screenLocked, .offConsole] {
    let locked = LockPolicy.list(list, reading: reading)
    check(locked.windows.isEmpty, "locked list withholds windows")
    check(locked.captureIssue == nil, "lock state takes precedence")
    check(LockPolicy.withheld(.frame, picture: .window, reading: reading), "lock withholds window frames")
}
check(LockPolicy.withheld(.frame, picture: .display, reading: .offConsole), "off-console display withheld")
check(!LockPolicy.withheld(.frame, picture: .placeholder, reading: .offConsole), "deliberate placeholder can pass")
check(LockPolicy.list(list, reading: .unlocked).captureIssue == list.captureIssue, "unlocked issue retained")

var recovery = FirstPictureRecovery()
check(recovery.tick() == .nothing, "no requests before session")
recovery.begin()
for n in 1...3 { check(recovery.tick() == .retry && recovery.attempts == n, "bounded request \(n)") }
check(recovery.tick() == .failed && recovery.exhausted, "next tick reports failure, no fourth request")
for _ in 0..<10 { check(recovery.tick() == .nothing, "exhausted startup stays quiet") }
recovery.begin()
check(recovery.tick() == .retry, "manual retry gets fresh budget")
recovery.stop()
check(recovery.tick() == .nothing, "known host failure/lock stops requests")
recovery.begin(); recovery.resolved()
check(recovery.tick() == .nothing && !recovery.exhausted, "ready picture ends startup")
check(!CaptureIssue.noFrames.detail.contains("allow"), "no picture does not claim permission denial")
check(CaptureIssue.permission.detail.contains("DuoDeck Host"), "permission action identifies Mac app")
var ready = PictureReadiness()
ready.invalidate(generation: 1, at: 10)
check(ready.observed(ready: true, at: 11) == nil, "late old ready after reset cannot claim picture")
_ = ready.observed(ready: false, at: 12)
check(ready.observed(ready: true, at: 13) == nil, "empty-to-ready without current keyframe is ignored")
ready.enqueuedKeyframe(at: 14)
check(ready.observed(ready: true, at: 13.5) == nil, "queued ready before current keyframe is ignored")
check(ready.observed(ready: true, at: 15) == 1, "new keyframe plus ready transition resolves generation")
check(ready.observed(ready: true, at: 16) == nil, "one completion per picture")
ready.invalidate(generation: 2, at: 20)
ready.enqueuedKeyframe(at: 21)
check(ready.observed(ready: true, at: 22) == nil, "retained ready image cannot resolve retry")
check(ready.observed(ready: false, at: 19) == nil, "old empty event cannot qualify retry")
check(ready.observed(ready: true, at: 23) == nil, "old empty event leaves retry unqualified")
_ = ready.observed(ready: false, at: 24)
check(ready.observed(ready: true, at: 25) == 2, "fresh empty-to-ready resolves only current retry")
ready.invalidate(at: 30)
check(ready.observed(ready: true, at: 31) == nil, "lock or format blank rejects prior readiness")
_ = ready.observed(ready: false, at: 32)
ready.enqueuedKeyframe(at: 33)
check(ready.observed(ready: true, at: 34) == 2, "same-generation format recovery needs fresh picture")
ready.invalidate(generation: 3, at: 40)
_ = ready.observed(ready: false, at: 41)
ready.enqueuedKeyframe(at: 39)
check(ready.observed(ready: true, at: 42) == nil, "old-session keyframe cannot arm new readiness")


Task {
    do {
        let value: Int = try await CaptureLookup.read(timeout: 0.05) { $0(.success(7)) }
        check(value == 7, "immediate native success")
        let once: Int = try await CaptureLookup.read(timeout: 0.05) { done in
            done(.success(8)); done(.failure(CaptureLookup.Failure.unavailable)); done(.success(9))
        }
        check(once == 8, "duplicate callback resumes once")
        let before = ProcessInfo.processInfo.systemUptime
        do {
            let _: Int = try await CaptureLookup.read(timeout: 0.03) { _ in }
            check(false, "never-returning call must timeout")
        } catch {
            check((error as? CaptureLookup.Failure) == .timedOut, "timeout identity preserved")
            check(ProcessInfo.processInfo.systemUptime - before < 0.5, "timeout releases wait promptly")
        }
        do {
            let _: Int = try await CaptureLookup.read(timeout: 0.01) { done in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.04) { done(.success(10)) }
            }
            check(false, "late native success cannot overtake timeout")
        } catch {
            check((error as? CaptureLookup.Failure) == .timedOut, "late callback loses")
        }
        let task = Task {
            try await CaptureLookup.read(timeout: 1) { (done: @escaping (Result<Int,Error>) -> Void) in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.04) { done(.success(11)) }
            }
        }
        task.cancel()
        do { _ = try await task.value; check(false, "canceled lookup cannot succeed") }
        catch { check(error is CancellationError, "cancellation propagates promptly") }
        do {
            let _: Int = try await CaptureLookup.read(timeout: 0.05) {
                $0(.failure(NSError(domain: "NativeCapture", code: -3801)))
            }
            check(false, "native error must propagate")
        } catch {
            check((error as NSError).domain == "NativeCapture" && (error as NSError).code == -3801,
                  "native domain/code retained")
        }
        try await Task.sleep(for: .milliseconds(70))
    } catch { check(false, "unexpected async error \(error)") }
    print("\(checks) checks, \(failures) failed")
    exit(failures == 0 ? 0 : 1)
}
dispatchMain()
