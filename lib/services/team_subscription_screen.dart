import 'package:b_net/services/team_subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamSubscriptionScreen extends StatefulWidget {
  final String teamId;

  const TeamSubscriptionScreen({Key? key, required this.teamId})
      : super(key: key);

  @override
  State<TeamSubscriptionScreen> createState() => _TeamSubscriptionScreenState();
}

class _TeamSubscriptionScreenState extends State<TeamSubscriptionScreen>
    with SingleTickerProviderStateMixin {
  List<Package> _packages = [];
  bool _isLoading = true;
  // ignore: unused_field
  CustomerInfo? _customerInfo;
  String? _subscriptionOwnerUid;
  String? _teamOwnerUid;
  bool _loadingOwner = true;
  List<_TeamMember> _teamMembers = [];
  Map<String, dynamic>? _teamSub;
  bool _loadingTeamSub = true;
  bool _isPlanPanelExpanded = false;

//デバックしたい時に true
  static const bool _billingDebugLog =  false;

   void _log(String message) {
    if (_billingDebugLog) {
      debugPrint(message);
    }
  }

  String get _platformKey {
    final p = defaultTargetPlatform;
    return p == TargetPlatform.iOS ? 'iOS' : 'Android';
  }

  String _planNameFromProductId(String productId) {
    final idLower = productId.trim().toLowerCase();

    // Gold (Monthly)
    if (idLower == 'com.sk.bnet.teamgold.monthly' ||
        idLower == 'com.sk.bnet.team:gold-monthly') {
      return 'ゴールドプラン';
    }

    // Gold (Yearly)
    if (idLower == 'com.sk.bnet.teamgold.yearly' ||
        idLower == 'com.sk.bnet.team:gold-yearly') {
      return 'ゴールドプラン';
    }

    // Platina (Monthly)
    if (idLower == 'com.sk.bnet.teamplatina.monthly' ||
        idLower == 'com.sk.bnet.team:platina-monthly') {
      return 'プラチナプラン';
    }

    // Platina (Yearly)
    if (idLower == 'com.sk.bnet.teamplatina.yearly' ||
        idLower == 'com.sk.bnet.team:platina-yearly') {
      return 'プラチナプラン';
    }

    // フォールバック（IDに含まれていれば判定）
    final isPlatina = idLower.contains('platina');
    final isGold = idLower.contains('gold');
    if (isPlatina) return 'プラチナプラン';
    if (isGold) return 'ゴールドプラン';

    return '不明なプラン';
  }

  bool _isYearlyProductId(String productId) {
    final idLower = productId.trim().toLowerCase();
    return idLower.contains('12month') || idLower.contains('yearly');
  }

  // 料金（表示は固定でこの値にする）
  String _overridePriceLabel(String productId) {
    final idLower = productId.trim().toLowerCase();
    final isPlatina = idLower.contains('platina');
    final isGold = idLower.contains('gold');
    final isYearly = _isYearlyProductId(productId);

    if (isGold && !isYearly) return '1000円/月';
    if (isGold && isYearly) return '10000円/年';
    if (isPlatina && !isYearly) return '1500円/月';
    if (isPlatina && isYearly) return '13000円/年';

    return '';
  }

  String? _badgeLabelForProduct(String productId) {
    final idLower = productId.trim().toLowerCase();
    final isPlatina = idLower.contains('platina');
    final isGold = idLower.contains('gold');
    final isYearly = _isYearlyProductId(productId);

    if (!isYearly) return null;

    // 年額のお得バッジ（固定）
    if (isGold) return '年間2000円お得';
    if (isPlatina) return '年間5000円お得';
    return 'お得';
  }

  String _monthlyEquivalentLabel(String productId) {
    final idLower = productId.trim().toLowerCase();
    final isPlatina = idLower.contains('platina');
    final isGold = idLower.contains('gold');
    final isYearly = _isYearlyProductId(productId);

    if (!isYearly) return '';

    // 年額 -> 月換算（四捨五入）
    if (isGold) return '${(10000 / 12).round()}円/月';
    if (isPlatina) return '${(13000 / 12).round()}円/月';
    return '';
  }

  double _collapsedPlanListHeight() => 0;

  double _expandedPlanListHeight(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    // できるだけ「全プランが見える」高さを確保する（端末高さに合わせて上限あり）
    // 目安：1カードあたりの高さ + 間隔で必要高さを概算
    final int n = _packages.isEmpty ? 4 : _packages.length;
    const double tileH = 120.0; // optionTile の概算高さ（端末差を吸収するため少し余裕）
    const double gap = 10.0; // optionTile の bottom padding
    final needed = (n * tileH) + ((n - 1) * gap);

    // 画面を覆い過ぎない上限（ただし今の 450 上限だと4件が少し隠れることがあるので緩める）
    final maxH = (h * 0.62).clamp(340.0, 560.0);

    // ここで必要高さに寄せつつ、上限を超えない
    return needed.clamp(300.0, maxH);
  }

  double _bottomPanelTotalHeight(BuildContext context) {
    // Header/handle/title/paddings roughly
    const headerChrome = 92.0;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final listH = _isPlanPanelExpanded
        ? _expandedPlanListHeight(context)
        : _collapsedPlanListHeight();
    return headerChrome + listH + safeBottom;
  }

  Widget _buildPlanOptionsBottomPanel() {
    final String activeProductIdRaw =
        (_teamSub?['productId'] ?? '').toString().trim();
    final String activeProductIdLower = activeProductIdRaw.toLowerCase();
    final bool isTeamActive =
        (_teamSub?['status'] ?? '').toString().trim() == 'active';

    final listHeight = _isPlanPanelExpanded
        ? _expandedPlanListHeight(context)
        : _collapsedPlanListHeight();

    Widget optionTile(Package p) {
      final id = p.storeProduct.identifier.trim();
      final idLower = id.toLowerCase();

      final isPlatina = idLower.contains('platina');
      final baseName = isPlatina ? 'プラチナ' : 'ゴールド';
      final isYearly = _isYearlyProductId(id);

      final priceMain = _overridePriceLabel(id).isNotEmpty
          ? _overridePriceLabel(id)
          : p.storeProduct.priceString;

      final badge = _badgeLabelForProduct(id);
      final priceSub = isYearly ? _monthlyEquivalentLabel(id) : '';

      final isSubscribed =
          isTeamActive && activeProductIdLower.isNotEmpty && activeProductIdLower == idLower;
      final disabled = isSubscribed || !_isSubscriptionOwner;

      // Any.do風：行全体が選択肢。説明は出さず、バッジだけ。
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: disabled
                ? null
                : () async {
                    await _buy(p);
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isPlatina
                    ? const Color(0xFFEDE7F6) // プラチナ：上品なラベンダー
                    : const Color(0xFFFFF8E1), // ゴールド：やわらかいゴールド
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSubscribed ? Colors.deepPurple : Colors.grey.shade200,
                  width: isSubscribed ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // バッジ（縦並び：年額/月額 + お得）
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isYearly
                                    ? Colors.deepPurple.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isYearly ? '年額' : '月額',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isYearly
                                      ? Colors.deepPurple
                                      : Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (badge != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  badge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                        Text(
                          '$baseNameプラン',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        priceMain,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (priceSub.isNotEmpty)
                        Text(
                          priceSub,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                          ],
                        ),
                        if (isSubscribed) ...[
                          const SizedBox(height: 6),
                          const Text(
                            '登録中',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else if (!_isSubscriptionOwner) ...[
                          const SizedBox(height: 6),
                          const Text(
                            '購入不可（支払い担当のみ）',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    color: disabled ? Colors.grey.shade400 : Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.grey.shade100,
      child: SafeArea(
        top: false,
        // bottom: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Text(
                              '料金プラン',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 8),
                            if (isTeamActive && activeProductIdRaw.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '現在：${_planNameFromProductId(activeProductIdRaw)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.deepPurple,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _isPlanPanelExpanded ? '閉じる' : '開く',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isPlanPanelExpanded = !_isPlanPanelExpanded;
                          });
                        },
                        icon: AnimatedRotation(
                          turns: _isPlanPanelExpanded ? 0.0 : 0.5,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_packages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('プラン情報を取得できませんでした。')),
                    )
                  else
                    // 下の領域だけスクロール（背面説明は別でスクロールできる）
                    ClipRect(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        height: listHeight,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          opacity: _isPlanPanelExpanded ? 1 : 0,
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            offset: _isPlanPanelExpanded
                                ? Offset.zero
                                : const Offset(0, 0.04),
                            child: ListView(
                              padding: EdgeInsets.only(
                                bottom: 12 + MediaQuery.of(context).padding.bottom,
                              ),
                              physics: const BouncingScrollPhysics(),
                              children: _packages.map(optionTile).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTeamOwnerInfo();
    _loadTeamMembers();
    _loadTeamSubscription();
    _loadPackages();
    _loadCustomerInfo();
  }
  Future<void> _loadTeamSubscription() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('subscription')
          .doc(_platformKey)
          .get();

      if (!mounted) return;
      setState(() {
        _teamSub = doc.data();
        _loadingTeamSub = false;
      });
    } catch (e) {
      print('❌ チーム購読(teams側)の取得に失敗: $e');
      if (!mounted) return;
      setState(() {
        _teamSub = null;
        _loadingTeamSub = false;
      });
    }
  }

  Future<void> _loadPackages() async {
    try {
      _log('🧾 [_loadPackages] start');

      final offerings = await Purchases.getOfferings();
      _log('🧾 offerings.current: ${offerings.current?.identifier}');
      _log('🧾 offerings.all keys: ${offerings.all.keys.toList()}');

      for (final entry in offerings.all.entries) {
        final off = entry.value;
        final ids = off.availablePackages
            .map((p) => p.storeProduct.identifier)
            .toList();
        _log('🧾 offering=${off.identifier} packages=$ids');
      }

      // Prefer the specific offering key, but fall back safely.
      final Offering? target =
          offerings.all['B-Net Team'] ?? offerings.current ??
          (offerings.all.isNotEmpty ? offerings.all.values.first : null);

      if (target == null) {
        _log('❌ offerings has no target offering (current/all empty)');
        if (!mounted) return;
        setState(() {
          _packages = [];
          _isLoading = false;
        });
        return;
      }

      // Deduplicate (some offerings can accidentally include the same product twice)
      final uniqueById = <String, Package>{};
      for (final p in target.availablePackages) {
        uniqueById[p.storeProduct.identifier] = p;
      }
      final packages = uniqueById.values.toList();

      // Sort in a predictable order: Gold monthly/yearly, Platina monthly/yearly
      int rank(Package p) {
        final id = p.storeProduct.identifier.trim().toLowerCase();
        final isPlatina = id.contains('platina');
        final isGold = id.contains('gold');
        final isYearly = id.contains('12month') || id.contains('yearly');
        final base = isGold
            ? 0
            : (isPlatina ? 2 : 4); // unknowns go last
        final period = isYearly ? 1 : 0;
        return base + period;
      }

      packages.sort((a, b) => rank(a).compareTo(rank(b)));

      _log(
        '🧾 [picked] offering=${target.identifier} packages: ${packages.map((p) => p.storeProduct.identifier).toList()}',
      );
      for (final p in packages) {
        final sp = p.storeProduct;
        _log(
          '🧾 [pkg] type=${p.packageType} id=${sp.identifier} title=${sp.title} price=${sp.priceString} currency=${sp.currencyCode}',
        );
      }

      if (!mounted) return;
      setState(() {
        _packages = packages;
        _isLoading = false;
      });
    } catch (e, st) {
      _log('❌ パッケージ取得エラー: $e');
      _log('❌ stack: $st');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomerInfo() async {
    try {
      final info = await Purchases.getCustomerInfo();
      // ignore: unused_local_variable
      final currentAppUserId = await Purchases.appUserID;

      setState(() {
        _customerInfo = info;
      });
    } catch (e) {
      print('❌ チーム購読情報の取得に失敗: $e');
    }
  }

  Future<void> _loadTeamOwnerInfo() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _subscriptionOwnerUid = null;
          _teamOwnerUid = null;
          _loadingOwner = false;
        });
        return;
      }

      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .get();

      final data = teamDoc.data() ?? {};

      // 代表者UID（フィールド名が違う可能性があるので候補を複数見る）
      final teamOwnerUid = (data['ownerUid'] ?? data['createdBy'] ?? data['adminUid'])?.toString();

      // 支払い担当UID（Map: subscriptionOwner.uid を参照。未設定なら代表者をデフォルトに）
      String? subscriptionOwnerUid;
      final subOwner = data['subscriptionOwner'];
      if (subOwner is Map) {
        final v = subOwner['uid'];
        if (v != null) subscriptionOwnerUid = v.toString();
      }
      subscriptionOwnerUid ??= teamOwnerUid;

      setState(() {
        _teamOwnerUid = teamOwnerUid;
        _subscriptionOwnerUid = subscriptionOwnerUid;
        _loadingOwner = false;
      });
    } catch (e) {
      print('❌ チーム支払い担当の取得に失敗: $e');
      setState(() {
        _loadingOwner = false;
      });
    }
  }

  bool get _isSubscriptionOwner {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return _subscriptionOwnerUid != null && uid == _subscriptionOwnerUid;
  }

  bool get _isTeamOwner {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return _teamOwnerUid != null && uid == _teamOwnerUid;
  }

  String get _subscriptionOwnerName {
    if (_subscriptionOwnerUid == null) return '未設定';
    final m = _teamMembers.where((e) => e.uid == _subscriptionOwnerUid).toList();
    if (m.isEmpty) return '未設定';
    return m.first.name;
  }

  Future<void> _showChangeSubscriptionOwnerDialog() async {
    // 権限：チーム代表者のみ変更可能
    if (!_isTeamOwner) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ 支払い担当の変更はチーム代表者のみ可能です')),
      );
      return;
    }

    // メンバー一覧が空なら取得
    if (_teamMembers.isEmpty) {
      await _loadTeamMembers();
    }

    final selectedUid = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  '支払い担当を選択',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                splashRadius: 20,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          children: [
            if (_teamMembers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('メンバーが見つかりません'),
              ),
            ..._teamMembers.map((m) {
              final isCurrent = m.uid == _subscriptionOwnerUid;
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, m.uid),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.name,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      const Text(
                        '現在',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );

    if (selectedUid == null) return;

     // ✅ すでに他チームで「課金担当(subscriptionOwner)」になっているユーザーは選べない
    try {
      final alreadyOwnerQuery = await FirebaseFirestore.instance
          .collection('teams')
          .where('subscriptionOwner.uid', isEqualTo: selectedUid)
          .get();

      final otherTeamOwner = alreadyOwnerQuery.docs.any((d) => d.id != widget.teamId);

      if (otherTeamOwner) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ このユーザーはすでに別チームの支払い担当です。別のメンバーを選択してください。'),
          ),
        );
        return;
      }
      } catch (e) {
      // チェックに失敗した場合は安全に止める（誤って設定変更しない）
      print('❌ 支払い担当の重複チェックに失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ 支払い担当の確認に失敗しました。時間をおいて再度お試しください。')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .update({
        'subscriptionOwner': {
          'uid': selectedUid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 支払い担当を更新しました')),
      );

      await _loadTeamOwnerInfo();
      await _loadTeamMembers();
    } catch (e) {
      print('❌ 支払い担当の更新に失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ 支払い担当の更新に失敗しました')),
      );
    }
  }

  Future<void> _loadTeamMembers() async {
    try {
      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .get();

      final data = teamDoc.data() ?? {};
      final memberUids = List<String>.from(data['members'] ?? []);

      if (memberUids.isEmpty) {
        if (!mounted) return;
        setState(() => _teamMembers = []);
        return;
      }

      // whereIn は最大10件。超える可能性がある場合は分割。
      final List<_TeamMember> members = [];
      const int chunkSize = 10;

      for (int i = 0; i < memberUids.length; i += chunkSize) {
        final chunk = memberUids.sublist(
          i,
          (i + chunkSize > memberUids.length) ? memberUids.length : i + chunkSize,
        );

        final userSnaps = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in userSnaps.docs) {
          final u = doc.data();
          final name = (u['displayName'] ?? u['name'] ?? '名前未設定').toString();
          members.add(_TeamMember(uid: doc.id, name: name));
        }
      }

      // members の順序を teamDoc の members 配列順に揃える
      members.sort((a, b) {
        final ia = memberUids.indexOf(a.uid);
        final ib = memberUids.indexOf(b.uid);
        return ia.compareTo(ib);
      });

      if (!mounted) return;
      setState(() => _teamMembers = members);
    } catch (e) {
      print('❌ チームメンバーの取得に失敗: $e');
      if (!mounted) return;
      setState(() => _teamMembers = []);
    }
  }

  Future<void> _buy(Package package) async {
    try {
      // 🔒 安全派：支払い担当は「明示変更」。購入だけでは自動で切り替えない。
      // ここでは「支払い担当UIDと一致するユーザーだけ購入可能」にする。
      if (_loadingOwner) {
        await _loadTeamOwnerInfo();
      }

      if (!_isSubscriptionOwner) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ このチームの支払い担当ではありません。チーム代表者に「支払い担当」を変更してもらってください。'),
          ),
        );
        return;
      }

      // 💳 購入処理（この時点ではCustomerInfoが最新でない場合もある）
      await Purchases.purchasePackage(package);

      // 🔄 最新のCustomerInfoを取得
      final updatedInfo = await Purchases.getCustomerInfo();
      // ignore: unused_local_variable
      final currentAppUserId = await Purchases.appUserID;

      // 今回購入した Store Product のID（ゴールド / プラチナ、月額 / 年額 など）
      final purchasedProductId = package.storeProduct.identifier;

      // 🔥 Firestore に保存（ユーザーが選んだ productId で）
      await TeamSubscriptionService().saveTeamSubscriptionToFirestore(
        widget.teamId,
        updatedInfo,
        purchasedProductId,
      );

      await _loadCustomerInfo();
      await _loadTeamSubscription();

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
        await _loadTeamSubscription();
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
      ('❌ 開けませんでした: $url');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アカウント設定ページを開けませんでした')),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("チームプラン"),
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
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isIpad = constraints.maxWidth >= 600;
                final horizontalPadding = isIpad ? 20.0 : 16.0;
                final maxContentWidth = isIpad ? 720.0 : double.infinity;

                final bottomPanelHeight = _bottomPanelTotalHeight(context);

                return Column(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxContentWidth),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.only(
                              left: horizontalPadding,
                              right: horizontalPadding,
                              top: 16,
                              bottom: _isPlanPanelExpanded
                                  ? (bottomPanelHeight * 0.60).clamp(40.0, 120.0)
                                  : 8 + (bottomPanelHeight * 0.05),
                            ),
                            child: Column(
                              children: [
                                // --- ヒーロー（説明） ---
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
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
                                              "チームを、もう一段強く。",
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                height: 1.15,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              "プランを選んで、使える機能をチーム全員で最大化しよう。\n分析・ランキング・MVP・スケジュール管理まで、勝ちに近づく仕組みをまとめて強化。",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                                height: 1.45,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // --- 支払い担当表示 & 変更 ---
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: _loadingOwner
                                      ? const Row(
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            SizedBox(width: 10),
                                            Text('支払い担当を確認中…'),
                                          ],
                                        )
                                      : Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              '支払い担当',
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _subscriptionOwnerUid == null
                                                  ? '未設定（代表者が設定してください）'
                                                  : (_isSubscriptionOwner
                                                      ? 'あなた（$_subscriptionOwnerName）'
                                                      : _subscriptionOwnerName),
                                              style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              '支払い担当はチーム代表者が変更できます。',
                                              style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
                                            ),
                                            const SizedBox(height: 8),
                                            if (!_loadingTeamSub)
                                              Text(
                                                (_teamSub != null && (_teamSub?['status'] ?? '') == 'active')
                                                    ? '現在のチームプラン：${_planNameFromProductId((_teamSub?['productId'] ?? '').toString())}'
                                                    : '現在のチームプラン：未登録',
                                                style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
                                              ),
                                            if (_loadingTeamSub)
                                              const Text(
                                                '現在のチームプラン：確認中…',
                                                style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
                                              ),
                                            const SizedBox(height: 10),
                                            if (!_isSubscriptionOwner)
                                              const Text(
                                                '※ 購入は「支払い担当」に設定されたユーザーのみ可能です。',
                                                style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
                                              ),
                                            if (_isTeamOwner) ...[
                                              const SizedBox(height: 10),
                                              Align(
                                                alignment: Alignment.centerRight,
                                                child: TextButton.icon(
                                                  onPressed: _showChangeSubscriptionOwnerDialog,
                                                  icon: const Icon(Icons.manage_accounts, size: 18),
                                                  label: const Text('支払い担当を変更'),
                                                ),
                                              ),
                                            ] else ...[
                                              const SizedBox(height: 10),
                                              const Text(
                                                '※ 支払い担当の変更はチーム代表者のみ可能です。',
                                                style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
                                              ),
                                            ],
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 24),
                                const PlanComparisonTable(),
                                const SizedBox(height: 24),
                                const TeamFeaturesSection(),
                                const SizedBox(height: 24),
                                TeamSubscriptionLegalSection(
                                  isPlanPanelExpanded: _isPlanPanelExpanded,
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 固定の下部プラン（Any.do風）
                    Material(
                      elevation: 18,
                      color: Colors.transparent,
                      child: _buildPlanOptionsBottomPanel(),
                    ),
                  ],
                );
              },
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
                child: Text(priceText ?? (disabled ? '登録中' : '購入')),
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
                    "100円",
                    style: cellStyle,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "150円",
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
                    "約83円",
                    style: cellStyle,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "約108円",
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

