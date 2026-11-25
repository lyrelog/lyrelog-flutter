## 1.0.3

- No change: released in step with `lyrelog` 1.0.3.

## 1.0.2

- No change: released in step with `lyrelog` 1.0.2.

## 1.0.1

- Over the Lyrelog Swift SDK from 1.1.1 (crashes caught in the app's own process, sent on the next
  launch) up to (not including) 2.0.0.

## 1.0.0

- The iOS side of `lyrelog` 1.0.0, over the Lyrelog Swift SDK from 1.0.0 up to (not including)
  2.0.0. Nothing else changed since 0.9.0.

## 0.9.0

- The iOS side of `lyrelog` 0.9.0, over the Lyrelog Swift SDK 0.9.0 (`@_spi(Wrapper) import
  Lyrelog`; the wrapper name is set on the configuration). Calls arrive on one serial background
  queue, not on the main thread. Flutter 3.44 or newer, with Swift Package Manager on.

## 0.1.0

- First version: the iOS side of `lyrelog` 0.1.0, over the Lyrelog Swift SDK 0.1.0, built with
  Swift Package Manager. `flush` answers when its time is up, even while the flush goes on.
