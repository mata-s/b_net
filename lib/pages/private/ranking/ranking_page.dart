import 'package:flutter/material.dart';
import 'package:b_net/pages/private/ranking/batting_ranking.dart';
import 'package:b_net/pages/private/ranking/pitching_ranking.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class RankingPage extends StatefulWidget {
  final String uid;
  final String prefecture;

  const RankingPage({super.key, required this.uid, required this.prefecture});

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
          // アイコンボタンで切り替え
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  FontAwesomeIcons.baseballBatBall,
                  color: _currentIndex == 0 ? Colors.blue : Colors.grey,
                  size: 30,
                ),
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                  });
                },
                tooltip: '打撃ランキング',
              ),
              Icon(Icons.swap_horiz),
              SizedBox(
                height: 16,
              ),
              IconButton(
                icon: Icon(
                  Icons.sports_baseball,
                  color: _currentIndex == 1 ? Colors.blue : Colors.grey,
                  size: 30,
                ),
                onPressed: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                tooltip: '投手ランキング',
              ),
            ],
          ),
          const SizedBox(height: 10),
          // IndexedStackでページを切り替え
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
