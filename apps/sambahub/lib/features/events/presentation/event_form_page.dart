// CHANGELOG
// 2026-09-23: Texto de apoio da criação de evento agora diz onde cadastrar
// ingressos e preços (na campanha do evento). Só texto; nenhuma lógica
// alterada.
// 2026-09-20: Novo campo "Convites VIP gratuitos (opcional)" (só na criação),
// abaixo de Capacidade, com o mesmo validador (inteiro >= 0; vazio = sem
// VIP). O valor é repassado a EventsRepository.createEvent(vipQuantity:) e
// vira o produto VIP da campanha em CampaignsRepository.create(). Na edição o
// campo não aparece e updateEvent não foi alterado. Nenhuma outra lógica
// alterada.
// 2026-09-20: Slug público com preenchimento automático (só na criação).
// - Ao digitar o nome, o slug é preenchido em tempo real (ex.: "Samba de
//   Roda" -> "samba-de-roda") enquanto o usuário não editar o slug à mão.
// - Ao digitar no campo slug, o texto é convertido na hora: minúsculas, sem
//   acentos, espaços/símbolos viram hífen, hífens repetidos colapsam. Apagar o
//   campo por completo volta a acompanhar o nome.
// - Ao salvar, o slug é normalizado de novo e hífens nas pontas são removidos.
// - Edição não muda: slug continua somente leitura. Nenhuma outra lógica
//   alterada.
// 2026-09-19: P10 (Trilha G) — formulário passa a criar E editar eventos.
// - Novo contrato: EventFormPage(profileType, tenantId?, event?). Com event
//   != null é edição (título "Editar evento", slug somente leitura, campos
//   preenchidos). Com tenantId informado não chama ensureWorkspace; sem
//   tenantId mantém o fluxo antigo (ensureWorkspace). Ao salvar, fecha com
//   Navigator.pop(true) (EventsPage recarrega a lista).
// - Agora é ConsumerStatefulWidget: a edição e a troca de flyer passam pelo
//   EventsController (regras de status e recarga da lista).
// - Novo campo: término do evento (opcional, com botão para limpar); valida
//   término depois do início. Capacidade valida inteiro >= 0 (vazio = sem
//   limite).
// - Local na edição: se o nome do local não mudou, endereço/cidade/UF/CEP não
//   são exibidos nem exigidos (o local existente é reaproveitado). Se o nome
//   mudar, esses campos aparecem e são obrigatórios.
// - Flyer: mostra o flyer atual na edição; na troca envia previousPath para o
//   repository remover o arquivo antigo se a extensão mudou.
// - Erros: EventsException mostra a mensagem pronta. Se o evento for salvo mas
//   o upload do flyer falhar, avisa isso (o evento não é perdido) e fecha.
// - Seletor de data aceita evento já iniciado (não quebra na edição).
// - Não há seletor de grupo (falta a migration de groups); group_id não é
//   alterado por este formulário.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import 'events_controller.dart';

class EventFormPage extends ConsumerStatefulWidget {
  const EventFormPage({
    required this.profileType,
    this.tenantId,
    this.event,
    super.key,
  });

  final String profileType;
  final String? tenantId;

  /// Evento a editar. Nulo = criar.
  final SambaEvent? event;

  @override
  ConsumerState<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends ConsumerState<EventFormPage> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _venue = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController(text: 'SP');
  final _postal = TextEditingController();
  final _description = TextEditingController();
  final _capacity = TextEditingController();
  final _vip = TextEditingController();
  DateTime _startsAt = DateTime.now().add(const Duration(days: 7));
  DateTime? _endsAt;
  bool _saving = false;

  XFile? _coverImage;
  Uint8List? _coverBytes;

  bool get _isEdit => widget.event != null;

  /// Só na edição: o nome do local foi trocado (vai reaproveitar ou criar).
  bool get _venueChanged =>
      _isEdit && _venue.text.trim() != (widget.event!.venueName ?? '');

  bool get _showVenueAddress => !_isEdit || _venueChanged;

