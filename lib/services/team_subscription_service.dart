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
    String teamId,
    CustomerInfo info,
    String actualProductId,
  ) async {
    // ✅ Entitlement は RevenueCat 側で `team` に統一
    // active が取れないケースもあるので all もフォールバック
    final entitlement =
        info.entitlements.active['team'] ?? info.entitlements.all['team'];

    if (entitlement == null) {
      print('❌ Team entitlement(team) が見つかりません');
      print('🧾 entitlements.active keys: ${info.entitlements.active.keys}');
      print('🧾 entitlements.all keys: ${info.entitlements.all.keys}');
      return;
    }

    // productId からプラン種別を推定（表示用/保存用）
    final bool isAnnualPlan =
        actualProductId.contains('12month') ||
        actualProductId.toLowerCase().contains('annual');
    final bool isPlatinaPlan =
        actualProductId.toLowerCase().contains('teamplatina');

    // 現在のチームプラン表示名
    final String planName = isPlatinaPlan ? 'プラチナプラン' : 'ゴールドプラン';
    final String billingPeriod = isAnnualPlan ? '1年' : '1ヶ月';

    // ✅ 購入日
    final String? rawPurchaseDate = entitlement.latestPurchaseDate;
    final DateTime purchaseDate = rawPurchaseDate != null
        ? DateTime.parse(rawPurchaseDate)
        : DateTime.now();

    // ✅ プランに応じた期間（年額 or 月額で判断）
    final int fallbackDays = isAnnualPlan ? 365 : 30;

    // ✅ 有効期限
    final String? rawExpiryDate = entitlement.expirationDate;
    final DateTime expiryDate = rawExpiryDate != null
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
      'planName': planName, // ゴールドプラン / プラチナプラン
      'billingPeriod': billingPeriod, // 1ヶ月 / 1年
      'purchaseDate': purchaseDate,
      'expiryDate': expiryDate,
      'status': entitlement.isActive ? 'active' : 'inactive',
    });

    print('✅ Firestore にチームサブスク保存: $actualProductId (entitlement: team)');
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