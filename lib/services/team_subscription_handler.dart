import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:b_net/services/team_subscription_service.dart';

Future<void> buyTeamSubscription(String teamId, Package package) async {
  try {
    print('🎯 購入開始！Package ID: ${package.storeProduct.identifier}');

    // 💳 購入処理（この時点ではCustomerInfoが最新でない可能性あり）
    await Purchases.purchasePackage(package);

    // 🔄 最新のCustomerInfoを取得
    final updatedInfo = await Purchases.getCustomerInfo();

    // 🔍 現在アクティブなEntitlement（チーム）の productId を取得
    final activeProductId =
        updatedInfo.entitlements.active['B-Net Team']?.productIdentifier;

    if (activeProductId != null) {
      print('✅ チームサブスク購入成功: $activeProductId');

      // 🔥 Firestore に保存
      final service = TeamSubscriptionService();
      await service.saveTeamSubscriptionToFirestore(
        teamId,
        updatedInfo,
        activeProductId,
      );
    } else {
      print('⚠️ チームサブスクは購入されたが "B-Net Team" entitlement が有効でない');
    }
  } catch (e) {
    print('❌ チーム購入中にエラー: $e');
  }
}
