import 'package:b_net/widgets/b_net_floating_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GameSaveResultPage extends StatelessWidget {
  const GameSaveResultPage({
    super.key,
    required this.gameDate,
    required this.games,
    this.isEditing = false,
  });

  final DateTime gameDate;
  final List<Map<String, dynamic>> games;
  final bool isEditing;

  static const _hitResults = {'内野安打', '単打', '二塁打', '三塁打', '本塁打'};

  int _number(Map<String, dynamic> game, String key) =>
      (game[key] as num?)?.toInt() ?? 0;

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _atBatResults(List<dynamic> atBats) {
    if (atBats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text('各打席', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...atBats.asMap().entries.map((entry) {
          final raw = entry.value;
          final atBat = raw is Map ? raw : const {};
          final result = (atBat['result'] ?? '').toString().trim();
          final position = (atBat['position'] ?? '').toString().trim();
          final displayResult = result.isEmpty
              ? '結果未選択'
              : position.isEmpty || position == '打'
                  ? result
                  : '$position－$result';
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Text(
                  '${entry.key + 1}  $displayResult',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(label, style: const TextStyle(color: Colors.black54))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _pitchingResultChip(String label, {IconData? icon}) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: icon == null ? null : Icon(icon, size: 17),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: const Color(0xFFEFF6FF),
      side: const BorderSide(color: Color(0xFFBFDBFE)),
    );
  }

  Widget _detailExpansion(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: children,
      ),
    );
  }

  Widget _battingDetails(Map<String, dynamic> game, List<dynamic> atBats) {
    final swingCount = atBats.fold<int>(0, (total, raw) {
      final atBat = raw is Map ? raw : const {};
      return total + ((atBat['swingCount'] as num?)?.toInt() ?? 0);
    });
    final missSwingCount = atBats.fold<int>(0, (total, raw) {
      final atBat = raw is Map ? raw : const {};
      return total + ((atBat['missSwingCount'] as num?)?.toInt() ?? 0);
    });
    final batterPitchCount = atBats.fold<int>(0, (total, raw) {
      final atBat = raw is Map ? raw : const {};
      return total + ((atBat['batterPitchCount'] as num?)?.toInt() ?? 0);
    });
    final firstPitchSwings = atBats.where((raw) {
      return raw is Map && raw['firstPitchSwing'] == true;
    }).length;

    return _detailExpansion(
      '打撃・走塁の詳しい記録',
      [
        _detailRow('打席で見た球数', '$batterPitchCount'),
        _detailRow('スイング数', '$swingCount'),
        _detailRow('空振り数', '$missSwingCount'),
        _detailRow('初球スイング', '$firstPitchSwings'),
        _detailRow('盗塁企図', '${_number(game, 'stealsAttempts')}'),
        _detailRow('盗塁死', '${_number(game, 'caughtStealingByRunner')}'),
      ],
    );
  }

  Widget _pitchingDetails(Map<String, dynamic> game) {
    return _detailExpansion(
      '投手の詳しい記録',
      [
        _detailRow('失点', '${_number(game, 'runsAllowed')}'),
        _detailRow('被安打', '${_number(game, 'hitsAllowed')}'),
        _detailRow('与四球', '${_number(game, 'walks')}'),
        _detailRow('与死球', '${_number(game, 'hitByPitch')}'),
        _detailRow('被本塁打', '${_number(game, 'homeRunsAllowed')}'),
        _detailRow('対戦打者', '${_number(game, 'battersFaced')}'),
        _detailRow('投球数', '${_number(game, 'pitchCount')}'),
      ],
    );
  }

  Widget _gameCard(Map<String, dynamic> game, int index) {
    final atBats = (game['atBats'] as List?) ?? const [];
    final hits = atBats.where((atBat) {
      if (atBat is! Map) return false;
      return _hitResults.contains(atBat['result']);
    }).length;
    final homeRuns = atBats.where((atBat) {
      return atBat is Map && atBat['result'] == '本塁打';
    }).length;
    final positions = (game['positions'] as List?) ?? const [];
    final isPitcher = positions.contains('投手');
    final isCatcher = positions.contains('捕手');
    final isDetailed = game['inputMode'] != 'simple';
    final pitchingResult = (game['resultGame'] ?? '').toString().trim();
    final appearanceType = (game['appearanceType'] ?? '').toString().trim();
    final isCompleteGame = game['isCompleteGame'] == true;
    final isShutoutGame = game['isShutoutGame'] == true;
    final isSave = game['isSave'] == true;
    final isHold = game['isHold'] == true;
    final opponent = (game['opponent'] ?? '').toString().trim();
    final location = (game['location'] ?? '').toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              games.length > 1
                  ? '${index + 1}試合目'
                  : isEditing
                      ? '修正後の成績'
                      : '今回の成績',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (opponent.isNotEmpty || location.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                [
                  if (opponent.isNotEmpty) '対 $opponent',
                  if (location.isNotEmpty) location,
                ].join('・'),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 8),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                isDetailed ? Icons.analytics_outlined : Icons.bolt_outlined,
                size: 17,
              ),
              label: Text(isDetailed ? '詳細入力' : '簡単入力'),
            ),
            const SizedBox(height: 16),
            const Text('打撃', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _stat('打席', '${atBats.length}'),
                _stat('安打', '$hits'),
                if (homeRuns > 0) _stat('本塁打', '$homeRuns'),
                _stat('打点', '${_number(game, 'rbis')}'),
                _stat('得点', '${_number(game, 'runs')}'),
                _stat('盗塁', '${_number(game, 'steals')}'),
              ],
            ),
            _atBatResults(atBats),
            if (isDetailed) _battingDetails(game, atBats),
            if (isPitcher) ...[
              const SizedBox(height: 18),
              const Text('投手', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (pitchingResult.isNotEmpty ||
                  appearanceType.isNotEmpty ||
                  isCompleteGame ||
                  isShutoutGame ||
                  isSave ||
                  isHold) ...[
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (appearanceType.isNotEmpty)
                      _pitchingResultChip(appearanceType),
                    if (pitchingResult.isNotEmpty)
                      _pitchingResultChip(
                        pitchingResult,
                        icon: Icons.emoji_events_outlined,
                      ),
                    if (isCompleteGame)
                      _pitchingResultChip('完投', icon: Icons.sports_baseball),
                    if (isShutoutGame)
                      _pitchingResultChip('完封', icon: Icons.shield_outlined),
                    if (isHold) _pitchingResultChip('ホールド'),
                    if (isSave) _pitchingResultChip('セーブ'),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _stat('投球回', '${_number(game, 'inningsThrow')}'),
                  _stat('奪三振', '${_number(game, 'strikeouts')}'),
                  _stat('自責点', '${_number(game, 'earnedRuns')}'),
                ],
              ),
              if (isDetailed) _pitchingDetails(game),
            ],
            const SizedBox(height: 18),
            const Text('守備', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _stat('刺殺', '${_number(game, 'putouts')}'),
                _stat('捕殺', '${_number(game, 'assists')}'),
                _stat('失策', '${_number(game, 'errors')}'),
              ],
            ),
            if (isCatcher) ...[
              const SizedBox(height: 14),
              const Text(
                '捕手成績',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _stat(
                    '盗塁企図',
                    '${_number(game, 'stolenBaseAttempts')}',
                  ),
                  _stat('盗塁阻止', '${_number(game, 'caughtStealing')}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('保存完了'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            BNetFloatingTabBar.bodyClearance(context) + 24,
          ),
          children: [
            const Icon(Icons.check_circle, size: 72, color: Color(0xFF16A34A)),
            const SizedBox(height: 10),
            Text(
              isEditing ? '試合記録を修正しました！' : '試合を記録しました！',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat('yyyy年M月d日').format(gameDate),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ...games
                .asMap()
                .entries
                .map((entry) => _gameCard(entry.value, entry.key)),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sync, color: Color(0xFFEA580C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing
                          ? '修正内容をもとに累計成績とランキングを再計算しています。反映まで少し時間がかかる場合があります。'
                          : '累計成績とランキングを更新しています。反映まで少し時間がかかる場合があります。',
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: const Text('カレンダーに戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
