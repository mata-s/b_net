import 'package:b_net/widgets/ranking_next_update_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RankingRequiredGamesLabel.requiredGames', () {
    test('monthly ranking uses four games outside winter', () {
      expect(
        RankingRequiredGamesLabel.requiredGames(
          isSeasonMode: false,
          now: DateTime(2026, 7, 24),
        ),
        4,
      );
    });

    test('monthly ranking uses zero games for a winter target month', () {
      expect(
        RankingRequiredGamesLabel.requiredGames(
          isSeasonMode: false,
          now: DateTime(2026, 2, 10),
        ),
        0,
      );
    });

    test('season ranking increases by four games from April', () {
      expect(
        RankingRequiredGamesLabel.requiredGames(
          isSeasonMode: true,
          now: DateTime(2026, 4, 1, 3),
        ),
        4,
      );
      expect(
        RankingRequiredGamesLabel.requiredGames(
          isSeasonMode: true,
          now: DateTime(2026, 7, 24),
        ),
        16,
      );
    });

    test('keeps the previous requirement until the update completes', () {
      expect(
        RankingRequiredGamesLabel.requiredGames(
          isSeasonMode: true,
          now: DateTime(2026, 4, 1, 2),
        ),
        36,
      );
      expect(
        RankingRequiredGamesLabel.requiredGames(
          isSeasonMode: true,
          now: DateTime(2026, 7, 1, 2),
        ),
        12,
      );
    });

    test('season ranking stays capped at 36 games through winter', () {
      expect(
        RankingRequiredGamesLabel.requiredGames(
          isSeasonMode: true,
          now: DateTime(2026, 12, 1, 3),
        ),
        36,
      );
      expect(
        RankingRequiredGamesLabel.requiredGames(
          isSeasonMode: true,
          now: DateTime(2027, 2, 1),
        ),
        36,
      );
    });
  });
}
