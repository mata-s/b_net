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

class _SubscriptionGuardState extends State<SubscriptionGuard> {
  late final PageController _pageController;
  int _currentPage = 0;

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
  }

  @override
  void dispose() {
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

              const SizedBox(height: 8),

              const Text(
                'あなたの野球が、もっと面白くなる。',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '有料プランで使える全機能を紹介します。',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // カード部分（PageView）
              Expanded(
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

              const SizedBox(height: 16),

              // ドットインジケータ
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 10 : 6,
                    height: isActive ? 10 : 6,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.blueAccent : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

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
            ],
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