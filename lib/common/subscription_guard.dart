import 'package:b_net/services/subscription_screen.dart';
import 'package:flutter/material.dart';

class SubscriptionGuard extends StatefulWidget {
  final bool isLocked;
  final int initialPage;
  final bool showCloseButton;

  const SubscriptionGuard({
    super.key,
    required this.isLocked,
    this.initialPage = 0,
    this.showCloseButton = false,
  });

  @override
  State<SubscriptionGuard> createState() => _SubscriptionGuardState();
}

class _SubscriptionGuardState extends State<SubscriptionGuard> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  int _currentPage = 0;

  late final AnimationController _hintController;
  late final Animation<double> _hintOffset;
  bool _hintAnimating = true;

  // 「有料プランでできること」リスト
  final List<_FeaturePage> _pages = const [
    _FeaturePage(
      title: 'ランキングに参加できる',
      description: '数字で成長が見えると、野球がもっと楽しくなる。\n'
          'あなたもランキングに参加してみよう！',
      icon: Icons.leaderboard,
    ),
    _FeaturePage(
      title: '都道府県対抗ヒットバトル',
      description: 'あなたの一打が地元のスコアに加算される。\n'
          '都道府県ごとのヒット合計で順位が決まる白熱バトル！',
      icon: Icons.flag_circle,
    ),
    _FeaturePage(
      title: '全国トップ選手を覗いてみよう',
      description: '全国の強者の成績を見ると、刺激と発見がある。\n'
          'あなたの次の目標が自然と見つかります。',
      icon: Icons.workspace_premium,
    ),
    _FeaturePage(
      title: '打撃のさらに詳細がわかる',
      description: '打球の分布や打撃傾向など、\n'
          'いつもの成績表では見えない打撃のクセが見えてきます。',
      icon: Icons.analytics,
    ),
    _FeaturePage(
      title: 'チーム別・球場別の成績も見られる',
      description: 'どのチーム相手に強いか、\n'
          'どの球場と相性がいいかをデータで分析できます。',
      icon: Icons.stadium,
    ),
    _FeaturePage(
      title: '目標を決めると、野球がもっと楽しくなる',
      description: '月の目標や、1年のテーマを決めるだけで、\n'
          '野球に取り組む毎日がもっとワクワクします。',
      icon: Icons.flag,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);

    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _hintOffset = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _hintController, curve: Curves.easeInOut),
    );

    // 画面表示直後だけ、矢印を軽く動かして「左右スワイプ」を伝える
    _hintController.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;

      // 終わり方を滑らかに：0位置へスッと戻してから止める
      try {
        await _hintController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
        );
      } catch (_) {
        // dispose 済み等で animateTo が投げる可能性があるので握りつぶす
      }

      if (!mounted) return;
      _hintController.stop();
      setState(() => _hintAnimating = false);
    });
  }

  @override
  void dispose() {
    _hintController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    // iPad の時だけ全体を少し大きく（SPはそのまま）
    // 600〜: iPad相当 / 900〜: 大きめタブレット
    final double contentMaxWidth = !isTablet
        ? double.infinity
        : (size.width >= 900 ? 820 : 720);

    final double titleFont = isTablet ? 30 : 22;
    final double subtitleFont = isTablet ? 18 : 14;
    final double buttonHeight = isTablet ? 56 : 48;
    final double cardAreaHeight = !isTablet
        ? 320
        : (size.width >= 900 ? 480 : 420);
    final EdgeInsets contentPadding = EdgeInsets.symmetric(
      horizontal: isTablet ? 40 : 24,
      vertical: isTablet ? 20 : 16,
    );

    if (!widget.isLocked) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE3F2FD), // 薄い青
            Colors.white,      // 下は白
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Padding(
              padding: contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.showCloseButton)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'あなたの野球が、もっと面白くなる。',
                      style: TextStyle(
                        fontSize: titleFont,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                     overflow: TextOverflow.clip,
                    ),
                  ),
                  const SizedBox(height: 8),

                  const SizedBox(height: 12),

                  // ===== Feature Section (subtitle + card + dots as one unit) =====
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '有料プランでできること',
                            style: TextStyle(
                              fontSize: subtitleFont,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          // カード
                          SizedBox(
                            height: cardAreaHeight - 60,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _pages.length,
                              onPageChanged: (index) {
                                setState(() => _currentPage = index);
                              },
                              itemBuilder: (context, index) {
                                final page = _pages[index];
                                return _FeatureCard(page: page);
                              },
                            ),
                          ),

                          const SizedBox(height: 4),

                          // ドット（カード直下）
                          SizedBox(
                            height: isTablet ? 14 : 10,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_pages.length, (index) {
                                  final isActive = index == _currentPage;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: isTablet ? (isActive ? 14 : 8) : (isActive ? 10 : 6),
                                    height: isTablet ? (isActive ? 14 : 8) : (isActive ? 10 : 6),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.blueAccent : Colors.grey[300],
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // スワイプヒント（最初だけ軽く動く）
                          SizedBox(
                            height: isTablet ? 26 : 22,
                            child: AnimatedBuilder(
                              animation: _hintController,
                              builder: (context, _) {
                                final v = _hintAnimating ? _hintOffset.value : 0.0;
                                final leftDx = -v; // 左は左へ
                                final rightDx = v; // 右は右へ

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: Offset(leftDx, 0),
                                      child: Icon(
                                        Icons.chevron_left_rounded,
                                        size: isTablet ? 26 : 22,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(width: 25),
                                    Transform.translate(
                                      offset: Offset(rightDx, 0),
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        size: isTablet ? 26 : 22,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 購読ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SubscriptionScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, buttonHeight),
                        padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '有料プランをチェックする',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    '※ すでに購読中の方は、一度アプリを再起動してください。',
                    style: TextStyle(fontSize: 11, color: Colors.black45),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePage {
  final String title;
  final String description;
  final IconData icon;

  const _FeaturePage({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeaturePage page;

  const _FeatureCard({required this.page});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    final isBigTablet = width >= 900;

    final double cardMaxWidth = !isTablet ? 380 : (isBigTablet ? 680 : 600);
    final double cardPadding = !isTablet ? 20 : (isBigTablet ? 32 : 28);
    final double iconSize = !isTablet ? 60 : (isBigTablet ? 96 : 84);
    final double titleSize = !isTablet ? 18 : (isBigTablet ? 26 : 24);
    final double descSize = !isTablet ? 14 : (isBigTablet ? 18 : 16);

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: cardMaxWidth),
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(page.icon, size: iconSize, color: Colors.blueAccent),
            const SizedBox(height: 16),
            Text(
              page.title,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              page.description,
              style: TextStyle(fontSize: descSize, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}