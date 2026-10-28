import 'package:flutter/material.dart';
import 'package:b_net/widgets/b_net_floating_tab_bar.dart';

class FirstGameValuePreview extends StatelessWidget {
  const FirstGameValuePreview({
    super.key,
    required this.isPitcher,
    required this.onStart,
  });

  final bool isPitcher;
  final VoidCallback onStart;

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sampleTitle(IconData icon, Color color, String title) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
        const Chip(
          visualDensity: VisualDensity.compact,
          label: Text('サンプル'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        18,
        24,
        18,
        BNetFloatingTabBar.bodyClearance(context) + 24,
      ),
      children: [
        const CircleAvatar(
          radius: 38,
          backgroundColor: Color(0xFFEFF6FF),
          child: Icon(Icons.auto_graph, size: 38, color: Color(0xFF2563EB)),
        ),
        const SizedBox(height: 16),
        const Text(
          '試合を記録すると、\nあなたの野球が見えてきます',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 24, height: 1.35, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'これは記録後に見られる画面のサンプルです',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 22),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sampleTitle(Icons.bar_chart, const Color(0xFF2563EB), '今季の成績'),
              const SizedBox(height: 16),
              Row(children: [
                _stat('.333', '打率'),
                _stat('8', '安打'),
                _stat('1', '本塁打'),
                _stat('5', '打点'),
              ]),
              if (isPitcher) ...[
                const Divider(height: 30),
                Row(children: [
                  _stat('2.10', '防御率'),
                  _stat('2', '勝利'),
                  _stat('12', '奪三振'),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sampleTitle(Icons.emoji_events_outlined, const Color(0xFFF59E0B),
                  'あなたのランキング'),
              const SizedBox(height: 10),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('都道府県・打率ランキング'),
                trailing: Text('18位',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('同年代・打率ランキング'),
                trailing: Text('5位',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sampleTitle(Icons.insights_outlined, const Color(0xFF7C3AED),
                  'プレースタイル分析'),
              const SizedBox(height: 14),
              const Text('・センター方向への安打が多い'),
              const SizedBox(height: 8),
              const Text('・初球から積極的に振るタイプ'),
              const SizedBox(height: 8),
              const Text('・最近3試合で出塁率が上昇中'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.sports_baseball),
          label: const Text('最初の試合を記録する'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '簡単入力なら、分かる成績だけで始められます',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
