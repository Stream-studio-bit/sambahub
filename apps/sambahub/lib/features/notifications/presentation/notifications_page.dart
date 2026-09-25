import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/app_notification.dart';
import 'notifications_controller.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key, this.tenantId, this.onOpenRoute});
  final String? tenantId;
  final ValueChanged<String>? onOpenRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsControllerProvider(tenantId));
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações'), actions: [
        notifications.maybeWhen(
            data: (items) => items.any((item) => !item.isRead)
                ? TextButton(
                    onPressed: () => ref
                        .read(
                            notificationsControllerProvider(tenantId).notifier)
                        .markAllAsRead(),
                    child: const Text('Ler todas'))
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink())
      ]),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
            onRetry: () => ref
                .read(notificationsControllerProvider(tenantId).notifier)
                .refresh()),
        data: (items) {
          if (items.isEmpty) return const _EmptyState();
          return RefreshIndicator(
              onRefresh: () => ref
                  .read(notificationsControllerProvider(tenantId).notifier)
                  .refresh(),
              child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) => _NotificationTile(
                      notification: items[index],
                      onTap: () => _open(context, ref, items[index]))));
        },
      ),
    );
  }

  Future<void> _open(
      BuildContext context, WidgetRef ref, AppNotification notification) async {
    if (!notification.isRead)
      await ref
          .read(notificationsControllerProvider(tenantId).notifier)
          .markAsRead(notification.id);
    if (notification.actionRoute != null && onOpenRoute != null)
      onOpenRoute!(notification.actionRoute!);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = _typeColor(notification.type);
    return AppCard(
        onTap: onTap,
        semanticLabel: 'Notificação: ${notification.title}',
        backgroundColor: notification.isRead
            ? AppColors.paper
            : AppColors.peach.withValues(alpha: .55),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(_typeIcon(notification.type), color: color)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(notification.title,
                          style: AppTypography.textTheme.titleMedium)),
                  if (!notification.isRead)
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: AppColors.orange, shape: BoxShape.circle))
                ]),
                const SizedBox(height: AppSpacing.xs),
                Text(notification.body,
                    style: AppTypography.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(_date(notification.createdAt),
                    style: AppTypography.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted))
              ]))
        ]));
  }

  IconData _typeIcon(String type) => switch (type) {
        'payment' => Icons.payments_outlined,
        'ticket' => Icons.confirmation_number_outlined,
        'checkin' => Icons.qr_code_scanner_rounded,
        'settlement' => Icons.account_balance_wallet_outlined,
        _ => Icons.notifications_none_rounded
      };
  Color _typeColor(String type) => switch (type) {
        'payment' => AppColors.success,
        'ticket' => AppColors.wine,
        'checkin' => AppColors.orange,
        'settlement' => AppColors.gold,
        _ => AppColors.muted
      };
  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text('Você está em dia. Nenhuma notificação nova.')));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
        const SizedBox(height: AppSpacing.md),
        const Text('Não foi possível carregar as notificações.'),
        const SizedBox(height: AppSpacing.md),
        TextButton(onPressed: onRetry, child: const Text('Tentar novamente'))
      ]));
}
