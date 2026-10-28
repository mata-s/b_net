import 'package:b_net/widgets/b_net_floating_tab_bar.dart';
import 'package:flutter/material.dart';

class FirstGameDashboardEmpty extends StatelessWidget {
  const FirstGameDashboardEmpty({
    super.key,
    required this.onStart,
  });

  final VoidCallback onStart;

  Widget _step(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        28,
        20,
        BNetFloatingTabBar.bodyClearance(context) + 24,
      ),
      children: [
        const Icon(
          Icons.check_circle,
          size: 70,
          color: Color(0xFF16A34A),
        ),
        const SizedBox(height: 12),
        const Text(
          '登録完了！',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'まずは1試合記録して、\nあなたの成績を作ってみましょう。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.5, color: Colors.black54),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _step(
                Icons.edit_note,
                '1. 試合を入力',
                '簡単入力なら、分かる成績だけで始められます。',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Icon(Icons.keyboard_arrow_down, color: Colors.black38),
              ),
              _step(
                Icons.calculate_outlined,
                '2. 成績を自動集計',
                '打率や防御率などを自動で計算します。',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Icon(Icons.keyboard_arrow_down, color: Colors.black38),
              ),
              _step(
                Icons.emoji_events_outlined,
                '3. ランキングに反映',
                '地域や同年代の選手と成績を比べられます。',
              ),
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
        const SizedBox(height: 10),
        const Text(
          '完成後のイメージは「成績」タブで確認できます',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
