import 'package:flutter/material.dart';
import 'manager_game_input_fielding.dart';
import 'manager_game_input_batting.dart';

class ManagerGameInputHomePage extends StatefulWidget {
  final int matchIndex;
  final String userUid;
  final String teamId;
  final List<Map<String, dynamic>> members;

  const ManagerGameInputHomePage({
    Key? key,
    required this.matchIndex,
    required this.userUid,
    required this.teamId,
    required this.members,
  }) : super(key: key);

  @override
  _ManagerGameInputHomePageState createState() =>
      _ManagerGameInputHomePageState();
}

class _ManagerGameInputHomePageState extends State<ManagerGameInputHomePage>
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
        title: const Text('試合入力'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '打撃'),
            Tab(text: '守備'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ManagerGameInputBatting(
            matchIndex: widget.matchIndex,
            userUid: widget.userUid,
            teamId: widget.teamId,
            members: widget.members,
          ),
          ManagerGameInputFielding(
            matchIndex: widget.matchIndex,
            userUid: widget.userUid,
            teamId: widget.teamId,
            members: widget.members,
          ),
        ],
      ),
    );
  }
}
