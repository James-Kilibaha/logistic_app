import 'dart:convert';
import 'dart:js_interop';

@JS('applyBranding')
external void _applyBranding(JSString json);

/// Web: inaita `window.applyBranding` (web/index.html) - favicon, theme-color, splash na title ya kampuni.
void applyWebBranding({required String name, String? logoUrl, String? primaryHex}) {
  try {
    _applyBranding(jsonEncode({'resolved': true, 'name': name, 'logoUrl': logoUrl, 'primaryColor': primaryHex}).toJS);
  } catch (_) {
    // index.html ya zamani (bila applyBranding) - hakuna tatizo
  }
}
