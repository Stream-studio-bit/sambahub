// lib/features/checkout/presentation/checkout_page.dart
//
// CHANGELOG
// 2026-09-22: Unificação de carrinho (campanha + catálogo).
// - _submit() deixou de montar um único `products` assumindo que todo
//   item do carrinho é CampaignProduct. Agora itera cart.items.values e
//   separa por item.product.source (CartProductSource, de cart_item.dart):
//   itens 'campaign' entram no map `products`, itens 'catalog' entram no
//   novo map `catalogProducts` — ambos com `item.product.id` (id cru da
//   tabela de origem) como chave, não `cartKey` (o backend espera o id
//   real da tabela, cartKey é um detalhe interno do carrinho). Ambos os
//   maps são passados para controller.submit(products: ..., catalogProducts:
//   ...), que agora aceita o segundo parâmetro (checkout_controller.dart).
// - Import de cart_item.dart adicionado só para o enum CartProductSource.
// - Nenhuma outra parte do arquivo mudou: _orderSummary já lia
//   item.product.name/item.totalCents, que continuam existindo em
//   CartProductRef sem alteração; _PaymentStep, _CustomerForm, estados de
//   pagamento aprovado/aguardando/erro, tudo fora de escopo e intocado.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../cart/domain/cart_item.dart';
import '../../cart/domain/cart_state.dart';
import 'checkout_controller.dart';
import 'mercadopago_payment_brick.dart';
import '../domain/checkout_request.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({required this.campaignId, super.key});

  final String campaignId;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  String? _paymentError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<CheckoutFlowState?>>(checkoutControllerProvider,
        (_, next) {
      next.whenOrNull(
        data: (flow) {
          final payment = flow?.payment;
          if (payment != null &&
              (payment.isApproved || payment.isAwaitingConfirmation)) {
            ref.read(cartControllerProvider.notifier).clear();
          }
          if (payment == null || !payment.isRejected) {
            setState(() => _paymentError = null);
          }
        },
        error: (error, _) {
          if (!mounted) return;
          setState(() {
            _paymentError =
                error is CheckoutPaymentException ? error.message : _friendlyError(error);
          });
        },
      );
    });

    final cart = ref.watch(cartControllerProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final order = ref.read(checkoutControllerProvider.notifier).currentOrder;
    final payment = checkout.valueOrNull?.payment;

    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar pedido')),
      body: cart.isEmpty && order == null
          ? const _EmptyCheckout()
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
                  AppSpacing.md, AppSpacing.section),
              children: [
                Text('Quase lá.', style: AppTypography.textTheme.displaySmall),
                const SizedBox(height: AppSpacing.sm),
                Text('Informe seus dados para receber a confirmação do pedido.',
                    style: AppTypography.textTheme.bodyLarge
                        ?.copyWith(color: AppColors.muted)),
                const SizedBox(height: AppSpacing.xl),
                _orderSummary(cart),
                const SizedBox(height: AppSpacing.xl),
                if (payment != null && payment.isApproved)
                  _PaymentApproved(orderId: order!.orderId)
                else if (payment != null && payment.isAwaitingConfirmation)
                  _PaymentAwaitingConfirmation(
                      orderId: order!.orderId, payment: payment)
                else if (order != null)
                  _PaymentStep(
                    order: order,
                    payerEmail: _email.text,
                    error: _paymentError,
                  )
                else
                  _CustomerForm(
                    formKey: _formKey,
                    name: _name,
                    email: _email,
                    phone: _phone,
                    isLoading: checkout.isLoading,
                    onSubmit: _submit,
                  ),
              ],
            ),
    );
  }

  Widget _orderSummary(CartState cart) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumo do pedido', style: AppTypography.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...cart.items.values.map<Widget>((item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text('${item.quantity}× ${item.product.name}')),
                    Text(_formatCents(item.totalCents))
                  ]))),
          const Divider(height: AppSpacing.lg),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total', style: AppTypography.textTheme.titleMedium),
            Text(_formatCents(cart.totalCents),
                style: AppTypography.textTheme.titleLarge
                    ?.copyWith(color: AppColors.wine))
          ]),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cart = ref.read(cartControllerProvider);
    final products = <String, int>{};
    final catalogProducts = <String, int>{};
    for (final item in cart.items.values) {
      switch (item.product.source) {
        case CartProductSource.campaign:
          products[item.product.id] = item.quantity;
        case CartProductSource.catalog:
          catalogProducts[item.product.id] = item.quantity;
      }
    }
    await ref.read(checkoutControllerProvider.notifier).submit(
        campaignId: widget.campaignId,
        customerName: _name.text,
        customerEmail: _email.text,
        customerPhone: _phone.text,
        products: products,
        catalogProducts: catalogProducts);
  }

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst('Exception: ', 'Não foi possível finalizar: ');
  String _formatCents(int cents) =>
      'R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';
}

