import 'package:b_net/services/team_subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class TeamSubscriptionScreen extends StatefulWidget {
  final String teamId;

  const TeamSubscriptionScreen({Key? key, required this.teamId})
      : super(key: key);

  @override
  State<TeamSubscriptionScreen> createState() => _TeamSubscriptionScreenState();
}

class _TeamSubscriptionScreenState extends State<TeamSubscriptionScreen> {
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
      final packages = List<Package>.from(
        offerings.all['B-Net Team']?.availablePackages ?? [],
      );

      print(
          "📦 チームパッケージ: ${packages.map((p) => p.storeProduct.identifier).toList()}");

      setState(() {
        _packages = packages;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ パッケージ取得エラー: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomerInfo() async {
    try {
      final info = await Purchases.getCustomerInfo();
      setState(() {
        _customerInfo = info;
      });
    } catch (e) {
      print('❌ チーム購読情報の取得に失敗: $e');
    }
  }

  Future<void> _buy(Package package) async {
    try {
      // 💳 購入処理（この時点ではCustomerInfoが最新でない場合もある）
      await Purchases.purchasePackage(package);

      // 🔄 最新のCustomerInfoを取得
      final updatedInfo = await Purchases.getCustomerInfo();

      // 🔍 現在アクティブなエンタイトルメントから productId を取得
      final actualProductId =
          updatedInfo.entitlements.active['B-Net Team']?.productIdentifier;

      if (actualProductId != null) {
        // 🔥 Firestore に保存
        await TeamSubscriptionService().saveTeamSubscriptionToFirestore(
          widget.teamId,
          updatedInfo,
          actualProductId,
        );

        await _loadCustomerInfo();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🎉 チームプランの購入が完了しました")),
        );
      } else {
        print("⚠️ アクティブなチームプランが見つかりません");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ 購入は完了しましたが、プランの確認に失敗しました")),
        );
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("キャンセルされました")),
        );
      } else {
        print("❌ チーム購入エラー: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ 購入に失敗しました: ${e.message}")),
        );
      }
    } catch (e) {
      print("❌ 予期せぬエラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ 予期せぬエラーが発生しました")),
      );
    }
  }

  Future<void> _restore() async {
    try {
      final restored = await Purchases.restorePurchases();
      if (restored.entitlements.active['B-Net Team'] != null) {
        await _loadCustomerInfo();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ チームの購入を復元しました")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ℹ️ 復元できるチームの購入が見つかりませんでした")),
        );
      }
    } catch (e) {
      print("❌ チーム復元エラー: $e");
    }
  }

  Future<void> _openSubscriptionSettings() async {
    final url = Theme.of(context).platform == TargetPlatform.iOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print('❌ 開けませんでした: $url');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アカウント設定ページを開けませんでした')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("チームプレミアムプラン"),
        actions: [
          TextButton(
            onPressed: _restore,
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
                  GoldFeaturesSection(),
                  PlatinumFeaturesSection(),
                  SizedBox(height: 24),
                  ..._packages.map((package) {
                    final id = package.storeProduct.identifier;
                    final isMonthly =
                        id.contains('1month') || !id.contains('12month');
                    final isPlatina = id.contains('Platina');

                    final imagePath = isPlatina
                        ? (isMonthly
                            ? 'assets/Subscription_teamPlatina.png'
                            : 'assets/Subscription_teamPlatina12month.png')
                        : (isMonthly
                            ? 'assets/Subscription_teamGold.png'
                            : 'assets/Subscription_teamGold12month.png');
                    final title = isPlatina
                        ? (isMonthly ? 'プラチナプラン（月額）' : 'プラチナプラン（年額）')
                        : (isMonthly ? 'ゴールドプラン（月額）' : 'ゴールドプラン（年額）');
                    final description = isPlatina
                        ? (isMonthly
                            ? '初月無料！プラチナ限定特典付き。\n月額課金でいつでも解約可能。'
                            : '1年間まとめて支払い。\n月額よりもお得な価格設定です。')
                        : (isMonthly
                            ? '初月無料！2ヶ月目から月額課金。\nいつでもキャンセル可能。'
                            : '1年間まとめて支払い。\n月額よりもお得な価格設定です。');

                    final entitlement =
                        _customerInfo?.entitlements.active['B-Net Team'];
                    final activeProductId = entitlement?.productIdentifier;
                    final isSubscribed = activeProductId == id;

// 🐛 トライアルかどうか判定
                    final isTrial =
                        (entitlement?.periodType ?? PeriodType.normal) ==
                            PeriodType.trial;

// ✅ バッジ表示条件
                    final badge = isMonthly && isTrial ? '初月無料' : null;

// 🔍 デバッグ出力
                    print('📦 プラン: $id');
                    print('✅ 現在登録中: $isSubscribed');
                    print('🧪 トライアル中？: $isTrial');
                    print('🏷 バッジ表示: ${badge ?? "なし"}');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: SubscriptionPlanCard(
                        imagePath: imagePath,
                        title: title,
                        description: description,
                        badge: badge,
                        disabled: isSubscribed,
                        onPressed: isSubscribed ? null : () => _buy(package),
                        priceText: isSubscribed ? '登録中' : '購入',
                      ),
                    );
                  }),
                  SizedBox(height: 32),
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
  final bool disabled;
  final String? badge;
  final VoidCallback? onPressed;
  final String? priceText;

  const SubscriptionPlanCard({
    required this.imagePath,
    required this.title,
    required this.description,
    this.disabled = false,
    this.badge,
    this.onPressed,
    this.priceText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(imagePath),
            ),
            SizedBox(height: 12),
            Text(description, style: TextStyle(fontSize: 14, height: 1.4)),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: disabled ? null : onPressed,
                child: Text(disabled ? '購入できません' : priceText ?? '購入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoldFeaturesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FeatureBox(
      title: "🥇 ゴールドプランでできること",
      color: Colors.amber.shade100,
      borderColor: Colors.amber,
      features: [
        FeatureBullet(icon: Icons.emoji_events, text: "都道府県ランキングに参加して、腕試し！"),
        FeatureBullet(icon: Icons.sports_baseball, text: "ライバルと競って記録を更新しよう！"),
        FeatureBullet(icon: Icons.groups, text: "ヒット数で県内チームに貢献！他県に勝とう！"),
      ],
    );
  }
}

class PlatinumFeaturesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FeatureBox(
      title: "💎 プラチナプランでできること",
      color: Colors.blue.shade50,
      borderColor: Colors.blueAccent,
      features: [
        FeatureBullet(icon: Icons.emoji_events, text: "都道府県ランキングに参加できる！"),
        FeatureBullet(icon: Icons.star, text: "全国ランキングの1位の成績をチェック可能！"),
        FeatureBullet(icon: Icons.bar_chart, text: "詳細な成績分析機能が解放！"),
        FeatureBullet(icon: Icons.lock_open, text: "今後追加される全ての機能が利用可能！"),
      ],
    );
  }
}

class FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeatureBullet({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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

class FeatureBox extends StatelessWidget {
  final String title;
  final List<FeatureBullet> features;
  final Color color;
  final Color borderColor;

  const FeatureBox({
    required this.title,
    required this.features,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: borderColor,
            ),
          ),
          SizedBox(height: 16),
          ...features,
        ],
      ),
    );
  }
}
