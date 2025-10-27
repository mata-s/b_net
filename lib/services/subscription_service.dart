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
    final entitlement = info.entitlements.all['B-Net'];
    if (entitlement == null) {
      print('❌ B-Net entitlement が見つかりません');
      return;
    }

    final actualProductId = entitlement.productIdentifier;

    final String? rawPurchaseDate = entitlement.latestPurchaseDate;
    final purchaseDate = rawPurchaseDate != null
        ? DateTime.parse(rawPurchaseDate)
        : DateTime.now();

    int fallbackDays;
    if (actualProductId.contains('12month')) {
      fallbackDays = 365;
    } else if (actualProductId.contains('1month')) {
      fallbackDays = 30;
    } else {
      fallbackDays = 30; // デフォルト
    }

    final String? rawExpiryDate = entitlement.expirationDate;
    final expiryDate = rawExpiryDate != null
        ? DateTime.parse(rawExpiryDate)
        : purchaseDate.add(Duration(days: fallbackDays));

    final platform = Platform.isIOS ? 'iOS' : 'Android';

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

    print("✅ Firestore に個人サブスク保存: $purchasedProductId");
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
