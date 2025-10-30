
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'health_state.dart';
import 'my_app.dart';
import 'notification_service.dart';
import 'theme_provider.dart';
import 'task_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    final NotificationService notificationService = NotificationService();
    await notificationService.init();
    await notificationService.requestPermissions();
  }

  await initializeDateFormatting('ja_JP', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HealthState()),
        ChangeNotifierProvider(create: (_) => TaskState()),
      ],
      child: const MyApp(),
    ),
  );
}
