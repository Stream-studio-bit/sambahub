import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../data/groups_repository.dart';
import '../domain/samba_group.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({required this.tenantId, super.key});

  final String tenantId;

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final _repository = GroupsRepository();
  List<SambaGroup> _groups = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groups = await _repository.list(tenantId: widget.tenantId);
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível carregar os grupos.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grupos de samba')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo grupo'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: AppButton(label: 'Tentar novamente', onPressed: _load),
      );
    }
    if (_groups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SizedBox(height: AppSpacing.section),
          Icon(Icons.groups_outlined, color: AppColors.wine, size: 56),
          const SizedBox(height: AppSpacing.lg),
          Text('Ainda não há grupos',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text('Cadastre o primeiro grupo para organizar suas rodas.',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted)),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, index) => _groupTile(_groups[index]),
    );
  }

  Widget _groupTile(SambaGroup group) {
    return AppCard(
      onTap: () => _openForm(group: group),
      semanticLabel: 'Editar ${group.name}',
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.peach,
            foregroundColor: AppColors.wine,
            child: Text(group.name.isEmpty ? '?' : group.name[0].toUpperCase()),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: AppTypography.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text('@${group.slug}',
                    style: AppTypography.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(
              group.isActive
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
              color: group.isActive ? AppColors.success : AppColors.muted),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  Future<void> _openForm({SambaGroup? group}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GroupFormSheet(
        repository: _repository,
        tenantId: widget.tenantId,
        group: group,
      ),
    );
    if (result == true && mounted) _load();
  }
}

class _GroupFormSheet extends StatefulWidget {
  const _GroupFormSheet(
      {required this.repository, required this.tenantId, this.group});
  final GroupsRepository repository;
  final String tenantId;
  final SambaGroup? group;
  @override
  State<_GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends State<_GroupFormSheet> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.group?.name);
  late final _slug = TextEditingController(text: widget.group?.slug);
  late final _description =
      TextEditingController(text: widget.group?.description);
  late final _contactName =
      TextEditingController(text: widget.group?.contactName);
  late final _contactEmail =
      TextEditingController(text: widget.group?.contactEmail);
  late final _contactPhone =
      TextEditingController(text: widget.group?.contactPhone);
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _active = widget.group?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _slug,
      _description,
      _contactName,
      _contactEmail,
      _contactPhone
    ]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md),
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.group == null ? 'Novo grupo' : 'Editar grupo',
                    style: AppTypography.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.lg),
                AppInput(
                    label: 'Nome',
                    controller: _name,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe o nome.'
                        : null),
                AppInput(
                    label: 'Slug público',
                    controller: _slug,
                    hintText: 'ex: grupo-do-bom',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe o slug.'
                        : null),
                AppInput(
                    label: 'Descrição', controller: _description, maxLines: 3),
                AppInput(label: 'Responsável', controller: _contactName),
                AppInput(
                    label: 'E-mail de contato',
                    controller: _contactEmail,
                    keyboardType: TextInputType.emailAddress),
                AppInput(
                    label: 'Telefone',
                    controller: _contactPhone,
                    keyboardType: TextInputType.phone),
                SwitchListTile.adaptive(
                    value: _active,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _active = value),
                    title: const Text('Grupo ativo'),
                    contentPadding: EdgeInsets.zero),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                    label: widget.group == null
                        ? 'Cadastrar grupo'
                        : 'Salvar alterações',
                    isFullWidth: true,
                    isLoading: _saving,
                    onPressed: _save),
                if (widget.group != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                      label: 'Excluir grupo',
                      variant: AppButtonVariant.destructive,
                      isFullWidth: true,
                      onPressed: _delete),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      if (widget.group == null) {
        await widget.repository.create(
            tenantId: widget.tenantId,
            name: _name.text,
            slug: _slug.text,
            description: _description.text,
            contactName: _contactName.text,
            contactEmail: _contactEmail.text,
            contactPhone: _contactPhone.text);
      } else {
        await widget.repository.update(
            id: widget.group!.id,
            name: _name.text,
            slug: _slug.text,
            description: _description.text,
            contactName: _contactName.text,
            contactEmail: _contactEmail.text,
            contactPhone: _contactPhone.text,
            isActive: _active);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível salvar o grupo.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await widget.repository.delete(widget.group!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível excluir o grupo.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
