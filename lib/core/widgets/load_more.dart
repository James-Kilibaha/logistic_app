import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Kitufe cha "Pakia zaidi" mwishoni mwa orodha yenye kurasa.
class LoadMoreButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;
  final int shown;

  const LoadMoreButton({super.key, required this.busy, required this.onPressed, required this.shown});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: busy ? null : onPressed,
          icon: busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.expand_more_rounded),
          label: Text('loadMoreN'.trParams({'n': '$shown'})),
        ),
      ),
    );
  }
}
