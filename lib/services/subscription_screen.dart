import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:b_net/services/subscription_service.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends StatefulWidget {
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<Package> _packages = [];
  bool _isLoading = true;
  CustomerInfo? _customerInfo;

  @override
  void initState() {
    super.initState();
    _loadPackages();
    _loadCustomerInfo();
  }

  Future<void> _loadPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final packages = offerings.all['B-Net']?.availablePackages ?? [];

      if (!mounted) return;
      setState(() {
        _packages = packages;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ パッケージ取得エラー: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomerInfo() async {
    try {
      final info = await Purchases.getCustomerInfo();
      if (!mounted) return;
      setState(() {
        _customerInfo = info;
      });
    } catch (e) {
      print('❌ 購読情報の取得に失敗: $e');
    }
  }

  Future<void> _buy(Package package) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 💳 購入処理（この時点でCustomerInfoは最新ではない可能性あり）
      await Purchases.purchasePackage(package);

      // 🔄 最新のCustomerInfoを取得
      final updatedInfo = await Purchases.getCustomerInfo();

      // 今回購入した Store Product のID（1ヶ月 / 12ヶ月 など）
      final purchasedProductId = package.storeProduct.identifier;

      print('🧾 購入した productId: $purchasedProductId');

      // 🔥 Firestore に保存（ユーザーが選んだ productId で）
      await SubscriptionService().savePersonalSubscriptionToFirestore(
        user.uid,
        updatedInfo,
        purchasedProductId,
      );

      // 📲 UI 更新のため再取得
      await _loadCustomerInfo();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🎉 購入が完了しました")),
      );
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("キャンセルされました")),
        );
      } else {
        print('❌ 購入エラー: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("エラーが発生しました: ${e.message}")),
        );
      }
    } catch (e) {
      print('❌ 未知のエラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("予期せぬエラーが発生しました")),
      );
    }
  }

  Future<void> _restorePurchase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final restoredInfo = await Purchases.restorePurchases();
      final entitlement = restoredInfo.entitlements.all['B-Net'];
      final purchasedProductId = entitlement?.productIdentifier ?? 'unknown';

      if (entitlement != null) {
        await SubscriptionService().savePersonalSubscriptionToFirestore(
          user.uid,
          restoredInfo,
          purchasedProductId,
        );
        await _loadCustomerInfo();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ 購入を復元しました")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ℹ️ 復元できる購入が見つかりませんでした")),
        );
      }
    } catch (e) {
      print('❌ 復元エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ 復元に失敗しました")),
      );
    }
  }

  Future<void> _openSubscriptionSettings() async {
    final url = Theme.of(context).platform == TargetPlatform.iOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 設定画面を開けませんでした')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("サブスクリプション"),
        actions: [
          TextButton(
            onPressed: _restorePurchase,
            child: Text("復元", style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: _openSubscriptionSettings,
            child: Text("設定", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  PremiumFeaturesSection(),
                  SizedBox(height: 20),
                  ..._packages.map((package) {
                    final id = package.storeProduct.identifier;
                    final isMonthly = id.contains('1month');
                    final imagePath = isMonthly
                        ? 'assets/Subscription_personal1month.png'
                        : 'assets/Subscription_personal12month.png';

                    // プランごとに見るエンタイトルメントを切り替える
                    final bool isAnnualPlan =
                        id.contains('12month') || id.contains('annual');
                    final String entitlementKey =
                        isAnnualPlan ? 'B-Net Annual' : 'B-Net Monthly';

                    final entitlement =
                        _customerInfo?.entitlements.active[entitlementKey];

                    // このプランに対応するエンタイトルメントが有効なら「登録中」
                    final isSubscribed = entitlement != null;

                    // トライアルかどうか
                    final isTrial =
                        (entitlement?.periodType ?? PeriodType.normal) ==
                            PeriodType.trial;

                    final isNeverPurchased = entitlement == null;

                    // 🔍 デバッグ出力
                    print('🔍 intro price: ${package.storeProduct.introductoryPrice}');
                    print('📦 プラン: $id');
                    print('🎫 使用する entitlementKey: $entitlementKey');
                    print('✅ 現在登録中: $isSubscribed');
                    print('🧪 現在トライアル中？ → $isTrial');
                    print('🆕 未購入？ → $isNeverPurchased');

                    // 月額プランで、トライアル中またはまだ未購入なら「初月無料」バッジ
                    final badge = (isMonthly && (isTrial || isNeverPurchased))
                        ? '初月無料'
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: SubscriptionPlanCard(
                        imagePath: imagePath,
                        title: isMonthly ? '月額プラン' : '年額プラン',
                        description: isMonthly
                            ? '初回1ヶ月無料！\n2ヶ月目から自動更新されます。\nいつでもキャンセル可能。'
                            : '1年間まとめて支払い。\n月額よりお得な価格設定です。',
                        badge: badge,
                        priceText: isSubscribed ? '登録中' : '購入',
                        onPressed: isSubscribed ? null : () => _buy(package),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class SubscriptionPlanCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;
  final String? badge;
  final String? priceText;
  final VoidCallback? onPressed;

  const SubscriptionPlanCard({
    required this.imagePath,
    required this.title,
    required this.description,
    this.badge,
    this.priceText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!,
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            SizedBox(height: 8),
            Text(title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(imagePath),
            ),
            SizedBox(height: 12),
            Text(description,
                style: TextStyle(
                    fontSize: 14, height: 1.4, color: Colors.black87)),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                child: Text(priceText ?? '購入'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class PremiumFeaturesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🎖️ プレミアムプランの特典",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
          SizedBox(height: 16),
          FeatureBullet(icon: Icons.emoji_events, text: "都道府県ランキングに参加して、腕試し！"),
          FeatureBullet(
              icon: Icons.sports_baseball, text: "ライバルと競い合いながら、記録をどんどん伸ばそう！"),
          FeatureBullet(icon: Icons.groups, text: "ヒット数で県内チームに貢献！他県に勝利を！"),
          FeatureBullet(
              icon: Icons.star, text: "全国のトッププレイヤーの成績をチェックして刺激を受けよう！"),
        ],
      ),
    );
  }
}

class FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeatureBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepOrange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
