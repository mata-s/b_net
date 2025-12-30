import 'package:flutter/material.dart';

class GameDetailPage extends StatelessWidget {
  final Map<String, dynamic> gameData;
  final bool isPitcher;
  final bool isCatcher;

  const GameDetailPage({
    super.key,
    required this.gameData,
    required this.isPitcher,
    this.isCatcher = false,

  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('試合詳細'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本情報
            Text(
              '${gameData['gameType'] ?? '不明'}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text('対戦相手: ${gameData['opponent'] ?? '不明'}'),
            Text('場所: ${gameData['location'] ?? '不明'}'),
            const SizedBox(height: 20),

            // 投手成績
            if (isPitcher) ...[
              const Text('投手成績',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('投球回: ${gameData['inningsThrow'] ?? 0}回'),
                  if (gameData['outFraction'] != null &&
                      gameData['outFraction'] != '0')
                    Text('と${gameData['outFraction']}'),
                  const SizedBox(width: 45),
                  if ((gameData['resultGame'] ?? '').isNotEmpty)
                    Text('${gameData['resultGame']}投手'),
                  if (gameData['isCompleteGame'] == true)
                    const SizedBox(width: 10),
                  if (gameData['isCompleteGame'] == true) const Text('完投'),
                  if (gameData['isShutoutGame'] == true)
                    const SizedBox(width: 10),
                  if (gameData['isShutoutGame'] == true) const Text('完封'),
                  if (gameData['isSave'] == true) const SizedBox(width: 10),
                  if (gameData['isSave'] == true) const Text('セーブ'),
                  if (gameData['isHold'] == true) const SizedBox(width: 10),
                  if (gameData['isHold'] == true) const Text('ホールド'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('登板: ${gameData['appearanceType'] ?? ''}'),
                  const SizedBox(width: 45),
                  Text('対戦打者: ${gameData['battersFaced'] ?? 0}人'),
                  const SizedBox(width: 45),
                  Text('球数: ${gameData['pitchCount'] ?? 0}球'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('与四球: ${gameData['walks'] ?? 0}')),
                  Expanded(child: Text('与死球: ${gameData['hitByPitch'] ?? 0}')),
                  Expanded(child: Text('失点: ${gameData['runsAllowed'] ?? 0}')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('自責点: ${gameData['earnedRuns'] ?? 0}')),
                  Expanded(child: Text('被安打: ${gameData['hitsAllowed'] ?? 0}')),
                  Expanded(child: Text('奪三振: ${gameData['strikeouts'] ?? 0}')),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // 打席結果
            const Text('打席結果',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (gameData['atBats'] != null && gameData['atBats'] is List)
              ...List.generate((gameData['atBats'] as List).length, (index) {
                final atBat = gameData['atBats'][index];
                final swingCount = atBat['swingCount'];
                final batterPitchCount = atBat['batterPitchCount'];

                String extraInfo = '';
                if (swingCount != null) {
                  extraInfo += 'スイング数: $swingCount';
                }
                if (batterPitchCount != null) {
                  if (extraInfo.isNotEmpty) extraInfo += ' / ';
                  extraInfo += '球数: $batterPitchCount';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${atBat['at_bat']}打席目: '
                    '${atBat['position'] ?? '不明'} - '
                    '${atBat['result'] ?? '不明'}'
                    '${extraInfo.isNotEmpty ? '（$extraInfo）' : ''}',
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('盗塁: ${gameData['steals'] ?? 0}'),
                Text('打点: ${gameData['rbis'] ?? 0}'),
                Text('得点: ${gameData['runs'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 20),

            // 守備成績
            const Text('守備成績',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('刺殺: ${gameData['putouts'] ?? 0}'),
                Text('捕殺: ${gameData['assists'] ?? 0}'),
                Text('失策: ${gameData['errors'] ?? 0}'),
              ],
            ),
            if (isCatcher) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('盗塁刺し: ${gameData['caughtStealing'] ?? 0}'),
                ],
              ),
            ],
            const SizedBox(height: 20),

            // メモ
            const Text('メモ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(gameData['memo'] ?? 'メモなし'),
          ],
        ),
      ),
    );
  }
}
