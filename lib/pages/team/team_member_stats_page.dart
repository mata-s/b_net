import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeamMemberStatsPage extends StatelessWidget {
  final String teamId;

  const TeamMemberStatsPage({
    super.key,
    required this.teamId,
  });

  int get _currentYear => DateTime.now().year;

  Future<List<Map<String, dynamic>>> _loadMembers() async {
    final teamDoc = await FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .get();

    final memberIds = List<String>.from(teamDoc.data()?['members'] ?? []);
    if (memberIds.isEmpty) return [];

    final yearKey = 'results_stats_${_currentYear}_all';

    final futures = memberIds.map((uid) async {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final statsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stats')
          .doc(yearKey)
          .get();

      final userData = userDoc.data() ?? {};
      final statsData = statsDoc.data() ?? {};

      return {
        'uid': uid,
        'name': userData['name'] ?? '名前なし',
        'profileImage': userData['profileImage'],
        'positions': List<String>.from(userData['positions'] ?? []),
        'isTeamMemberOnly': userData['isTeamMemberOnly'] ?? false,
        'battingAverage': statsData['battingAverage'],
        'era': statsData['era'],
        'totalGames': statsData['totalGames'],
        'totalWins': statsData['totalWins'],
        'ops': statsData['ops'],
      };
    }).toList();

    final members = await Future.wait(futures);
    final filteredMembers = members.where((member) {
      final positions = List<String>.from(member['positions'] ?? []);
      final isDirectorOrManager =
          positions.contains('監督') || positions.contains('マネージャー');
      return !isDirectorOrManager;
    }).toList();
    filteredMembers.sort((a, b) {
      final aOps = a['ops'];
      final bOps = b['ops'];

      final aValue = aOps is num ? aOps.toDouble() : -1.0;
      final bValue = bOps is num ? bOps.toDouble() : -1.0;

      final byOps = bValue.compareTo(aValue);
      if (byOps != 0) return byOps;

      final aName = (a['name'] ?? '').toString();
      final bName = (b['name'] ?? '').toString();
      return aName.compareTo(bName);
    });
    return filteredMembers;
  }

  String _formatAverage(dynamic value) {
    if (value is num) return value.toStringAsFixed(3);
    return '-';
  }

  String _formatEra(dynamic value) {
    if (value is num) return value.toStringAsFixed(2);
    return '-';
  }

  String _formatOps(dynamic value) {
    if (value is num) return value.toStringAsFixed(3);
    return '-';
  }

  String _formatCount(dynamic value) {
    if (value is int) return value.toString();
    if (value is num) return value.toInt().toString();
    return '-';
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('チームメンバー成績（$_currentYear年）'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadMembers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('成績の読み込みに失敗しました'));
          }

          final members = snapshot.data ?? [];
          if (members.isEmpty) {
            return const Center(child: Text('メンバーがいません'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final m = members[index];
              final isTeamMemberOnly = m['isTeamMemberOnly'] == true;
              final positions = List<String>.from(m['positions'] ?? []);
              final isPitcher = positions.contains('投手');
              final imageUrl = (m['profileImage'] ?? '').toString();

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                          child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (m['name'] ?? '名前なし').toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (isTeamMemberOnly)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      '仮登録',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.3,
                      children: [
                        _buildStatChip('打率', _formatAverage(m['battingAverage'])),
                        if (isPitcher)
                          _buildStatChip('防御率', _formatEra(m['era'])),
                        _buildStatChip('試合数', _formatCount(m['totalGames'])),
                        if (isPitcher)
                          _buildStatChip('勝利', _formatCount(m['totalWins'])),
                        _buildStatChip('OPS', _formatOps(m['ops'])),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}