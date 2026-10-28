import 'package:flutter/material.dart';

enum RankingUpdateCycle {
  weekly,
  monthlyFirstDay,
}

class RankingNextUpdateLabel extends StatelessWidget {
  const RankingNextUpdateLabel({
    super.key,
    required this.isSeasonMode,
    this.cycle = RankingUpdateCycle.weekly,
  });

  final bool isSeasonMode;
  final RankingUpdateCycle cycle;

  static DateTime nextUpdateDate({
    required bool isSeasonMode,
    RankingUpdateCycle cycle = RankingUpdateCycle.weekly,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    if (cycle == RankingUpdateCycle.monthlyFirstDay) {
      var candidate = current.day == 1 && current.hour < 3
          ? DateTime(current.year, current.month)
          : DateTime(current.year, current.month + 1);

      if (isSeasonMode) {
        // チーム年間・全国は先月分を処理するため、1〜3月の実行は
        // それぞれ12〜2月分となりスキップされる。再開は4月1日。
        while (candidate.month == DateTime.january ||
            candidate.month == DateTime.february ||
            candidate.month == DateTime.march) {
          candidate = DateTime(candidate.year, candidate.month + 1);
        }
      }

      return candidate;
    }

    if (isSeasonMode &&
        (current.month == DateTime.december ||
            current.month == DateTime.january ||
            current.month == DateTime.february)) {
      final marchYear =
          current.month == DateTime.december ? current.year + 1 : current.year;
      return _firstMondayOfMarch(marchYear);
    }

    final today = DateTime(current.year, current.month, current.day);
    var daysUntilMonday = (DateTime.monday - current.weekday) % 7;

    // ランキング処理は月曜早朝に完了するため、それ以降は次週を案内する。
    if (daysUntilMonday == 0 && current.hour >= 3) {
      daysUntilMonday = 7;
    }

    return today.add(Duration(days: daysUntilMonday));
  }

  static DateTime _firstMondayOfMarch(int year) {
    final marchFirst = DateTime(year, DateTime.march);
    final daysUntilMonday =
        (DateTime.monday - marchFirst.weekday) % DateTime.daysPerWeek;
    return marchFirst.add(Duration(days: daysUntilMonday));
  }

  @override
  Widget build(BuildContext context) {
    final nextUpdate = nextUpdateDate(
      isSeasonMode: isSeasonMode,
      cycle: cycle,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '次回更新：${nextUpdate.month}月${nextUpdate.day}日',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class RankingRequiredGamesLabel extends StatelessWidget {
  const RankingRequiredGamesLabel({
    super.key,
    required this.currentGames,
    required this.isSeasonMode,
  });

  final int currentGames;
  final bool isSeasonMode;

  static int requiredGames({
    required bool isSeasonMode,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    if (!isSeasonMode) {
      var targetMonth = current.day == 1 && current.hour < 3
          ? current.month - 2
          : current.month - 1;
      if (targetMonth == 0) targetMonth = DateTime.december;
      if (targetMonth == -1) targetMonth = DateTime.november;
      return targetMonth == DateTime.december ||
              targetMonth == DateTime.january ||
              targetMonth == DateTime.february
          ? 0
          : 4;
    }

    // 年間ランキングは毎月1日に先月分を集計する。
    // 4月1日の4試合から月ごとに4試合増え、最大36試合。
    // 更新日の午前3時までは、まだ前回の規定数を表示する。
    var latestUpdateMonth = current.month;
    if (current.day == 1 && current.hour < 3) {
      latestUpdateMonth -= 1;
    }
    if (latestUpdateMonth <= DateTime.march) return 36;
    return ((latestUpdateMonth - 3) * 4).clamp(4, 36);
  }

  @override
  Widget build(BuildContext context) {
    final required = requiredGames(isSeasonMode: isSeasonMode);
    return Text(
      '規定試合：$currentGames / $required',
      style: const TextStyle(
        fontSize: 12,
        color: Colors.black45,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
