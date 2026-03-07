import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_dialog.dart'; // 🔹 プロフィール表示用

class _RecommendSection {
  final String title;
  final String kind; // セクション種別（表示の出し分け用）
  final List<Map<String, dynamic>> teams;

  const _RecommendSection({
    required this.title,
    required this.kind,
    required this.teams,
  });
}

class SearchPage extends StatefulWidget {
  /// ログインユーザーの守備位置（例: ["投手", "内野手"]）
  final List<String> userPosition;

  /// ログインユーザーの所属チーム（代表チーム）
  final String? userTeamId;

  /// ログインユーザーの都道府県（取得済みなら渡す。未取得ならこのページ内で取得）
  final String? userPrefecture;

  const SearchPage({
    super.key,
    required this.userPosition,
    this.userTeamId,
    this.userPrefecture,
  });

  @override
  _SearchPageState createState() => _SearchPageState();
}


class _SearchPageState extends State<SearchPage> {
  String _searchType = 'チーム名'; // 🔹 初期状態はチーム検索
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  String? _myPrefecture;
  String? _myTeamId;
  double? _myTeamPower;
  double? _myTeamAvgAge;

  bool _isLoadingRecommend = false;
  List<_RecommendSection> _recommendSections = [];

  bool get _isDirectorOrManager {
    return widget.userPosition.contains('監督') ||
        widget.userPosition.contains('マネージャー');
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged); // 🔹 入力ごとに検索
    _loadMyPrefectureAndRecommend();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// 🔹 テキスト変更時の処理
  void _onSearchTextChanged() {
    String searchQuery = _searchController.text.trim();
    if (searchQuery.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      // 未検索状態になったらおすすめを表示
      _fetchRecommendedTeams();
    } else {
      _searchData();
    }
  }

  /// 🔹 Firestore からリアルタイム検索
  Future<void> _searchData() async {
    String searchQuery = _searchController.text.trim();
    if (searchQuery.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    QuerySnapshot querySnapshot;
    if (_searchType == 'チーム名') {
      querySnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('teamName', isGreaterThanOrEqualTo: searchQuery)
          .where('teamName', isLessThan: searchQuery + '\uf8ff')
          .get();
    } else if (_searchType == '県') {
      // 🔹 県の検索（あいまい検索）
      querySnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('prefecture', isGreaterThanOrEqualTo: searchQuery)
          .where('prefecture', isLessThan: searchQuery + '\uf8ff')
          .get();
    } else {
      // 🔹 ユーザー検索
      querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: searchQuery)
          .where('name', isLessThan: searchQuery + '\uf8ff')
          .get();
    }

    setState(() {
  _searchResults = querySnapshot.docs
      .map<Map<String, dynamic>?>((doc) {
    final data = doc.data() as Map<String, dynamic>;

    if (_searchType == 'ユーザー名') {
      // ✅ チームメンバー登録のみユーザーは検索に出さない
      final isTeamMemberOnly = (data['isTeamMemberOnly'] == true);
      if (isTeamMemberOnly) return null;

      return {
        'id': doc.id,
        'name': data['name'] ?? '不明',
        'profileImage': (data['profileImage'] ?? data['photoURL'] ?? '').toString(),
        'sub': Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['prefecture'] != null)
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      data['prefecture'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (data['positions'] != null && (data['positions'] as List).isNotEmpty)
              Row(
                children: [
                  const Text('ポジション:'),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      (data['positions'] as List).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
          ],
        ),
        'isTeam': false,
      };
    } else {
      return {
        'id': doc.id,
        'name': data['teamName'] ?? '不明',
        'profileImage': data['profileImage'],
        'sub': Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                (data['prefecture'] ?? '不明').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        'isTeam': true,
      };
    }
  })
      .whereType<Map<String, dynamic>>() // ✅ null を除外
      .toList();
});
  }

  Future<void> _loadMyPrefectureAndRecommend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 画面遷移元で既に分かっているならそれを優先
      String? pref = widget.userPrefecture;
      String? teamId = widget.userTeamId;

