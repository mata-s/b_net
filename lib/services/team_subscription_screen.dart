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

          // 🐛 デバッグ: entitlements と appUserId を確認
    print('🧾 [Team] entitlements.all: ${info.entitlements.all.keys}');
    print('🟢 [Team] entitlements.active: ${info.entitlements.active.keys}');
    print('👤 [Team] appUserId: ${info.originalAppUserId}');


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


// 🐛 購入直後の entitlements の状態を確認
print('🧾 [Team BUY] entitlements.all: ${updatedInfo.entitlements.all.keys}');
print('🟢 [Team BUY] entitlements.active: ${updatedInfo.entitlements.active.keys}');
print('👤 [Team BUY] appUserId: ${updatedInfo.originalAppUserId}');

      // 今回購入した Store Product のID（ゴールド / プラチナ、月額 / 年額 など）
      final purchasedProductId = package.storeProduct.identifier;

      print('🧾 チームプランで購入した productId: $purchasedProductId');

      // 🔥 Firestore に保存（ユーザーが選んだ productId で）
      await TeamSubscriptionService().saveTeamSubscriptionToFirestore(
        widget.teamId,
        updatedInfo,
        purchasedProductId,
      );

      await _loadCustomerInfo();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🎉 チームプランの購入が完了しました")),
      );
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

      // いずれかのチーム用エンタイトルメントが有効なら復元成功とみなす
      final hasTeamEntitlement = [
        'B-Net Team Gold Monthly',
        'B-Net Team Gold Annual',
        'B-Net Team Platina Monthly',
        'B-Net Team Platina Annual',
      ].any((key) => restored.entitlements.active[key] != null);

      if (hasTeamEntitlement) {
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "あなたのチームを、もう一段強く。",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "プランを選んで、使える機能をチーム全員で最大化しよう。",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
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

                    // チーム用エンタイトルメントをプラン（ゴールド / プラチナ）と月額 / 年額で切り替える
                    final bool isAnnualPlan =
                        id.contains('12month') || id.contains('Annual');

                    late final String entitlementKey;
                    if (isPlatina) {
                      // プラチナプラン
                      entitlementKey = isAnnualPlan
                          ? 'B-Net Team Platina Annual'
                          : 'B-Net Team Platina Monthly';
                    } else {
                      // ゴールドプラン
                      entitlementKey = isAnnualPlan
                          ? 'B-Net Team Gold Annual'
                          : 'B-Net Team Gold Monthly';
                    }

                    print('🎫 [Team] 使用する entitlementKey: $entitlementKey');

                    final entitlement =
                        _customerInfo?.entitlements.active[entitlementKey];

                    // このプランに対応するエンタイトルメントが有効なら「登録中」
                    final isSubscribed = entitlement != null;

                    // 🐛 トライアルかどうか判定
                    final isTrial =
                        (entitlement?.periodType ?? PeriodType.normal) ==
                            PeriodType.trial;

                    // ✅ バッジ表示条件
                    final hasFreeTrial = package.storeProduct.introductoryPrice != null;
                    final badge = isMonthly && (isTrial || hasFreeTrial) ? '初月無料' : null;

                    final isNeverPurchased = entitlement == null;

                    // 🔍 デバッグ出力
                    print('🔍 intro price: ${package.storeProduct.introductoryPrice}');
                    print('📦 プラン: $id');
                    print('✅ 現在登録中: $isSubscribed');
                    print('🧪 トライアル中？: $isTrial');
                    print('🆕 未購入？ → $isNeverPurchased');
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
                  const SizedBox(height: 24),
                  const PlanComparisonTable(),
                  SizedBox(height: 24),
                  const TeamFeaturesSection(),
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
                child: Text(disabled ? '登録中' : priceText ?? '購入'),
              ),
            ),
          ],
        ),
      ),
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

