# Lantern

A made-up reading app that shows the lyrelog plugin: events from an area logger, screens from
`LyrelogNavigatorObserver`, a handled error, a Flutter error thrown while building, an async
error nobody catches, a flush and the consent choice.

Put a key and an endpoint in `lyrelog.local.json` (never committed):

```json
{"LYRELOG_KEY": "lyr_ing_...", "LYRELOG_ENDPOINT": "http://127.0.0.1:8090"}
```

and run `flutter run --dart-define-from-file=lyrelog.local.json`. On the Android emulator the
endpoint is `http://10.0.2.2:8090` (your computer). `--dart-define=LYRELOG_TOUR=true` presses
every button once after launch.
