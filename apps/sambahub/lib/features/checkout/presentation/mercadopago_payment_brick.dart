// lib/features/checkout/presentation/mercadopago_payment_brick.dart
//
// CHANGELOG
// 2026-09-24 (2): Corrige "payment_brick_initialization_failed: No payment
// type was selected". Causa (evidência: mensagem do SDK + este arquivo):
// settings só tinha initialization e callbacks, sem customization.
// paymentMethods (a documentação do Payment Brick inclui esse bloco na
// configuração padrão). Adicionado com creditCard, debitCard e bankTransfer
// (Pix), todos 'all'.
// 2026-09-24: Corrige "Could not find the Brick container ID". Causa
// (evidência: mensagem do SDK + este arquivo): _createBrick() rodava logo
// após o initState, enquanto _loading era true e o HtmlElementView estava
// dentro de Offstage(offstage: _loading) — o container do Brick ainda não
// existia no DOM quando o SDK procurou o ID. Agora: (1) o HtmlElementView
// fica sempre no build (o spinner vira overlay em Stack, sem Offstage);
// (2) _waitForContainer() espera o primeiro frame e só segue quando
// document.getElementById(_viewType) encontra o elemento (limite de 5 s,
// com erro explícito); (3) _createBrick() só roda depois disso.
// Também: se o widget for removido enquanto o Brick é criado, o controller
// recebe unmount() na hora, em vez de ficar sem dono.
// Diagnóstico temporário (2026-09-23) REMOVIDO: _diagnostics(), _jsErrors,
// listeners globais de 'error'/'unhandledrejection', espera de 300 ms e o
// import de package:http. A causa do "window.MercadoPago não disponível" era
// a injeção dinâmica do SDK; o SDK agora vem por tag estática em
// web/index.html (mesmo padrão do OmniWA). A injeção dinâmica abaixo ficou
// só como fallback, caso o global não exista.
//
// 2026-09-21 (fix pós flutter analyze): dart:js_util não existe mais no
// Dart 3.11 (removido junto com dart:html na migração para
// dart:js_interop) — era a causa do erro "Target of URI doesn't exist".
// Reescrito usando só dart:js_interop + dart:js_interop_unsafe:
// - Construção/chamada de métodos JS sem binding estático (new
//   MercadoPago(...), .bricks(), .create(...)) usa as extensions de
//   dart:js_interop_unsafe: operator [] / []= em JSObject,
//   callMethodVarArgs, callAsConstructorVarArgs.
// - jsify()/dartify() (extensions do próprio dart:js_interop, não da
//   unsafe) substituem js_util.jsify/dartify — e simplificaram bastante a
//   leitura do formData do onSubmit: em vez de navegar propriedade por
//   propriedade com getProperty, agora é um Object?.dartify() e depois
//   Map normal do Dart.
// - Promise<->Future: .toJS / .toDart (extensions de dart:js_interop),
//   substituindo js_util.promiseToFuture/futureToPromise.
// - Requer o pacote `web` como dependência direta do pubspec.yaml
//   (confirmado pelo flutter analyze que não estava declarado — rodar
//   `flutter pub add web`).
// - Mantido o aviso do lint avoid_web_libraries_in_flutter como
//   ignore_for_file: este arquivo é deliberadamente web-only (app é
//   Flutter Web only para checkout, confirmado).
//
// 2026-09-21: Criação (Prompt Mestre, item 7). Embute o Payment Brick do
// Mercado Pago (SDK JS https://sdk.mercadopago.com/js/v2) no Flutter Web via
// HtmlElementView. Ciclo de vida: initState garante o SDK (tag estática do
// index.html; injeta o script só se window.MercadoPago ainda não existir) e
// cria o Brick; dispose chama controller.unmount(). onSubmit do Brick só
// resolve quando checkoutController.submitPayment terminar (via Future.toJS)
// — é isso que mantém o loading do próprio Brick aceso até o backend
// responder, em vez de um loading duplicado nosso.

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/checkout_request.dart';

const _sdkUrl = 'https://sdk.mercadopago.com/js/v2';

class MercadoPagoPaymentBrick extends StatefulWidget {
  const MercadoPagoPaymentBrick({
    required this.publicKey,
    required this.amount,
    required this.payerEmail,
    required this.onSubmit,
    super.key,
  });

