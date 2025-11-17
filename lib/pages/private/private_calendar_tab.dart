import 'package:b_net/pages/private/game_dateile/private_game_detail.dart';
import 'package:flutter/material.dart';
import 'private_calendar.dart';

class PrivateCalendarTab extends StatelessWidget {
  final String userUid;
  final List<String> positions;

  const PrivateCalendarTab({
    super.key,
    required this.userUid,
    required this.positions,
  });

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
            PrivateCalendar(userUid: userUid, positions: positions),
            PrivateGameDetail(userUid: userUid),
          ],
        ),
      ),
    );
  }
}
