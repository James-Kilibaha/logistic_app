import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'layout.dart';

/// Rangi za chati (zinafanana na za ripoti za PDF).
const List<Color> chartPalette = [
  Color(0xFF1F4FD8),
  Color(0xFF16A34A),
  Color(0xFFF59E0B),
  Color(0xFFDC2626),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFDB2777),
  Color(0xFF65A30D),
  Color(0xFFEA580C),
  Color(0xFF475569),
];

class ChartSlice {
  final String label;
  final double value;
  final Color? color;

  const ChartSlice(this.label, this.value, [this.color]);
}

/// Inageuza ramani (jina -> thamani) kuwa vipande, vikubwa kwanza; zaidi ya [max] vinaunganishwa "Nyingine".
List<ChartSlice> slicesFrom(Map<String, double> data, {int max = 7, String Function(String)? label}) {
  final entries = data.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
  final out = <ChartSlice>[
    for (final e in entries.take(max)) ChartSlice(label?.call(e.key) ?? e.key, e.value),
  ];
  if (entries.length > max) {
    out.add(ChartSlice('chartOther'.tr, entries.skip(max).fold<double>(0, (s, e) => s + e.value)));
  }
  return out;
}

/// Kadi ya pie (donut) chart yenye maelezo (legend) ya kila kipande na asilimia.
class PieChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<ChartSlice> slices;
  final String Function(double value)? format;
  final VoidCallback? onTap;

  const PieChartCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.pie_chart_outline_rounded,
    required this.slices,
    this.format,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = slices.where((s) => s.value > 0).toList();
    final total = items.fold<double>(0, (s, e) => s + e.value);
    final fmt = format ?? Fmt.compact;
    Color colorOf(int i) => items[i].color ?? chartPalette[i % chartPalette.length];

    final Widget content = items.isEmpty
        ? SizedBox(height: 150, child: Center(child: Text('noData'.tr, style: TextStyle(color: p.muted))))
        : LayoutBuilder(builder: (context, c) {
            final bool row = c.maxWidth >= 360;
            final donut = SizedBox(
              width: 150,
              height: 150,
              child: CustomPaint(
                painter: _DonutPainter([for (int i = 0; i < items.length; i++) (items[i].value, colorOf(i))], p.surface),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fmt(total), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.text)),
                      Text('total'.tr, style: TextStyle(fontSize: 11, color: p.muted)),
                    ],
                  ),
                ),
              ),
            );
            final legend = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: colorOf(i), borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(items[i].label,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        Text(fmt(items[i].value),
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.text, fontSize: 12.5)),
                        SizedBox(
                          width: 52,
                          child: Text(
                            '${(items[i].value / total * 100).toStringAsFixed(1)}%',
                            textAlign: TextAlign.end,
                            style: TextStyle(color: p.muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
            if (row) {
              return Row(children: [donut, const SizedBox(width: 18), Expanded(child: legend)]);
            }
            return Column(children: [donut, const SizedBox(height: 14), legend]);
          });

    final card = SectionCard(title: title, subtitle: subtitle, icon: icon, child: content);
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: card);
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> parts;
  final Color gap;

  _DonutPainter(this.parts, this.gap);

  @override
  void paint(Canvas canvas, Size size) {
    final total = parts.fold<double>(0, (s, e) => s + e.$1);
    if (total <= 0) return;
    final double stroke = size.shortestSide * .18;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - stroke / 2);
    double start = -math.pi / 2;
    for (final (value, color) in parts) {
      final sweep = value / total * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color;
      canvas.drawArc(rect, start, sweep, false, paint);
      if (parts.length > 1) {
        final sep = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke + 1
          ..color = gap;
        canvas.drawArc(rect, start + sweep - 0.008, 0.016, false, sep);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.parts != parts || old.gap != gap;
}

class BarSeries {
  final String name;
  final List<double> values;
  final Color? color;

  const BarSeries(this.name, this.values, [this.color]);
}

/// Chati ya nguzo (bars) kwa makundi - mf. kwa mwezi: iliyotozwa / malipo / matumizi.
class GroupedBarChart extends StatelessWidget {
  final List<String> labels;
  final List<BarSeries> series;
  final double height;
  final String Function(double value)? format;

  const GroupedBarChart({super.key, required this.labels, required this.series, this.height = 220, this.format});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fmt = format ?? Fmt.compact;
    double max = 0;
    for (final s in series) {
      for (final v in s.values) {
        if (v > max) max = v;
      }
    }
    if (labels.isEmpty || max <= 0) {
      return SizedBox(height: height, child: Center(child: Text('noData'.tr, style: TextStyle(color: p.muted))));
    }
    Color colorOf(int i) => series[i].color ?? chartPalette[i % chartPalette.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (int i = 0; i < series.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: colorOf(i), borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text(series[i].name, style: TextStyle(color: p.text, fontSize: 12.5)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int k = 0; k < labels.length; k++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (int i = 0; i < series.length; i++)
                                Expanded(
                                  child: Tooltip(
                                    message: '${labels[k]} · ${series[i].name}: '
                                        '${fmt(k < series[i].values.length ? series[i].values[k] : 0)}',
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 1),
                                      child: FractionallySizedBox(
                                        heightFactor: ((k < series[i].values.length ? series[i].values[k] : 0) / max)
                                            .clamp(0.01, 1.0)
                                            .toDouble(),
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: colorOf(i),
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(labels[k],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: p.muted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