class _CustomerForm extends StatelessWidget {
  const _CustomerForm({
    required this.formKey,
    required this.name,
    required this.email,
    required this.phone,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Form(
        key: formKey,
        child: Column(
          children: [
            AppInput(
                label: 'Nome completo',
                controller: name,
                textInputAction: TextInputAction.next,
                validator: _required('Informe seu nome.')),
            const SizedBox(height: AppSpacing.sm),
            AppInput(
                label: 'E-mail',
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: _emailValidator),
            const SizedBox(height: AppSpacing.sm),
            AppInput(
                label: 'Telefone',
                controller: phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                validator: (value) => value == null || value.trim().length < 8
                    ? 'Informe um telefone válido.'
                    : null),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
                label: 'Continuar para pagamento',
                size: AppButtonSize.large,
                isFullWidth: true,
                isLoading: isLoading,
                onPressed: isLoading ? null : onSubmit),
            const SizedBox(height: AppSpacing.md),
            Text(
                'O pagamento será processado com segurança pelo Mercado Pago.',
                textAlign: TextAlign.center,
                style: AppTypography.textTheme.bodySmall),
          ],
        ),
      );

  FormFieldValidator<String> _required(String message) =>
      (value) => value == null || value.trim().isEmpty ? message : null;
  String? _emailValidator(String? value) => value == null ||
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
      ? 'Informe um e-mail válido.'
      : null;
}

/// Pedido já criado: embute o Payment Brick. order.mercadopagoPublicKey é
/// garantido não-nulo aqui — o controller já joga CheckoutPaymentException
/// em submit() quando vem null, então esse estado nunca chega com order
/// preenchido e public_key ausente.
class _PaymentStep extends ConsumerWidget {
  const _PaymentStep({
    required this.order,
    required this.payerEmail,
    this.error,
  });

  final CheckoutResult order;
  final String payerEmail;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pedido criado', style: AppTypography.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        SelectableText('Código do pedido: ${order.orderId}',
            style: AppTypography.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        if (error != null) ...[
          AppCard(
              child: Text(error!,
                  style: AppTypography.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.error))),
          const SizedBox(height: AppSpacing.md),
        ],
        MercadoPagoPaymentBrick(
          publicKey: order.mercadopagoPublicKey!,
          amount: (order.grossAmount ?? 0).toDouble(),
          payerEmail: payerEmail,
          onSubmit: (data) =>
              ref.read(checkoutControllerProvider.notifier).submitPayment(data),
        ),
      ],
    );
  }
}

class _PaymentApproved extends StatelessWidget {
  const _PaymentApproved({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) => AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Text('Pagamento aprovado!',
              style: AppTypography.textTheme.titleMedium),
        ]),
        const SizedBox(height: AppSpacing.xs),
        SelectableText('Código do pedido: $orderId'),
        const SizedBox(height: AppSpacing.xs),
        Text('Você vai receber a confirmação por e-mail.',
            style: AppTypography.textTheme.bodySmall),
      ]));
}

class _PaymentAwaitingConfirmation extends StatelessWidget {
  const _PaymentAwaitingConfirmation({required this.orderId, required this.payment});
  final String orderId;
  final PaymentResult payment;

  @override
  Widget build(BuildContext context) {
    final poi = payment.pointOfInteraction;
    return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.hourglass_top_rounded, color: AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        Text('Aguardando confirmação do pagamento',
            style: AppTypography.textTheme.titleMedium),
      ]),
      const SizedBox(height: AppSpacing.xs),
      SelectableText('Código do pedido: $orderId'),
      if (poi?.qrCode != null) ...[
        const SizedBox(height: AppSpacing.md),
        Text('Pix copia e cola:', style: AppTypography.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(poi!.qrCode!,
            style: AppTypography.textTheme.bodySmall
                ?.copyWith(color: AppColors.muted)),
      ],
      const SizedBox(height: AppSpacing.xs),
      Text('A confirmação chega automaticamente assim que o pagamento cair.',
          style: AppTypography.textTheme.bodySmall),
    ]));
  }
}

class _EmptyCheckout extends StatelessWidget {
  const _EmptyCheckout();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('Adicione ingressos ao carrinho antes de finalizar.'));
}