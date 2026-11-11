
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide Phone;
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../session.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'feedback.dart';

/// Simu (Android / iOS) - ina kamera na skana. Kwenye web ni `false`.
bool get isMobileDevice =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Skana ya kamera inapatikana: simu (app) na web (browser yoyote yenye kamera: simu au laptop).
/// Kwenye web kamera inahitaji https (au localhost wakati wa develop).
bool get canScanWithCamera => isMobileDevice || kIsWeb;

/// Picha iliyochaguliwa (bytes + jina) - inafanya kazi kwenye web na simu.
class PickedImage {
  final Uint8List bytes;
  final String name;

  const PickedImage(this.bytes, this.name);
}

// ------------------------------------------------------------------ picha

/// Picha ndogo ya bidhaa (kutoka kwenye server). Ukiibonyeza inafunguka kubwa.
class ProductThumb extends StatelessWidget {
  final String? path;
  final double size;
  final double radius;

  const ProductThumb(this.path, {super.key, this.size = 52, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final url = Session.imageUrl(path);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(radius)),
      child: Icon(Icons.inventory_2_outlined, color: p.muted, size: size * .45),
    );
    if (url == null) return placeholder;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: () => Get.to(() => ImageViewerPage(url: url), transition: Transition.fadeIn),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: url,
          cacheKey: url.split('?').first, // tokeni hubadilika; picha ni ileile
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: (size * 3).round(),
          placeholder: (_, __) => placeholder,
          errorWidget: (_, __, ___) => placeholder,
        ),
      ),
    );
  }
}

class ImageViewerPage extends StatelessWidget {
  final String url;

  const ImageViewerPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: const Border(),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: CachedNetworkImage(
            imageUrl: url,
          cacheKey: url.split('?').first, // tokeni hubadilika; picha ni ileile
            fit: BoxFit.contain,
            placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}

/// Kuchagua picha: kamera (simu) au faili / gallery (web).
Future<PickedImage?> pickImage({bool camera = true}) async {
  try {
    final source = camera && isMobileDevice ? ImageSource.camera : ImageSource.gallery;
    final XFile? file = await ImagePicker().pickImage(source: source, imageQuality: 72, maxWidth: 1600);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    var name = file.name;
    final lower = name.toLowerCase();
    if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png'))) {
      name = '$name.jpg'; // backend inakubali .jpg/.jpeg/.png tu
    }
    return PickedImage(bytes, name);
  } catch (e) {
    Toast.error(e);
    return null;
  }
}

// --------------------------------------------------------------------- PDF

/// Inapakua PDF (ikionyesha "inapakia...") kisha inaifungua. Kosa linaonyeshwa kama toast.
Future<void> openPdfFrom(
  Future<Uint8List> Function() load, {
  required String title,
  required String fileName,
}) async {
  final ctx = Get.overlayContext ?? Get.context;
  bool shown = false;
  if (ctx != null) {
    shown = true;
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(22), child: CircularProgressIndicator()))),
    );
  }
  try {
    final bytes = await load();
    if (shown) Get.back<void>();
    shown = false;
    await PdfViewerPage.open(title: title, bytes: bytes, fileName: fileName);
  } catch (e) {
    if (shown) Get.back<void>();
    Toast.error(e);
  }
}

/// Kuonyesha PDF (invoice / ripoti) pamoja na kuhifadhi na kushiriki.
class PdfViewerPage extends StatelessWidget {
  final String title;
  final Uint8List bytes;
  final String fileName;

  const PdfViewerPage({super.key, required this.title, required this.bytes, required this.fileName});

  static Future<void> open({required String title, required Uint8List bytes, required String fileName}) async {
    await Get.to(() => PdfViewerPage(title: title, bytes: bytes, fileName: fileName));
  }

  Future<void> _save() async {
    try {
      final path = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      Toast.success(kIsWeb ? '$fileName.pdf' : path, title: 'savedTo'.tr);
    } catch (e) {
      Toast.error(e);
    }
  }

