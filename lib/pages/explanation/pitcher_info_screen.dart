import 'package:flutter/material.dart';

class PitcherInfoScreen extends StatelessWidget {
  const PitcherInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '投手の役割とルール',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade900,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                _showImageDialog(context);
              },
              child: Center(
                child: Image.asset(
                  'assets/pitcher.png',
                  width: MediaQuery.of(context).size.width * 0.8, // 画面幅の80%
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSection('① 先発投手', [
              _buildSubSection('完投した場合', [
                _buildListItem(
                  '勝利投手',
                  'チームが勝利し、先発投手が規定投球回数（本アプリでは3回以上）を投げてリードを守ったまま試合を終了すれば、勝利投手になります。',
                  icon: Icons.emoji_events_outlined,
                  iconColor: Colors.green.shade700,
                ),
                _buildListItem(
                  '負け投手',
                  'チームが敗北し、先発投手が敗因となる決定的な点を失った場合、負け投手になります。',
                  icon: Icons.error_outline,
                  iconColor: Colors.red.shade700,
                ),
              ]),
              _buildSubSection('途中で交代した場合', [
                _buildListItem(
                  '勝利投手',
                  'チームが勝利した場合でも、先発投手が規定投球回数を満たしていないと勝利投手にはなれません。その場合、リリーフ投手のうち最も貢献した選手が勝利投手になります。',
                  icon: Icons.emoji_events_outlined,
                  iconColor: Colors.green.shade700,
                ),
                _buildListItem(
                  '負け投手',
                  'チームが敗北し、交代前に失った点が敗因となった場合、負け投手になります。',
                  icon: Icons.error_outline,
                  iconColor: Colors.red.shade700,
                ),
                _buildListItem(
                  'ホールド/セーブ',
                  '先発投手にはホールドやセーブはつきません。',
                  icon: Icons.block,
                  iconColor: Colors.grey.shade700,
                ),
              ]),
            ]),
            _buildSection('② 中継ぎ投手', [
              _buildListItem(
                '勝利投手',
                'チームが勝利し、規定投球回数に満たない先発投手の代わりに勝利条件を満たした場合、または試合をひっくり返してリードを奪った後に交代した場合、中継ぎ投手が勝利投手になります。',
                icon: Icons.emoji_events_outlined,
                iconColor: Colors.green.shade700,
              ),
              _buildListItem(
                '負け投手',
                '試合中に交代した中継ぎ投手が、失点によってチームがリードを失い、そのリードを取り返せないまま試合が終了した場合、負け投手になります。',
                icon: Icons.error_outline,
                iconColor: Colors.red.shade700,
              ),
              _buildListItem(
                'ホールド',
                'リードしている場面で登板し、リードを保ったまま降板した場合にホールドがつきます。',
                icon: Icons.security_outlined,
                iconColor: Colors.orange.shade700,
              ),
              _buildListItem(
                'セーブ',
                '中継ぎ投手がセーブの条件を満たすことは稀ですが、リードを守って試合終了した場合にセーブがつくことがあります。',
                icon: Icons.save_alt,
                iconColor: Colors.blue.shade700,
              ),
              _buildSubSection('救援勝利', [
                _buildListItem(
                  '救援勝利',
                  '先発投手が規定投球回数を満たしておらず、リリーフ投手が登板している間にチームがリードを奪い、その後リードを守り切って勝利した場合に記録されます。',
                  icon: Icons.star,
                  iconColor: Colors.purple.shade700,
                ),
              ]),
            ]),
            _buildSection('③ 抑え投手', [
              _buildListItem(
                '勝利投手',
                '試合終盤でリードがない場面で登板し、その後チームが勝ち越して試合が終了した場合、抑え投手に勝利投手がつきます。',
                icon: Icons.emoji_events_outlined,
                iconColor: Colors.green.shade700,
              ),
              _buildListItem(
                '負け投手',
                '抑え投手が登板している間にリードを失い、そのまま試合が終了すれば負け投手になります。',
                icon: Icons.error_outline,
                iconColor: Colors.red.shade700,
              ),
              _buildListItem(
                'ホールド',
                '抑え投手にはホールドはつきません。ホールドは中継ぎ投手のみに適用されます。',
                icon: Icons.block,
                iconColor: Colors.grey.shade700,
              ),
              _buildListItem(
                'セーブ',
                '最終回に3点以内のリードを保った状態で登板し、リードを守って試合を終えるなどの条件を満たした場合にセーブがつきます。',
                icon: Icons.save,
                iconColor: Colors.blue.shade700,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...content,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSubSection(String title, List<Widget> content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00008B),
          ),
        ),
        const SizedBox(height: 5),
        ...content,
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildListItem(String title, String description,
      {required IconData icon, required Color iconColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
              Text(description),
            ],
          ),
        ),
      ],
    );
  }
}

void _showImageDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: InteractiveViewer(
        child: Image.asset(
          'assets/pitcher.png',
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}
