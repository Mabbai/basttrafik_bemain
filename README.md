# basttrafik

Interaktiv busskarta över Göteborg.

## Departures fetching by platform

This app now uses different departure-fetching strategies per platform:

- **Desktop/mobile (IO runtimes):** calls `scripts/fetch_departures_bridge.py`, which loads `basttrafik/src/*.py` and fetches departures through Python.
- **Web (Chrome, etc.):** calls `GET /api/departures?stop=<stopName>`. By default this uses the same origin, but you can point to another backend with `--dart-define=DEPARTURES_API_BASE=<origin>`.

### Why departures failed in Chrome

Chrome runs the Flutter **web** target, where `Process.run(...)` and `dart:io` are not available. A service implemented only with `dart:io` will always fail on web when trying to fetch departures.

To make departures work in web deployments, provide a backend route at `/api/departures` that returns the same JSON shape as the Python bridge.


### Debugging tip for web

If the network request returns `200` with `content-type: text/html` and an HTML page (often `index.html`), your API route is not wired and the frontend server is returning the SPA shell instead.

Use one of these:

- configure your web server/proxy so `/api/departures` goes to the backend
- or run Flutter web with `--dart-define=DEPARTURES_API_BASE=http://<backend-host>:<port>`
