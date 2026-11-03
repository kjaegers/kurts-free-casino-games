{{flutter_js}}
{{flutter_build_config}}

// Offline-first (CLAUDE.md section 2): every font the app needs is bundled
// (see pubspec.yaml), so the engine must never fetch fallback fonts from
// Google's font CDN. Pointing the fallback base URL at the app's own origin
// keeps any lookup for a glyph we don't ship local; it simply 404s.
// CanvasKit itself is self-hosted by building with --no-web-resources-cdn.
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    fontFallbackBaseUrl: "assets/fonts/fallback/",
  },
});
