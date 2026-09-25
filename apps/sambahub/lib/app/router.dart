// lib/app/router.dart
//
// CHANGELOG
// 2026-09-24: Fix do link público caindo em /auth para usuário deslogado.
// O redirect global checava state.name == 'public-campaign', mas o
// GoRouterState entregue ao redirect top-level não tem name (buildTopLevel-
// GoRouterState não o preenche), então isPublicCampaign era sempre false e
// todo visitante anônimo era mandado para /auth. Agora a rota pública é
// detectada por state.pathParameters.containsKey('campaignSlug').
// 2026-09-23: Registradas as páginas que existiam mas não tinham rota:
// /tickets (TicketsPage), /orders (OrdersPage), /payments (PaymentsPage),
// /notifications (NotificationsPage) e /cart (CartPage). As quatro
// primeiras seguem o padrão ?tenant=<id> das demais rotas de gestão
// (/tickets aceita também ?event=<id> opcional, /notifications aceita
// tenant opcional, como o construtor da página). /cart recebe
// ?campaign=<id> e, com ele, o botão "Continuar para checkout" vai para
// /checkout?campaign=<id>; sem ele o botão fica desabilitado
// (CartPage.onCheckout nulo). /cart entrou na lista de rotas públicas do
// redirect, junto com /checkout: faz parte do fluxo de compra do
// comprador anônimo.
// Também registrada /recuperar-senha (ForgotPasswordPage), o caminho exato
// que auth_page.dart usa em context.go('/recuperar-senha') no link "Esqueci
// minha senha" (confirmado por grep em auth_page.dart:276). Rota pública no
// redirect: quem esqueceu a senha não está logado e seria mandado de volta
// para /auth. A própria página já volta ao login com context.go('/auth').
// 2026-09-22: Unificação de carrinho (campanha + catálogo) — registrada a
// rota /checkout (CheckoutPage), recebendo o id da campanha via query param
// ?campaign=<id>, no mesmo padrão de query param usado em /events, /groups,
// /catalog etc. (mas com nome `campaign`, não `tenant` — checkout não é
// escopado por tenant, e sim pela campanha de origem). Sem campaignId,
// mostra _RouteMessage, mesmo padrão das demais rotas que exigem parâmetro.
// Rota adicionada também à lista de rotas públicas do redirect (junto com
// isPublicCampaign, '/c/:slug'): o checkout é alcançado a partir da página
// pública da campanha (public_campaign_page.dart) e não pode exigir login,
// senão o redirect manda o comprador anônimo para /auth no meio do fluxo de
// compra. Nenhuma rota existente foi alterada.
// 2026-09-22: Fix de build — reset_password_page.dart chamava
// AuthRefreshNotifier.instance.clearPasswordRecovery(), mas a classe não era
// singleton (era instanciada só localmente em createRouter()) e não tinha
// esse método. AuthRefreshNotifier agora expõe instance estática e
// clearPasswordRecovery() (apenas notifica os listeners, forçando o
// GoRouter a reavaliar o redirect após a troca de senha). Registrada também
// a rota '/nova-senha' -> ResetPasswordPage, path real usado no redirectTo
// do e-mail de recovery (ver supabase_service.dart). Não precisou de lógica
// extra no redirect: usuário chega via link de recovery já com sessão ativa
// (currentSession != null), e '/nova-senha' não é '/auth', então nenhuma das
// regras existentes o redireciona para fora da tela.
// 2026-09-22: Link público de campanha trocado de /c/:slug para
// /:tenantSlug/:campaignSlug (nome da casa/produtor + slug da campanha),
// por decisão do usuário. isPublicCampaign no redirect não pode mais checar
// prefixo de path (startsWith('/c/')) — passou a checar state.name ==
// 'public-campaign'. Colisão com rotas literais de 2 segmentos já
// existentes (/events/new, /campaigns/:campaignId, /checkin/:eventId) foi
// avaliada e descartada por ora: o slug do tenant é gerado só em
// provision-workspace/index.ts como slugify(name)-<8 chars aleatórios>,
// nunca digitado pelo usuário, então nunca vai bater exatamente com
// 'events', 'campaigns' ou 'checkin'. Sem bloqueio de slug reservado
// adicionado — reavaliar se o slug do tenant virar editável no futuro.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/supabase_service.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/reset_password_page.dart';
import '../features/campaigns/presentation/campaigns_admin_page.dart';
import '../features/campaigns/presentation/campaign_detail_page.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/campaigns/presentation/public_campaign_page.dart';
import '../features/cart/presentation/cart_page.dart';
import '../features/checkin/presentation/checkin_event_picker_page.dart';
import '../features/checkin/presentation/checkin_page.dart';
import '../features/checkout/presentation/checkout_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/events/presentation/event_form_page.dart';
import '../features/events/presentation/events_page.dart';
import '../features/groups/presentation/groups_page.dart';
import '../features/group_contracts/presentation/group_contracts_page.dart';
import '../features/members/presentation/members_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/orders/presentation/orders_page.dart';
import '../features/payments/presentation/payments_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settlements/presentation/settlements_page.dart';
import '../features/tenants/presentation/tenant_switcher_page.dart';
import '../features/tickets/presentation/tickets_page.dart';

