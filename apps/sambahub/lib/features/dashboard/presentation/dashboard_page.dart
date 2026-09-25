// Changelog:
// 2026-09-23 (2): Venda de ingressos nos perfis producer e group. Cada um
// ganhou 7 atalhos que já existiam no painel da casa: Campanhas (cadastro de
// ingressos e preços e link de venda), Eventos (lista e edição), Ingressos,
// Pedidos, Pagamentos, Check-in e Notificações. Producer e group passam de 5
// para 12 atalhos (número par). Nenhuma rota nova: reaproveita
// /tenants?target=<x> e as rotas já registradas em router.dart. O perfil
// continua vindo de user.userMetadata['profile_type'] (venue por padrão).
// 2026-09-23: Painel da casa (venue) ganhou 4 atalhos: Ingressos, Pedidos,
// Pagamentos e Notificações, navegando para /tenants?target=tickets|orders|
// payments|notifications (rotas registradas em router.dart nesta data).
// Venue passa de 6 para 10 atalhos (número par, então o layout de 2 colunas
// não deixa card sozinho). Os perfis producer e group não foram alterados.
// 2026-09-19: Adicionada a ação "Eventos" ao perfil venue (único que não tinha
// atalho para a lista de eventos), navegando para /tenants?target=events (a
// rota /events, que exige tenantId, foi registrada em router.dart e lista
// EventsPage). "Produções" (producer) e "Agenda" (group) não foram alteradas:
// continuam abrindo /events/new diretamente. Venue passa de 5 para 6 atalhos.
// 2026-09-19: Adicionada a ação "Configurações" ao "Acesso rápido" dos três
// perfis (venue, producer, group), navegando para /tenants?target=settings (a
// rota /settings foi registrada em router.dart). Cada perfil passa de 4 para 5
// atalhos, então no layout de 2 colunas (>=760px) o último card fica sozinho na
// linha, ocupando metade da largura. Nenhuma outra parte do arquivo foi
// alterada.
// 2026-09-18: Item 6 (Dashboard) — Catálogo e Grupos agora navegam para
// /tenants?target=catalog e /tenants?target=groups (rotas já existentes em
// router.dart), no mesmo padrão de Campanhas/Check-in. Relatórios, Contratos,
// Repasses e Membros continuam em "coming soon": não há rota registrada para
// eles no router.dart, e o item 6 proíbe apontar para rota inexistente.
// 2026-09-18: _BrandMark — ícone graphic_eq_rounded substituído por
// assets/icons/icon.png (caminho relativo assumido a partir de
// apps/sambahub/pubspec.yaml; confirmar que está declarado em pubspec.yaml >
// flutter > assets). "Hub" em AppColors.orange, "Samba" mantém a cor padrão
// do tema (herdada de titleLarge).
// 2026-09-18: _BrandMark — removido o badge (Container wine com cantos
// arredondados + ClipRRect) que envolvia o ícone; agora o icon.png aparece
// solto, 30x30, BoxFit.contain (antes cover, que cortava a imagem).
// 2026-09-18: Relatórios, Contratos, Repasses e Membros agora navegam para
// /tenants?target=reports|contracts|settlements|members, pois as rotas
// /reports, /contracts, /settlements e /members foram registradas em router.dart.
// _showComingSoon permanece para qualquer atalho sem rota.
// Nenhuma outra parte do arquivo foi alterada.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final displayName = (metadata['name'] as String?)?.trim();
    final profileType = metadata['profile_type'] as String? ?? 'venue';
    final profile = _DashboardProfile.fromValue(profileType);
    final firstName = displayName == null || displayName.isEmpty
        ? 'por aqui'
        : displayName.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: const _BrandMark(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton(
              tooltip: 'Sair',
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 1024
                ? AppSpacing.pageHorizontalDesktop
                : constraints.maxWidth >= 600
                    ? AppSpacing.pageHorizontalTablet
                    : AppSpacing.pageHorizontalMobile;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.lg,
                horizontalPadding,
                AppSpacing.section,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWelcome(firstName, profile),
                      const SizedBox(height: AppSpacing.lg),
                      _buildHighlight(context, profile),
                      const SizedBox(height: AppSpacing.lg),
                      _buildStats(constraints.maxWidth),
                      const SizedBox(height: AppSpacing.section),
                      _buildQuickActions(context, profile),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcome(String firstName, _DashboardProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.eyebrow,
          style: AppTypography.textTheme.labelSmall?.copyWith(
            color: AppColors.orange,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Bom te ver, $firstName.',
          style: AppTypography.textTheme.displaySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          profile.subtitle,
          style: AppTypography.textTheme.bodyLarge?.copyWith(
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildHighlight(
    BuildContext context,
    _DashboardProfile profile,
  ) {
    return AppCard(
      padding: EdgeInsets.zero,
      backgroundColor: AppColors.wineDeep,
      borderColor: AppColors.wineDeep,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.wineDeep, AppColors.wine],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.highlightEyebrow,
              style: AppTypography.textTheme.labelSmall?.copyWith(
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              profile.highlightTitle,
              style: AppTypography.textTheme.headlineMedium?.copyWith(
                color: AppColors.white,
                height: 1.05,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              profile.highlightDescription,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.darkMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: profile.primaryAction,
              variant: AppButtonVariant.primary,
              leading: const Icon(Icons.add_rounded),
              onPressed: () => context.go('/events/new?profile=${profile.routeValue}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(double screenWidth) {
    final stats = <_StatData>[
      const _StatData('0', 'Eventos ativos', Icons.event_note_rounded),
      const _StatData('0', 'Ingressos vendidos', Icons.confirmation_number_outlined),
      const _StatData('R\$ 0', 'A receber', Icons.account_balance_wallet_outlined),
    ];

    final cards = stats.map(_buildStatCard).toList(growable: false);
    if (screenWidth < 600) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            cards[index],
            if (index < cards.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          Flexible(child: cards[index]),
          if (index < cards.length - 1)
            const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildStatCard(_StatData stat) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, color: AppColors.wine, size: 22),
          const SizedBox(height: AppSpacing.md),
          Text(stat.value, style: AppTypography.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(stat.label, style: AppTypography.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    _DashboardProfile profile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Acesso rápido', style: AppTypography.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 2 : 1;
            final width = columns == 2
                ? (constraints.maxWidth - AppSpacing.sm) / 2
                : constraints.maxWidth;
            final actions = profile.actions;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions
                  .map(
                    (action) => SizedBox(
                      width: width,
                      child: _actionCard(context, action, profile),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Widget _actionCard(BuildContext context, _DashboardAction action, _DashboardProfile profile) {
    return AppCard(
      onTap: () {
        if (action.title == 'Produções' || action.title == 'Agenda') {
          context.go('/events/new?profile=${profile.routeValue}');
        } else if (action.title == 'Campanhas') {
          context.go('/tenants?target=campaigns');
        } else if (action.title == 'Check-in') {
          context.go('/tenants?target=checkin');
        } else if (action.title == 'Catálogo') {
          context.go('/tenants?target=catalog');
        } else if (action.title == 'Grupos') {
          context.go('/tenants?target=groups');
        } else if (action.title == 'Relatórios') {
          context.go('/tenants?target=reports');
        } else if (action.title == 'Contratos') {
          context.go('/tenants?target=contracts');
        } else if (action.title == 'Repasses') {
          context.go('/tenants?target=settlements');
        } else if (action.title == 'Membros') {
          context.go('/tenants?target=members');
        } else if (action.title == 'Configurações') {
          context.go('/tenants?target=settings');
        } else if (action.title == 'Eventos') {
          context.go('/tenants?target=events');
        } else if (action.title == 'Ingressos') {
          context.go('/tenants?target=tickets');
        } else if (action.title == 'Pedidos') {
          context.go('/tenants?target=orders');
        } else if (action.title == 'Pagamentos') {
          context.go('/tenants?target=payments');
        } else if (action.title == 'Notificações') {
          context.go('/tenants?target=notifications');
        } else {
          _showComingSoon(context, action.title);
        }
      },
      semanticLabel: 'Abrir ${action.title}',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.peach,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(action.icon, color: AppColors.wine, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.title, style: AppTypography.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(action.subtitle, style: AppTypography.textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await SupabaseService.instance.signOut();
    if (context.mounted) context.go('/auth');
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature estará disponível em breve.')),
    );
  }
}

class _StatData {
  const _StatData(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

class _DashboardAction {
  const _DashboardAction(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

enum _DashboardProfile {
  venue,
  producer,
  group;

  static _DashboardProfile fromValue(String value) {
    return switch (value) {
      'producer' => _DashboardProfile.producer,
      'group' => _DashboardProfile.group,
      _ => _DashboardProfile.venue,
    };
  }

  String get eyebrow => switch (this) {
        _DashboardProfile.venue => 'PAINEL DA CASA NOTURNA',
        _DashboardProfile.producer => 'PAINEL DA PRODUTORA',
        _DashboardProfile.group => 'PAINEL DO GRUPO DE SAMBA',
      };

  String get subtitle => switch (this) {
        _DashboardProfile.venue => 'Organize sua casa, seus eventos e suas vendas.',
        _DashboardProfile.producer => 'Produza eventos, conecte parceiros e acompanhe resultados.',
        _DashboardProfile.group => 'Cuide da agenda, dos contratos e das suas rodas.',
      };

  String get highlightEyebrow => switch (this) {
        _DashboardProfile.venue => 'PRÓXIMA RODA',
        _DashboardProfile.producer => 'PRÓXIMA PRODUÇÃO',
        _DashboardProfile.group => 'PRÓXIMO SHOW',
      };

  String get highlightTitle => switch (this) {
        _DashboardProfile.venue => 'Seu próximo evento começa aqui.',
        _DashboardProfile.producer => 'Sua próxima produção começa aqui.',
        _DashboardProfile.group => 'Sua próxima apresentação começa aqui.',
      };

  String get highlightDescription => switch (this) {
        _DashboardProfile.venue => 'Crie um evento e compartilhe o link da sua campanha.',
        _DashboardProfile.producer => 'Monte a produção, convide grupos e acompanhe a venda.',
        _DashboardProfile.group => 'Organize sua agenda e mantenha seus contratos em dia.',
      };

  String get primaryAction => switch (this) {
        _DashboardProfile.venue => 'Criar evento',
        _DashboardProfile.producer => 'Criar produção',
        _DashboardProfile.group => 'Adicionar apresentação',
      };

  String get routeValue => switch (this) {
        _DashboardProfile.venue => 'venue',
        _DashboardProfile.producer => 'producer',
        _DashboardProfile.group => 'group',
      };

  List<_DashboardAction> get actions => switch (this) {
        _DashboardProfile.venue => const [
            _DashboardAction(Icons.campaign_outlined, 'Campanhas', 'Venda pelo seu link'),
            _DashboardAction(Icons.event_outlined, 'Eventos', 'Gerencie sua agenda'),
            _DashboardAction(Icons.inventory_2_outlined, 'Catálogo', 'Gerencie produtos'),
            _DashboardAction(Icons.qr_code_scanner_rounded, 'Check-in', 'Valide ingressos'),
            _DashboardAction(Icons.confirmation_number_outlined, 'Ingressos', 'Veja os ingressos emitidos'),
            _DashboardAction(Icons.shopping_bag_outlined, 'Pedidos', 'Acompanhe suas vendas'),
            _DashboardAction(Icons.payments_outlined, 'Pagamentos', 'Confira as transações'),
            _DashboardAction(Icons.notifications_none_rounded, 'Notificações', 'Avisos da sua conta'),
            _DashboardAction(Icons.bar_chart_rounded, 'Relatórios', 'Acompanhe seus dados'),
            _DashboardAction(Icons.settings_outlined, 'Configurações', 'Ajuste sua organização'),
          ],
        _DashboardProfile.producer => const [
            _DashboardAction(Icons.event_outlined, 'Produções', 'Planeje seus eventos'),
            _DashboardAction(Icons.campaign_outlined, 'Campanhas', 'Venda pelo seu link'),
            _DashboardAction(Icons.event_outlined, 'Eventos', 'Gerencie sua agenda'),
            _DashboardAction(Icons.confirmation_number_outlined, 'Ingressos', 'Veja os ingressos emitidos'),
            _DashboardAction(Icons.shopping_bag_outlined, 'Pedidos', 'Acompanhe suas vendas'),
            _DashboardAction(Icons.payments_outlined, 'Pagamentos', 'Confira as transações'),
            _DashboardAction(Icons.qr_code_scanner_rounded, 'Check-in', 'Valide ingressos'),
            _DashboardAction(Icons.notifications_none_rounded, 'Notificações', 'Avisos da sua conta'),
            _DashboardAction(Icons.groups_outlined, 'Grupos', 'Conecte atrações'),
            _DashboardAction(Icons.receipt_long_outlined, 'Contratos', 'Controle acordos'),
            _DashboardAction(Icons.bar_chart_rounded, 'Relatórios', 'Acompanhe resultados'),
            _DashboardAction(Icons.settings_outlined, 'Configurações', 'Ajuste sua organização'),
          ],
        _DashboardProfile.group => const [
            _DashboardAction(Icons.calendar_month_outlined, 'Agenda', 'Veja suas apresentações'),
            _DashboardAction(Icons.campaign_outlined, 'Campanhas', 'Venda pelo seu link'),
            _DashboardAction(Icons.event_outlined, 'Eventos', 'Gerencie sua agenda'),
            _DashboardAction(Icons.confirmation_number_outlined, 'Ingressos', 'Veja os ingressos emitidos'),
            _DashboardAction(Icons.shopping_bag_outlined, 'Pedidos', 'Acompanhe suas vendas'),
            _DashboardAction(Icons.payments_outlined, 'Pagamentos', 'Confira as transações'),
            _DashboardAction(Icons.qr_code_scanner_rounded, 'Check-in', 'Valide ingressos'),
            _DashboardAction(Icons.notifications_none_rounded, 'Notificações', 'Avisos da sua conta'),
            _DashboardAction(Icons.receipt_long_outlined, 'Contratos', 'Acompanhe seus acordos'),
            _DashboardAction(Icons.payments_outlined, 'Repasses', 'Acompanhe seus recebimentos'),
            _DashboardAction(Icons.groups_outlined, 'Membros', 'Gerencie seu grupo'),
            _DashboardAction(Icons.settings_outlined, 'Configurações', 'Ajuste sua organização'),
          ],
      };
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icons/icon.png',
          width: 30,
          height: 30,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text.rich(
          TextSpan(
            style: AppTypography.textTheme.titleLarge,
            children: const [
              TextSpan(text: 'Samba'),
              TextSpan(text: 'Hub', style: TextStyle(color: AppColors.orange)),
            ],
          ),
        ),
      ],
    );
  }
}