      // 未取得なら users/{uid} から読む
      if (pref == null || pref.isEmpty || teamId == null || teamId.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = userDoc.data();

        pref = (pref != null && pref.isNotEmpty)
            ? pref
            : ((data != null) ? (data['prefecture'] as String?) : null);

        // users/{uid}.teams は配列想定（最初のチームを代表として使う）
        if (teamId == null || teamId.isEmpty) {
          final teams = (data != null) ? data['teams'] : null;
          if (teams is List && teams.isNotEmpty) {
            final first = teams.first;
            if (first is String && first.isNotEmpty) {
              teamId = first;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _myPrefecture = pref;
        _myTeamId = teamId;
      });

      // 代表チームの power / averageAge を読む（無ければ null のまま）
      if (teamId != null) {
        try {
          final teamDoc = await FirebaseFirestore.instance
              .collection('teams')
              .doc(teamId)
              .get();
          final t = teamDoc.data();
          if (!mounted) return;
          setState(() {
            _myTeamPower = (t?['powerScores${DateTime.now().year}'] as num?)?.toDouble() ??
                (t?['powerScoresAll'] as num?)?.toDouble();
            _myTeamAvgAge = (t?['averageAge'] as num?)?.toDouble();
          });
        } catch (_) {
          // ignore
        }
      }

      await _fetchRecommendedTeams();
    } catch (_) {
      // 失敗しても検索自体は使えるので無視
    }
  }

