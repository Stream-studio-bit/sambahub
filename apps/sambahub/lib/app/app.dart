import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'app_config.dart';
import 'router.dart';

class SambaHubApp extends StatefulWidget {
  const SambaHubApp({super.key, this.config});

  final AppConfig? config;

  @override
  State<SambaHubApp> createState() => _SambaHubAppState();
}

class _SambaHubAppState extends State<SambaHubApp> {
  late final router = createRouter();

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config ?? AppConfig.fromEnvironment();
    return ProviderScope(
      child: MaterialApp.router(
        title: config.appName,
        debugShowCheckedModeBanner: !config.isProduction,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }
}
