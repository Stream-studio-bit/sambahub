import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../campaigns/data/campaigns_repository.dart';

class CheckinEventPickerPage extends StatefulWidget {
  const CheckinEventPickerPage({required this.tenantId, super.key});
  final String tenantId;
  @override State<CheckinEventPickerPage> createState() => _CheckinEventPickerPageState();
}
class _CheckinEventPickerPageState extends State<CheckinEventPickerPage> {
  final _repo = CampaignsRepository(); List<Map<String, dynamic>> _events = const []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { _events = await _repo.listEvents(tenantId: widget.tenantId); } finally { if (mounted) setState(() => _loading = false); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Escolha o evento')), body: _loading ? const Center(child: CircularProgressIndicator()) : _events.isEmpty ? const Center(child: Text('Nenhum evento cadastrado.')) : ListView.separated(padding: const EdgeInsets.all(AppSpacing.md), itemCount: _events.length, separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm), itemBuilder: (_, index) { final event = _events[index]; return AppCard(onTap: () => context.go('/checkin/${event['id']}?tenant=${widget.tenantId}'), child: Row(children: [const Icon(Icons.event_outlined, color: AppColors.wine), const SizedBox(width: 12), Expanded(child: Text(event['name'].toString())), const Icon(Icons.chevron_right)])); }));
}