  Future<void> _fetchRecommendedTeams() async {
    if (_isLoadingRecommend) return;

    // チーム検索以外ではおすすめを作らない
    if (_searchType != 'チーム名' && _searchType != '県') {
      if (!mounted) return;
      setState(() {
        _recommendSections = [];
      });
      return;
    }

    final pref = _myPrefecture;
    if (pref == null || pref.isEmpty) return;

    setState(() {
      _isLoadingRecommend = true;
    });

    try {
      final now = DateTime.now();
      final seasonYear = now.year;
      final useAllPower = now.month <= 3; // 3月中は全期間を使う

      // まずは県内の候補を広めに取得して、クライアントで使い回す
      final baseQs = await FirebaseFirestore.instance
          .collection('teams')
          .where('prefecture', isEqualTo: pref)
          .limit(80)
          .get();

      final candidates = baseQs.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['teamName'] ?? '不明',
          'prefecture': data['prefecture'] ?? '不明',
          'profileImage': (data['profileImage'] ?? '').toString(),
          'averageAge': (data['averageAge'] as num?)?.toDouble(),
          'currentWinStreak': (data['currentWinStreak'] as num?)?.toInt() ?? 0,
          'startYear': (data['startYear'] as num?)?.toInt(),
          'createdAt': data['createdAt'],
          'achievements': (data['achievements'] is List)
              ? List.from(data['achievements'])
              : <dynamic>[],
          // ミラー値（チームdocにある前提）
          'powerAll': (data['powerScoresAll'] as num?)?.toDouble(),
          'powerYear':
              (data['powerScores$seasonYear'] as num?)?.toDouble(),
          // 更新/アクティブ系（あれば拾う）
          'updatedAt': data['updatedAt'] ?? data['lastUpdatedAt'] ?? data['lastActiveAt'] ?? data['lastLoginAt'],
          // 年別stats（監督/マネージャー向けおすすめで使う）
          'yearTotalGames': null,
          'yearWinRate': null,
          'isTeam': true,
        };
      }).toList();

      // 自分のチームは除外（同じ県の候補に混ざっている場合）
      final myTeamId = _myTeamId;
      if (myTeamId != null) {
        candidates.removeWhere((t) => t['id'] == myTeamId);
      }

      // 監督/マネージャー向け：年別stats（totalGames / winRate）を追加で読む
      if (_isDirectorOrManager) {
        final periodId = 'results_stats_${seasonYear}_all';
        for (final t in candidates) {
          final id = (t['id'] ?? '').toString();
          if (id.isEmpty) continue;
          try {
            final sDoc = await FirebaseFirestore.instance
                .collection('teams')
                .doc(id)
                .collection('stats')
                .doc(periodId)
                .get();
            final s = sDoc.data();
            if (s == null) continue;

            final tg = (s['totalGames'] as num?)?.toInt();
            final wr = (s['winRate'] as num?)?.toDouble();
            if (tg != null) t['yearTotalGames'] = tg;
            if (wr != null) t['yearWinRate'] = wr;
          } catch (_) {
            // ignore
          }
        }
      }

      // ---- 1) レベルが近い（power） ----
      final myPower = useAllPower ? (_myTeamPower ?? 0) : (_myTeamPower ?? 0);
      const powerDelta = 10.0; // とりあえず固定（後で設定化OK）
      List<Map<String, dynamic>> similarPower = [];
      if (myPower > 0) {
        similarPower = candidates.where((t) {
          final p = (useAllPower ? t['powerAll'] : t['powerYear']) as double?;
          if (p == null) return false;
          return (p - myPower).abs() <= powerDelta;
        }).toList();
        similarPower.sort((a, b) {
          final pa = (useAllPower ? a['powerAll'] : a['powerYear']) as double? ?? 0;
          final pb = (useAllPower ? b['powerAll'] : b['powerYear']) as double? ?? 0;
          return (pa - myPower).abs().compareTo((pb - myPower).abs());
        });
      }

      // ---- 2) 同じ年齢帯 ----
      final myAge = _myTeamAvgAge;
      const ageDelta = 3.0;
      List<Map<String, dynamic>> similarAge = [];
      if (myAge != null && myAge > 0) {
        similarAge = candidates.where((t) {
          final a = t['averageAge'] as double?;
          if (a == null) return false;
          return (a - myAge).abs() <= ageDelta;
        }).toList();
        similarAge.sort((a, b) {
          final aa = (a['averageAge'] as double?) ?? 0;
          final ab = (b['averageAge'] as double?) ?? 0;
          return (aa - myAge).abs().compareTo((ab - myAge).abs());
        });
      }

      // ---- 3) 連勝中（2以上のみ） ----
      final streak = [...candidates]
        ..sort((a, b) => (b['currentWinStreak'] as int)
            .compareTo(a['currentWinStreak'] as int));
      final hotStreak = streak
          .where((t) => (t['currentWinStreak'] as int) >= 2)
          .toList();

      // ---- 4) 結成が新しい（今年から2年以内） ----
      int? _toStartYear(dynamic v) {
        if (v is num) {
          final n = v.toInt();
          // 20000101 のような形式が来ても年だけ抜く
          if (n >= 10000) return n ~/ 10000;
          return n;
        }
        return null;
      }

      final cutoffStartYear = seasonYear - 2;
      final youngTeams = candidates
          .where((t) {
            final y = _toStartYear(t['startYear']);
            return y != null && y >= cutoffStartYear;
          })
          .toList()
        ..sort((a, b) {
          final ay = _toStartYear(a['startYear']) ?? 0;
          final by = _toStartYear(b['startYear']) ?? 0;
          return by.compareTo(ay);
        });

      // ---- 5) 最近登録（直近3ヶ月以内） ----
      DateTime _toDate(dynamic v) {
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      final recentCutoff = DateTime(now.year, now.month - 3, now.day);
      final recent = candidates
          .where((t) => _toDate(t['createdAt']).isAfter(recentCutoff))
          .toList()
        ..sort((a, b) => _toDate(b['createdAt']).compareTo(_toDate(a['createdAt'])));

      // ---- 6) 実績あり ----
      final achieved = candidates
          .where((t) => (t['achievements'] as List).isNotEmpty)
          .toList()
        ..sort((a, b) => (b['achievements'] as List).length
            .compareTo((a['achievements'] as List).length));

      // ---- 7) 活発なチーム（年別 totalGames が多い）※監督/マネージャーのみ ----
      List<Map<String, dynamic>> activeTeams = [];
      if (_isDirectorOrManager) {
        activeTeams = candidates
            .where((t) => (t['yearTotalGames'] as int?) != null)
            .toList()
          ..sort((a, b) =>
              ((b['yearTotalGames'] as int?) ?? 0)
                  .compareTo((a['yearTotalGames'] as int?) ?? 0));
      }

      // ---- 8) 勝率の高いチーム（年別 winRate 高い + 最低試合数あり）※監督/マネージャーのみ ----
      List<Map<String, dynamic>> highWinRateTeams = [];
      const minGamesForWinRate = 3;
      if (_isDirectorOrManager) {
        highWinRateTeams = candidates
            .where((t) {
              final tg = (t['yearTotalGames'] as int?) ?? 0;
              final wr = t['yearWinRate'] as double?;
              return tg >= minGamesForWinRate && wr != null;
            })
            .toList()
          ..sort((a, b) =>
              ((b['yearWinRate'] as double?) ?? 0)
                  .compareTo((a['yearWinRate'] as double?) ?? 0));
      }

      // ---- 9) 格上（自分より power が高い）※監督/マネージャーのみ ----
      List<Map<String, dynamic>> strongerTeams = [];
      if (_isDirectorOrManager) {
        final myP = _myTeamPower;
        if (myP != null && myP > 0) {
          strongerTeams = candidates.where((t) {
            final p = (useAllPower ? t['powerAll'] : t['powerYear']) as double?;
            if (p == null) return false;
            return p > myP;
          }).toList();
          strongerTeams.sort((a, b) {
            final pa = (useAllPower ? a['powerAll'] : a['powerYear']) as double? ?? 0;
            final pb = (useAllPower ? b['powerAll'] : b['powerYear']) as double? ?? 0;
            return pb.compareTo(pa);
          });
        }
      }

      // ---- 10) 最近ログイン/更新がある（updatedAt系があれば）※監督/マネージャーのみ ----
      List<Map<String, dynamic>> recentlyUpdatedTeams = [];
      if (_isDirectorOrManager) {
        DateTime? _toMaybeDate(dynamic v) {
          if (v is Timestamp) return v.toDate();
          if (v is DateTime) return v;
          return null;
        }

        final cutoff = now.subtract(const Duration(days: 30));
        recentlyUpdatedTeams = candidates.where((t) {
          final d = _toMaybeDate(t['updatedAt']);
          if (d == null) return false;
          return d.isAfter(cutoff);
        }).toList();
        recentlyUpdatedTeams.sort((a, b) {
          final da = _toMaybeDate(a['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = _toMaybeDate(b['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
      }

      // 表示数（要望）
      // - レベルが近い: 12件
      // - それ以外: 8件（ここでは 8件 に統一）
      // - 合計50件以内。足りなければ「同じ県」セクションで埋める
      final maxTotal = _isDirectorOrManager ? 50 : 25;
      final countSimilarPower = _isDirectorOrManager ? 12 : 4;
      final countOther = _isDirectorOrManager ? 8 : 4;

      // 監督/マネージャーの場合、「最近動きがあるチーム」を必ず出したいので枠を予約する
      final reservedForRecentActivity = _isDirectorOrManager ? countOther : 0;
      final maxBeforeManagerExtras = (maxTotal - reservedForRecentActivity).clamp(0, maxTotal);

      int totalShown = 0;
      final usedIds = <String>{};

      List<Map<String, dynamic>> _takeWithLimit(List<Map<String, dynamic>> xs, int limit) {
        if (xs.isEmpty) return const [];
        final n = (xs.length < limit) ? xs.length : limit;
        return xs.take(n).toList();
      }

      void _markUsed(List<Map<String, dynamic>> list) {
        for (final t in list) {
          final id = (t['id'] ?? '').toString();
          if (id.isNotEmpty) usedIds.add(id);
        }
        totalShown += list.length;
      }

      final sections = <_RecommendSection>[];

      if (similarPower.isNotEmpty && totalShown < maxBeforeManagerExtras) {
        final picked = _takeWithLimit(similarPower, countSimilarPower);
        if (picked.isNotEmpty) {
          _markUsed(picked);
          sections.add(_RecommendSection(
            title: '実力が近いチーム',
            kind: 'similarPower',
            teams: picked,
          ));
        }
      }

      if (similarAge.isNotEmpty && totalShown < maxBeforeManagerExtras) {
        final picked = _takeWithLimit(similarAge, countOther);
        if (picked.isNotEmpty) {
          _markUsed(picked);
          sections.add(_RecommendSection(
            title: '年齢が近いチーム',
            kind: 'similarAge',
            teams: picked,
          ));
        }
      }

      // 条件に当てはまるチームが無いなら「出さない」
      if (hotStreak.isNotEmpty && totalShown < maxBeforeManagerExtras) {
        final picked = _takeWithLimit(hotStreak, countOther);
        if (picked.isNotEmpty) {
          _markUsed(picked);
          sections.add(_RecommendSection(
            title: '連勝中で勢いのあるチーム',
            kind: 'hotStreak',
            teams: picked,
          ));
        }
      }

      if (youngTeams.isNotEmpty && totalShown < maxBeforeManagerExtras) {
        final picked = _takeWithLimit(youngTeams, countOther);
        if (picked.isNotEmpty) {
          _markUsed(picked);
          sections.add(_RecommendSection(
            title: '結成が新しいチーム',
            kind: 'newlyFormed',
            teams: picked,
          ));
        }
      }

      if (recent.isNotEmpty && totalShown < maxBeforeManagerExtras) {
        final picked = _takeWithLimit(recent, countOther);
        if (picked.isNotEmpty) {
          _markUsed(picked);
          sections.add(_RecommendSection(
            title: '最近登録したチーム',
            kind: 'recentRegistered',
            teams: picked,
          ));
        }
      }

      if (achieved.isNotEmpty && totalShown < maxBeforeManagerExtras) {
        final picked = _takeWithLimit(achieved, countOther);
        if (picked.isNotEmpty) {
          _markUsed(picked);
          sections.add(_RecommendSection(
            title: '実績があるチーム',
            kind: 'achievements',
            teams: picked,
          ));
        }
      }

      // 監督/マネージャーだけ追加で表示するおすすめ
      if (_isDirectorOrManager) {
        if (recentlyUpdatedTeams.isNotEmpty && totalShown < maxTotal) {
          final picked = _takeWithLimit(recentlyUpdatedTeams.where((t) {
            final id = (t['id'] ?? '').toString();
            return id.isNotEmpty && !usedIds.contains(id);
          }).toList(), countOther);
          if (picked.isNotEmpty) {
            _markUsed(picked);
            sections.add(_RecommendSection(
              title: '最近動きがあるチーム',
              kind: 'recentlyUpdated',
              teams: picked,
            ));
          }
        }

        if (activeTeams.isNotEmpty && totalShown < maxTotal) {
          final picked = _takeWithLimit(activeTeams.where((t) {
            final id = (t['id'] ?? '').toString();
            return id.isNotEmpty && !usedIds.contains(id);
          }).toList(), countOther);
          if (picked.isNotEmpty) {
            _markUsed(picked);
            sections.add(_RecommendSection(
              title: '活発なチーム',
              kind: 'activeTeams',
              teams: picked,
            ));
          }
        }

        if (highWinRateTeams.isNotEmpty && totalShown < maxTotal) {
          final picked = _takeWithLimit(
            highWinRateTeams.where((t) {
              final id = (t['id'] ?? '').toString();
              return id.isNotEmpty;
            }).toList(),
            countOther,
          );
          if (picked.isNotEmpty) {
            _markUsed(picked);
            sections.add(_RecommendSection(
              title: '勝率の高いチーム',
              kind: 'highWinRate',
              teams: picked,
            ));
          }
        }

        if (strongerTeams.isNotEmpty && totalShown < maxTotal) {
          final picked = _takeWithLimit(strongerTeams.where((t) {
            final id = (t['id'] ?? '').toString();
            return id.isNotEmpty && !usedIds.contains(id);
          }).toList(), countOther);
          if (picked.isNotEmpty) {
            _markUsed(picked);
            sections.add(_RecommendSection(
              title: '格上のチーム',
              kind: 'strongerTeams',
              teams: picked,
            ));
          }
        }
      }

      // 合計がmaxTotal件に満たない場合は「同じ県のチーム」で埋める
      if (totalShown < maxTotal) {
        final remaining = maxTotal - totalShown;
        final pool = [...candidates];
        pool.shuffle();

        final filler = <Map<String, dynamic>>[];
        for (final t in pool) {
          if (filler.length >= remaining) break;
          final id = (t['id'] ?? '').toString();
          if (id.isEmpty) continue;
          if (usedIds.contains(id)) continue;
          filler.add(t);
          usedIds.add(id);
        }

        if (filler.isNotEmpty) {
          sections.add(_RecommendSection(
            title: '同じ県のチーム',
            kind: 'samePrefFill',
            teams: filler,
          ));
          totalShown += filler.length;
        }
      }

      if (!mounted) return;
      setState(() {
        _recommendSections = sections;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recommendSections = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingRecommend = false;
      });
    }
  }

  Widget _buildRecommendedSection() {
    // 県が取れていない/チーム検索以外なら出さない
    if (_searchType != 'チーム名' && _searchType != '県') {
      return const Center(child: Text('検索ワードを入力してください'));
    }

    if (_myPrefecture == null || _myPrefecture!.isEmpty) {
      return const Center(child: Text('おすすめを表示するにはプロフィールに県を設定してください'));
    }

    if (_isLoadingRecommend) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recommendSections.isEmpty) {
      return Center(child: Text('おすすめチーム（${_myPrefecture!}）はまだありません'));
    }

    return ListView.builder(
      itemCount: _recommendSections.length,
      itemBuilder: (context, index) {
        final section = _recommendSections[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...section.teams.map((t) {
                final profileImage = (t['profileImage'] ?? '').toString();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: (profileImage.isNotEmpty && profileImage.startsWith('http'))
                        ? NetworkImage(profileImage)
                        : const AssetImage('assets/default_team_avatar.png') as ImageProvider,
                    onBackgroundImageError: (_, __) {},
                  ),
                  title: Text(t['name'] ?? '不明'),
                  subtitle: Builder(
                    builder: (context) {
                      // 追加情報（セクションごとに出し分け）
                      String? extra;

                      if (section.kind == 'hotStreak') {
                        final s = (t['currentWinStreak'] as int?) ?? 0;
                        extra = '${s}連勝中';
                      } else if (section.kind == 'similarAge') {
                        final a = (t['averageAge'] as double?) ??
                            (t['averageAge'] as num?)?.toDouble();
                        if (a != null && a > 0) {
                          extra = '平均年齢: ${a.toStringAsFixed(1)}歳';
                        }
                      } else if (section.kind == 'newlyFormed') {
                        // startYear が 20000101 のような形式でも年だけ抜く
                        int? y;
                        final raw = t['startYear'];
                        if (raw is num) {
                          final n = raw.toInt();
                          y = (n >= 10000) ? (n ~/ 10000) : n;
                        }
                        if (y != null && y > 0) {
                          extra = '結成: ${y}年';
                        }
                      } else if (section.kind == 'recentRegistered') {
                        // 何ヶ月前に登録したか（0ヶ月は「今月」扱い）
                        DateTime created;
                        final ca = t['createdAt'];
                        if (ca is Timestamp) {
                          created = ca.toDate();
                        } else if (ca is DateTime) {
                          created = ca;
                        } else {
                          created = DateTime.fromMillisecondsSinceEpoch(0);
                        }
                        final now = DateTime.now();
                        int months = (now.year - created.year) * 12 + (now.month - created.month);
                        if (months < 0) months = 0;
                        extra = (months == 0) ? '登録: 今月' : '登録: ${months}ヶ月前';
                      } else if (section.kind == 'achievements') {
                        final ach = (t['achievements'] is List) ? (t['achievements'] as List) : <dynamic>[];
                        if (ach.isNotEmpty) {
                          extra = ach.first.toString(); // 1つだけ表示
                        }
                      }
                      else if (section.kind == 'activeTeams') {
                        final g = (t['yearTotalGames'] as int?) ?? 0;
                        if (g > 0) extra = '今年: $g試合';
                      } else if (section.kind == 'highWinRate') {
                        final g = (t['yearTotalGames'] as int?) ?? 0;
                        final wr = t['yearWinRate'] as double?;
                        if (wr != null) {
                          extra = '今年: 勝率 ${(wr * 100).toStringAsFixed(0)}%（$g試合）';
                        }
                      } else if (section.kind == 'strongerTeams') {
                        extra = '格上のチーム';
                      } else if (section.kind == 'recentlyUpdated') {
                        // 何日前に更新/ログインしたか（updatedAtがある前提）
                        DateTime? d;
                        final v = t['updatedAt'];
                        if (v is Timestamp) d = v.toDate();
                        if (v is DateTime) d = v;
                        if (d != null) {
                          final days = DateTime.now().difference(d).inDays;
                          extra = (days <= 0) ? '最近更新あり' : '更新: ${days}日前';
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  (t['prefecture'] ?? '不明').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (extra != null && extra.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              extra,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showProfileDialog(
                      context,
                      t['id'],
                      true,
                      currentUserUid: FirebaseAuth.instance.currentUser!.uid,
                      currentUserName:
                          FirebaseAuth.instance.currentUser!.displayName,
                      isFromSearch: true,
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("検索")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 ラジオボタン（検索タイプ選択）
            Row(
              children: [
                _buildRadioButton("チーム名", "チーム名"),
                _buildRadioButton("県", "県"),
                _buildRadioButton("ユーザー名", "ユーザー名"),
              ],
            ),
            const SizedBox(height: 10),

            // 🔹 検索バー（検索ボタン付き）
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _searchType == '県'
                          ? "都道府県を入力"
                          : _searchType == 'ユーザー名'
                              ? "ユーザー名を入力"
                              : "チーム名を入力",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12.0),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchData, // 🔹 検索ボタンタップで検索
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 🔹 検索結果リスト
            Expanded(
              child: (_searchController.text.trim().isEmpty)
                  ? _buildRecommendedSection()
                  : (_searchResults.isEmpty
                      ? const Center(child: Text("該当する結果がありません"))
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final result = _searchResults[index];
                            return ListTile(
                              leading: result['isTeam'] == true
                                  ? CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage: (result['profileImage'] != null &&
                                              (result['profileImage'] as String?)?.isNotEmpty == true)
                                          ? NetworkImage(result['profileImage'])
                                          : const AssetImage('assets/default_team_avatar.png')
                                              as ImageProvider,
                                      onBackgroundImageError: (_, __) {},
                                    )
                                  : CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage: (result['profileImage'] != null &&
                                              (result['profileImage'] as String).isNotEmpty)
                                          ? NetworkImage(result['profileImage'] as String)
                                          : const AssetImage('assets/default_user_avatar.png') as ImageProvider,
                                      onBackgroundImageError: (_, __) {},
                                      child: (result['profileImage'] == null ||
                                              (result['profileImage'] as String).isEmpty)
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                              title: Text(result['name']),
                              subtitle: result['sub'],
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // 🔹 プロフィールを開く（チーム or ユーザー）
                                showProfileDialog(
                                  context,
                                  result['id'],
                                  result['isTeam'],
                                  currentUserUid: FirebaseAuth.instance.currentUser!.uid,
                                  currentUserName: FirebaseAuth.instance.currentUser!.displayName,
                                  isFromSearch: true, // 🔹 検索結果から開く時だけ true にする
                                );
                              },
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 **ラジオボタンウィジェット**
  Widget _buildRadioButton(String title, String value) {
    return Row(
      children: [
        Radio(
          value: value,
          groupValue: _searchType,
          onChanged: (newValue) {
            setState(() {
              _searchType = newValue.toString();
              _searchController.clear(); // 🔹 入力欄をリセット
              _searchResults = []; // 🔹 検索結果をクリア
              if (_searchType != 'ユーザー名') {
                _fetchRecommendedTeams();
              }
            });
          },
        ),
        Text(title),
        const SizedBox(width: 10),
      ],
    );
  }
}
