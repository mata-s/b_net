import 'package:b_net/widgets/ranking_next_update_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('team monthly ranking next update', () {
    test('monthly mode continues updating during the off-season', () {
      final result = RankingNextUpdateLabel.nextUpdateDate(
        isSeasonMode: false,
        cycle: RankingUpdateCycle.monthlyFirstDay,
        now: DateTime(2027, 1, 15),
      );

      expect(result, DateTime(2027, 2, 1));
    });

    test('season mode resumes on April 1', () {
      final result = RankingNextUpdateLabel.nextUpdateDate(
        isSeasonMode: true,
        cycle: RankingUpdateCycle.monthlyFirstDay,
        now: DateTime(2027, 1, 15),
      );

      expect(result, DateTime(2027, 4, 1));
    });

    test('March 1 processing is skipped for season mode', () {
      final result = RankingNextUpdateLabel.nextUpdateDate(
        isSeasonMode: true,
        cycle: RankingUpdateCycle.monthlyFirstDay,
        now: DateTime(2027, 3, 1, 2),
      );

      expect(result, DateTime(2027, 4, 1));
    });

    test('April 1 before processing completion remains April 1', () {
      final result = RankingNextUpdateLabel.nextUpdateDate(
        isSeasonMode: true,
        cycle: RankingUpdateCycle.monthlyFirstDay,
        now: DateTime(2027, 4, 1, 2),
      );

      expect(result, DateTime(2027, 4, 1));
    });
  });
}
