import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config.dart';
import 'storage.dart';

/// "Remove ads" non-consumable purchase. Failure-tolerant: when billing is
/// unavailable (e.g. sideloaded build) the UI simply reports it.
class IapService extends ChangeNotifier {
  IapService(this.store);
  final Store store;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? product;
  bool available = false;
  bool busy = false;
  String? message;

  String get priceLabel => product?.price ?? '';

  Future<void> init() async {
    try {
      final iap = InAppPurchase.instance;
      available = await iap.isAvailable();
      if (!available) return;
      _sub = iap.purchaseStream.listen(_onPurchases, onError: (_) {});
      final resp = await iap.queryProductDetails({AppConfig.removeAdsProductId});
      if (resp.productDetails.isNotEmpty) product = resp.productDetails.first;
      notifyListeners();
    } catch (e) {
      debugPrint('IAP init failed: $e');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != AppConfig.removeAdsProductId) {
        if (p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
        continue;
      }
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          store.setAdsRemoved(true);
          message = 'Ads removed. Thank you!';
          busy = false;
          break;
        case PurchaseStatus.error:
          message = 'Purchase failed. Please try again.';
          busy = false;
          break;
        case PurchaseStatus.canceled:
          busy = false;
          break;
        case PurchaseStatus.pending:
          busy = true;
          break;
      }
      if (p.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(p);
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> buyRemoveAds() async {
    final p = product;
    if (!available || p == null) {
      message = 'Store unavailable right now.';
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (_) {
      busy = false;
      message = 'Could not start purchase.';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (!available) {
      message = 'Store unavailable right now.';
      notifyListeners();
      return;
    }
    try {
      await InAppPurchase.instance.restorePurchases();
      message = 'Checking your purchases...';
    } catch (_) {
      message = 'Could not restore purchases.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
