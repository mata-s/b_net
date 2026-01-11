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
  String userId,
  CustomerInfo info,
  String purchasedProductId,
) async {
  const String entitlementKey = 'personal_premium'; // ← RCのEntitlement Identifier

  print('🧾 all entitlements: ${info.entitlements.all.keys.toList()}');
  print('🧾 active entitlements: ${info.entitlements.active.keys.toList()}');
  print('🧾 期待している entitlementKey: $entitlementKey');

  // 基本は active を見る（all だとinactiveも混ざる）
  EntitlementInfo? entitlement = info.entitlements.active[entitlementKey];

  if (entitlement == null) {
    print('❌ Personal entitlement($entitlementKey) がactiveに存在しません');
    return;
  }

  final purchaseDate = DateTime.tryParse(entitlement.latestPurchaseDate) ?? DateTime.now();
  final expiryDate = DateTime.tryParse(entitlement.expirationDate ?? '') ??
      purchaseDate.add(const Duration(days: 30));

  final platform = Platform.isIOS ? 'iOS' : 'Android';

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('subscription')
      .doc(platform)
      .set({
    'productId': purchasedProductId,
    'purchaseDate': Timestamp.fromDate(purchaseDate),
    'expiryDate': Timestamp.fromDate(expiryDate),
    'status': entitlement.isActive ? 'active' : 'inactive',
    'platform': platform,
    'entitlementId': entitlement.identifier, // ← 保存しておくとデバッグ強い
  });

  print("✅ Firestore に個人サブスク保存: $purchasedProductId (entitlement: ${entitlement.identifier})");
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
