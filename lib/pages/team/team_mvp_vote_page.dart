import 'package:flutter/material.dart';
import 'team_mvp_month_page.dart';
import 'team_mvp_year_page.dart';

class TeamMvpVotePage extends StatelessWidget {
  final String teamId;

  const TeamMvpVotePage({Key? key, required this.teamId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
