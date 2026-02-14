# basttrafik

Interaktiv busskarta över Göteborg.

## Departures fetching by platform

This app now uses different departure-fetching strategies per platform:

- **Desktop/mobile (IO runtimes):** calls `scripts/fetch_departures_bridge.py`, which loads `basttrafik/src/*.py` and fetches departures through Python.
- **Web (Chrome, etc.):** calls `GET /api/departures?stop=<stopName>` from the same origin.

### Why departures failed in Chrome

Chrome runs the Flutter **web** target, where `Process.run(...)` and `dart:io` are not available. A service implemented only with `dart:io` will always fail on web when trying to fetch departures.

To make departures work in web deployments, provide a backend route at `/api/departures` that returns the same JSON shape as the Python bridge.
