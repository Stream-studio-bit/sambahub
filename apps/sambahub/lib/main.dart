// CHANGELOG
// - Adicionado usePathUrlStrategy() (flutter_web_plugins) antes do runApp.
//   Sem isso o Flutter Web usa hash routing por padrão (/#/c/slug); um link
//   limpo como https://samba-hub.web.app/c/slug caía na raiz e o GoRouter
//   resolvia para initialLocation ('/dashboard') em vez de /c/:slug
//   (PublicCampaignPage). usePathUrlStrategy() é um no-op em builds não-web,
//   então é seguro chamar incondicionalmente aqui.

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await SupabaseService.initialize();
  runApp(const SambaHubApp());
}