class TeamSubscriptionLegalSection extends StatelessWidget {
  final bool isPlanPanelExpanded;

  const TeamSubscriptionLegalSection({
    super.key,
    required this.isPlanPanelExpanded,
  });

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リンクを開けませんでした')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const privacyPolicyUrl = 'https://baseball-net.vercel.app/privacy';
    const termsUrl = 'https://baseball-net.vercel.app/terms';
    const appleEulaUrl =
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

    final textStyle = TextStyle(
      fontSize: 11,
      color: Colors.grey.shade700,
      height: 1.4,
    );

    final linkStyle = textStyle.copyWith(
      color: Colors.blue,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '購読に関するご案内',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
    const SizedBox(height: 8),

          // --- 審査向け：購読に関する詳細案内 ---
          Text(
            '■ 料金の請求について\n'
            '・購入確定時に、Apple ID / Google アカウントに代金が請求されます。\n'
            '・支払いは各ストア（App Store / Google Play）を通じて処理されます。',
            style: textStyle,
          ),
          const SizedBox(height: 10),

          Text(
            '■ 自動更新について\n'
            '・本プランは自動更新のサブスクリプションです。\n'
            '・現在の期間が終了する24時間前までに解約しない限り、自動的に更新されます。\n'
            '・更新時には、次回分の料金が同じストアアカウントに請求されます。',
            style: textStyle,
          ),
          const SizedBox(height: 10),

        Text(
            '■ 解約（自動更新の停止）・プラン変更\n'
            '・解約/プラン変更は、アプリ内ではなく App Store / Google Play のサブスクリプション管理から行えます。解約しても、現在の請求期間が終了するまでは利用できます。\n'
            '・（iOS）設定アプリ ＞ Apple ID ＞ サブスクリプション\n'
            '・（Android）Google Play ＞ お支払いと定期購入 ＞ 定期購入',
            style: textStyle,
          ),
          const SizedBox(height: 10),


          Text(
            '■ 返金について\n'
            '・購入後の返金可否や手続きは、App Store / Google Play のポリシーに従います。\n'
            '・返金を希望する場合は、各ストアのサポート窓口からお手続きください。',
            style: textStyle,
          ),
          const SizedBox(height: 10),

          Text(
            '■ チームプランの適用範囲\n'
            '・チームプランはチーム代表者が管理し、支払い担当（支払いを行うメンバー）を変更できます。\n'
            '・メンバーは、招待され参加しているチーム内でプレミアム機能を利用できます。\n'
            '・チームから退出した場合、チームプランの機能は利用できなくなります。',
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
          // ✅ パネルを開いている時だけ、下に余白を足してリンクまでスクロールしやすくする
          SizedBox(height: isPlanPanelExpanded ? 0 : 0),
        ],
      ),
    );
  }
}

// --- チームメンバーモデル ---
class _TeamMember {
  final String uid;
  final String name;

  const _TeamMember({required this.uid, required this.name});
}