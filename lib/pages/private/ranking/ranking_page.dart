import 'package:flutter/material.dart';
import 'package:b_net/pages/private/ranking/batting_ranking.dart';
import 'package:b_net/pages/private/ranking/pitching_ranking.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class RankingPage extends StatefulWidget {
  final String uid;
  final String prefecture;

  const RankingPage({
    super.key,
    required this.uid,
    required this.prefecture,
  });

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  int _currentIndex = 0; // 0: 打撃ランキング, 1: 投手ランキング

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _RankingTypeButton(
                          label: '打撃ランキング',
                          icon: FontAwesomeIcons.baseballBatBall,
                          isSelected: _currentIndex == 0,
                          onTap: () {
                            setState(() {
                              _currentIndex = 0;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: _RankingTypeButton(
                          label: '投手ランキング',
                          icon: Icons.sports_baseball,
                          isSelected: _currentIndex == 1,
                          onTap: () {
                            setState(() {
                              _currentIndex = 1;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    BattingRanking(
                      uid: widget.uid,
                      prefecture: widget.prefecture,
                    ),
                    PitchingRanking(
                      uid: widget.uid,
                      prefecture: widget.prefecture,
                    ),
                  ],
                ),
              ),
            ],
          ),
      );
  }
}

class _RankingTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RankingTypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.blue : Colors.black45,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.black : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
