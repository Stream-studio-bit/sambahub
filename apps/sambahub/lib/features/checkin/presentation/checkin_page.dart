// checkin_page.dart
//
// CHANGELOG
// 2026-09-25 — Item 8 (Check-in), Handoff 08:
//   - Convertido de StatefulWidget com CheckinRepository() instanciado
//     direto para ConsumerStatefulWidget usando checkinControllerProvider
//     (bug confirmado: o controller já existia mas não tinha consumidor).
//   - Nome do evento agora exibido via checkinEventNameProvider(eventId).
//   - Código lido é classificado com QrService.parse() antes de decidir o
//     fluxo: ingresso segue direto para o controller; produto abre um
//     diálogo de quantidade (stepper, padrão 1 — decisão do usuário:
//     sem "retirar tudo" nesta entrega, por não haver endpoint de consulta
//     de saldo sem efeito colateral em redeem-catalog-item) antes de
//     chamar o controller.
//   - _resultCard() agora trata os dois formatos de CheckinResult (kind
//     ticket/product), mostrando titular+horário ou produto+saldo restante
//     conforme o caso. Erros (AsyncError) ganham um card próprio.
//   - Corrigido bug confirmado: _lastCode não zera mais por temporizador
//     fixo (900ms), o que causava releitura do mesmo QR parado na câmera e
//     inflava "recusados". Agora só zera quando (a) um código diferente é
//     lido pela câmera, ou (b) o operador toca a tela, ou (c) o código é
//     enviado por digitação manual.
//   - _sessionStats (aceitos/recusados) passa a ser incrementado a partir
//     do resultado do provider (ref.listen), não mais dentro de _validate().

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../../../shared/services/qr_service.dart';
import '../domain/checkin_result.dart';
import 'checkin_controller.dart';

class CheckinPage extends ConsumerStatefulWidget {
  const CheckinPage({required this.eventId, required this.tenantId, super.key});

  final String eventId;
  final String tenantId;

  @override
  ConsumerState<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends ConsumerState<CheckinPage> {
  final _scanner = MobileScannerController();
  String? _lastCode;
  int _acceptedCount = 0;
  int _rejectedCount = 0;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultState = ref.watch(checkinControllerProvider);
    final eventName = ref.watch(checkinEventNameProvider(widget.eventId));
    final isProcessing = resultState.isLoading;

    ref.listen<AsyncValue<CheckinResult?>>(checkinControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (result) {
          if (result == null) return;
          setState(() => result.accepted ? _acceptedCount++ : _rejectedCount++);
        },
        error: (error, stackTrace) {
          setState(() => _rejectedCount++);
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in'),
        actions: [
          IconButton(
            tooltip: 'Alternar lanterna',
            onPressed: isProcessing ? null : _toggleScanner,
            icon: const Icon(Icons.videocam_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_lastCode != null) setState(() => _lastCode = null);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text('Entrada da roda', style: AppTypography.textTheme.headlineSmall),
              eventName.when(
                data: (name) => name == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(name, style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.gold)),
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Aponte para o QR Code. A validação acontece no servidor e impede reutilização.',
                style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.md),
              _sessionStats(),
              const SizedBox(height: AppSpacing.md),
              _scannerView(isProcessing),
              const SizedBox(height: AppSpacing.md),
              if (isProcessing) const LinearProgressIndicator(),
              resultState.when(
                data: (result) => result == null
                    ? const SizedBox.shrink()
                    : Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: _resultCard(result)),
                loading: () => const SizedBox.shrink(),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _errorCard(error),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Digitar código manualmente',
                variant: AppButtonVariant.outline,
                isFullWidth: true,
                onPressed: isProcessing ? null : _openManualCode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sessionStats() {
    return Row(children: [
      Expanded(child: _stat('Liberados', _acceptedCount.toString(), AppColors.success)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _stat('Recusados', _rejectedCount.toString(), AppColors.error)),
    ]);
  }

  Widget _stat(String label, String value, Color color) {
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.confirmation_number_outlined, color: color), const SizedBox(height: AppSpacing.xs), Text(value, style: AppTypography.textTheme.headlineSmall), Text(label, style: AppTypography.textTheme.bodySmall)]));
  }

