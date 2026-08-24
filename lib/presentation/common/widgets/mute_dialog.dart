import 'package:flutter/material.dart';

/// Duration options mirror RN's muteDialog.js
enum MuteDuration {
  oneHour    ('1 Hour',     Duration(hours: 1)),
  eightHours ('8 Hours',    Duration(hours: 8)),
  oneWeek    ('1 Week',     Duration(days: 7)),
  always     ('Always',     Duration(days: 36500)); // ~100 years = always

  const MuteDuration(this.label, this.duration);
  final String   label;
  final Duration duration;
}

/// Shows a bottom sheet to pick mute duration.
/// Returns the chosen [MuteDuration] or null if dismissed.
class MuteDialog {
  static Future<MuteDuration?> show(BuildContext context) {
    return showModalBottomSheet<MuteDuration>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Mute Notifications',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            ...MuteDuration.values.map((d) => ListTile(
                  title: Text(d.label),
                  onTap: () => Navigator.pop(context, d),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
