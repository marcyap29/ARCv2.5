// lib/chronicle/dual/services/dual_chronicle_services.dart
//
// Shared instances for dual chronicle so UI and agentic loop use the same
// PromotionService (pending offers visible in settings).

import '../repositories/user_chronicle_repository.dart';
import '../repositories/lumara_chronicle_repository.dart';
import '../storage/chronicle_storage.dart';
import 'promotion_service.dart';

/// Shared dual chronicle services. Use these so the Chronicle settings UI
/// and the agentic loop share the same promotion offers and repositories.
abstract final class DualChronicleServices {
  static ChronicleStorage? _storage;
  static UserChronicleRepository? _userRepo;
  static LumaraChronicleRepository? _lumaraRepo;
  static PromotionOfferStore? _offerStore;
  static PromotionService? _promotionService;

  static ChronicleStorage get storage => _storage ??= ChronicleStorage();
  static UserChronicleRepository get userChronicle => _userRepo ??= UserChronicleRepository(storage);
  static LumaraChronicleRepository get lumaraChronicle => _lumaraRepo ??= LumaraChronicleRepository(storage);
  static PromotionOfferStore get promotionOfferStore => _offerStore ??= PromotionOfferStore();
  static PromotionService get promotionService =>
      _promotionService ??= PromotionService(
        userChronicleRepo: userChronicle,
        lumaraChronicleRepo: lumaraChronicle,
        offerStore: promotionOfferStore,
      );
}