  Widget _scannerView(bool isProcessing) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(controller: _scanner, onDetect: (capture) => _onDetect(capture.barcodes)),
            IgnorePointer(child: CustomPaint(painter: _ScannerFramePainter())),
            if (isProcessing) Container(color: Colors.black54, alignment: Alignment.center, child: const CircularProgressIndicator(color: AppColors.gold)),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(CheckinResult result) {
    final color = result.accepted ? AppColors.success : AppColors.error;
    return AppCard(
      backgroundColor: result.accepted ? AppColors.successSurface : AppColors.errorSurface,
      borderColor: color.withValues(alpha: .25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(result.accepted ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(result.message, style: AppTypography.textTheme.titleMedium?.copyWith(color: color))),
        ]),
        if (result.kind == QrKind.ticket && result.holderName != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Titular: ${result.holderName}'),
        ],
        if (result.kind == QrKind.ticket && result.checkedInAt != null) ...[
          const SizedBox(height: 3),
          Text('Processado: ${_formatTimestamp(result.checkedInAt)}', style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
        ],
        if (result.kind == QrKind.product && result.productName != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Produto: ${result.productName}'),
        ],
        if (result.kind == QrKind.product && result.remainingBalance != null) ...[
          const SizedBox(height: 3),
          Text('Saldo restante: ${result.remainingBalance}', style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
        ],
      ]),
    );
  }

  Widget _errorCard(Object error) {
    return AppCard(
      backgroundColor: AppColors.errorSurface,
      borderColor: AppColors.error.withValues(alpha: .25),
      child: Row(children: [
        const Icon(Icons.cancel_rounded, color: AppColors.error, size: 28),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(error.toString().replaceFirst('Exception: ', ''), style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.error))),
      ]),
    );
  }

  Future<void> _onDetect(List<Barcode> barcodes) async {
    if (ref.read(checkinControllerProvider).isLoading) return;
    final raw = barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .map((value) => value.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (raw.isEmpty || raw == _lastCode) return;
    await _handleCode(raw);
  }

  Future<void> _handleCode(String raw) async {
    _lastCode = raw;

    QrPayload payload;
    try {
      payload = QrService.parse(raw);
    } on QrException {
      // Código vazio/ inválido antes de chamar o servidor: não trava a
      // câmera nem conta como recusado, apenas libera para nova leitura.
      _lastCode = null;
      return;
    }

    await _scanner.stop();

    var quantity = 1;
    if (payload.isProduct) {
      final chosen = await _promptQuantity();
      if (chosen == null) {
        _lastCode = null;
        if (mounted) await _scanner.start();
        return;
      }
      quantity = chosen;
    }

    await ref.read(checkinControllerProvider.notifier).checkin(
          rawCode: raw,
          eventId: widget.eventId,
          tenantId: widget.tenantId,
          quantity: quantity,
        );

    if (mounted) await _scanner.start();
  }

  Future<int?> _promptQuantity() async {
    var quantity = 1;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Quantidade a retirar'),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: quantity > 1 ? () => setDialogState(() => quantity--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('$quantity', textAlign: TextAlign.center, style: AppTypography.textTheme.headlineSmall),
                  ),
                  IconButton(
                    onPressed: () => setDialogState(() => quantity++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
                TextButton(onPressed: () => Navigator.pop(dialogContext, quantity), child: const Text('Confirmar')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openManualCode() async {
    final controller = TextEditingController();
    final key = GlobalKey<FormState>();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Código'),
        content: Form(
          key: key,
          child: AppInput(
            label: 'Código do ingresso ou produto',
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            validator: (value) => value == null || value.trim().isEmpty ? 'Informe o código.' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (key.currentState?.validate() ?? false) Navigator.pop(context, controller.text);
            },
            child: const Text('Validar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code != null && code.trim().isNotEmpty) {
      // Entrada manual sempre processa, mesmo repetindo o último código
      // lido pela câmera (ex.: operador confirmando um código que a câmera
      // não conseguiu ler bem).
      _lastCode = null;
      await _handleCode(code.trim());
    }
  }

  Future<void> _toggleScanner() async {
    if (ref.read(checkinControllerProvider).isLoading) return;
    await _scanner.toggleTorch();
  }

  String? _formatTimestamp(DateTime? value) {
    if (value == null) return null;
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.gold..style = PaintingStyle.stroke..strokeWidth = 3;
    final inset = size.width * .18;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2), const Radius.circular(18)), paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}