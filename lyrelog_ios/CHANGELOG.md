## 0.9.0

- The iOS side of `lyrelog` 0.9.0, over the Lyrelog Swift SDK 0.9.0 (`@_spi(Wrapper) import
  Lyrelog`; the wrapper name is set on the configuration). Calls arrive on one serial background
  queue, not on the main thread. Flutter 3.44 or newer, with Swift Package Manager on.

## 0.1.0

- First version: the iOS side of `lyrelog` 0.1.0, over the Lyrelog Swift SDK 0.1.0, built with
  Swift Package Manager. `flush` answers when its time is up, even while the flush goes on.
