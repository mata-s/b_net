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

  bool _isMonthlyProduct(String productId) {
    final p = productId.toLowerCase();
    return p.contains('1month') || p.contains('monthly');
  }

  bool _isYearlyProduct(String productId) {
    final p = productId.toLowerCase();
    return p.contains('12month') || p.contains('yearly') || p.contains('annual');
  }

  bool _hasEverPurchasedMonthly() {
    final ids = _customerInfo?.allPurchasedProductIdentifiers ?? <String>[];
    if (ids.isEmpty) return false;

    // RevenueCat/Store では `base:offer` のように返ることがあるので prefix も許容
    return ids.any((id) {
      final lower = id.toLowerCase();
      return _isMonthlyProduct(lower);
    });
  }

  bool _isSubscribedToPackageId(String packageId) {
    const String entitlementKey = 'personal_premium';
    final entitlement = _customerInfo?.entitlements.active[entitlementKey];
    final String? activeProductId = entitlement?.productIdentifier;
    final activeSubs = _customerInfo?.activeSubscriptions ?? <String>[];

    if (activeSubs.isNotEmpty) {
      if (activeSubs.contains(packageId)) return true;
      return activeSubs.any((s) =>
          s == packageId ||
          s.startsWith('$packageId:') ||
          packageId.startsWith('$s:'));
    }

    if (activeProductId == null || activeProductId.isEmpty) return false;
    if (activeProductId == packageId) return true;
    if (packageId.startsWith('$activeProductId:')) return true;
    if (activeProductId.startsWith('$packageId:')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    final Package? monthlyPackage = _packages.cast<Package?>().firstWhere(
      (p) => p != null && _isMonthlyProduct(p.storeProduct.identifier),
      orElse: () => null,
    );
    final Package? yearlyPackage = _packages.cast<Package?>().firstWhere(
      (p) => p != null && _isYearlyProduct(p.storeProduct.identifier),
      orElse: () => null,
    );

    const int monthlyPrice = 480;
    const int yearlyPrice = 4980;
    const int yearlySavings = monthlyPrice * 12 - yearlyPrice; // 780
    final int yearlyPerMonth = (yearlyPrice / 12).round(); // 415

    final bool isMonthlySubscribed = monthlyPackage == null
        ? false
        : _isSubscribedToPackageId(monthlyPackage.storeProduct.identifier);
    final bool isYearlySubscribed = yearlyPackage == null
        ? false
        : _isSubscribedToPackageId(yearlyPackage.storeProduct.identifier);

    // trial判定（月額のみでOK）
    const String entitlementKey = 'personal_premium';
    final entitlement = _customerInfo?.entitlements.active[entitlementKey];
    final bool isTrial = (isMonthlySubscribed || isYearlySubscribed) &&
        (entitlement?.periodType ?? PeriodType.normal) == PeriodType.trial;
    final bool hasEverPurchasedMonthly = _hasEverPurchasedMonthly();

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
      bottomNavigationBar: (_isLoading || (monthlyPackage == null && yearlyPackage == null))
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (monthlyPackage != null)
                      _PlanSelectTile(
                        titleLeft: '月額プラン',
                        subtitleLeft: null,
                        badgeText: isMonthlySubscribed
                            ? null
                            : (isTrial
                                ? '初月無料'
                                : (hasEverPurchasedMonthly ? null : '初回無料')),
                        priceRight: '${monthlyPrice}円/月',
                        subPriceRight: null,
                        isSubscribed: isMonthlySubscribed,
                        onTap: isMonthlySubscribed ? null : () => _buy(monthlyPackage),
                      ),
                    if (yearlyPackage != null) const SizedBox(height: 10),
                    if (yearlyPackage != null)
                      _PlanSelectTile(
                        titleLeft: '年額プラン',
                        subtitleLeft: null,
                        badgeText: '年間${yearlySavings}円お得',
                        priceRight: '${yearlyPrice}円/年',
                        subPriceRight: '${yearlyPerMonth}円/月',
                        isSubscribed: isYearlySubscribed,
                        onTap: isYearlySubscribed ? null : () => _buy(yearlyPackage),
                      ),
                  ],
                ),
              ),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final hasPlans = !(monthlyPackage == null && yearlyPackage == null);

                // bottomNavigationBar の実高さを厳密に取れないので、だいたいの高さを見積もる
                // ここを確保しておくと、コンテンツが短い時でも「規約」を下に寄せられる。
                final double estimatedBottomBarHeight = !hasPlans
                    ? 0
                    : (monthlyPackage != null && yearlyPackage != null)
                        ? 170
                        : 95;

                final contentHorizontal = isTablet ? 40.0 : 16.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    contentHorizontal,
                    16,
                    contentHorizontal,
                    // 下の余白は“最小限”にして、余った分は Spacer で吸収して規約を下に寄せる
                    16,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 720 : double.infinity,
                        // 画面の残り高さを埋める（余った分は Spacer が吸収）
                        minHeight: (constraints.maxHeight - estimatedBottomBarHeight)
                            .clamp(0.0, double.infinity),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            const SizedBox(height: 24),
                            const PremiumFeaturesSection(),

                            // 🔻 ここがポイント：余った分を吸収して「規約」を下に寄せる
                            const Spacer(),

                            const SubscriptionLegalSection(
                              privacyPolicyUrl:
                                  'https://baseball-net.vercel.app/privacy',
                              termsUrl: 'https://baseball-net.vercel.app/terms',
                            ),

                            // bottomNavigationBar に隠れないように最低限の余白だけ入れる
                            if (hasPlans) const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SubscriptionPlanCard extends StatelessWidget {
  final String title;
  final String description;
  final String? badge;
  final String? priceText;
  final VoidCallback? onPressed;

  const SubscriptionPlanCard({
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
            '■ プランの種類\n'
            '・「月額プラン」は 1か月ごとの自動更新サブスクリプションです。\n'
            '・「年額プラン」は 1年ごとの自動更新サブスクリプションです。',
            style: textStyle,
          ),
          const SizedBox(height: 10),

          const Text(
            '■ 料金の請求について\n'
            '・料金は購入確定時に、ご利用のストアアカウントに請求されます。',
            style: textStyle,
          ),
          const SizedBox(height: 10),

          const Text(
            '■ 自動更新について\n'
            '・本プランは自動更新のサブスクリプションです。\n'
            '・現在の期間が終了する24時間前までに解約しない限り、自動的に更新されます。\n'
            '・更新時には、次回分の料金が同じストアアカウントに請求されます。',
            style: textStyle,
          ),
          const SizedBox(height: 10),

          const Text(
            '■ 解約（自動更新の停止）・プラン変更\n'
            '・解約/プラン変更は、アプリ内ではなく、ご利用のストアのサブスクリプション管理画面から行えます。\n'
            '・解約しても、現在の請求期間が終了するまでは機能を利用できます。',
            style: textStyle,
          ),
          const SizedBox(height: 10),

          const Text(
            '■ 無料トライアルについて\n'
            '・無料トライアルがある場合、トライアル終了後に自動的に有料期間に切り替わります。\n'
            '・無料トライアルを利用している場合、トライアル期間中に解約しても請求は発生しません。',
            style: textStyle,
          ),
          const SizedBox(height: 10),

          const Text(
            '■ 購入の復元について\n'
            '・購入の復元（機種変更時など）は、画面右上の「復元」から行えます。',
            style: textStyle,
          ),
          const SizedBox(height: 10),

          const Text(
            '■ 返金について\n'
            '・購入後の返金可否や手続きは、各ストアのポリシーに従います。\n'
            '・返金を希望する場合は、ご利用のストアのサポート窓口からお手続きください。',
            style: textStyle,
          ),
          const SizedBox(height: 10),

          const Text(
            '■ その他\n'
            '・プランの有効期間中は、解約しても機能がすぐに止まることはありません（期間終了まで利用できます）。\n'
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
              if (Theme.of(context).platform == TargetPlatform.iOS)
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
class _PlanSelectTile extends StatelessWidget {
  final String titleLeft;
  final String? subtitleLeft;
  final String? badgeText;
  final String priceRight;
  final String? subPriceRight;
  final bool isSubscribed;
  final VoidCallback? onTap;

  const _PlanSelectTile({
    required this.titleLeft,
    required this.subtitleLeft,
    required this.badgeText,
    required this.priceRight,
    required this.subPriceRight,
    required this.isSubscribed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isSubscribed || onTap == null;

    return Material(
      color: disabled ? Colors.grey.shade200 : Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleLeft,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: disabled ? Colors.black87 : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(disabled ? 0.8 : 0.95),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitleLeft != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitleLeft!,
                        style: TextStyle(
                          color: disabled ? Colors.black54 : Colors.white70,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isSubscribed ? '登録中' : priceRight,
                    style: TextStyle(
                      color: disabled ? Colors.black87 : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!isSubscribed && subPriceRight != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subPriceRight!,
                      style: TextStyle(
                        color: disabled ? Colors.black54 : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 10),
              if (!isSubscribed)
                Icon(
                  Icons.chevron_right,
                  color: disabled ? Colors.black45 : Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}