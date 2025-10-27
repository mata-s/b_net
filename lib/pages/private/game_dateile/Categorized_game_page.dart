import 'package:b_net/pages/private/game_dateile/categorized_batting_tab.dart';
import 'package:b_net/pages/private/game_dateile/categorized_pitcher_tab.dart';
import 'package:flutter/material.dart';

class CategorizedGamePage extends StatefulWidget {
  final String userUid;
  final String statId;
  final List<String> userPositions;

  const CategorizedGamePage({
    super.key,
    required this.userUid,
    required this.statId,
    required this.userPositions,
  });

  @override
  State<CategorizedGamePage> createState() => _CategorizedGamePageState();
}

class _CategorizedGamePageState extends State<CategorizedGamePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Tab> _tabs = const [
    Tab(text: '打撃成績'),
    Tab(text: '投手/守備'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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
        title: Text(widget.statId
            .replaceFirst(RegExp(r'^(team_|location_)'), '')), // チーム名 or 球場名
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CategorizedBattingTab(
            userUid: widget.userUid,
            statId: widget.statId,
            userPositions: widget.userPositions,
          ),
          CategorizedPitcherTab(
            userUid: widget.userUid,
            statId: widget.statId,
            userPositions: widget.userPositions,
          ),
        ],
      ),
    );
  }
}