class TeamFeaturesSection extends StatelessWidget {
  const TeamFeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final features = [
      TeamFeatureCard(
        icon: Icons.leaderboard,
        title: 'チーム全員でランキングに参加できる',
        description: 'チームの成績がランキングに反映され、\n'
            '全員の活躍が数字で見えるようになります。\n'
            'みんなで上位を目指そう！',
      ),
      TeamFeatureCard(
        icon: Icons.groups,
        title: '全国の強豪チームを覗いてみよう',
        description: '全国の強豪チームの成績や傾向を見ると、刺激と発見が生まれる。\n'
            '次に目指すチーム像が、自然とイメージできます。',
      ),
      TeamFeatureCard(
        icon: Icons.analytics,
        title: 'チーム全体の詳細データがわかる',
        description: '打球の分布や打撃傾向に加えて、投手の傾向も分析。\n'
            'チーム全体の強みと課題がより明確になります。',
      ),
      TeamFeatureCard(
        icon: Icons.stadium,
        title: 'チーム別・球場別の成績も見られる',
        description: 'どのチームに強いか、\n'
            'チームがどの球場と相性がいいかをデータで分析できます。',
      ),
      TeamFeatureCard(
        icon: Icons.flag,
        title: 'チーム目標を決めると、一体感が生まれる',
        description: 'チームで月や年間の目標を共有すると、\n'
            '練習や試合への意識が揃い、達成感をチーム全員で分かち合える強いチームになります。',
      ),
      TeamFeatureCard(
        icon: Icons.emoji_events,
        title: 'チーム内ランキングで盛り上がれる',
        description: '楽しみながら競い合うことで、自然とモチベーションが高まります。',
      ),
      TeamFeatureCard(
        icon: Icons.military_tech,
        title: 'MVP投票で仲間の活躍を称えよう',
        description: '月間・年間MVPをチームで決めて、\n'
            '活躍した仲間をみんなで称えられます。',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "チームプランでできること",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...features,
        ],
      ),
    );
  }
}

class TeamFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const TeamFeatureCard({
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
          Icon(icon, size: 28, color: Colors.deepOrange),
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

class PlanComparisonTable extends StatelessWidget {
  const PlanComparisonTable({super.key});

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
    );

    final cellStyle = TextStyle(
      fontSize: 14,
      height: 1.4,
    );

    Widget check(bool enabled) {
      return Icon(
        enabled ? Icons.check_circle : Icons.remove_circle,
        color: enabled ? Colors.green : Colors.grey,
        size: 20,
      );
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "プラン比較",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(flex: 2, child: Text("機能", style: headerStyle)),
              Expanded(child: Text("ゴールド", style: headerStyle, textAlign: TextAlign.center)),
              Expanded(child: Text("プラチナ", style: headerStyle, textAlign: TextAlign.center)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: Text("チームランキング参加", style: cellStyle)),
              Expanded(child: Align(child: check(false))),
              Expanded(child: Align(child: check(true))),
            ],
          ),
          SizedBox(height: 12),

          // 2
          Row(
            children: [
              Expanded(flex: 2, child: Text("全国強豪チームの閲覧", style: cellStyle)),
              Expanded(child: Align(child: check(false))),
              Expanded(child: Align(child: check(true))),
            ],
          ),
          SizedBox(height: 12),

          // 3
          Row(
            children: [
              Expanded(flex: 2, child: Text("チーム内ランキング", style: cellStyle)),
              Expanded(child: Align(child: check(true))),
              Expanded(child: Align(child: check(true))),
            ],
          ),
          SizedBox(height: 12),

          // 4
          Row(
            children: [
              Expanded(flex: 2, child: Text("詳細データ分析", style: cellStyle)),
              Expanded(child: Align(child: check(true))),
              Expanded(child: Align(child: check(true))),
            ],
          ),
          SizedBox(height: 12),

          // 5
          Row(
            children: [
              Expanded(flex: 2, child: Text("球場別・対戦チーム別成績", style: cellStyle)),
              Expanded(child: Align(child: check(true))),
              Expanded(child: Align(child: check(true))),
            ],
          ),
          SizedBox(height: 12),

          // 6
          Row(
            children: [
              Expanded(flex: 2, child: Text("チーム目標／意識共有", style: cellStyle)),
              Expanded(child: Align(child: check(true))),
              Expanded(child: Align(child: check(true))),
            ],
          ),
          SizedBox(height: 12),

          // 7
          Row(
            children: [
              Expanded(flex: 2, child: Text("MVP投票", style: cellStyle)),
              Expanded(child: Align(child: check(false))),
              Expanded(child: Align(child: check(true))),
            ],
          ),
          SizedBox(height: 12),

          // Per-person monthly price (static)
          Row(
            children: [
              Expanded(flex: 2, child: Text("1人あたり\n（月額・10人計算）", style: cellStyle)),
              Expanded(
                child: Center(
                  child: Text(
                    "150円",
                    style: cellStyle,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "180円",
                    style: cellStyle,
                  ),
                ),
              ),
            ],
          ),
           SizedBox(height: 12),

          Row(
            children: [
              Expanded(flex: 2, child: Text("1人あたり\n（年額換算・10人計算）", style: cellStyle)),
              Expanded(
                child: Center(
                  child: Text(
                    "約133円",
                    style: cellStyle,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "約162円",
                    style: cellStyle),
                  ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
