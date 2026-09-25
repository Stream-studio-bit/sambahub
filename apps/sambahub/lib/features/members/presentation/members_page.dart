// CHANGELOG
// 2026-09-19 — P7 / Trilha E (Membros)
// - Convertida para ConsumerStatefulWidget para controlar o estado "ocupado"
//   por membro (evita duplo toque durante a mutação) e exibir SnackBar de
//   sucesso/erro — nenhum dos dois existia antes.
// - Suspensão passou a pedir confirmação, como o P7 exige explicitamente
//   ("suspensão com confirmação"). Reativar um membro não pede confirmação
//   (ação reversível e de baixo risco).
// - A proteção do owner já existia na UI (dropdown/botão desabilitado quando
//   member.role == 'owner'); mantida como primeira barreira visual. A defesa
//   real agora está no controller (MembersController), que barra mesmo uma
//   chamada que não passe por este widget.
// - Convite de membro (seção 3 do prompt mestre) não foi implementado aqui:
//   decisão pendente do responsável entre nova Edge Function com
//   auth.admin.inviteUserByEmail ou vincular usuário já cadastrado por
//   e-mail. Nada nesta página assume qual caminho será escolhido.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../data/members_repository.dart';
import '../domain/tenant_member.dart';
import 'members_controller.dart';

class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({required this.tenantId, super.key});
  final String tenantId;

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  String? _busyMemberId;

  Future<void> _run(
    String memberId,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _busyMemberId = memberId);
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } on MembersException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Não foi possível concluir a ação. Tente novamente.'),
      ));
    } finally {
      if (mounted) {
        setState(() => _busyMemberId = null);
      }
    }
  }

  Future<bool> _confirmSuspension(TenantMember member) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspender membro'),
        content: Text(
          'Confirma a suspensão de ${member.name ?? member.email ?? 'este membro'}? '
          'Ele perde acesso à organização até ser reativado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Suspender'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersControllerProvider(widget.tenantId));
    final notifier =
        ref.read(membersControllerProvider(widget.tenantId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Membros e funções')),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(onRetry: notifier.refresh),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, index) {
                final member = items[index];
                final busy = _busyMemberId == member.id;
                return _MemberTile(
                  member: member,
                  busy: busy,
                  onRoleChanged: (role) => _run(
                    member.id,
                    () => notifier.updateRole(member, role),
                    successMessage: 'Função atualizada.',
                  ),
                  onToggleStatus: () async {
                    if (member.isActive) {
                      final ok = await _confirmSuspension(member);
                      if (!ok) {
                        return;
                      }
                      await _run(
                        member.id,
                        () => notifier.updateStatus(member, 'suspended'),
                        successMessage: 'Membro suspenso.',
                      );
                    } else {
                      await _run(
                        member.id,
                        () => notifier.updateStatus(member, 'active'),
                        successMessage: 'Membro reativado.',
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.busy,
    required this.onRoleChanged,
    required this.onToggleStatus,
  });

  final TenantMember member;
  final bool busy;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onToggleStatus;

  static const roles = [
    'owner',
    'admin',
    'producer',
    'finance',
    'checkin',
    'group_manager',
    'viewer',
  ];

  @override
  Widget build(BuildContext context) {
    final locked = member.isOwner || busy;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: AppColors.peach,
              foregroundColor: AppColors.wine,
              child: Text(
                (member.name ?? member.email ?? '?').characters.first.toUpperCase(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name ?? 'Membro sem nome',
                    style: AppTypography.textTheme.titleMedium,
                  ),
                  Text(
                    member.email ?? 'E-mail não informado',
                    style: AppTypography.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              _StatusChip(status: member.status),
          ]),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue:
                    roles.contains(member.role) ? member.role : 'viewer',
                decoration: const InputDecoration(labelText: 'Função'),
                items: roles
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(_roleLabel(role)),
                        ))
                    .toList(),
                onChanged: locked
                    ? null
                    : (role) {
                        if (role != null) {
                          onRoleChanged(role);
                        }
                      },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: member.isActive ? 'Suspender membro' : 'Ativar membro',
              onPressed: locked ? null : onToggleStatus,
              icon: Icon(
                member.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                color: member.isActive ? AppColors.orange : AppColors.success,
              ),
            ),
          ]),
          if (member.isOwner) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Proprietário: função e status não podem ser alterados.',
              style: AppTypography.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  String _roleLabel(String role) => switch (role) {
        'owner' => 'Proprietário',
        'admin' => 'Administrador',
        'producer' => 'Produtor',
        'finance' => 'Financeiro',
        'checkin' => 'Check-in',
        'group_manager' => 'Gestor de grupo',
        _ => 'Visualizador',
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'active';
    final label = switch (status) {
      'active' => 'Ativo',
      'invited' => 'Convidado',
      'suspended' => 'Suspenso',
      _ => status,
    };
    final color = active ? AppColors.success : AppColors.error;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text('Nenhum membro nesta organização.')));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
        const SizedBox(height: AppSpacing.md),
        const Text('Não foi possível carregar os membros.'),
        const SizedBox(height: AppSpacing.md),
        TextButton(onPressed: onRetry, child: const Text('Tentar novamente'))
      ]));
}