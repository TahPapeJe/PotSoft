import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/report_provider.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

void main() {
  runApp(const PotSoftApp());
}

class PotSoftApp extends StatelessWidget {
  const PotSoftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ReportProvider())],
      child: MaterialApp.router(
        title: 'PotSoft',
        theme: appTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
