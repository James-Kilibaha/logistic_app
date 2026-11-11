import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';

/// Inahifadhi mistari ya sahihi na kuigeuza kuwa PNG.
class SignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  List<List<Offset>> get strokes => _strokes;

  bool get isEmpty => _strokes.every((s) => s.length < 2);

  void _start(Offset p) {
    _strokes.add([p]);
    notifyListeners();
  }

  void _add(Offset p) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(p);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// PNG yenye mandharinyuma meupe (`null` kama hakuna sahihi).
  Future<Uint8List?> toPng({double pixelRatio = 2}) async {
    if (isEmpty || _size.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    canvas.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
    _SignaturePainter.paintStrokes(canvas, _strokes, Colors.black);
    final image = await recorder
        .endRecording()
        .toImage((_size.width * pixelRatio).round(), (_size.height * pixelRatio).round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}

/// Eneo la kusaini kwa kidole (simu) au kipanya (kompyuta).
class SignaturePad extends StatelessWidget {
  final SignatureController controller;
  final double height;

  const SignaturePad({super.key, required this.controller, this.height = 170});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: LayoutBuilder(builder: (context, c) {
          controller._size = Size(c.maxWidth, c.maxHeight);
          return Stack(
            children: [
              Positioned(
                left: 16,
                right: 16,
                bottom: 34,
                child: Container(height: 1, color: const Color(0xFFCBD5E1)),
              ),
              Positioned(
                left: 16,
                bottom: 12,
                child: Text('signHere'.tr, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ),
              // EagerGestureRecognizer inashinda mara moja: ukurasa hausogei wakati wa kusaini.
              RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                    (_) {},
                  ),
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => controller._start(e.localPosition),
                  onPointerMove: (e) => controller._add(e.localPosition),
                  child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                      painter: _SignaturePainter(controller.strokes),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => controller.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'clear'.tr,
                          onPressed: controller.clear,
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                        ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _SignaturePainter(this.strokes);

  static void paintStrokes(Canvas canvas, List<List<Offset>> strokes, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (int i = 1; i < s.length - 1; i++) {
        final mid = Offset((s[i].dx + s[i + 1].dx) / 2, (s[i].dy + s[i + 1].dy) / 2);
        path.quadraticBezierTo(s[i].dx, s[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(s.last.dx, s.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) => paintStrokes(canvas, strokes, const Color(0xFF0F172A));

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
