import 'package:b_net/services/team_subscription_screen.dart';
import 'package:flutter/material.dart';

class TeamSubscriptionGuard extends StatefulWidget {
  final bool isLocked;
  final int initialPage;
  final bool showCloseButton;
  final String teamId;

  const TeamSubscriptionGuard({
    super.key,
    required this.isLocked,
    this.initialPage = 0,
    this.showCloseButton = false,
    required this.teamId,
  });

  @override
  State<TeamSubscriptionGuard> createState() => _TeamSubscriptionGuardState();
}

class _TeamSubscriptionGuardState extends State<TeamSubscriptionGuard>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  int _currentPage = 0;

  // スワイプヒント（最初だけ軽く動く）
  late final AnimationController _hintController;
  late final Animation<double> _hintOffset;
  bool _hintAnimating = true;

  // 「有料プランでできること」リスト
  final List<_FeaturePage> _pages = const [
    _FeaturePage(
      title: 'チーム全員でランキングに参加できる',
      description: 'チームの成績がランキングに反映され、\n'
        '全員の活躍が数字で見えるようになります。\n'
        'みんなで上位を目指そう！',
      icon: Icons.leaderboard,
    ),
    _FeaturePage(
      title: '全国の強豪チームを覗いてみよう',
      description: '全国の強豪チームの成績や傾向を見ると、刺激と発見が生まれる。\n'
          '次に目指すチーム像が、自然とイメージできます。',
      icon: Icons.groups,
    ),
    _FeaturePage(
      title: 'チーム全体の詳細データがわかる',
      description: '打球の分布や打撃傾向に加えて、投手の傾向も分析。\n'
          'チーム全体の強みと課題がより明確になります。',
      icon: Icons.analytics,
    ),
    _FeaturePage(
      title: 'チーム別・球場別の成績も見られる',
      description: 'どのチームに強いか、\n'
          'チームがどの球場と相性がいいかをデータで分析できます。',
      icon: Icons.stadium,
    ),
    _FeaturePage(
      title: 'チーム目標を決めると、一体感が生まれる',
      description: 'チームで月や年間の目標を共有すると、\n'
          '練習や試合への意識が揃い、達成感をチーム全員で分かち合える強いチームになります。',
      icon: Icons.flag,
    ),
    _FeaturePage(
      title: 'チーム内ランキングで盛り上がれる',
      description:'楽しみながら競い合うことで、自然とモチベーションが高まります。',
      icon: Icons.emoji_events,
    ),
    _FeaturePage(
      title: 'MVP投票で仲間の活躍を称えよう',
      description: '月間・年間MVPをチームで決めて、\n'
          '活躍した仲間をみんなで称えられます。',
      icon: Icons.military_tech,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SingleChildScrollView(
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
                  'チーム全員で、強くなる楽しさを。',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
                ),
                const SizedBox(height: 8),

                const SizedBox(height: 24),

                // カード + ドットをまとめた領域
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardAreaHeight = 320.0;

                    return SizedBox(
                      height: cardAreaHeight,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '有料プランでできること',
                             style: TextStyle(fontSize: 14, color: Colors.black54),
                             textAlign: TextAlign.center,
                          ),
                          // カード
                          SizedBox(
                            height: cardAreaHeight - 36, // ← ドット分だけ引く
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

                          // ドット（カードに近づける）
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 10,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(_pages.length, (index) {
                                  final isActive = index == _currentPage;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: isActive ? 10 : 6,
                                    height: isActive ? 10 : 6,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Colors.blueAccent
                                          : Colors.grey[300],
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // スワイプヒント（最初だけ軽く動く）
                SizedBox(
                  height: 16,
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
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              size: 22,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(width: 25),
                          Transform.translate(
                            offset: Offset(rightDx, 0),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 22,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // チームプランの料金・内容
                const _TeamPricingSection(),

                const SizedBox(height: 16),

                // 購読ボタン
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TeamSubscriptionScreen(teamId: widget.teamId),),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                const SizedBox(height: 16),
              ],
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

  const _FeatureCard({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(20),
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
            Icon(page.icon, size: 60, color: Colors.blueAccent),
            const SizedBox(height: 16),
            Text(
              page.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              page.description,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamPricingSection extends StatelessWidget {
  const _TeamPricingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'チームプラン',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.left,
        ),
        const SizedBox(height: 8),
        Row(
          children: const [
            Expanded(
              child: _PlanCard(
                title: 'ゴールド',
                price: '¥1,500 / 月',
                badgeText: 'スタンダード',
                description:
                    'チーム内ランキング・目標設定・\nチーム全体の詳細・チーム別/球場別成績が使えます。',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _PlanCard(
                title: 'プラチナ',
                price: '¥1,800 / 月',
                badgeText: 'フルアクセス',
                description:
                    'ゴールドの内容に加えて、\n全国の強豪チーム比較やMVP投票など\nすべてのチーム機能が解放されます。',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String badgeText;
  final String description;

  const _PlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.badgeText,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: title == 'プラチナ'
              ? Colors.amber.shade400
              : Colors.grey.shade300,
          width: title == 'プラチナ' ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: title == 'プラチナ'
                  ? Colors.amber.shade400
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}