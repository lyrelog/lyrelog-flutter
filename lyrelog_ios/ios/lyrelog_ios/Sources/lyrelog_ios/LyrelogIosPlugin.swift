import Flutter
import Foundation
// `wrapper` (this package in `resource.sdk`) is the Swift SDK's SPI for its own wrappers.
@_spi(Wrapper) import Lyrelog
import UIKit

/// The iOS side of the lyrelog Flutter plugin: every call from Dart goes straight to the Lyrelog
/// Swift SDK, which owns the disk queue, batching, retries, MetricKit crashes, sessions, consent
/// and App Attest. Nothing here keeps state of its own, and nothing throws back into Dart.
///
/// Pigeon delivers every call on one serial background queue (`@TaskQueue` in
/// `pigeon/messages.dart`), not on the main thread the UI runs on, in the order Dart made them;
/// the Swift SDK is safe to call from any thread.
public final class LyrelogIosPlugin: NSObject, FlutterPlugin, LyrelogHostApi {
    public static func register(with registrar: FlutterPluginRegistrar) {
        LyrelogHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: LyrelogIosPlugin())
    }

    func start(configuration message: StartMessage) throws {
        guard let configuration = message.configuration else { return }
        Lyrelog.start(configuration)
    }

    func log(level: LevelMessage, message: String, category: String?, attrs: [String: Any?]?, payload: Any?) throws {
        Lyrelog.log(level.level, message, category: category, attrs: Self.attributes(attrs),
                    payload: payload.map(Self.value))
    }

    func setUser(id: String?) throws {
        Lyrelog.setUser(id)
    }

    func setConsent(consent: ConsentMessage) throws {
        Lyrelog.setConsent(consent.consent)
    }

    func screen(name: String, attrs: [String: Any?]?) throws {
        Lyrelog.screen(name, attrs: Self.attributes(attrs))
    }

    func sessionId() throws -> String? {
        Lyrelog.sessionID
    }

    /// `Lyrelog.flush()` has no deadline of its own (it honours `Retry-After`): give up waiting
    /// after `timeoutMs`; the flush itself carries on.
    func flush(timeoutMs: Int64) async throws -> Bool {
        await Self.waitAtMost(milliseconds: timeoutMs) { await Lyrelog.flush() }
    }

    /// True when `work` finished within the time, false once the time is up; `work` then carries
    /// on unawaited. (Not a task group: it waits for every child, so a flush that ignores
    /// cancellation, waiting out a long `Retry-After`, would hold the answer for its whole length.)
    static func waitAtMost(milliseconds: Int64, _ work: @escaping @Sendable () async -> Void) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let answer = Once(continuation)
            let timer = Task {
                try? await Task.sleep(nanoseconds: UInt64(max(milliseconds, 0)) * 1_000_000)
                answer.resume(false)
            }
            Task {
                await work()
                answer.resume(true)
                timer.cancel()
            }
        }
    }

    func stop() async throws {
        await Lyrelog.stop()
    }

    // MARK: - Values from the channel

    static func attributes(_ raw: [String: Any?]?) -> [String: Lyrelog.LogValue] {
        guard let raw else { return [:] }
        var out: [String: Lyrelog.LogValue] = [:]
        for (key, value) in raw { out[key] = Self.value(value) }
        return out
    }

    /// The standard codec hands numbers and booleans over as `NSNumber`: a boolean is told
    /// apart by its CoreFoundation type, a double by its encoding.
    static func value(_ raw: Any?) -> Lyrelog.LogValue {
        guard let raw else { return .null }
        switch raw {
        case is NSNull:
            return .null
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            let type = String(cString: number.objCType)
            if type == "d" || type == "f" { return .double(number.doubleValue) }
            return .int(number.intValue)
        case let string as String:
            return .string(string)
        case let list as [Any?]:
            return .array(list.map(Self.value))
        case let map as [AnyHashable: Any?]:
            var out: [String: Lyrelog.LogValue] = [:]
            for (key, value) in map { out[String(describing: key.base)] = Self.value(value) }
            return .object(out)
        default:
            return .string(String(describing: raw))
        }
    }
}

/// Resumes a continuation once, whichever side comes first.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Bool) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}

extension StartMessage {
    /// This package's name and version (pubspec.yaml), named in `resource.sdk` before the Swift
    /// SDK's: `lyrelog-flutter/0.9.0 lyrelog-swift/0.9.0`.
    static let wrapper = "lyrelog-flutter/0.9.0"

    /// The Swift SDK's configuration, or nil for an endpoint that isn't a URL (nothing starts:
    /// it must not fall back to another address).
    var configuration: Lyrelog.Configuration? {
        guard let url = URL(string: endpoint) else { return nil }
        var configuration = Lyrelog.Configuration(
            endpoint: url,
            apiKey: apiKey,
            consent: consent.consent,
            minimumLevel: minimumLevel.level,
            mirrorToOSLog: mirrorToConsole,
            uploadInterval: .milliseconds(flushIntervalMs),
            pauseUploadsInLowPowerMode: pauseUploadsInLowPowerMode,
            maxBatchBytes: Int(maxBatchBytes),
            maxBatchEvents: Int(maxBatchEvents),
            maxDiskBytes: Int(maxDiskBytes),
            maxEventAge: .milliseconds(maxEventAgeMs),
            sessionTimeout: .milliseconds(sessionTimeoutMs),
            captureDiagnostics: captureNativeCrashes,
            attachScreen: attachScreen,
            environment: environment,
            platform: platform,
            redactedKeys: redactedKeys,
            appAttest: attest
        )
        configuration.wrapper = Self.wrapper
        return configuration
    }
}

extension LevelMessage {
    var level: Lyrelog.LogLevel {
        switch self {
        case .trace: .trace
        case .debug: .debug
        case .info: .info
        case .notice: .notice
        case .warning: .warning
        case .error: .error
        case .critical: .critical
        }
    }
}

extension ConsentMessage {
    var consent: Lyrelog.Consent {
        switch self {
        case .pending: .pending
        case .granted: .granted
        case .denied: .denied
        }
    }
}
