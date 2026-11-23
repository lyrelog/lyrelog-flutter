import Flutter
@_spi(Wrapper) import Lyrelog
import Testing
import UIKit

@testable import lyrelog_ios

// The values the standard codec hands over, as the Swift SDK's LogValue.
struct RunnerTests {
  @Test func booleansNumbersAndTextKeepTheirKind() {
    #expect(LyrelogIosPlugin.value(NSNumber(value: true)) == .bool(true))
    #expect(LyrelogIosPlugin.value(NSNumber(value: 7)) == .int(7))
    #expect(LyrelogIosPlugin.value(NSNumber(value: 12.5)) == .double(12.5))
    #expect(LyrelogIosPlugin.value("b_12") == .string("b_12"))
    #expect(LyrelogIosPlugin.value(nil) == .null)
    #expect(LyrelogIosPlugin.value(NSNull()) == .null)
  }

  @Test func listsAndMapsNest() {
    let raw: [String: Any?] = ["tags": ["a", NSNumber(value: false)], "nested": ["depth": NSNumber(value: 2)]]
    #expect(LyrelogIosPlugin.attributes(raw) == [
      "tags": .array([.string("a"), .bool(false)]),
      "nested": .object(["depth": .int(2)]),
    ])
  }

  @Test func anEndpointThatIsNotAURLStartsNothing() {
    let message = StartMessage(
      apiKey: "lyr_ing_test", endpoint: "", consent: .granted, minimumLevel: .debug,
      flushIntervalMs: 15000, maxBatchBytes: 524288, maxBatchEvents: 500, maxDiskBytes: 20971520,
      maxEventAgeMs: 604_800_000, sessionTimeoutMs: 1_800_000, captureNativeCrashes: true,
      attachScreen: true, attest: true, mirrorToConsole: false, pauseUploadsInLowPowerMode: true)
    #expect(message.configuration == nil)
    var good = message
    good.endpoint = "http://127.0.0.1:8090"
    #expect(good.configuration?.endpoint.absoluteString == "http://127.0.0.1:8090")
    #expect(good.configuration?.uploadInterval == .seconds(15))
  }

  /// The Swift SDK names this package before itself in `resource.sdk`.
  @Test func theConfigurationNamesThisPackage() {
    let message = StartMessage(
      apiKey: "lyr_ing_test", endpoint: "https://ingest.lyrelog.com", consent: .pending,
      minimumLevel: .warning, flushIntervalMs: 15000, maxBatchBytes: 524288, maxBatchEvents: 500,
      maxDiskBytes: 20971520, maxEventAgeMs: 604_800_000, sessionTimeoutMs: 1_800_000,
      captureNativeCrashes: true, attachScreen: true, attest: true, mirrorToConsole: false,
      pauseUploadsInLowPowerMode: true)
    let configuration = message.configuration
    #expect(configuration?.wrapper == "lyrelog-flutter/1.0.0")
    #expect(configuration?.consent == .pending)
    #expect(configuration?.minimumLevel == Lyrelog.LogLevel.warning)
  }

  /// `flush(timeoutMs:)` must answer once its time is up, even when the flush goes on (one
  /// honouring a long Retry-After ignores cancellation).
  @Test func waitingGivesUpWhenTheTimeIsUp() async {
    let started = ContinuousClock.now
    let finished = await LyrelogIosPlugin.waitAtMost(milliseconds: 100) {
      let until = ContinuousClock.now + .seconds(3)
      while ContinuousClock.now < until { usleep(10_000) }
    }
    #expect(!finished)
    #expect(ContinuousClock.now - started < .seconds(1))
    #expect(await LyrelogIosPlugin.waitAtMost(milliseconds: 2_000) {})
  }
}
