import 'package:flutter/material.dart';

class LiveStreamSignalBar extends StatelessWidget {
  const LiveStreamSignalBar({super.key});

  @override
  Widget build(BuildContext context) {
    final bars = List<int>.generate(42, (index) => (index % 5) + 1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      color: Colors.black.withValues(alpha: 0.75),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: bars.asMap().entries.map((entry) {
            final index = entry.key;
            final heightTier = entry.value;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: 5.0 + (heightTier * 2.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Color.lerp(
                    Colors.green.shade400,
                    Colors.red.shade400,
                    index / bars.length,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