final class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier._() {
    _subscription = SupabaseService.instance.authStateChanges.listen((_) {
      notifyListeners();
    });
  }

  static final AuthRefreshNotifier instance = AuthRefreshNotifier._();

  late final StreamSubscription<AuthState> _subscription;

  /// Chamado após a troca de senha no fluxo de recovery
  /// (reset_password_page.dart), para forçar o GoRouter a reavaliar o
  /// redirect assim que a sessão deixa de ser uma sessão de recovery.
  void clearPasswordRecovery() {
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: AuthRefreshNotifier.instance,
    routes: [
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/recuperar-senha',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/nova-senha',
        name: 'reset-password',
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/events/new',
        name: 'event-new',
        builder: (context, state) => EventFormPage(
          profileType: state.uri.queryParameters['profile'] ?? 'venue',
        ),
      ),
      GoRoute(
        path: '/events',
        name: 'events',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          if (tenantId == null || tenantId.isEmpty) {
            return const _RouteMessage(
              message: 'Selecione uma organização para gerenciar os eventos.',
            );
          }
          return EventsPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/tenants',
        name: 'tenants',
        builder: (context, state) => TenantSwitcherPage(
          onSelected: (tenant) {
            final target = state.uri.queryParameters['target'] ?? 'dashboard';
            context.go('/$target?tenant=${tenant.id}');
          },
        ),
      ),
      GoRoute(
        path: '/campaigns',
        name: 'campaigns',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          return tenantId == null
              ? const _RouteMessage(message: 'Selecione uma organização para gerenciar campanhas.')
              : CampaignsAdminPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/campaigns/:campaignId',
        name: 'campaign-detail',
        builder: (context, state) => CampaignDetailPage(
          campaignId: state.pathParameters['campaignId']!,
        ),
      ),
      GoRoute(
        path: '/checkin',
        name: 'checkin-picker',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          return tenantId == null
              ? const _RouteMessage(message: 'Selecione uma organização para operar o check-in.')
              : CheckinEventPickerPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/groups',
        name: 'groups',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          if (tenantId == null || tenantId.isEmpty) {
            return const _RouteMessage(
              message: 'Selecione uma organização para gerenciar os grupos.',
            );
          }
          return GroupsPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/catalog',
        name: 'catalog',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          if (tenantId == null || tenantId.isEmpty) {
            return const _RouteMessage(
              message: 'Selecione uma organização para gerenciar o catálogo.',
            );
          }
          return CatalogPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/contracts',
        name: 'contracts',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          if (tenantId == null || tenantId.isEmpty) {
            return const _RouteMessage(
              message: 'Selecione uma organização para gerenciar os contratos.',
            );
          }
          return GroupContractsPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/members',
        name: 'members',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          if (tenantId == null || tenantId.isEmpty) {
            return const _RouteMessage(
              message: 'Selecione uma organização para gerenciar os membros.',
            );
          }
          return MembersPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          if (tenantId == null || tenantId.isEmpty) {
            return const _RouteMessage(
              message: 'Selecione uma organização para ver os relatórios.',
            );
          }
          return ReportsPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/settlements',
        name: 'settlements',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          if (tenantId == null || tenantId.isEmpty) {
            return const _RouteMessage(
              message: 'Selecione uma organização para acompanhar os repasses.',
            );
          }
          return SettlementsPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          if (tenantId == null || tenantId.isEmpty) {
            return const _RouteMessage(
              message: 'Selecione uma organização para ajustar as configurações.',
            );
          }
          return SettingsPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/checkin/:eventId',
        name: 'checkin',
        builder: (context, state) => CheckinPage(
          eventId: state.pathParameters['eventId']!,
          tenantId: state.uri.queryParameters['tenant'] ?? '',
        ),
      ),
      GoRoute(
        path: '/tickets',
        name: 'tickets',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          if (tenantId == null || tenantId.isEmpty) {
            return const _RouteMessage(
              message: 'Selecione uma organização para ver os ingressos.',
            );
          }
          final eventId = state.uri.queryParameters['event'];
          return TicketsPage(
            tenantId: tenantId,
            eventId: (eventId == null || eventId.isEmpty) ? null : eventId,
          );
        },
      ),
      GoRoute(
        path: '/orders',
        name: 'orders',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          if (tenantId == null || tenantId.isEmpty) {
            return const _RouteMessage(
              message: 'Selecione uma organização para ver os pedidos.',
            );
          }
          return OrdersPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/payments',
        name: 'payments',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          if (tenantId == null || tenantId.isEmpty) {
            return const _RouteMessage(
              message: 'Selecione uma organização para ver os pagamentos.',
            );
          }
          return PaymentsPage(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenant'];
          return NotificationsPage(
            tenantId: (tenantId == null || tenantId.isEmpty) ? null : tenantId,
            onOpenRoute: (route) => context.go(route),
          );
        },
      ),
      GoRoute(
        path: '/cart',
        name: 'cart',
        builder: (context, state) {
          final campaignId = state.uri.queryParameters['campaign'];
          return CartPage(
            onCheckout: (campaignId == null || campaignId.isEmpty)
                ? null
                : () => context.go('/checkout?campaign=$campaignId'),
          );
        },
      ),
      GoRoute(
        path: '/:tenantSlug/:campaignSlug',
        name: 'public-campaign',
        builder: (context, state) => PublicCampaignPage(
          tenantSlug: state.pathParameters['tenantSlug']!,
          campaignSlug: state.pathParameters['campaignSlug']!,
        ),
      ),
      GoRoute(
        path: '/checkout',
        name: 'checkout',
        builder: (context, state) {
          final campaignId = state.uri.queryParameters['campaign'];
          if (campaignId == null || campaignId.isEmpty) {
            return const _RouteMessage(
              message: 'Campanha não informada para o checkout.',
            );
          }
          return CheckoutPage(campaignId: campaignId);
        },
      ),
    ],
    redirect: (context, state) {
      final isAuthenticated = SupabaseService.instance.currentSession != null;
      final isAuthRoute = state.matchedLocation == '/auth';
      // state.name é sempre null no redirect global do GoRouter (o state
      // top-level não recebe o nome da rota); por isso a rota pública é
      // identificada pelo path parameter que só ela declara.
      final isPublicCampaign = state.pathParameters.containsKey('campaignSlug');
      final isPublicCheckout = state.matchedLocation == '/checkout';
      final isPublicCart = state.matchedLocation == '/cart';
      final isPublicForgotPassword =
          state.matchedLocation == '/recuperar-senha';

      if (!isAuthenticated &&
          !isAuthRoute &&
          !isPublicCampaign &&
          !isPublicCheckout &&
          !isPublicCart &&
          !isPublicForgotPassword) {
        return '/auth';
      }
      if (isAuthenticated && isAuthRoute) return '/dashboard';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Página não encontrada: ${state.uri}'),
      ),
    ),
  );
}

class _RouteMessage extends StatelessWidget {
  const _RouteMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}