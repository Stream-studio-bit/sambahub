// CHANGELOG: adicionado publicBaseUrl (String.fromEnvironment 'PUBLIC_BASE_URL',
// default 'https://samba-hub.web.app') e o helper campaignShareUrl(slug), para
// montar o link público de campanha (/c/:slug) usado nos botões de
// compartilhar. Nenhum outro campo foi alterado.
// CHANGELOG: linha 16 — `final rawEnvironment` corrigido para `const rawEnvironment`.
// String.fromEnvironment só é válido em contexto const (compile-time); estava
// causando UnsupportedError em runtime no build() de SambaHubApp, resultando
// em tela branca no flutter run -d chrome.
// CHANGELOG: 2026-09-22 — link público trocado de /c/:slug para
// /:tenantSlug/:campaignSlug (decisão do usuário — ver router.dart).
// campaignShareUrl(slug) virou campaignShareUrl({tenantSlug, campaignSlug}).
// Nenhum outro campo foi alterado.

enum AppEnvironment {
  development,
  staging,
  production,
}

final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appName,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.publicBaseUrl,
  });

  factory AppConfig.fromEnvironment() {
    const rawEnvironment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    final environment = AppEnvironment.values.firstWhere(
      (value) => value.name == rawEnvironment,
      orElse: () => AppEnvironment.development,
    );

    return AppConfig(
      environment: environment,
      appName: const String.fromEnvironment(
        'APP_NAME',
        defaultValue: 'SambaHub',
      ),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      publicBaseUrl: const String.fromEnvironment(
        'PUBLIC_BASE_URL',
        defaultValue: 'https://samba-hub.web.app',
      ),
    );
  }

  final AppEnvironment environment;
  final String appName;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String publicBaseUrl;

  bool get isProduction => environment == AppEnvironment.production;
  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Link público de uma campanha (rota /:tenantSlug/:campaignSlug do
  /// router), para compartilhamento fora do app. Ex.:
  /// campaignShareUrl(tenantSlug: 'bar-do-ze-a3f9c1e2', campaignSlug:
  /// 'roda-tal') -> https://samba-hub.web.app/bar-do-ze-a3f9c1e2/roda-tal
  String campaignShareUrl({
    required String tenantSlug,
    required String campaignSlug,
  }) =>
      '$publicBaseUrl/$tenantSlug/$campaignSlug';

  String get environmentLabel => switch (environment) {
        AppEnvironment.development => 'Desenvolvimento',
        AppEnvironment.staging => 'Staging',
        AppEnvironment.production => 'Produção',
      };
}