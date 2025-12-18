import 'package:b_net/pages/team/team_home.dart';
import 'package:b_net/pages/team/team_subscription_guard.dart';
import 'package:flutter/material.dart';
import 'team_mvp_month_page.dart';
import 'team_mvp_year_page.dart';

class TeamMvpVotePage extends StatelessWidget {
  final String teamId;
  final bool hasActiveTeamSubscription;
  final TeamPlanTier teamPlanTier;

  const TeamMvpVotePage({Key? key, required this.teamId, required this.hasActiveTeamSubscription, required this.teamPlanTier}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (teamPlanTier != TeamPlanTier.platina) {
      return TeamSubscriptionGuard(
        isLocked: true,
        initialPage: 6,
        teamId: teamId,
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 40), // Top padding instead of AppBar
            const TabBar(
              tabs: [
                Tab(text: '月間MVP'),
                Tab(text: '年間MVP'),
              ],
              labelColor: Colors.black,
              indicatorColor: Colors.blue,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  TeamMvpMonthPage(teamId: teamId),
                  TeamMvpYearPage(teamId: teamId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
