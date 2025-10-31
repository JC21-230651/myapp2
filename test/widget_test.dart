import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:myapp/my_app.dart';
import 'package:myapp/theme_provider.dart';
import 'package:myapp/health_state.dart';
import 'package:myapp/task_state.dart';

void main() async {
  // テスト実行前に初期化
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja_JP', null);

  testWidgets('App starts and displays home page', (WidgetTester tester) async {
    // 本番と同じ構成でMultiProviderを適用
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => HealthState()),
          ChangeNotifierProvider(create: (_) => TaskState()),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // BottomNavigationBarが表示されていることを確認
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}