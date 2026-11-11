import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/media.dart';
import '../../data/models/box.dart';
import '../../data/repositories.dart';

/// Kuburuta (drag) mzigo kwenda kwenye box.
///
/// - Kompyuta / web: shika na uburute moja kwa moja.
/// - Simu: bonyeza kwa muda (long-press) kisha uburute - ili kusogeza orodha kubaki kawaida.
///
/// Ukiburuta mzigo uliochaguliwa pamoja na mingine, mizigo yote iliyochaguliwa inaenda pamoja.
class DraggableCargo extends StatelessWidget {
  final BoxProduct product;
  final List<BoxProduct> group;
  final Widget child;

  const DraggableCargo({super.key, required this.product, required this.child, this.group = const []});

  List<BoxProduct> get _payload => group.length > 1 && group.any((g) => g.id == product.id) ? group : [product];

  @override
  Widget build(BuildContext context) {
    final feedback = _DragFeedback(products: _payload);
    final faded = Opacity(opacity: .35, child: child);
    if (isMobileDevice) {
      return LongPressDraggable<List<BoxProduct>>(
        data: _payload,
        feedback: feedback,
        childWhenDragging: faded,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        child: child,
      );
    }
    return Draggable<List<BoxProduct>>(
      data: _payload,
      feedback: feedback,
      childWhenDragging: faded,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: child),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  final List<BoxProduct> products;

  const _DragFeedback({required this.products});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = products.first;
    final double kg = products.fold<double>(0, (s, e) => s + e.weight);
    return Transform.translate(
      offset: const Offset(-24, -24),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.primary, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              ProductThumb(first.path, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      products.length > 1 ? '${products.length} ${'items'.tr}' : first.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: p.text, fontSize: 14),
                    ),
                    Text(Fmt.kg(kg), style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.open_with_rounded, color: p.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eneo la kudondoshea mzigo (box). [builder] inapata hali: `hovering` na `rejected`
/// (mzigo wa usafiri mwingine - mf. mzigo wa meli kwenye box la ndege).
class BoxDropTarget extends StatelessWidget {
  final Box box;
  final Widget Function(BuildContext context, bool hovering, bool rejected) builder;
  final VoidCallback? onDropped;

  const BoxDropTarget({super.key, required this.box, required this.builder, this.onDropped});

  @override
  Widget build(BuildContext context) {
    if (!box.isOpen) return builder(context, false, false);
    return DragTarget<List<BoxProduct>>(
      onWillAcceptWithDetails: (details) => details.data.every((p) => box.accepts(p.carrierType)),
      onAcceptWithDetails: (details) async {
        final ok = await dropCargo(box, details.data);
        if (ok) onDropped?.call();
      },
      builder: (context, candidates, rejected) =>
          builder(context, candidates.isNotEmpty, rejected.isNotEmpty),
    );
  }
}

/// Kuweka mizigo kwenye box (inatumika na drag & drop na kitufe cha "Weka kwenye box").
Future<bool> dropCargo(Box box, List<BoxProduct> products) async {
  final wrong = products.where((p) => !box.accepts(p.carrierType)).toList();
  if (wrong.isNotEmpty) {
    Toast.warning(box.isContainer ? 'containerHint'.tr : 'airBoxHint'.tr, title: 'wrongCarrier'.tr);
    return false;
  }
  int added = 0;
  try {
    for (final product in products) {
      await BoxRepo.addProduct(box.id, product);
      added++;
    }
    Toast.success(
      'droppedInBoxMsg'.trParams({'n': '$added', 'box': box.boxId}),
      title: 'addedToBox'.tr,
    );
    return true;
  } catch (e) {
    Toast.error(e);
    return added > 0;
  } finally {
    if (added > 0) AppController.to.notifyChanged();
  }
}

/// Mapambo ya eneo la kudondoshea (mpaka wa rangi + ujumbe).
class DropHighlight extends StatelessWidget {
  final bool hovering;
  final bool rejected;
  final Widget child;
  final double radius;

  const DropHighlight({
    super.key,
    required this.hovering,
    required this.rejected,
    required this.child,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color? color = rejected ? p.danger : (hovering ? p.primary : null);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius + 2),
        border: Border.all(color: color ?? Colors.transparent, width: 2.5),
        color: color?.withValues(alpha: .06),
      ),
      child: Stack(
        children: [
          child,
          if (color != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      rejected ? 'wrongCarrier'.tr : 'dropHere'.tr,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
