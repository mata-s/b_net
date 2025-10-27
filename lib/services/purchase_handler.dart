import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:b_net/services/subscription_service.dart';

Future<void> buySubscription(String userId, Package package) async {
  try {
    print('🎯 購入開始！Package ID: ${package.storeProduct.identifier}');

    // 💳 購入処理
    await Purchases.purchasePackage(package);

    // 🔄 最新のCustomerInfoを取得
    final updatedInfo = await Purchases.getCustomerInfo();

    // 🔍 アクティブなEntitlementからproductIdを取得
    final activeProductId =
        updatedInfo.entitlements.active['B-Net']?.productIdentifier;

    if (activeProductId != null) {
      print('✅ サブスク購入成功: $activeProductId');

      // 🔥 Firestoreに保存（正確な productId を渡す）
      final service = SubscriptionService();
      await service.savePersonalSubscriptionToFirestore(
          userId, updatedInfo, activeProductId);
    } else {
      print('⚠️ サブスクは購入されたが "B-Net" entitlement が有効でない');
    }
  } catch (e) {
    print('❌ 購入中にエラー: $e');
  }
}
