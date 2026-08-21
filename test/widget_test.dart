import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:circuit_chat/core/di/providers.dart';
import 'package:circuit_chat/core/storage/shared_prefs.dart';
import 'package:circuit_chat/main.dart';

void main() {
  testWidgets('App renders splash screen smoke test',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final appPrefs = AppSharedPrefs(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(appPrefs),
        ],
        child: const CircuitChatApp(),
      ),
    );

    expect(find.text('CircuitChat'), findsOneWidget);
  });
}
