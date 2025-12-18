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

    print('🧾 entitlements.all: ${info.entitlements.all.keys}');
    print('🟢 entitlements.active: ${info.entitlements.active.keys}');
    print('👤 appUserId: ${info.originalAppUserId}');

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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("個人プラン"),
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
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      "あなたの野球を、もう一段楽しく。",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
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
                  const SizedBox(height: 24),
                  const PremiumFeaturesSection(),
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
  const PremiumFeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final features = [
      _PremiumFeatureCard(
        icon: Icons.leaderboard,
        title: 'ランキングに参加しよう！',
        description: '数字で成長が見えると、野球がもっと楽しくなる。\n'
            'あなたもランキングに参加してみよう！',
      ),
      _PremiumFeatureCard(
        icon: Icons.flag_circle,
        title: '都道府県対抗ヒットバトル',
        description: 'あなたの一打が地元のスコアに加算される。\n'
            '都道府県ごとのヒット合計で順位が決まる白熱バトル！',
      ),
      _PremiumFeatureCard(
        icon: Icons.workspace_premium,
        title: '全国トップ選手を覗いてみよう',
        description: '全国の強者の成績を見ると、刺激と発見がある。\n'
            'あなたの次の目標が自然と見つかります。',
      ),
      _PremiumFeatureCard(
        icon: Icons.analytics,
        title: '打撃のさらに詳細がわかる',
        description: '打球の分布や打撃傾向など、\n'
            'いつもの成績表では見えない打撃のクセが見えてきます。',
      ),
      _PremiumFeatureCard(
        icon: Icons.stadium,
        title: 'チーム別・球場別の成績も見られる',
        description: 'どのチーム相手に強いか、\n'
            'どの球場と相性がいいかをデータで分析できます。',
      ),
      _PremiumFeatureCard(
        icon: Icons.flag,
        title: '目標を決めると、野球がもっと楽しくなる',
        description: '月の目標や、1年のテーマを決めるだけで、\n'
            '野球に取り組む毎日がもっとワクワクします。',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "有料プランでできること",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "このプランに登録すると、こんな機能が使えるようになります。",
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...features,
        ],
      ),
    );
  }
}

class _PremiumFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PremiumFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 28,
            color: Colors.deepOrange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
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