import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Programu na kifaa kinachotumika: kinatumwa kwa kila ombi (X-Client / X-Device) ili kumbukumbu za
/// vitendo (audit) zionyeshe kama kazi ilifanywa kwa app au web, na kwa kifaa gani.
class ClientInfo {
  ClientInfo._();

  /// web / android / ios / windows / macos / linux
  static String client = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

  /// mf. "Samsung SM-A515F | Android 13" (web: server inasoma browser kutoka User-Agent)
  static String device = '';

  static Map<String, String> get headers => {
        'X-Client': client,
        if (device.isNotEmpty) 'X-Device': device,
      };

  /// Headers za HTTP ni ASCII tu.
  static String _ascii(String v) => v.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      final info = DeviceInfoPlugin();
      String label;
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final a = await info.androidInfo;
          final brand = a.manufacturer.isEmpty ? '' : '${a.manufacturer[0].toUpperCase()}${a.manufacturer.substring(1)} ';
          label = '$brand${a.model} | Android ${a.version.release}';
        case TargetPlatform.iOS:
          final i = await info.iosInfo;
          label = '${i.utsname.machine} | iOS ${i.systemVersion}';
        case TargetPlatform.windows:
          final w = await info.windowsInfo;
          label = '${w.computerName} | ${w.productName}';
        case TargetPlatform.macOS:
          final m = await info.macOsInfo;
          label = '${m.model} | macOS ${m.osRelease}';
        case TargetPlatform.linux:
          final l = await info.linuxInfo;
          label = l.prettyName;
        default:
          label = '';
      }
      device = _ascii(label);
      if (device.length > 120) device = device.substring(0, 120);
    } catch (_) {
      device = '';
    }
  }
}