  String get _title {
    if (_isEdit) return 'Editar evento';
    return widget.profileType == 'group'
        ? 'Adicionar apresentação'
        : widget.profileType == 'producer'
            ? 'Criar produção'
            : 'Criar evento';
  }

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _name.text = event.name;
      _slug.text = event.slug;
      _description.text = event.description ?? '';
      _capacity.text = event.capacity?.toString() ?? '';
      _venue.text = event.venueName ?? '';
      _city.text = event.venueCity ?? '';
      _startsAt = event.startsAt;
      _endsAt = event.endsAt;
      _venue.addListener(_onVenueChanged);
    } else {
      _name.addListener(_onNameChanged);
      _slug.addListener(_onSlugChanged);
    }
  }

  bool _slugEdited = false;
  bool _syncingSlug = false;

  static const Map<String, String> _accentMap = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };

  /// Converte texto livre em slug: minúsculas, sem acentos, só [a-z0-9-].
  /// keepTrailingHyphen=true preserva um hífen final (usuário ainda digitando).
  static String _slugify(String input, {bool keepTrailingHyphen = false}) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_accentMap[ch] ?? ch);
    }
    var result = buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+'), '');
    if (!keepTrailingHyphen) result = result.replaceAll(RegExp(r'-+$'), '');
    return result;
  }

  void _setSlugText(String value) {
    _syncingSlug = true;
    _slug.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _syncingSlug = false;
  }

  void _onNameChanged() {
    if (_slugEdited) return;
    final generated = _slugify(_name.text, keepTrailingHyphen: true);
    if (generated != _slug.text) _setSlugText(generated);
  }

  void _onSlugChanged() {
    if (_syncingSlug) return;
    final raw = _slug.text;
    _slugEdited = raw.isNotEmpty;
    final normalized = _slugify(raw, keepTrailingHyphen: true);
    if (normalized != raw) _setSlugText(normalized);
    if (raw.isEmpty) _onNameChanged();
  }

  void _onVenueChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _slug,
      _venue,
      _address,
      _city,
      _state,
      _postal,
      _description,
      _capacity,
      _vip
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _key,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            _isEdit
                                ? 'Ajuste os dados do evento.'
                                : 'Vamos colocar essa roda na agenda.',
                            style: AppTypography.textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                            _isEdit
                                ? 'As alterações valem para o evento em rascunho ou publicado.'
                                : 'Preencha os dados principais. Depois de salvar, crie uma campanha para cadastrar ingressos e preços.',
                            style: AppTypography.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.muted)),
                      ])),
                  const SizedBox(height: AppSpacing.md),
                  Text('Flyer do evento',
                      style: AppTypography.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  _buildCoverPicker(),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                      label: 'Nome do evento',
                      controller: _name,
                      validator: _required),
                  if (_isEdit)
                    Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Text(
                            'Slug público: ${widget.event!.slug} (não pode ser alterado)',
                            style: AppTypography.textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted)))
                  else
                    AppInput(
                        label: 'Slug público',
                        hintText: 'ex: samba-de-sabado',
                        controller: _slug,
                        validator: _required),
                  AppInput(
                      label: 'Descrição',
                      controller: _description,
                      maxLines: 3),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Data e horário',
                      style: AppTypography.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton.icon(
                      onPressed: _saving ? null : _pickStart,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text('Início: ${_formatDate(_startsAt)}')),
                  const SizedBox(height: AppSpacing.xs),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: _saving ? null : _pickEnd,
                            icon: const Icon(Icons.event_available_outlined),
                            label: Text(_endsAt == null
                                ? 'Definir término (opcional)'
                                : 'Término: ${_formatDate(_endsAt!)}'))),
                    if (_endsAt != null)
                      IconButton(
                          tooltip: 'Remover término',
                          onPressed:
                              _saving ? null : () => setState(() => _endsAt = null),
                          icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  Text('Local', style: AppTypography.textTheme.titleMedium),
                  AppInput(
                      label: 'Nome da casa ou local',
                      controller: _venue,
                      validator: _required),
                  if (!_showVenueAddress)
                    Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Text(
                            'Para trocar o local, altere o nome e informe o endereço.',
                            style: AppTypography.textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted))),
                  if (_showVenueAddress) ...[
                    AppInput(
                        label: 'Endereço',
                        controller: _address,
                        validator: _required),
                    Row(children: [
                      Expanded(
                          child: AppInput(
                              label: 'Cidade',
                              controller: _city,
                              validator: _required)),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                          width: 76,
                          child: AppInput(
                              label: 'UF',
                              controller: _state,
                              validator: _required))
                    ]),
                    AppInput(
                        label: 'CEP',
                        controller: _postal,
                        keyboardType: TextInputType.number,
                        validator: _required),
                  ],
                  AppInput(
                      label: 'Capacidade (opcional)',
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      validator: _capacityValidator),
                  if (!_isEdit)
                    AppInput(
                        label: 'Convites VIP gratuitos (opcional)',
                        controller: _vip,
                        keyboardType: TextInputType.number,
                        validator: _capacityValidator),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                      label: _isEdit
                          ? 'Salvar alterações'
                          : 'Salvar ${widget.profileType == 'group' ? 'apresentação' : 'evento'}',
                      isFullWidth: true,
                      isLoading: _saving,
                      onPressed: _saving ? null : _save),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPicker() {
    final existingUrl = _isEdit
        ? ref
            .read(eventsRepositoryProvider)
            .getCoverImageUrl(widget.event!.coverImagePath)
        : null;

    Widget preview;
    if (_coverBytes != null) {
      preview = Image.memory(_coverBytes!,
          width: 72, height: 72, fit: BoxFit.cover);
    } else if (existingUrl != null) {
      preview = Image.network(existingUrl,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _CoverPlaceholder());
    } else {
      preview = const _CoverPlaceholder();
    }

    final label = _coverImage != null
        ? _coverImage!.name
        : existingUrl != null
            ? 'Flyer atual'
            : 'Nenhuma imagem selecionada';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: preview),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _pickCoverImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Galeria'),
                    ),
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _pickCoverImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Câmera'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCoverImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _coverImage = picked;
      _coverBytes = bytes;
    });
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = DateTime.now();
    var firstDate = now;
    if (initial.isBefore(firstDate)) firstDate = initial;
    var lastDate = now.add(const Duration(days: 730));
    if (!initial.isBefore(lastDate)) {
      lastDate = initial.add(const Duration(days: 365));
    }

    final date = await showDatePicker(
        context: context,
        firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
        lastDate: lastDate,
        initialDate: initial);
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(_startsAt);
    if (picked != null && mounted) setState(() => _startsAt = picked);
  }

  Future<void> _pickEnd() async {
    final picked =
        await _pickDateTime(_endsAt ?? _startsAt.add(const Duration(hours: 4)));
    if (picked != null && mounted) setState(() => _endsAt = picked);
  }

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    final endsAt = _endsAt;
    if (endsAt != null && !endsAt.isAfter(_startsAt)) {
      _snack('O término deve ser depois do início.');
      return;
    }

    setState(() => _saving = true);
    try {
      final capacity = int.tryParse(_capacity.text.trim());
      String? coverError;
      final event = widget.event;

      if (event != null) {
        final controller =
            ref.read(eventsControllerProvider(event.tenantId).notifier);
        final changed = _venueChanged;
        await controller.updateEvent(
          eventId: event.id,
          name: _name.text,
          startsAt: _startsAt,
          venueName: _venue.text,
          address: changed ? _address.text : '',
          city: _city.text,
          state: changed ? _state.text : '',
          postalCode: changed ? _postal.text : '',
          description: _description.text,
          endsAt: endsAt,
          capacity: capacity,
        );
        if (_coverBytes != null && _coverImage != null) {
          try {
            await controller.uploadCover(
              eventId: event.id,
              bytes: _coverBytes!,
              fileName: _coverImage!.name,
            );
          } catch (error) {
            coverError = _message(error);
          }
        }
      } else {
        final repository = ref.read(eventsRepositoryProvider);
        var tenantId = widget.tenantId;
        if (tenantId == null) {
          final user = SupabaseService.instance.currentUser;
          final displayName =
              user?.userMetadata?['name'] as String? ?? 'Minha organização';
          tenantId = await repository.ensureWorkspace(
              name: displayName, profileType: widget.profileType);
        }
        final created = await repository.createEvent(
            tenantId: tenantId,
            name: _name.text,
            slug: _slugify(_slug.text),
            startsAt: _startsAt,
            endsAt: endsAt,
            venueName: _venue.text,
            address: _address.text,
            city: _city.text,
            state: _state.text,
            postalCode: _postal.text,
            description: _description.text,
            capacity: capacity,
            vipQuantity: int.tryParse(_vip.text.trim()));

        if (_coverBytes != null && _coverImage != null) {
          try {
            await repository.uploadCoverImage(
              tenantId: tenantId,
              eventId: created['id'] as String,
              bytes: _coverBytes!,
              fileName: _coverImage!.name,
            );
          } catch (error) {
            coverError = _message(error);
          }
        }
      }

      if (!mounted) return;
      _snack(coverError == null
          ? 'Salvo com sucesso.'
          : 'Evento salvo, mas o flyer não foi enviado: $coverError');
      Navigator.of(context).pop(true);
    } catch (error) {
      _snack(_message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _message(Object error) => error is EventsException
      ? error.message
      : 'Não foi possível salvar. Tente novamente.';

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Informe este campo.' : null;

  String? _capacityValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null || number < 0) {
      return 'Informe um número inteiro maior ou igual a 0.';
    }
    return null;
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} às ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
      width: 72,
      height: 72,
      color: AppColors.peach,
      child: const Icon(Icons.image_outlined, color: AppColors.wine));
}