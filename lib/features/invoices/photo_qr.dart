import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/app_controller.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/media.dart';
import '../../data/models/invoice.dart';
import '../../data/repositories.dart';

/// QR yenye code ya ofisi: app ya simu inaiskani ili kupiga picha ya mzigo huo.
class OfficeCodeQr extends StatelessWidget {
  final String code;
  final double size;

  const OfficeCodeQr(this.code, {super.key, this.size = 112});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (code.trim().isEmpty) return SizedBox(width: size, height: size);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white, // QR lazima iwe na mandhari meupe hata kwenye dark mode
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border),
          ),
          // SizedBox: QrImageView inatumia LayoutBuilder (haikubali vipimo vya "intrinsic" vya dialog)
          child: SizedBox(
            width: size,
            height: size,
            child: QrImageView(data: code.trim().toUpperCase(), size: size, padding: EdgeInsets.zero),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: size + 12,
          child: Text(
            'scanForPhoto'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Kuuliza server kila sekunde 3 kama simu imepakia picha ya code hii.
class PhotoWatcher {
  final String Function() code;
  final void Function(Map<String, dynamic> status) onChange;
  Timer? _timer;
  String _last = '';

  PhotoWatcher({required this.code, required this.onChange});

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  Future<void> _tick() async {
    final c = code().trim();
    if (c.length < 4) return;
    try {
      final s = await PhotoRepo.status(c);
      final sig = '${s['path']}|${s['staged']}|${s['stagedAt']}';
      if (sig != _last) {
        final first = _last.isEmpty;
        _last = sig;
        if (!first || s['staged'] == true) onChange(s);
      }
    } catch (_) {
      // kimya - inajaribu tena
    }
  }

  void stop() => _timer?.cancel();
}

/// Ukurasa wa ankara (web): QR ya mzigo uliopo ili kuongeza/kubadilisha picha kwa simu.
Future<void> showProductPhotoQr(Product product) async {
  final code = product.officeCode ?? '';
  if (code.isEmpty) return;
  final ctx = Get.overlayContext ?? Get.context;
  if (ctx == null) return;
  String? path = product.path;
  StateSetter? refresh;
  final watcher = PhotoWatcher(
    code: () => code,
    onChange: (s) {
      final newPath = s['path']?.toString();
      if (newPath != null && newPath != path) {
        path = newPath;
        refresh?.call(() {});
        Toast.success(product.description, title: 'photoFromPhone'.tr);
      }
    },
  )..start();
  await showDialog<void>(
    context: ctx,
    builder: (context) => StatefulBuilder(builder: (context, setState) {
      refresh = setState;
      final p = context.palette;
      final url = Session.imageUrl(path);
      // Dialog (si AlertDialog): AlertDialog inapima upana kwa IntrinsicWidth, jambo ambalo QR haikubali
      // na lilikuwa linasimamisha ukurasa kwenye web.
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('photoByPhone'.tr, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(product.description, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${'officeCode'.tr}: $code', style: TextStyle(color: p.muted)),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  OfficeCodeQr(code, size: 150),
                  Container(
                    width: 120,
                    height: 120,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    child: url == null
                        ? Icon(Icons.image_outlined, color: p.muted, size: 36)
                        : Image.network(url, fit: BoxFit.cover, key: ValueKey(url)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('photoByPhoneHint'.tr, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('close'.tr)),
              ),
            ],
          ),
          ),
        ),
      );
    }),
  );
  watcher.stop();
  if (path != product.path) AppController.to.notifyChanged();
}

/// Simu: skani QR (ya skrini ya web au ya lebo), piga picha, ipakie kwenye mzigo huo. Inaweza kurudiwa.
Future<void> photoByQr() async {
  while (true) {
    final code = await scanCode(title: 'scanForPhoto'.tr);
    if (code == null) return;
    final picked = await pickImage(camera: true);
    if (picked == null) return;
    Map<String, dynamic>? result;
    final ok = await runGuarded(() async {
      result = await PhotoRepo.upload(code, Uint8List.fromList(picked.bytes), picked.name);
    });
    if (!ok) return;
    final r = result ?? const {};
    if (r['attached'] == true) {
      Toast.success('${r['description'] ?? ''} · #${r['invoiceNumber'] ?? ''}', title: 'photoSaved'.tr);
      AppController.to.notifyChanged();
    } else {
      Toast.success('photoWaitingForSave'.trParams({'code': code}), title: 'photoSent'.tr);
    }
    final again = await confirmAction(
      title: 'photoAnother'.tr,
      message: 'photoAnotherMsg'.tr,
      confirmText: 'scanCode'.tr,
      icon: Icons.photo_camera_outlined,
    );
    if (!again) return;
  }
}
