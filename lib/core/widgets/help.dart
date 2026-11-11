import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../help/help_content.dart';
import '../theme/app_theme.dart';
import 'layout.dart';

/// Msaada wa mada [key] kwa lugha ya app (Kiswahili au Kiingereza).
HelpTopic? helpTopic(String key) {
  final en = Get.locale?.languageCode == 'en';
  return (en ? helpEn : helpSw)[key] ?? helpSw[key];
}

/// Kitufe cha "?" kinachofungua msaada wa ukurasa au fomu.
class HelpButton extends StatelessWidget {
  final String topic;

  const HelpButton({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    if (helpTopic(topic) == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'help'.tr,
      onPressed: () => showHelp(topic),
      icon: const Icon(Icons.help_outline_rounded),
    );
  }
}

/// Kuonyesha msaada: dirisha (kompyuta) au karatasi ya chini (simu).
Future<void> showHelp(String key) async {
  final topic = helpTopic(key);
  final ctx = Get.overlayContext ?? Get.context;
  if (topic == null || ctx == null) return;
  final bool wide = MediaQuery.sizeOf(ctx).width >= Breakpoints.medium;
  if (wide) {
    await showDialog<void>(
      context: ctx,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 620, maxHeight: MediaQuery.sizeOf(context).height * .88),
          child: _HelpView(topic: topic, asDialog: true),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
        child: _HelpView(topic: topic, asDialog: false),
      ),
    );
  }
}

class _HelpView extends StatelessWidget {
  final HelpTopic topic;
  final bool asDialog;

  const _HelpView({required this.topic, required this.asDialog});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, asDialog ? 18 : 0, asDialog ? 10 : 20, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: p.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.help_outline_rounded, color: p.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('help'.tr, style: TextStyle(fontSize: 12.5, color: p.muted, fontWeight: FontWeight.w600)),
                    Text(topic.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text)),
                  ],
                ),
              ),
              if (asDialog)
                IconButton(
                  tooltip: 'close'.tr,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: p.border),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: HelpBody(topic: topic),
          ),
        ),
        Divider(height: 1, color: p.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Get.to(() => const HelpCenterPage(), preventDuplicates: true);
                },
                icon: const Icon(Icons.menu_book_outlined, size: 20),
                label: Text('helpAllTopics'.tr),
              ),
              const Spacer(),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text('helpGotIt'.tr)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Maudhui ya mada moja (yanatumika kwenye dirisha na kwenye kituo cha msaada).
class HelpBody extends StatelessWidget {
  final HelpTopic topic;

  const HelpBody({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(topic.intro, style: TextStyle(color: p.text, height: 1.45, fontSize: 14.5)),
        for (final section in topic.sections) ...[
          const SizedBox(height: 16),
          Text(section.title, style: TextStyle(color: p.primary, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          for (int i = 0; i < section.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 10, top: 1),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.primarySoft, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.primary)),
                  ),
                  Expanded(child: Text(section.steps[i], style: TextStyle(color: p.text, height: 1.4))),
                ],
              ),
            ),
        ],
        if (topic.tips.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.warning.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.warning.withValues(alpha: .3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: p.warning, size: 18),
                    const SizedBox(width: 6),
                    Text('helpTips'.tr, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                  ],
                ),
                const SizedBox(height: 6),
                for (final tip in topic.tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $tip', style: TextStyle(color: p.text, height: 1.4)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Kituo cha msaada: mada zote, zinatafutika.
class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(HelpTopic t) {
    if (_q.isEmpty) return true;
    final all = [t.title, t.intro, ...t.tips, for (final s in t.sections) ...[s.title, ...s.steps]].join(' ').toLowerCase();
    return all.contains(_q);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final topics = [
      for (final key in helpOrder)
        if (helpTopic(key) != null && _matches(helpTopic(key)!)) (key, helpTopic(key)!),
    ];
    return AppPage(
      title: 'helpCenter'.tr,
      subtitle: 'helpCenterSub'.tr,
      showBack: true,
      body: PageScroll(
        spacing: 10,
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'helpSearchHint'.tr,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
            ),
          ),
          if (topics.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('noMatch'.tr, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
            ),
          for (final (key, t) in topics)
            Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                key: PageStorageKey('help_$key'),
                shape: const Border(),
                leading: Icon(key.startsWith('form') ? Icons.edit_note_rounded : Icons.article_outlined, color: p.primary),
                title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(t.intro, maxLines: 1, overflow: TextOverflow.ellipsis),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [HelpBody(topic: t)],
              ),
            ),
        ],
      ),
    );
  }
}
