import 'package:flutter/material.dart';
import 'monthly_goal_list_view.dart';
import 'yearly_goal_list_view.dart';

class TeamGoalListPage extends StatefulWidget {
  final String teamId;
  const TeamGoalListPage({
    Key? key,
    required this.teamId,
  }) : super(key: key);

  @override
  _TeamGoalListPageState createState() => _TeamGoalListPageState();
}

class _TeamGoalListPageState extends State<TeamGoalListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('目標一覧'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '月の目標'),
            Tab(text: '年の目標'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MonthlyGoalListView(teamId: widget.teamId),
          YearlyGoalListView(teamId: widget.teamId),
        ],
      ),
    );
  }
}
