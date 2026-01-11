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

  Future<void> _bootstrap() async {
    // 起動直後（再起動含む）は RevenueCat が anonymous のままになりやすいので
    // Firebase のログイン状態に合わせて必ず user:{uid} を確定させてから読み込みを行う。
    await _ensureUserRevenueCatLogin();
    await _loadPackages();
    await _loadCustomerInfo();
  }

  Future<void> _ensureUserRevenueCatLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final targetId = 'user:${user.uid}';

    try {
      final currentId = await Purchases.appUserID;
      // print('👤 RevenueCat current appUserId(before): $currentId');

      if (currentId != targetId) {
        // 直前に anonymous や team: になっている可能性があるため、確実に user:{uid} に寄せる
        try {
          await Purchases.logOut();
        } catch (_) {
          // ignore
        }
        await Purchases.logIn(targetId);
        // ignore: unused_local_variable
        final after = await Purchases.appUserID;
        // print('👤 RevenueCat current appUserId(after) : $after');
      }
    } catch (e) {
      print('❌ RevenueCat logIn エラー: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
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
      // 現在の RevenueCat appUserID を先に確認（anonymous か user/team か）
      // ignore: unused_local_variable
      final currentId = await Purchases.appUserID;
      // print('👤 current appUserId: $currentId');

      final info = await Purchases.getCustomerInfo();

      // print('🧾 entitlements.all: ${info.entitlements.all.keys}');
      // print('🟢 entitlements.active: ${info.entitlements.active.keys}');

      // 🔎 デバッグ：Google Play の base plan / offer だと productIdentifier が base だけ返ることがある
      // print('🧾 activeSubscriptions: ${info.activeSubscriptions}');
      // print('🧾 allPurchasedProductIdentifiers: ${info.allPurchasedProductIdentifiers}');
      // print('🧾 latestExpirationDate: ${info.latestExpirationDate}');

      // purchases_flutter v8系では CustomerInfo.appUserId が無いので、現在の appUserID は Purchases から取得する
//       final currentAppUserId = await Purchases.appUserID;
//       print('👤 current appUserId(from Purchases): $currentAppUserId');
//       print('👤 originalAppUserId: ${info.originalAppUserId}');
//       final activeEnt = info.entitlements.active['personal_premium'];
// if (activeEnt != null) {
//   print('🔎 active entitlement key: personal_premium');
//   print('🔎 active productIdentifier: ${activeEnt.productIdentifier}');
//   print('🔎 active expirationDate: ${activeEnt.expirationDate}');
//   print('🔎 active willRenew: ${activeEnt.willRenew}');
//   print('🔎 active periodType: ${activeEnt.periodType}');
//   print('🔎 active latestPurchaseDate: ${activeEnt.latestPurchaseDate}');
//   print('🔎 active store: ${activeEnt.store}');
// } else {
//   print('🔎 active entitlement personal_premium: null');
// }

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
    await _ensureUserRevenueCatLogin();

    try {
      // 💳 購入処理（この時点でCustomerInfoは最新ではない可能性あり）
      await Purchases.purchasePackage(package);

      // 🔄 最新のCustomerInfoを取得
      final updatedInfo = await Purchases.getCustomerInfo();

      // 今回購入した Store Product のID（1ヶ月 / 12ヶ月 など）
      final purchasedProductId = package.storeProduct.identifier;

      // print('🧾 購入した productId: $purchasedProductId');

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
    await _ensureUserRevenueCatLogin();

    try {
      final restoredInfo = await Purchases.restorePurchases();
      final entitlement = restoredInfo.entitlements.all['personal_premium'];
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
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return Scaffold(
      // backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        // backgroundColor: Colors.grey.shade100,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "個人プラン",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _restorePurchase,
            child: const Text("復元", style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: _openSubscriptionSettings,
            child: const Text("設定", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 16,
                vertical: 16,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 720 : double.infinity,
                  ),
                  child: Column(
                    children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "あなたの野球を、もう一段楽しく。",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  "記録・分析・目標・ランキングなど、成長が見える。\n野球がもっと面白くなる機能が解放されます。",
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ..._packages.map((package) {
                    final id = package.storeProduct.identifier;
                    
                    // iOS: com.sk.bNet.app.personal1month / personal12month
                    // Android: com.sk.bnet.app.personal:personal-monthly / personal-yearly
                    bool _isMonthlyProduct(String productId) {
                      final p = productId.toLowerCase();
                      return p.contains('1month') || p.contains('monthly');
                    }
                    
                    bool _isYearlyProduct(String productId) {
                      final p = productId.toLowerCase();
                      return p.contains('12month') || p.contains('yearly') || p.contains('annual');
                    }
                    
                    final isMonthly = _isMonthlyProduct(id);
                    final isYearly = _isYearlyProduct(id);

                    // 画像（判定できない場合は年額側に寄せる）
                    final imagePath = isMonthly
                        ? 'assets/Subscription_personal1month.png'
                        : 'assets/Subscription_personal12month.png';

                    // 表示文言（判定できない場合は「プラン」表記）
                    final planTitle = isMonthly
                        ? '月額プラン'
                        : (isYearly ? '年額プラン' : 'プラン');

                    final planDescription = isMonthly
                        ? '初回1ヶ月無料！\n2ヶ月目から自動更新されます。\nいつでもキャンセル可能。'
                        : (isYearly
                            ? '1年間まとめて支払い。\n月額よりお得な価格設定です。'
                            : 'プラン内容をご確認ください。');
                    
                  const String entitlementKey = 'personal_premium';
                  final entitlement = _customerInfo?.entitlements.active[entitlementKey];

                  // ✅ 有効な商品ID（iOSは productId、Androidは base product だけ返るケースあり）
                  final String? activeProductId = entitlement?.productIdentifier;

                  // ✅ CustomerInfo.activeSubscriptions が一番確実（Androidは base:plan が入ることが多い）
                  final activeSubs = _customerInfo?.activeSubscriptions ?? <String>[];

                  bool _matchesActive(String packageId) {
                    if (activeSubs.isNotEmpty) {
                      // 1) そのまま一致
                      if (activeSubs.contains(packageId)) return true;
                      // 2) base:plan 形式のどちらかが prefix になっている場合も拾う
                      return activeSubs.any((s) =>
                          s == packageId ||
                          s.startsWith('$packageId:') ||
                          packageId.startsWith('$s:'));
                    }

                    // fallback: entitlement.productIdentifier だけで判断（Androidは base だけ返ることがある）
                    if (activeProductId == null || activeProductId.isEmpty) return false;
                    if (activeProductId == packageId) return true;
                    // packageId が "base:plan" で、activeProductId が "base" の場合
                    if (packageId.startsWith('$activeProductId:')) return true;
                    // 逆（念のため）
                    if (activeProductId.startsWith('$packageId:')) return true;
                    return false;
                  }

                  // ✅ 月/年カードごとに「このpackageが登録中か」を判定
                  final bool isSubscribed = _matchesActive(id);

                  final bool isTrial = isSubscribed &&
                      (entitlement?.periodType ?? PeriodType.normal) == PeriodType.trial;
                      
                    // 月額プランで、トライアル中のときだけ「初月無料」バッヂ
                    final String? badge = (isMonthly && isTrial) ? '初月無料' : null;
                    
                    // デバッグ：このカードが何か/有効 product は何か
                  // print('🧾 [card] id=$id, activeProductId=$activeProductId, activeSubs=${(_customerInfo?.activeSubscriptions ?? const [])}, isSubscribed=$isSubscribed, isTrial=$isTrial');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: SubscriptionPlanCard(
                        imagePath: imagePath,
                        title: planTitle,
                        description: planDescription,
                        badge: badge,
                        priceText: isSubscribed ? '登録中' : '購入',
                        onPressed: isSubscribed ? null : () => _buy(package),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  const PremiumFeaturesSection(),
                  
                  const SubscriptionLegalSection(
                    privacyPolicyUrl: 'https://baseball-net.vercel.app/privacy',
                    termsUrl: 'https://baseball-net.vercel.app/terms',
                  ),
                    ],
                  ),
                ),
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

class SubscriptionLegalSection extends StatelessWidget {
  final String privacyPolicyUrl;
  final String termsUrl;

  const SubscriptionLegalSection({
    super.key,
    required this.privacyPolicyUrl,
    required this.termsUrl,
  });

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await canLaunchUrl(uri);
    if (ok) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ リンクを開けませんでした')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 12, height: 1.5);
    const appleEulaUrl =
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

    final linkStyle = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.primary,
      decorationColor: Theme.of(context).colorScheme.primary,
    );

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'サブスクリプションについて',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '・「月額プラン」は 1か月ごとの自動更新サブスクリプションです。',
            style: textStyle,
          ),
          const Text(
            '・「年額プラン」は 1年ごとの自動更新サブスクリプションです。',
            style: textStyle,
          ),
          const Text(
            '・料金は購入確定時に（iOSはApple ID、AndroidはGoogle Play）に請求されます。',
            style: textStyle,
          ),
          const Text(
            '・現在の期間が終了する24時間前までに自動更新をオフにしない限り、自動的に更新されます。',
            style: textStyle,
          ),
          const Text(
            '・解約/プラン変更は、アプリ内ではなく App Store / Google Play のサブスクリプション管理から行えます。解約しても、現在の請求期間が終了するまでは利用できます。',
            style: textStyle,
          ),
          const Text(
            '・（iOS）設定アプリ ＞ Apple ID ＞ サブスクリプション',
            style: textStyle,
          ),
          const Text(
            '・（Android）Google Play ＞ お支払いと定期購入 ＞ 定期購入',
            style: textStyle,
          ),
          const Text(
            '・無料トライアルがある場合、トライアル終了後に自動的に有料期間に切り替わります。',
            style: textStyle,
          ),
          const Text(
            '・無料トライアルを利用している場合、トライアル期間中に解約しても請求は発生しません。',
            style: textStyle,
          ),
          const Text(
            '・購入の復元（機種変更時など）は、画面右上の「復元」から行えます。',
            style: textStyle,
          ),
          const Text(
            '・払い戻し（返金）については、Apple / Google の規定に従い、原則としてストア側での対応となります。',
            style: textStyle,
          ),
          const Text(
            '・プランの有効期間中は、解約しても機能がすぐに止まることはありません（期間終了まで利用できます）。',
            style: textStyle,
          ),
          const Text(
            '・アプリ内の表示や利用可否は、ストアの購読状態（有効/失効）に基づいて反映されます。反映に少し時間がかかる場合があります。',
            style: textStyle,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              GestureDetector(
                onTap: () => _openUrl(context, privacyPolicyUrl),
                child: Text('プライバシーポリシー', style: linkStyle),
              ),
              GestureDetector(
                onTap: () => _openUrl(context, termsUrl),
                child: Text('利用規約', style: linkStyle),
              ),
              GestureDetector(
                onTap: () => _openUrl(context, appleEulaUrl),
                child: Text('Apple 標準利用規約 (EULA)', style: linkStyle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}