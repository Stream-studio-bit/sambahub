// CHANGELOG
// 2026-09-22: Link público trocado de /c/:slug para /:tenantSlug/:campaignSlug
// (decisão do usuário — ver router.dart, campaigns_repository.dart).
// publicCampaignProvider trocou de FutureProvider.family<PublicCampaign,
// String> (chave = slug) para FutureProvider.family<PublicCampaign,
// ({String tenantSlug, String campaignSlug})> (record como chave — mesmo
// padrão de retorno nomeado já usado em
// CampaignsRepository.getFavoriteState()), chamando
// findByTenantAndCampaignSlug() no lugar do findBySlug() removido.
// - Corrigido: import apontava para '../../public_campaign/data/public_campaign_repository.dart',
//   classe/arquivo inexistente (PublicCampaignRepository não definida) — causa dos erros
//   non_type_as_type_argument e undefined_function no log do analyzer (linhas 6 e 7).
// - Trocado para CampaignsRepository (campaigns_repository.dart), que já implementa
//   findBySlug() e createPublicOrder(), os únicos métodos usados por este controller.
// - Import do domain simplificado para caminho relativo direto (mesmo destino final,
//   antes escrito como '../../campaigns/domain/...' a partir da própria pasta campaigns/data).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaigns_repository.dart';
import '../domain/public_campaign.dart';

final publicCampaignRepositoryProvider = Provider<CampaignsRepository>(
  (ref) => CampaignsRepository(),
);

final publicCampaignProvider = FutureProvider.family<PublicCampaign,
    ({String tenantSlug, String campaignSlug})>(
  (ref, args) => ref.read(publicCampaignRepositoryProvider).findByTenantAndCampaignSlug(
        tenantSlug: args.tenantSlug,
        campaignSlug: args.campaignSlug,
      ),
);

final publicCampaignControllerProvider = Provider<PublicCampaignController>(
  (ref) => PublicCampaignController(ref),
);

final class PublicCampaignController {
  PublicCampaignController(this._ref);

  final Ref _ref;

  Future<Map<String, dynamic>> createOrder({
    required String campaignId,
    required String name,
    required String email,
    required String phone,
    required Map<String, int> products,
    required String idempotencyKey,
  }) {
    return _ref.read(publicCampaignRepositoryProvider).createPublicOrder(
          campaignId: campaignId,
          name: name,
          email: email,
          phone: phone,
          products: products,
          idempotencyKey: idempotencyKey,
        );
  }
}