  Future<void> _share() async {
    try {
      final file = XFile.fromData(bytes, name: '$fileName.pdf', mimeType: 'application/pdf');
      // ignore: deprecated_member_use
      await Share.shareXFiles([file], subject: title, fileNameOverrides: ['$fileName.pdf']);
    } catch (e) {
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(tooltip: 'save'.tr, onPressed: _save, icon: const Icon(Icons.download_rounded)),
          if (isMobileDevice)
            IconButton(tooltip: 'share'.tr, onPressed: _share, icon: const Icon(Icons.share_rounded)),
          const SizedBox(width: 6),
        ],
      ),
      body: SfPdfViewer.memory(bytes),
    );
  }
}

// --------------------------------------------------------------------- skana

/// Matokeo ya ScannerPage mtumiaji akichagua kuandika code badala ya kamera.
const String _typeInstead = '\u0000type';

/// Kusoma barcode/QR. Simu na web: kamera (na kitufe cha kuandika kwa mkono).
/// App ya kompyuta (Windows/Linux): kuandika (au skana ya USB inayoandika kama kibodi).
Future<String?> scanCode({String? title}) async {
  if (canScanWithCamera) {
    final result = await Get.to<String>(() => ScannerPage(title: title ?? 'scanCode'.tr));
    if (result != _typeInstead) {
      return (result == null || result.trim().isEmpty) ? null : result.trim();
    }
  }
  return _typeCode(title);
}

/// Kuandika code kwa mkono (au skana ya USB inayoandika kama kibodi).
Future<String?> _typeCode(String? title) async {
  final ctx = Get.overlayContext ?? Get.context;
  if (ctx == null) return null;
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: ctx,
    builder: (context) => AlertDialog(
      title: Text(title ?? 'scanCode'.tr),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'scanOrType'.tr,
            prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel'.tr)),
        FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: Text('ok'.tr)),
      ],
    ),
  );
  controller.dispose();
  return (value == null || value.trim().isEmpty) ? null : value.trim();
}

class ScannerPage extends StatefulWidget {
  final String title;

  const ScannerPage({super.key, required this.title});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final code in capture.barcodes) {
      final value = code.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _done = true;
        Get.back(result: value.trim());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: const Border(),
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'typeCodeInstead'.tr,
            onPressed: () {
              _done = true;
              Get.back(result: _typeInstead);
            },
            icon: const Icon(Icons.keyboard_alt_outlined),
          ),
          if (isMobileDevice) // tochi haipo kwenye kamera nyingi za kompyuta
            IconButton(
              tooltip: 'torch'.tr,
              onPressed: () => _controller.toggleTorch(),
              icon: const Icon(Icons.flashlight_on_rounded),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'scanHint'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 12),
                // Kamera ikikataa (hakuna kamera / ruhusa imekataliwa / http): andika code kwa mkono
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: () {
                    _done = true;
                    Get.back(result: _typeInstead);
                  },
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: Text('typeCodeInstead'.tr),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- simu

Future<void> callPhone(String phone) async {
  if (phone.trim().isEmpty) {
    Toast.info('noPhoneNumber'.tr);
    return;
  }
  final uri = Uri(scheme: 'tel', path: Phone.normalize(phone) ?? phone.replaceAll(' ', ''));
  try {
    await launchUrl(uri);
  } catch (e) {
    Toast.error(e);
  }
}

/// Kupakua ZIP (mf. data yote ya kampuni): web linapakuliwa; simu linahifadhiwa.
/// Inaonyesha "inaandaliwa..." kwa sababu inaweza kuchukua muda (picha nyingi).
Future<void> saveZip(Future<Uint8List> Function() load, String name) async {
  Toast.info('exportPreparing'.tr);
  try {
    final bytes = await load();
    final path = await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: 'zip',
      mimeType: MimeType.other,
    );
    Toast.success(kIsWeb ? '$name.zip' : path, title: 'savedTo'.tr);
  } catch (e) {
    Toast.error(e);
  }
}
