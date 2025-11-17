import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';

class TeamSubscriptionService {
  /// 🔹 RevenueCatから "B-Net Team"（チーム用）のパッケージを取得
  Future<List<Package>> fetchTeamPackages() async {
    try {
      final Offerings offerings = await Purchases.getOfferings();
      final Offering? offering = offerings.all['B-Net Team'];
      return offering?.availablePackages ?? [];
    } catch (e) {
      print('❌ チーム用パッケージ取得に失敗: $e');
      return [];
    }
  }

  /// 🔹 RevenueCatで購入した情報を Firestore に保存（チーム用）
  Future<void> saveTeamSubscriptionToFirestore(
      String teamId, CustomerInfo info, String actualProductId) async {
    // 購入した productId に応じてチーム用エンタイトルメントを切り替える
    final bool isAnnualPlan =
        actualProductId.contains('12month') ||
        actualProductId.contains('Annual');
    final bool isPlatinaPlan = actualProductId.contains('teamPlatina');

    final String entitlementKey = isPlatinaPlan
        ? (isAnnualPlan
            ? 'B-Net Team Platina Annual'
            : 'B-Net Team Platina Monthly')
        : (isAnnualPlan
            ? 'B-Net Team Gold Annual'
            : 'B-Net Team Gold Monthly');

    final entitlement = info.entitlements.all[entitlementKey];
    if (entitlement == null) {
      print('❌ Team entitlement($entitlementKey) が見つかりません');
      return;
    }

    // ✅ 購入日
    final String? rawPurchaseDate = entitlement.latestPurchaseDate;
    final DateTime purchaseDate = rawPurchaseDate != null
        ? DateTime.parse(rawPurchaseDate)
        : DateTime.now();

    // ✅ プランに応じた期間（年額 or 月額で判断）
    int fallbackDays;
    if (isAnnualPlan) {
      fallbackDays = 365;
    } else {
      fallbackDays = 30;
    }

    // ✅ 有効期限
    final String? rawExpiryDate = entitlement.expirationDate;
    final expiryDate = rawExpiryDate != null
        ? DateTime.parse(rawExpiryDate)
        : purchaseDate.add(Duration(days: fallbackDays));

    final platform = Platform.isIOS ? 'iOS' : 'Android';

    await FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .collection('subscription')
        .doc(platform)
        .set({
      'productId': actualProductId,
      'purchaseDate': purchaseDate,
      'expiryDate': expiryDate,
      'status': entitlement.isActive ? 'active' : 'inactive',
    });

    print("✅ Firestore にチームサブスク保存: $actualProductId (entitlement: $entitlementKey)");
  }

  /// 🔹 Firestore からチームのサブスクが有効か確認
  Future<bool> isTeamSubscribed(String teamId) async {
    final subRef = FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
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
