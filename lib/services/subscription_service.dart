import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';

class SubscriptionService {
  /// 🔹 RevenueCatから "B-Net"（個人用）のパッケージを取得
  Future<List<Package>> fetchPersonalPackages() async {
    try {
      final Offerings offerings = await Purchases.getOfferings();
      final Offering? offering = offerings.all['B-Net'];
      return offering?.availablePackages ?? [];
    } catch (e) {
      print('❌ パッケージ取得に失敗: $e');
      return [];
    }
  }

  /// 🔹 RevenueCatで購入した情報を Firestore に保存（個人用）
  Future<void> savePersonalSubscriptionToFirestore(
      String userId, CustomerInfo info, String purchasedProductId) async {
    // 購入した productId に応じて見るエンタイトルメントを切り替える
    final bool isAnnualPlan =
        purchasedProductId.contains('12month') ||
        purchasedProductId.contains('annual');
    final String entitlementKey =
        isAnnualPlan ? 'B-Net Annual' : 'B-Net Monthly';

    // デバッグ用ログ：現在のentitlementsの一覧を出す
    print('🧾 all entitlements: ${info.entitlements.all.keys.toList()}');
    print('🧾 active entitlements: ${info.entitlements.active.keys.toList()}');
    print('🧾 期待している entitlementKey: $entitlementKey');

    EntitlementInfo? entitlement = info.entitlements.all[entitlementKey];

    // 指定したキーで見つからない場合は、アクティブなエンタイトルメントにフォールバック
    if (entitlement == null) {
      if (info.entitlements.active.isNotEmpty) {
        entitlement = info.entitlements.active.values.first;
        print(
            '⚠️ Personal entitlement($entitlementKey) が見つからないため、アクティブなentitlement(${entitlement.identifier})を使用します');
      } else {
        print(
            '❌ Personal entitlement($entitlementKey) が見つからず、アクティブなentitlementも存在しません');
        return;
      }
    }

    final String? rawPurchaseDate = entitlement.latestPurchaseDate;
    final purchaseDate = rawPurchaseDate != null
        ? DateTime.parse(rawPurchaseDate)
        : DateTime.now();

    int fallbackDays;
    if (isAnnualPlan) {
      fallbackDays = 365;
    } else {
      fallbackDays = 30; // 月額またはデフォルト
    }

    final String? rawExpiryDate = entitlement.expirationDate;
    final expiryDate = rawExpiryDate != null
        ? DateTime.parse(rawExpiryDate)
        : purchaseDate.add(Duration(days: fallbackDays));

    final platform = Platform.isIOS ? 'iOS' : 'Android';

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('subscription')
          .doc(platform)
          .set({
        'productId': purchasedProductId,
        'purchaseDate': purchaseDate,
        'expiryDate': expiryDate,
        'status': entitlement.isActive ? 'active' : 'inactive',
      });

      print(
          "✅ Firestore に個人サブスク保存: $purchasedProductId (entitlement: ${entitlement.identifier})");
    } catch (e) {
      print('❌ Firestore への個人サブスク保存に失敗: $e');
    }
  }

  /// 🔹 Firestore からサブスクが有効か確認（個人用）
  Future<bool> isUserSubscribed(String userId) async {
    final subRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('subscription');

    final subSnapshot = await subRef.get();

    for (final doc in subSnapshot.docs) {
      final data = doc.data();
      final status = data['status'];
      final expiryTimestamp = data['expiryDate'];

      if (status == 'active' && expiryTimestamp is Timestamp) {
        final expiryDate = expiryTimestamp.toDate();
        if (expiryDate.isAfter(DateTime.now())) {
          return true;
        }
      }
    }

    return false;
  }
}
