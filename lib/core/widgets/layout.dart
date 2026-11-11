import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../branding.dart';
import '../theme/app_theme.dart';
import 'brand_logo.dart';
import 'help.dart';

/// Kitendo kikuu cha ukurasa (mf. "Mteja mpya").
/// Kwenye kompyuta kinakaa juu kulia; kwenye simu kinakuwa kitufe kinachoelea (FAB).
class PageAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const PageAction({required this.icon, required this.label, required this.onPressed});
}

/// Ukurasa wenye kichwa, vitendo na maudhui - unajipanga kufuatana na upana wa skrini.
class AppPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final PageAction? mainAction;
  final Widget body;
  final PreferredSizeWidget? bottom;

  /// Kurasa zinazofunguliwa juu ya nyingine (maelezo ya invoice, box ...).
  final bool showBack;

  /// Mada ya msaada (core/help/help_content.dart) - inaongeza kitufe cha "?" juu.
  final String? help;

  /// Kitendo cha kila ukurasa mkuu (mf. kengele ya taarifa) - kinawekwa na shell.
  static Widget Function()? globalAction;

  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.mainAction,
    required this.body,
    this.bottom,
    this.showBack = false,
    this.help,
  });

  /// Title ya browser / app switcher: "Ukurasa · Jina la kampuni".
  @override
  Widget build(BuildContext context) {
    final company = Get.isRegistered<BrandingController>() ? BrandingController.to.current.value.displayName : '';
    final label = company.isEmpty || title == company ? title : '$title · $company';
    return Title(title: label, color: context.palette.primary, child: _page(context));
  }

  Widget _page(BuildContext context) {
    final bool wide = context.isMediumUp;
    final p = context.palette;
    final actions = [
      ...this.actions,
      if (help != null) HelpButton(topic: help!),
      if (!showBack && globalAction != null) globalAction!(),
    ];

    if (!wide) {
      return Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          automaticallyImplyLeading: showBack,
          // kurasa kuu kwenye simu: logo ya kampuni kushoto (kurasa za ndani: kitufe cha kurudi)
          leading: showBack ? null : const Padding(padding: EdgeInsets.all(9), child: BrandLogo(size: 36)),
          leadingWidth: showBack ? null : 56,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, overflow: TextOverflow.ellipsis),
              if (subtitle != null)
                Text(
                  subtitle!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.muted),
                ),
            ],
          ),
          actions: [...actions, const SizedBox(width: 4)],
          bottom: bottom,
        ),
        floatingActionButton: mainAction == null
            ? null
            : FloatingActionButton.extended(
                heroTag: null,
                onPressed: mainAction!.onPressed,
                icon: Icon(mainAction!.icon),
                label: Text(mainAction!.label),
              ),
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(showBack ? 12 : 28, 18, 24, bottom == null ? 18 : 6),
                  child: Row(
                    children: [
                      if (showBack) ...[
                        IconButton(
                          tooltip: 'back'.tr,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.text),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(subtitle!, style: TextStyle(color: p.muted, fontSize: 13.5)),
                            ],
                          ],
                        ),
                      ),
                      ...actions,
                      if (mainAction != null) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: mainAction!.onPressed,
                          icon: Icon(mainAction!.icon, size: 20),
                          label: Text(mainAction!.label),
                        ),
                      ],
                    ],
                  ),
                ),
                if (bottom != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: bottom!),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Upana wa juu wa maudhui ya kurasa. `double.infinity` = maudhui yanajaza nafasi yote ya skrini (web/kompyuta).
/// Weka namba (mf. 1280) kama unataka maudhui yakae katikati kwenye skrini pana sana.
const double kContentMaxWidth = double.infinity;

/// Inaweka maudhui (yanajaza upana wote kwa chaguo-msingi; tazama [kContentMaxWidth]).
class ContentBox extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ContentBox({super.key, required this.child, this.maxWidth = kContentMaxWidth, this.padding});

  @override
  Widget build(BuildContext context) {
    final double h = context.isMediumUp ? 28 : 16;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding ?? EdgeInsets.fromLTRB(h, 20, h, 24), child: child),
      ),
    );
  }
}

/// Orodha inayosogezwa yenye upana wa juu na nafasi ya FAB chini.
class PageScroll extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double maxWidth;
  final double spacing;

  const PageScroll({super.key, required this.children, this.onRefresh, this.maxWidth = kContentMaxWidth, this.spacing = 16});

  @override
  Widget build(BuildContext context) {
    final double h = context.isMediumUp ? 28 : 16;
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(h, 20, h, context.isMediumUp ? 32 : 96),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: spacing),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Kadi yenye kichwa (si lazima) na maudhui.
class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(9)),
                      child: Icon(icon, size: 18, color: p.primary),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text)),
                        if (subtitle != null)
                          Text(subtitle!, style: TextStyle(fontSize: 12.5, color: p.muted)),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Gridi inayobadilisha idadi ya safu kufuatana na upana.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 240,
    this.spacing = 14,
    this.maxColumns = 4,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      int columns = ((c.maxWidth + spacing) / (minItemWidth + spacing)).floor();
      columns = columns.clamp(1, maxColumns).toInt();
      final double itemWidth = (c.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: itemWidth, child: child)],
      );
    });
  }
}

/// Mstari wa "kichwa: thamani" kwenye maelezo.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Widget? trailing;
  final bool emphasize;

  const InfoRow({super.key, required this.label, required this.value, this.icon, this.trailing, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: p.muted), const SizedBox(width: 10)],
          Expanded(child: Text(label, style: TextStyle(color: p.muted, fontSize: 13.5))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                fontSize: emphasize ? 15.5 : 14,
                color: p.text,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

/// Duara lenye herufi za mwanzo za jina.
class Initials extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;

  const Initials(this.text, {super.key, this.size = 40, this.color});

  static const List<Color> _colors = [
    Color(0xFF1F4FD8),
    Color(0xFF0E9F6E),
    Color(0xFFB45309),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
    Color(0xFF4F46E5),
  ];

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? _colors[text.codeUnits.fold<int>(0, (a, b) => a + b) % _colors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withValues(alpha: .14), shape: BoxShape.circle),
      child: Text(
        text,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: size * .36),
      ),
    );
  }
}

/// Lebo ndogo ya rangi (hali, aina ...).
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool dense;

  const Pill(this.text, {super.key, required this.color, this.icon, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: color), const SizedBox(width: 4)],
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: dense ? 11 : 12, height: 1.2),
          ),
        ],
      ),
    );
  }
}
