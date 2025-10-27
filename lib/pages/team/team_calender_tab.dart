import 'package:b_net/pages/team/location_pponent.dart';
import 'package:b_net/pages/team/team_calendar.dart';
import 'package:flutter/material.dart';

class TeamCalenderTab extends StatelessWidget {
  final String teamId;

  const TeamCalenderTab({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: '記録'),
              Tab(text: '詳細'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TeamGradesCalendar(teamId: teamId),
            LocationOpponentPage(teamId: teamId),
          ],
        ),
      ),
    );
  }
}
