import 'package:flutter/material.dart';

import '../../../calls/view/call_log_screen.dart';

/// The Calls tab simply embeds the full CallLogScreen.
class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) => const CallLogScreen();
}
