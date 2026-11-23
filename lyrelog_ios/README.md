# lyrelog_ios

The iOS implementation of the [`lyrelog`](https://pub.dev/packages/lyrelog) Flutter plugin, over the Lyrelog Swift
SDK. Don't depend on it directly: `lyrelog` brings it.

It is a package of its own because Flutter names a plugin's Swift module after its package, and
a module `lyrelog` next to the Swift SDK's `Lyrelog` collides on a case-insensitive disk.
