import 'package:flutter/material.dart';

import 'individual_home.dart';
import 'player_dashboard_page.dart';

class PlayerPage extends StatefulWidget {
  final String userUid;
  final List<String> userPosition;
  final bool hasActiveSubscription;

  const PlayerPage({
    super.key,
    required this.userUid,
    required this.userPosition,
    required this.hasActiveSubscription,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'ダッシュボード'),
                    Tab(text: '成績'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  PlayerDashboardPage(
                    userUid: widget.userUid,
                    userPosition: widget.userPosition,
                  ),
                  IndividualHome(
                    userUid: widget.userUid,
                    userPosition: widget.userPosition,
                    hasActiveSubscription: widget.hasActiveSubscription,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}