  final String publicKey;
  final double amount;
  final String payerEmail;
  final Future<void> Function(BrickPaymentSubmitData data) onSubmit;

  @override
  State<MercadoPagoPaymentBrick> createState() => _MercadoPagoPaymentBrickState();
}

class _MercadoPagoPaymentBrickState extends State<MercadoPagoPaymentBrick> {
  late final String _viewType;
  late final web.HTMLDivElement _container;
  JSObject? _brickController;
  web.MutationObserver? _emailAutofillObserver;
  bool _loading = true;
  bool _emailAutofilled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _viewType = 'mercadopago-brick-${identityHashCode(this)}';
    _container = (web.document.createElement('div') as web.HTMLDivElement)
      ..id = _viewType
      ..style.width = '100%';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _container,
    );

    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await _ensureSdkLoaded();
      await _waitForContainer();
      await _createBrick();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar o pagamento: $e';
        });
      }
    }
  }

  Future<void> _ensureSdkLoaded() async {
    final existing = web.window['MercadoPago'];
    if (existing != null) return;

    // Fallback: o normal é o SDK já vir da tag estática de web/index.html.
    final completer = Completer<void>();
    final script = web.document.createElement('script') as web.HTMLScriptElement
      ..src = _sdkUrl
      ..type = 'text/javascript';

    script.addEventListener('load', ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS);
    script.addEventListener('error', ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError('Falha ao carregar o SDK do Mercado Pago.');
      }
    }).toJS);

    web.document.head!.append(script);
    await completer.future;
  }

  /// O SDK procura o container pelo ID no documento. O HtmlElementView só
  /// coloca o elemento no DOM depois de ser construído e pintado, então
  /// espera aqui até document.getElementById(_viewType) encontrá-lo.
  Future<void> _waitForContainer() async {
    await WidgetsBinding.instance.endOfFrame;
    for (var i = 0; i < 100; i++) {
      if (!mounted) {
        throw StateError('Tela fechada antes de o pagamento carregar.');
      }
      if (web.document.getElementById(_viewType) != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw StateError('Container do Brick não apareceu no DOM ($_viewType).');
  }

  Future<void> _createBrick() async {
    final ctor = web.window['MercadoPago'] as JSFunction?;
    if (ctor == null) {
      throw StateError('window.MercadoPago não disponível após carregar o SDK.');
    }

    final initOptions = <String, Object?>{'locale': 'pt-BR'}.jsify();
    final mp = ctor.callAsConstructorVarArgs<JSObject>([widget.publicKey.toJS, initOptions]);

    final bricksBuilder = mp.callMethodVarArgs('bricks'.toJS, <JSAny?>[]) as JSObject;

    final settings = JSObject();
    settings['initialization'] = <String, Object?>{
      'amount': widget.amount,
      'payer': {'email': widget.payerEmail},
    }.jsify();

    final callbacks = JSObject();
    callbacks['onReady'] = (() {}).toJS;
    callbacks['onError'] = ((JSAny? error) {
      if (mounted) {
        setState(() => _error = 'Erro no pagamento: ${error?.dartify()}');
      }
    }).toJS;
    // Documentação do Brick: onSubmit recebe UM objeto {formData,
    // additionalData}. dartify() converte tudo (inclusive aninhado) para
    // Map/List/primitivos Dart de uma vez, sem precisar navegar
    // propriedade por propriedade via getProperty.
    callbacks['onSubmit'] = ((JSAny? param) {
      final paramMap = param?.dartify();
      final formData = paramMap is Map ? paramMap['formData'] : null;
      final BrickPaymentSubmitData data;
      try {
        data = _parseSubmitData(formData);
      } catch (e) {
        if (mounted) setState(() => _error = 'Dados de pagamento inválidos.');
        return Future<JSAny?>.error(e).toJS;
      }
      final future = widget.onSubmit(data).then<JSAny?>((_) => null).catchError((Object err) {
        if (mounted) {
          setState(() => _error = 'Não foi possível processar o pagamento.');
        }
        // Relança para o Brick saber que falhou e liberar o botão em vez de
        // ficar preso no estado de loading.
        throw err;
      });
      return future.toJS;
    }).toJS;
    // Obrigatório na prática: sem customization.paymentMethods o SDK falha com
    // "No payment type was selected". 'mercadoPago' fica de fora de propósito
    // (exige preferenceId) e 'ticket' (boleto) também, pois a tela de
    // aguardando confirmação só exibe Pix copia e cola.
    settings['customization'] = <String, Object?>{
      'paymentMethods': {
        'creditCard': 'all',
        'debitCard': 'all',
        'bankTransfer': 'all',
      },
    }.jsify();
    settings['callbacks'] = callbacks;

    final brickPromise = bricksBuilder.callMethodVarArgs(
      'create'.toJS,
      <JSAny?>['payment'.toJS, _viewType.toJS, settings],
    ) as JSPromise<JSObject>;

    final controller = await brickPromise.toDart;
    if (!mounted) {
      // Widget removido enquanto o Brick era criado: desmonta na hora.
      try {
        controller.callMethodVarArgs('unmount'.toJS, <JSAny?>[]);
      } catch (_) {}
      return;
    }
    _brickController = controller;
    _watchForPixEmailField();
  }

  /// Reforço além de initialization.payer.email (suportado pelo SDK também
  /// para Pix). Tenta preencher imediatamente, porque create() pode resolver
  /// depois de o campo já ter sido renderizado; só depois instala o observer
  /// para cobrir a montagem assíncrona ao trocar para Pix. Preenche uma única
  /// vez e não sobrescreve um valor já digitado pelo comprador.
  void _watchForPixEmailField() {
    final email = widget.payerEmail.trim();
    if (email.isEmpty) return;

    // Não dependa de uma mutação futura: o input pode já existir quando
    // bricksBuilder.create() terminar.
    if (_tryAutofillEmail(email)) return;

    final observer = web.MutationObserver(
      ((JSArray<JSAny?> _, web.MutationObserver __) {
        _tryAutofillEmail(email);
      }).toJS,
    );
    observer.observe(
      _container,
      web.MutationObserverInit(childList: true, subtree: true),
    );
    _emailAutofillObserver = observer;
  }

  bool _tryAutofillEmail(String email) {
    if (_emailAutofilled) return true;
    final input = _container.querySelector('input[type="email"]');
    if (input == null) return false;
    final el = input as web.HTMLInputElement;
    if (el.value.trim().isNotEmpty) {
      // O SDK já conseguiu inicializar o campo; não sobrescreva o valor.
      _emailAutofilled = true;
      return true;
    }
    el.value = email;
    el.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    el.dispatchEvent(web.Event('change', web.EventInit(bubbles: true)));
    _emailAutofilled = true;
    return true;
  }

  BrickPaymentSubmitData _parseSubmitData(Object? formData) {
    if (formData is! Map) {
      throw const FormatException('Brick devolveu formData vazio ou inválido.');
    }

    String? asString(Object? value) => value?.toString();

    final payer = formData['payer'];
    final payerMap = payer is Map ? payer : null;
    final identification = payerMap?['identification'];
    final identificationMap = identification is Map ? identification : null;
    final installments = formData['installments'];

    return BrickPaymentSubmitData(
      paymentMethodId: asString(formData['payment_method_id']) ?? '',
      token: asString(formData['token']),
      installments: installments == null ? null : int.tryParse(installments.toString()),
      issuerId: asString(formData['issuer_id']),
      payerEmail: asString(payerMap?['email']) ?? widget.payerEmail,
      payerIdentificationType: asString(identificationMap?['type']),
      payerIdentificationNumber: asString(identificationMap?['number']),
    );
  }

  @override
  void dispose() {
    try {
      _emailAutofillObserver?.disconnect();
    } catch (_) {}
    final controller = _brickController;
    if (controller != null) {
      try {
        controller.callMethodVarArgs('unmount'.toJS, <JSAny?>[]);
      } catch (_) {
        // Melhor esforço — não deve travar o dispose da página.
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: AppSpacing.sm),
          ],
          SizedBox(
            // Altura provisória — ajustar depois de ver o Brick renderizado
            // de verdade (o iframe interno pode precisar de mais/menos
            // espaço conforme o método de pagamento habilitado).
            height: 420,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Sempre presente: o SDK precisa do container no DOM.
                HtmlElementView(viewType: _viewType),
                if (_loading)
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
