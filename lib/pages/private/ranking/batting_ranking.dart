import 'package:b_net/common/profile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BattingRanking extends StatefulWidget {
  final String uid; // ユーザーのUID
  final String prefecture; // ユーザーの都道府県

  const BattingRanking(
      {super.key, required this.uid, required this.prefecture});

  @override
  _BattingRankingState createState() => _BattingRankingState();
}

class _BattingRankingState extends State<BattingRanking> {
  String? _selectedAgeGroup = '全年齢';
  List<Map<String, dynamic>> _players = []; // 選手データを保持
  Map<String, dynamic>? _userData; // ユーザー自身のデータを保持
  String _selectedRankingType = '打率ランキング';
  int _year = DateTime.now().year;
  bool _isSeasonMode = true;
  int _monthlyRankingYear = DateTime.now().year;
  int _monthlyRankingMonth = DateTime.now().month;
  int _playersCount = 0;
  // rankingContextの軽量キャッシュ（自分の前後±2など）
  List<Map<String, dynamic>> _ctxAroundUser = [];

  final List<String> rankingTypes = [
    // 選択肢リスト
    '打率ランキング',
    '本塁打ランキング',
    '盗塁ランキング',
    '打点ランキング',
    '長打率ランキング',
    '出塁率ランキング',
  ];

  // 年齢層のラベルマップ
  Map<String, String> ageGroupLabels = {
    '0_19': '10代',
    '20_29': '20代',
    '30_39': '30代',
    '40_49': '40代',
    '50_59': '50代',
    '60_69': '60代',
    '70_79': '70代',
    '80_89': '80代',
    '90_100': '90代以上',
  };

  List<String> _availableAgeGroups = ['全年齢'];

  @override
  void initState() {
    super.initState();
    _isSeasonMode = true; // 初期状態をシーズンモードに設定
    _fetchPlayersData(); // データを取得
    _fetchPlayersCount();
    _loadAvailableAgeGroups();
  }

  Future<_ResolvedMonthlyRankingPath> _resolveMonthlyRankingPath() async {
    final now = DateTime.now();
    final candidates = <DateTime>[
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month - 1, 1),
    ];

    for (final candidate in candidates) {
      final year = candidate.year;
      final month = candidate.month;
      final noPadBasePath =
          'battingAverageRanking/${year}_${month}/${widget.prefecture}';
      final padBasePath =
          'battingAverageRanking/${year}_${month.toString().padLeft(2, '0')}/${widget.prefecture}';

      final noPadStats =
          await FirebaseFirestore.instance.doc('$noPadBasePath/stats').get();
      if (noPadStats.exists) {
        return _ResolvedMonthlyRankingPath(
          year: year,
          month: month,
          basePath: noPadBasePath,
          monthKeyPad: month.toString().padLeft(2, '0'),
        );
      }

      final padStats =
          await FirebaseFirestore.instance.doc('$padBasePath/stats').get();
      if (padStats.exists) {
        return _ResolvedMonthlyRankingPath(
          year: year,
          month: month,
          basePath: padBasePath,
          monthKeyPad: month.toString().padLeft(2, '0'),
        );
      }
    }

    final fallback = DateTime(now.year, now.month, 1);
    return _ResolvedMonthlyRankingPath(
      year: fallback.year,
      month: fallback.month,
      basePath:
          'battingAverageRanking/${fallback.year}_${fallback.month}/${widget.prefecture}',
      monthKeyPad: fallback.month.toString().padLeft(2, '0'),
    );
  }

  Future<void> _loadAvailableAgeGroups() async {
    String collectionPath;
    if (_isSeasonMode) {
      collectionPath = 'battingAverageRanking/${_year}_total/${widget.prefecture}';
    } else {
      final resolved = await _resolveMonthlyRankingPath();
      final basePath = resolved.basePath;
      var snapshot = await FirebaseFirestore.instance.collection(basePath).get();
      List<String> foundGroups = ['全年齢'];
      for (String group in ageGroupLabels.keys) {
        final exists = snapshot.docs.any((doc) => doc.id.contains('_age_$group'));
        if (exists) foundGroups.add(group);
      }
      if (!mounted) return;
      setState(() {
        _availableAgeGroups = foundGroups;
        if (!_availableAgeGroups.contains(_selectedAgeGroup)) {
          _selectedAgeGroup = '全年齢';
        }
      });
      return;
    }

    // season path
    final snapshot = await FirebaseFirestore.instance
        .collection(collectionPath)
        .get();
    List<String> foundGroups = ['全年齢'];
    for (String group in ageGroupLabels.keys) {
      final exists = snapshot.docs.any((doc) => doc.id.contains('_age_$group'));
      if (exists) foundGroups.add(group);
    }
    if (!mounted) return;
    setState(() {
      _availableAgeGroups = foundGroups;
      if (!_availableAgeGroups.contains(_selectedAgeGroup)) {
        _selectedAgeGroup = '全年齢';
      }
    });
  }

  Future<void> _fetchPlayersData() async {
    try {
      DateTime currentDate = DateTime.now();
      int year;
      int targetMonth = 0; // 初期値を設定
      _ResolvedMonthlyRankingPath? resolvedMonthlyPath;

      // シーズンまたは月間モードに基づいて年と月を設定
      if (_isSeasonMode) {
        year = currentDate.year;
        if (currentDate.month <= 3) {
          year -= 1; // シーズンの場合、1月〜3月は前年のデータを使用
        }
      } else {
        resolvedMonthlyPath = await _resolveMonthlyRankingPath();
        year = resolvedMonthlyPath.year;
        targetMonth = resolvedMonthlyPath.month;
      }

      if (!mounted) return;
      setState(() {
        _year = year; // 年を設定
        if (!_isSeasonMode && resolvedMonthlyPath != null) {
          _monthlyRankingYear = resolvedMonthlyPath.year;
          _monthlyRankingMonth = resolvedMonthlyPath.month;
        }
      });

      // Firestoreのパスを構築
      String basePath;
      if (_isSeasonMode) {
        basePath = 'battingAverageRanking/${year}_total/${widget.prefecture}';
      } else {
        final String monthKeyNoPad = targetMonth.toString();
        // ignore: unused_local_variable
        final String monthKeyPad = targetMonth.toString().padLeft(2, '0');
        basePath = resolvedMonthlyPath?.basePath ??
            'battingAverageRanking/${year}_${monthKeyNoPad}/${widget.prefecture}';

        // 月間モードで「打率ランキング」以外を選択している場合、何も表示しない
        if (_selectedRankingType != '打率ランキング') {
          if (!mounted) return;
          setState(() {
            _players = [];
            _userData = null;
          });
          return;
        }
      }

      List<Map<String, dynamic>> players = [];
      Map<String, dynamic>? userData;
      // 軽量キャッシュを毎回リセット
      _ctxAroundUser = [];

      if (_selectedRankingType == '打率ランキング') {
        final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
            ? '_age_${_selectedAgeGroup}'
            : '';
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/battingAverageRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            players = List<Map<String, dynamic>>.from(
              ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? [],
            );
          } else if (!_isSeasonMode) {
            // 非ゼロ埋めで無ければゼロ埋めを試す
            final altBase = basePath.replaceAllMapped(RegExp(r'_(\d{1,2})/'), (m) {
              final mm = m.group(1) ?? '';
              return '_${mm.padLeft(2, '0')}/';
            });
            final ageDocPad = await FirebaseFirestore.instance
                .doc('$altBase/battingAverageRank_age_${_selectedAgeGroup}')
                .get();
            if (ageDocPad.exists) {
              players = List<Map<String, dynamic>>.from(
                ageDocPad.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? [],
              );
              basePath = altBase; // 以降の個人Doc参照も整合
            }
          }
          if (players.isNotEmpty) {
            // 🔧 年齢別: rank -> battingAverageRank_age_XX
            for (final player in players) {
              if (player.containsKey('rank') && !player.containsKey('battingAverageRank_age_${_selectedAgeGroup}')) {
                player['battingAverageRank_age_${_selectedAgeGroup}'] = player['rank'];
              }
            }
            loadedAgeData = true;
            if (!_isSeasonMode) {
              // print('📆 月別年齢別データ取得: PrefectureTop10_age_${_selectedAgeGroup} (base=$basePath) count=${players.length}');
            }
          }
        }

        if (!loadedAgeData) {
          final docSnapshot = await FirebaseFirestore.instance
              .doc('$basePath/battingAverageRank')
              .get();
          if (docSnapshot.exists) {
            players = List<Map<String, dynamic>>.from(
              docSnapshot.data()?['PrefectureTop10'] ?? [],
            );
          } else if (!_isSeasonMode) {
            // 非ゼロ埋めが無ければゼロ埋めへ
            final altBase = basePath.replaceAllMapped(RegExp(r'_(\d{1,2})/'), (m) {
              final mm = m.group(1) ?? '';
              return '_${mm.padLeft(2, '0')}/';
            });
            final docSnapshotPad = await FirebaseFirestore.instance
                .doc('$altBase/battingAverageRank')
                .get();
            if (docSnapshotPad.exists) {
              players = List<Map<String, dynamic>>.from(
                docSnapshotPad.data()?['PrefectureTop10'] ?? [],
              );
              basePath = altBase; // 以降の個人Doc参照も整合
            }
          }
          if (players.isNotEmpty) {
            for (final player in players) {
              if (player.containsKey('rank') && !player.containsKey('battingAverageRank')) {
                player['battingAverageRank'] = player['rank'];
              }
            }
            if (!_isSeasonMode) {
              // print('📆 月別全年齢データ取得: battingAverageRank (base=$basePath) count=${players.length}');
            }
          }
        }

        players.sort((a, b) => (a['rank'] ?? a['battingAverageRank'] ?? double.infinity)
            .compareTo(b['rank'] ?? b['battingAverageRank'] ?? double.infinity));

        // ignore: unused_local_variable
        final dynamicRankKey = players.firstWhere(
          (p) => p.containsKey('battingAverageRank$ageSuffix'),
          orElse: () => {'battingAverageRank$ageSuffix': 'battingAverageRank'},
        ).containsKey('battingAverageRank$ageSuffix')
            ? 'battingAverageRank$ageSuffix'
            : 'rank';

        final foundPlayer = players.firstWhere(
          (player) => player['id']?.toString() == widget.uid.toString(),
          orElse: () => {},
        );

          if (foundPlayer.isNotEmpty) {
            userData = foundPlayer;
          } else {
            // ユーザーがTOP10に含まれていない場合は rankingContext から補助取得
            if (_isSeasonMode) {
              // シーズン：従来の rankingContext（年間）を利用（軽量：_playersへは入れない）
              final contextDocSnapshot = await FirebaseFirestore.instance
                  .doc('users/${widget.uid}/rankingContext/battingAverageRank$ageSuffix')
                  .get();
              if (contextDocSnapshot.exists) {
                final contextData = contextDocSnapshot.data()?['context'] ?? [];
                if (contextData is List) {
                  final List<Map<String, dynamic>> contextPlayers =
                      contextData.cast<Map<String, dynamic>>();
                  // rank補完（UIでrankキーを使えるようにする）
                  final String computedRankKey = 'battingAverageRank' + ageSuffix;
                  for (final p in contextPlayers) {
                    if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                      p['rank'] = p[computedRankKey];
                    }
                  }
                  _ctxAroundUser = contextPlayers;
                  final self = contextPlayers.firstWhere(
                    (p) => p['id']?.toString() == widget.uid.toString(),
                    orElse: () => <String, dynamic>{},
                  );
                  if (self.isNotEmpty) {
                    userData = self;
                  }
                }
              }
            } else {
              // 月次：月別 rankingContext のみを利用（年間コンテキストは使わない）
              final String monthKey = resolvedMonthlyPath?.monthKeyPad ??
                  DateTime.now().month.toString().padLeft(2, '0');
              final int y = resolvedMonthlyPath?.year ?? DateTime.now().year;
              final monthlyCtxPath = 'users/${widget.uid}/rankingContext/month/${y}_${monthKey}/battingAverageRank$ageSuffix';
              final monthlyCtx = await FirebaseFirestore.instance.doc(monthlyCtxPath).get();
              if (monthlyCtx.exists) {
                final contextData = monthlyCtx.data()?['context'] ?? [];
                if (contextData is List) {
                  final List<Map<String, dynamic>> contextPlayers = contextData.cast<Map<String, dynamic>>();
                  // rank補完＆月キー一致のみ採用
                  final String computedRankKey = 'battingAverageRank' + ageSuffix;
                  final String expectKey = '${y}_${monthKey}';
                  final filtered = <Map<String, dynamic>>[];
                  for (final p in contextPlayers) {
                    if (p['_monthKey']?.toString() == expectKey) {
                      if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                        p['rank'] = p[computedRankKey];
                      }
                      filtered.add(p);
                    }
                  }
                  _ctxAroundUser = filtered;
                  final self = filtered.firstWhere(
                    (p) => p['id']?.toString() == widget.uid.toString(),
                    orElse: () => <String, dynamic>{},
                  );
                  if (self.isNotEmpty) {
                    userData = self;
                  }
                }
              }
            }

          // 個人Doc（該当月/県パス）
          final userDocSnapshot = await FirebaseFirestore.instance
              .doc('$basePath/${widget.uid}')
              .get();
          if (userDocSnapshot.exists) {
            final rawUserData = userDocSnapshot.data() as Map<String, dynamic>;
            if (!rawUserData.containsKey('battingAverageRank')) {
              rawUserData['battingAverageRank'] = rawUserData['rank'] ?? '圏外';
            }
            userData = rawUserData;
          } else {
            userData = {
              'battingAverageRank': '圏外',
              'rank': '圏外',
              'name': '自分',
              'team': ['チーム名不明'],
              'battingAverage': 0.0,
            };
          }
        }
      } else if (_selectedRankingType == '本塁打ランキング') {
        // 年齢別データが存在すればそちらを優先して取得
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/homeRunsRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            players = List<Map<String, dynamic>>.from(
                ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? []);
            loadedAgeData = true;
          }
        }
        if (!loadedAgeData) {
          final docSnapshot = await FirebaseFirestore.instance
              .doc('$basePath/homeRunsRank')
              .get();
          if (docSnapshot.exists) {
            players = List<Map<String, dynamic>>.from(
                docSnapshot.data()?['PrefectureTop10'] ?? []);
          }
        }
        players.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDがtop10に含まれているか確認
        final userInTop10 = players.firstWhere(
          (player) => player['id']?.toString() == widget.uid.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (userInTop10.isNotEmpty) {
          userData = userInTop10;
        } else {
          // top10に含まれていない場合は rankingContext から取得
          final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
              ? '_age_${_selectedAgeGroup}'
              : '';
          final contextDoc = await FirebaseFirestore.instance
              .doc('users/${widget.uid}/rankingContext/homeRunsRank$ageSuffix')
              .get();
          if (contextDoc.exists) {
            final contextData = contextDoc.data()?['context'] ?? [];
            if (contextData is List) {
              final List<Map<String, dynamic>> contextPlayers =
                  contextData.cast<Map<String, dynamic>>();
              final String computedRankKey = 'homeRunsRank' + ageSuffix;
              for (final p in contextPlayers) {
                if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                  p['rank'] = p[computedRankKey];
                }
              }
              _ctxAroundUser = contextPlayers;
              final fromContext = contextPlayers.firstWhere(
                (p) => p['id']?.toString() == widget.uid.toString(),
                orElse: () => <String, dynamic>{},
              );
              if (fromContext.isNotEmpty) {
                userData = fromContext;
              }
            }
          }
          // rankingContext にも無い場合のフォールバック
          userData ??= {
            'name': '自分',
            'team': ['チーム名不明'],
            'homeRuns': 0,
            'homeRunsRank': '圏外',
          };
        }
      } else if (_selectedRankingType == '盗塁ランキング') {
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/stealsRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            players = List<Map<String, dynamic>>.from(
                ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? []);
            loadedAgeData = true;
          }
        }
        if (!loadedAgeData) {
          final docSnapshot =
              await FirebaseFirestore.instance.doc('$basePath/stealsRank').get();
          if (docSnapshot.exists) {
            players = List<Map<String, dynamic>>.from(
                docSnapshot.data()?['PrefectureTop10'] ?? []);
          }
        }
        players.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDが`top10`に含まれているか確認
        final userInTop10 = players.firstWhere(
          (player) => player['id']?.toString() == widget.uid.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (userInTop10.isNotEmpty) {
          userData = userInTop10;
        } else {
          // top10に含まれていない場合は rankingContext から取得
          final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
              ? '_age_${_selectedAgeGroup}'
              : '';
          final contextDoc = await FirebaseFirestore.instance
              .doc('users/${widget.uid}/rankingContext/stealsRank$ageSuffix')
              .get();
          if (contextDoc.exists) {
            final contextData = contextDoc.data()?['context'] ?? [];
            if (contextData is List) {
              final List<Map<String, dynamic>> contextPlayers =
                  contextData.cast<Map<String, dynamic>>();
              final String computedRankKey = 'stealsRank' + ageSuffix;
              for (final p in contextPlayers) {
                if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                  p['rank'] = p[computedRankKey];
                }
              }
              _ctxAroundUser = contextPlayers;
              final fromContext = contextPlayers.firstWhere(
                (p) => p['id']?.toString() == widget.uid.toString(),
                orElse: () => <String, dynamic>{},
              );
              if (fromContext.isNotEmpty) {
                userData = fromContext;
              }
            }
          }
          userData ??= {
            'name': '自分',
            'team': ['チーム名不明'],
            'steals': 0,
            'stealsRank': '圏外',
          };
        }
      } else if (_selectedRankingType == '打点ランキング') {
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/totalRbisRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            players = List<Map<String, dynamic>>.from(
                ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? []);
            loadedAgeData = true;
          }
        }
        if (!loadedAgeData) {
          final docSnapshot = await FirebaseFirestore.instance
              .doc('$basePath/totalRbisRank')
              .get();
          if (docSnapshot.exists) {
            players = List<Map<String, dynamic>>.from(
                docSnapshot.data()?['PrefectureTop10'] ?? []);
          }
        }
        players.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDが`top10`に含まれているか確認
        final userInTop10 = players.firstWhere(
          (player) => player['id']?.toString() == widget.uid.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (userInTop10.isNotEmpty) {
          userData = userInTop10;
        } else {
          // top10に含まれていない場合は rankingContext から取得
          final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
              ? '_age_${_selectedAgeGroup}'
              : '';
          final contextDoc = await FirebaseFirestore.instance
              .doc('users/${widget.uid}/rankingContext/totalRbisRank$ageSuffix')
              .get();
          if (contextDoc.exists) {
            final contextData = contextDoc.data()?['context'] ?? [];
            if (contextData is List) {
              final List<Map<String, dynamic>> contextPlayers =
                  contextData.cast<Map<String, dynamic>>();
              final String computedRankKey = 'totalRbisRank' + ageSuffix;
              for (final p in contextPlayers) {
                if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                  p['rank'] = p[computedRankKey];
                }
              }
              _ctxAroundUser = contextPlayers;
              final fromContext = contextPlayers.firstWhere(
                (p) => p['id']?.toString() == widget.uid.toString(),
                orElse: () => <String, dynamic>{},
              );
              if (fromContext.isNotEmpty) {
                userData = fromContext;
              }
            }
          }
          userData ??= {
            'name': '自分',
            'team': ['チーム名不明'],
            'totalRbis': 0,
            'totalRbisRank': '圏外',
          };
        }
      } else if (_selectedRankingType == '長打率ランキング') {
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/sluggingRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            players = List<Map<String, dynamic>>.from(
                ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? []);
            loadedAgeData = true;
          }
        }
        if (!loadedAgeData) {
          final docSnapshot = await FirebaseFirestore.instance
              .doc('$basePath/sluggingRank')
              .get();
          if (docSnapshot.exists) {
            players = List<Map<String, dynamic>>.from(
                docSnapshot.data()?['PrefectureTop10'] ?? []);
          }
        }
        players.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDが`top10`に含まれているか確認
        final userInTop10 = players.firstWhere(
          (player) => player['id']?.toString() == widget.uid.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (userInTop10.isNotEmpty) {
          userData = userInTop10;
        } else {
          // top10に含まれていない場合は rankingContext から取得
          final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
              ? '_age_${_selectedAgeGroup}'
              : '';
          final contextDoc = await FirebaseFirestore.instance
              .doc('users/${widget.uid}/rankingContext/sluggingRank$ageSuffix')
              .get();
          if (contextDoc.exists) {
            final contextData = contextDoc.data()?['context'] ?? [];
            if (contextData is List) {
              final List<Map<String, dynamic>> contextPlayers =
                  contextData.cast<Map<String, dynamic>>();
              final String computedRankKey = 'sluggingRank' + ageSuffix;
              for (final p in contextPlayers) {
                if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                  p['rank'] = p[computedRankKey];
                }
              }
              _ctxAroundUser = contextPlayers;
              final fromContext = contextPlayers.firstWhere(
                (p) => p['id']?.toString() == widget.uid.toString(),
                orElse: () => <String, dynamic>{},
              );
              if (fromContext.isNotEmpty) {
                userData = fromContext;
              }
            }
          }
          userData ??= {
            'name': '自分',
            'team': ['チーム名不明'],
            'sluggingPercentage': 0,
            'sluggingRank': '圏外',
          };
        }
      } else if (_selectedRankingType == '出塁率ランキング') {
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/onBaseRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            players = List<Map<String, dynamic>>.from(
                ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? []);
            loadedAgeData = true;
          }
        }
        if (!loadedAgeData) {
          final docSnapshot =
              await FirebaseFirestore.instance.doc('$basePath/onBaseRank').get();
          if (docSnapshot.exists) {
            players = List<Map<String, dynamic>>.from(
                docSnapshot.data()?['PrefectureTop10'] ?? []);
          }
        }
        players.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDが`top10`に含まれているか確認
        final userInTop10 = players.firstWhere(
          (player) => player['id']?.toString() == widget.uid.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (userInTop10.isNotEmpty) {
          userData = userInTop10;
        } else {
          // top10に含まれていない場合は rankingContext から取得
          final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
              ? '_age_${_selectedAgeGroup}'
              : '';
          final contextDoc = await FirebaseFirestore.instance
              .doc('users/${widget.uid}/rankingContext/onBaseRank$ageSuffix')
              .get();
          if (contextDoc.exists) {
            final contextData = contextDoc.data()?['context'] ?? [];
            if (contextData is List) {
              final List<Map<String, dynamic>> contextPlayers =
                  contextData.cast<Map<String, dynamic>>();
              final String computedRankKey = 'onBaseRank' + ageSuffix;
              for (final p in contextPlayers) {
                if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                  p['rank'] = p[computedRankKey];
                }
              }
              _ctxAroundUser = contextPlayers;
              final fromContext = contextPlayers.firstWhere(
                (p) => p['id']?.toString() == widget.uid.toString(),
                orElse: () => <String, dynamic>{},
              );
              if (fromContext.isNotEmpty) {
                userData = fromContext;
              }
            }
          }
          userData ??= {
            'name': '自分',
            'team': ['チーム名不明'],
            'onBasePercentage': 0,
            'onBaseRank': '圏外',
          };
        }
      }

      if (!mounted) return;
      setState(() {
        _players = players;
        _userData = userData;
      });

      // print('最終的なユーザー自身のデータ: $_userData'); // 最終的なユーザーデータ確認
    } catch (e) {
      print('Firestoreからのデータ取得中にエラーが発生しました: $e');
      if (!mounted) return;
      setState(() {
        _players = [];
        _userData = null;
      });
    }
  }

  Future<void> _fetchPlayersCount() async {
    try {
      final now = DateTime.now();
      int year;
     
      _ResolvedMonthlyRankingPath? resolvedMonthlyPath;

      String docPath;

      if (_isSeasonMode) {
        // シーズンモード：1〜3月は前年扱い
        year = now.year;
        if (now.month <= 3) {
          year -= 1;
        }
        docPath =
            'battingAverageRanking/${year}_total/${widget.prefecture}/stats';
      } else {
        // 月間モード（最新更新月。今月がなければ先月）
        resolvedMonthlyPath = await _resolveMonthlyRankingPath();
        year = resolvedMonthlyPath.year;
        docPath = '${resolvedMonthlyPath.basePath}/stats';
      }

      // stats ドキュメント取得（先月モードはゼロ埋めフォールバックも試す）
      var statsSnapshot =
          await FirebaseFirestore.instance.doc(docPath).get();

      if (!statsSnapshot.exists && !_isSeasonMode) {
        final altDocPath =
            docPath.replaceAllMapped(RegExp(r'_(\d{1,2})/'), (m) {
          final mm = m.group(1) ?? '';
          return '_${mm.padLeft(2, '0')}/';
        });
        statsSnapshot =
            await FirebaseFirestore.instance.doc(altDocPath).get();
      }

      int count = 0;

      if (statsSnapshot.exists) {
        final data = statsSnapshot.data();

        // 「全年齢」のときは playersCount
        if (_selectedAgeGroup == null || _selectedAgeGroup == '全年齢') {
          count = (data?['playersCount'] ?? 0) as int;
        } else {
          // 年齢別のときは stats.totalPlayers_age_XX_YY を使用
          final statsMap =
              (data?['stats'] ?? <String, dynamic>{}) as Map<String, dynamic>;
          final key = 'totalPlayers_age_${_selectedAgeGroup}';
          count = (statsMap[key] ?? 0) as int;
        }
      }

      if (!mounted) return;
      setState(() {
        _year = year; // 見出しの年も合わせておく
        if (!_isSeasonMode && resolvedMonthlyPath != null) {
          _monthlyRankingYear = resolvedMonthlyPath.year;
          _monthlyRankingMonth = resolvedMonthlyPath.month;
        }
        _playersCount = count;
      });
    } catch (e) {
      print('stats取得エラー: $e');
      if (!mounted) return;
      setState(() {
        _playersCount = 0;
      });
    }
  }

  // Future<void> _fetchPlayersCount() async {
  //   final statsSnapshot = await FirebaseFirestore.instance
  //       .doc('battingAverageRanking/${_year}_total/${widget.prefecture}/stats')
  //       .get();

  //   if (statsSnapshot.exists) {
  //     final data = statsSnapshot.data();
  //     setState(() {
  //       _playersCount = data?['playersCount'] ?? 0;
  //     });
  //   }
  // }

  List<DataRow> _buildTop10Rows() {
    List<DataRow> result = [];

    if (_selectedRankingType == '打率ランキング') {
      // TOP10を表示（圏外を除外し、rankが10以下の選手を表示）
      for (var player in _players) {
        // rankが10以下で、かつ圏外でないことを確認
        final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
            ? '_age_${_selectedAgeGroup}'
            : '';
        final rankKey = 'battingAverageRank$ageSuffix';
        int playerRank = int.tryParse(player[rankKey]?.toString() ?? '') ?? -1;
        if (playerRank != -1 && playerRank <= 10) {
          final isUser = player['id'] == widget.uid;
          result.add(
          DataRow(
            color: MaterialStateProperty.resolveWith<Color?>(
              (states) {
                if (isUser) {
                  return const Color(0xFF1565C0).withOpacity(0.08);
                }
              return null;
            },
          ),
          cells: _buildDataCells(player, isUser: isUser),
        )); // ユーザー自身のデータを太字で表示
        }
      }
    } else if (_selectedRankingType == '本塁打ランキング' ||
        _selectedRankingType == '盗塁ランキング' ||
        _selectedRankingType == '打点ランキング' ||
        _selectedRankingType == '長打率ランキング' ||
        _selectedRankingType == '出塁率ランキング') {
      // 本塁打ランキングのTOP10を表示
      for (var player in _players) {
        if (player['rank'] != null &&
            player['rank'] != '' &&
            (int.tryParse(player['rank'].toString()) ?? 0) <= 10) {
              final isUser = player['id'] == widget.uid;
              result.add(
                DataRow(
                  color: MaterialStateProperty.resolveWith<Color?>(
                    (states) {
                      if (isUser) {
                        return const Color(0xFF1565C0).withOpacity(0.08);
                      }
                      return null;
                    },
                  ),
                  cells: _buildDataCells(player, isUser: isUser),
                ),
              );
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // ユーザーのランクを取得
    final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
        ? '_age_${_selectedAgeGroup}'
        : '';
    final rankKey = 'battingAverageRank$ageSuffix';

    int userRank = -1; // デフォルト値として-1を設定
    if (_selectedRankingType == '打率ランキング' &&
        _userData != null &&
        _userData![rankKey] != '圏外') {
      userRank =
          int.tryParse(_userData![rankKey].toString()) ?? -1;
    }
    final bool _userInAge = _isUserInSelectedAgeGroup();

    final bool isUserOutsideTop10 = (_selectedRankingType == '本塁打ランキング' ||
            _selectedRankingType == '盗塁ランキング' ||
            _selectedRankingType == '打点ランキング' ||
            _selectedRankingType == '長打率ランキング' ||
            _selectedRankingType == '出塁率ランキング') &&
        _userData != null &&
        !_players.any((player) =>
            player['id']?.toString() == widget.uid.toString() &&
            (int.tryParse(player['rank']?.toString() ?? '0') ?? 0) <= 10);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              '${widget.prefecture} 打撃ランキング',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isSeasonMode
                  ? '$_year年シーズン'
                  : '${_monthlyRankingYear}年${_monthlyRankingMonth}月',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _showModePicker(context),
                    child: _FilterChipButton(
                      label: _isSeasonMode ? 'シーズン' : '月',
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showAgePicker(context),
                    child: _FilterChipButton(
                      label: _selectedAgeGroup == '全年齢'
                          ? '全年齢'
                          : ageGroupLabels[_selectedAgeGroup!] ?? _selectedAgeGroup!,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_isSeasonMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.navigate_before, size: 24.0),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final currentIndex = rankingTypes.indexOf(_selectedRankingType);
                          final previousIndex = (currentIndex - 1 + rankingTypes.length) % rankingTypes.length;
                          setState(() {
                            _selectedRankingType = rankingTypes[previousIndex];
                            _fetchPlayersData();
                          });
                        },
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showCupertinoPicker(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                _selectedRankingType,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down,
                                size: 20,
                                color: Colors.black54,
                              )
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.navigate_next, size: 24.0),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final currentIndex = rankingTypes.indexOf(_selectedRankingType);
                          final nextIndex = (currentIndex + 1) % rankingTypes.length;
                          setState(() {
                            _selectedRankingType = rankingTypes[nextIndex];
                            _fetchPlayersData();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  _selectedRankingType,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: Center(
                child: Text(
                  '$_playersCount人がランキングに参加中',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // データがない場合の表示（全てのランキングに適用）
            if (_players.isEmpty) ...[
              Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.only(top: 20),
                child: const Text(
                  'データが見つかりません',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ] else if (_selectedRankingType == '打率ランキング') ...[
              // 打率ランキングの表示
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  columns: _buildDataColumns(),
                  rows: _buildTop10Rows(),
                ),
              ),
              // ユーザーがTOP10に入っていない場合のみ三つのドットを表示
              if (userRank > 10 || userRank == -1 && _userInAge) ...[
                // 三つのドットの表示（縦並び）
                Container(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('・', style: const TextStyle(fontSize: 20)),
                      Text('・', style: const TextStyle(fontSize: 20)),
                      Text('・', style: const TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
                // ユーザー自身と前後の選手を表示するテーブル
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 10,
                    columns: _buildDataColumns(),
                    rows: _buildUserAndPreviousRows(userRank),
                  ),
                ),
              ],
            ] else if (isUserOutsideTop10 && _userInAge) ...[
              // 他のランキングでTOP10外のユーザー表示
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  columns: _buildDataColumns(),
                  rows: _buildTop10Rows(),
                ),
              ),
              Container(
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('・', style: const TextStyle(fontSize: 20)),
                    Text('・', style: const TextStyle(fontSize: 20)),
                    Text('・', style: const TextStyle(fontSize: 20)),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  columns: _buildDataColumns(),
                  rows: _buildUserAndPreviousRows(-1),
                ),
              ),
            ] else
              // 他のランキング表示（ユーザーがTOP10以内の場合）
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  columns: _buildDataColumns(),
                  rows: _buildTop10Rows(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showModePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        int tempIndex = _isSeasonMode ? 0 : 1;

        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child:
                          const Text('キャンセル', style: TextStyle(fontSize: 16)),
                    ),
                    const Text('選択してください',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSeasonMode = tempIndex == 0;
                          _selectedRankingType = '打率ランキング';
                          _fetchPlayersData();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('決定',
                          style: TextStyle(fontSize: 16, color: Colors.blue)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: Colors.white,
                  itemExtent: 40.0,
                  scrollController:
                      FixedExtentScrollController(initialItem: tempIndex),
                  onSelectedItemChanged: (int index) {
                    tempIndex = index;
                  },
                  children: const [
                    Center(child: Text('シーズン', style: TextStyle(fontSize: 24))),
                    Center(child: Text('月', style: TextStyle(fontSize: 24))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCupertinoPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        int tempIndex = rankingTypes.indexOf(_selectedRankingType);

        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child:
                          const Text('キャンセル', style: TextStyle(fontSize: 16)),
                    ),
                    const Text('選択してください',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedRankingType = rankingTypes[tempIndex];
                          _fetchPlayersData();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('決定',
                          style: TextStyle(fontSize: 16, color: Colors.blue)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: Colors.white,
                  itemExtent: 40.0,
                  scrollController:
                      FixedExtentScrollController(initialItem: tempIndex),
                  onSelectedItemChanged: (int index) {
                    tempIndex = index;
                  },
                  children: rankingTypes.map((type) {
                    return Center(
                      child: Text(type, style: const TextStyle(fontSize: 22)),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<DataColumn> _buildDataColumns() {
    if (_selectedRankingType == '打率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // 選手列の幅を設定
            child: Center(child: _buildPlayerHeader()),
          ),
        ), // 選手
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildPlayerHeaderTeam()),
          ),
        ), // チーム
        DataColumn(label: Center(child: _buildVerticalText('打率'))),
        DataColumn(label: Center(child: _buildVerticalText('試合'))),
        DataColumn(label: Center(child: _buildVerticalText('打席'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
        DataColumn(label: Center(child: _buildVerticalText('打点'))),
        DataColumn(label: Center(child: _buildVerticalText('安打'))),
        DataColumn(label: Center(child: _buildVerticalText('二塁打'))),
        DataColumn(label: Center(child: _buildVerticalText('三塁打'))),
        DataColumn(label: Center(child: _buildVerticalText('本塁打'))),
        DataColumn(label: Center(child: _buildVerticalText('塁打'))),
        DataColumn(label: Center(child: _buildVerticalText('得点'))),
        DataColumn(label: Center(child: _buildVerticalText('盗塁'))),
        DataColumn(label: Center(child: _buildVerticalText('犠打'))),
        DataColumn(label: Center(child: _buildVerticalText('犠飛'))),
        DataColumn(label: Center(child: _buildVerticalText('四球'))),
        DataColumn(label: Center(child: _buildVerticalText('死球'))),
        DataColumn(label: Center(child: _buildVerticalText('三振'))),
        DataColumn(label: Center(child: _buildVerticalText('併殺打'))),
        DataColumn(label: Center(child: _buildVerticalText('長打率'))),
        DataColumn(label: Center(child: _buildVerticalText('出塁率'))),
        DataColumn(label: Center(child: _buildVerticalText('OPS'))),
        DataColumn(label: Center(child: _buildVerticalText('RC'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '本塁打ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // 選手列の幅を設定
            child: Center(child: _buildPlayerHeader()),
          ),
        ), // 選手
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildPlayerHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('本塁打'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '盗塁ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // 選手列の幅を設定
            child: Center(child: _buildPlayerHeader()),
          ),
        ), // 選手
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildPlayerHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('盗塁'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '打点ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // 選手列の幅を設定
            child: Center(child: _buildPlayerHeader()),
          ),
        ), // 選手
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildPlayerHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('打点'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '長打率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // 選手列の幅を設定
            child: Center(child: _buildPlayerHeader()),
          ),
        ), // 選手
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildPlayerHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('長打率'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
        DataColumn(label: Center(child: _buildVerticalText('単打'))),
        DataColumn(label: Center(child: _buildVerticalText('二塁打'))),
        DataColumn(label: Center(child: _buildVerticalText('三塁打'))),
        DataColumn(label: Center(child: _buildVerticalText('本塁打'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '出塁率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // 選手列の幅を設定
            child: Center(child: _buildPlayerHeader()),
          ),
        ), // 選手
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildPlayerHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('出塁率'))),
        DataColumn(label: Center(child: _buildVerticalText('打席'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else {
      // デフォルト値を返す
      return [
        DataColumn(
            label: Center(
                child: Text('エラー',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))),
      ];
    }
  }


  // ==== 共通ヘルパー（前後±2表示用）====
String _ageSuffixStr() {
  return _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
      ? '_age_${_selectedAgeGroup}'
      : '';
}

String _metricRankKeyBase() {
  switch (_selectedRankingType) {
    case '本塁打ランキング':
      return 'homeRunsRank';
    case '盗塁ランキング':
      return 'stealsRank';
    case '打点ランキング':
      return 'totalRbisRank';
    case '長打率ランキング':
      return 'sluggingRank';
    case '出塁率ランキング':
      return 'onBaseRank';
    default:
      return 'battingAverageRank';
  }
}

String _resolveRankKeyForCurrentMetric(Map<String, dynamic> player) {
  // playerに'rank'があればそれを優先。無ければ各指標のrankKey + ageSuffix
  if (player.containsKey('rank')) return 'rank';
  return _metricRankKeyBase() + _ageSuffixStr();
}

int _extractRankForCurrentMetric(Map<String, dynamic> player) {
  final key = _resolveRankKeyForCurrentMetric(player);
  final v = player[key]?.toString() ?? '';
  return int.tryParse(v) ?? -1;
}

bool _isUserInSelectedAgeGroup() {
  if (_selectedAgeGroup == null || _selectedAgeGroup == '全年齢') return true;
  final userAge = _userData != null ? _userData!['age'] : null;
  if (userAge is! int) return false; // 年齢不明なら対象外として扱う
  final parts = _selectedAgeGroup!.split('_');
  if (parts.length != 2) return true; // 想定外表記なら弾かない（安全側）
  final minAge = int.tryParse(parts[0]) ?? 0;
  final maxAge = int.tryParse(parts[1]) ?? 200;
  return userAge >= minAge && userAge <= maxAge;
}

  List<DataRow> _buildUserAndPreviousRows(int userRank) {
    // 打率含む全指標で使える汎用版（centerは引数 or _userData）
    if (_userData == null) return [];

    // context優先、無ければ従来の_playersを使う
    final List<Map<String, dynamic>> sourceList =
        _ctxAroundUser.isNotEmpty ? _ctxAroundUser : _players;

    final int centerRank =
        userRank > 0 ? userRank : _extractRankForCurrentMetric(_userData!);

    if (centerRank <= 0) {
      return [
        DataRow(
          color: MaterialStateProperty.resolveWith<Color?>(
            (states) {
              return const Color(0xFF1565C0).withOpacity(0.08);
            },
          ),
          cells: _buildDataCells(_userData!, isUser: true),
        )
      ];
    }

    final List<DataRow> result = [];

    // 上位（自分より良い）: 降順→最後に追加されるよう reverse で2件
    final upper = sourceList
        .where((p) {
          final r = _extractRankForCurrentMetric(p);
          return r > 0 && r < centerRank;
        })
        .toList()
      ..sort((a, b) => _extractRankForCurrentMetric(b)
          .compareTo(_extractRankForCurrentMetric(a)));

    for (final p in upper.take(2).toList().reversed) {
      final isUser = p['id'] == widget.uid;
      result.add(
        DataRow(
          color: MaterialStateProperty.resolveWith<Color?>(
            (states) {
              if (isUser) {
                return const Color(0xFF1565C0).withOpacity(0.08);
              }
              return null;
            },
          ),
          cells: _buildDataCells(p, isUser: isUser),
        ),
      );
    }

    // 自分
    result.add(
      DataRow(
        color: MaterialStateProperty.resolveWith<Color?>(
          (states) {
            return const Color(0xFF1565C0).withOpacity(0.08);
          },
        ),
        cells: _buildDataCells(_userData!, isUser: true),
      ),
    );

    // 下位（自分より悪い）: 昇順で2件
    final lower = sourceList
        .where((p) {
          final r = _extractRankForCurrentMetric(p);
          return r > centerRank;
        })
        .toList()
      ..sort((a, b) => _extractRankForCurrentMetric(a)
          .compareTo(_extractRankForCurrentMetric(b)));

    for (final p in lower.take(2)) {
      final isUser = p['id'] == widget.uid;
      result.add(
        DataRow(
          color: MaterialStateProperty.resolveWith<Color?>(
            (states) {
              if (isUser) {
                return const Color(0xFF1565C0).withOpacity(0.08);
              }
              return null;
            },
          ),
          cells: _buildDataCells(p, isUser: isUser),
        ),
      );
    }

    return result;
  }

  List<DataCell> _buildDataCells(Map<String, dynamic> player,
      {bool isUser = false}) {
    final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
        ? '_age_${_selectedAgeGroup}'
        : '';

    final rankKey = _selectedRankingType == '本塁打ランキング'
        ? (player.containsKey('rank') ? 'rank' : 'homeRunsRank$ageSuffix')
        : _selectedRankingType == '盗塁ランキング'
            ? (player.containsKey('rank') ? 'rank' : 'stealsRank$ageSuffix')
            : _selectedRankingType == '打点ランキング'
                ? (player.containsKey('rank') ? 'rank' : 'totalRbisRank$ageSuffix')
                : _selectedRankingType == '長打率ランキング'
                    ? (player.containsKey('rank') ? 'rank' : 'sluggingRank$ageSuffix')
                    : _selectedRankingType == '出塁率ランキング'
                        ? (player.containsKey('rank') ? 'rank' : 'onBaseRank$ageSuffix')
                        : 'battingAverageRank$ageSuffix';

    String valueKey = 'value';
    if (!player.containsKey('value')) {
      valueKey = _selectedRankingType == '本塁打ランキング'
          ? 'homeRuns'
          : _selectedRankingType == '盗塁ランキング'
              ? 'steals'
              : _selectedRankingType == '打点ランキング'
                  ? 'totalRbis'
                  : _selectedRankingType == '長打率ランキング'
                      ? 'sluggingPercentage'
                      : _selectedRankingType == '出塁率ランキング'
                          ? 'onBasePercentage'
                          : 'battingAverage';
    }

    if (_selectedRankingType == '打率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            (player[rankKey] ?? player['rank'] ?? '圏外').toString(),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              if (player['id'] != null) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  player['id'].toString(),
                  false,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Text(
                (player['name'] ?? '選手名不明').length > 8
                    ? (player['name'] as String).substring(0, 8) + '…'
                    : player['name'] ?? '選手名不明',
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamIDs = player['teamID'] as List<dynamic>? ?? [];
              if (teamIDs.isNotEmpty) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  teamIDs.first.toString(),
                  true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: (player['team'] as List<dynamic>? ?? ['チーム名不明'])
                    .take(2) // 最大2つまで表示
                    .map((team) {
                  final displayTeam =
                      team.length > 8 ? '${team.substring(0, 8)}…' : team;
                  return Text(
                    displayTeam,
                    style: TextStyle(
                      fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      color: isUser ? Colors.blue : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentage(
                num.tryParse((_isSeasonMode ? player[valueKey] : player['battingAverage'])?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalGames']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalRbis']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['single']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['doubles']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['triples']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['homeRuns']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalBases']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['runs']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['steals']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['sacrificeBunts']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['sacrificeFlies']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['walks']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['hitByPitch']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['strikeouts']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['doublePlays']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(player['sluggingPercentage'] ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(player['onBasePercentage'] ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(player['ops'] ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(player['rc'] ?? 0).toString(),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['age']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '本塁打ランキング') {
      return [
        DataCell(Center(
          child: Text(
            player[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              if (player['id'] != null) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  player['id'].toString(),
                  false,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Text(
                (player['name'] ?? '選手名不明').length > 8
                    ? (player['name'] as String).substring(0, 8) + '…'
                    : player['name'] ?? '選手名不明',
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamIDs = player['teamID'] as List<dynamic>? ?? [];
              if (teamIDs.isNotEmpty) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context, 
                  teamIDs.first.toString(),
                  true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: (player['team'] as List<dynamic>? ?? ['チーム名不明'])
                    .take(2) // 最大2つまで表示
                    .map((team) {
                  final displayTeam =
                      team.length > 8 ? '${team.substring(0, 8)}…' : team;
                  return Text(
                    displayTeam,
                    style: TextStyle(
                      fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      color: isUser ? Colors.blue : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            player[valueKey]?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['age']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '盗塁ランキング') {
      return [
        DataCell(Center(
          child: Text(
            player[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              if (player['id'] != null) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  player['id'].toString(),
                  false,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Text(
                (player['name'] ?? '選手名不明').length > 8
                    ? (player['name'] as String).substring(0, 8) + '…'
                    : player['name'] ?? '選手名不明',
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamIDs = player['teamID'] as List<dynamic>? ?? [];
              if (teamIDs.isNotEmpty) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  teamIDs.first.toString(),
                  true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: (player['team'] as List<dynamic>? ?? ['チーム名不明'])
                    .take(2) // 最大2つまで表示
                    .map((team) {
                  final displayTeam =
                      team.length > 8 ? '${team.substring(0, 8)}…' : team;
                  return Text(
                    displayTeam,
                    style: TextStyle(
                      fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      color: isUser ? Colors.blue : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            player[valueKey]?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['age']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '打点ランキング') {
      return [
        DataCell(Center(
          child: Text(
            player[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              if (player['id'] != null) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  player['id'].toString(),
                  false,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Text(
                (player['name'] ?? '選手名不明').length > 8
                    ? (player['name'] as String).substring(0, 8) + '…'
                    : player['name'] ?? '選手名不明',
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamIDs = player['teamID'] as List<dynamic>? ?? [];
              if (teamIDs.isNotEmpty) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  teamIDs.first.toString(),
                  true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: (player['team'] as List<dynamic>? ?? ['チーム名不明'])
                    .take(2) // 最大2つまで表示
                    .map((team) {
                  final displayTeam =
                      team.length > 8 ? '${team.substring(0, 8)}…' : team;
                  return Text(
                    displayTeam,
                    style: TextStyle(
                      fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      color: isUser ? Colors.blue : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            player[valueKey]?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['age']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '長打率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            player[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              if (player['id'] != null) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  player['id'].toString(),
                  false,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Text(
                (player['name'] ?? '選手名不明').length > 8
                    ? (player['name'] as String).substring(0, 8) + '…'
                    : player['name'] ?? '選手名不明',
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamIDs = player['teamID'] as List<dynamic>? ?? [];
              if (teamIDs.isNotEmpty) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  teamIDs.first.toString(),
                  true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: (player['team'] as List<dynamic>? ?? ['チーム名不明'])
                    .take(2) // 最大2つまで表示
                    .map((team) {
                  final displayTeam =
                      team.length > 8 ? '${team.substring(0, 8)}…' : team;
                  return Text(
                    displayTeam,
                    style: TextStyle(
                      fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      color: isUser ? Colors.blue : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentage(
                num.tryParse(player[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['single']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['doubles']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['triples']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['homeRuns']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['age']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '出塁率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            player[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              if (player['id'] != null) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context, 
                  player['id'].toString(), 
                  false,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Text(
                (player['name'] ?? '選手名不明').length > 8
                    ? (player['name'] as String).substring(0, 8) + '…'
                    : player['name'] ?? '選手名不明',
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamIDs = player['teamID'] as List<dynamic>? ?? [];
              if (teamIDs.isNotEmpty) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  teamIDs.first.toString(),
                  true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: (player['team'] as List<dynamic>? ?? ['チーム名不明'])
                    .take(2) // 最大2つまで表示
                    .map((team) {
                  final displayTeam =
                      team.length > 8 ? '${team.substring(0, 8)}…' : team;
                  return Text(
                    displayTeam,
                    style: TextStyle(
                      fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      color: isUser ? Colors.blue : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentage(
                num.tryParse(player[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
         DataCell(Center(
          child: Text(
            player['age']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    }
    return [];
  }

  String formatPercentage(num value) {
    double doubleValue = value.toDouble(); // intをdoubleに変換
    String formatted = doubleValue.toStringAsFixed(3);
    return formatted.startsWith("0")
        ? formatted.replaceFirst("0", "")
        : formatted; // 先頭の0を削除
  }

  // 縦書きテキストウィジェット
  static Widget _buildVerticalText(String text) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: text.split('').map((char) {
          return Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                char,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 選手名のヘッダー
  static Widget _buildPlayerHeader() {
    return const Center(
      child: Text(
        '選手',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  // チーム名のヘッダー
  static Widget _buildPlayerHeaderTeam() {
    return const Center(
      child: Text(
        'チーム',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }


  // 年齢別CupertinoPicker
  void _showAgePicker(BuildContext context) {
    int selectedIndex =
        _availableAgeGroups.indexOf(_selectedAgeGroup ?? '全年齢');

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        int tempIndex = selectedIndex;
        return Container(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                    const Text('年齢を選択',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedAgeGroup = _availableAgeGroups[tempIndex];
                          _fetchPlayersData();
                          _fetchPlayersCount(); 
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('決定',
                          style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                      initialItem: selectedIndex),
                  itemExtent: 40.0,
                  onSelectedItemChanged: (index) {
                    tempIndex = index;
                  },
                  children: _availableAgeGroups.map((group) {
                    return Center(
                        child: Text(group == '全年齢'
                            ? '全年齢'
                            : ageGroupLabels[group] ?? group));
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
// UI filter chip button widget
class _FilterChipButton extends StatelessWidget {
  final String label;

  const _FilterChipButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: Colors.black54,
          ),
        ],
      ),
    );
  }
}

class _ResolvedMonthlyRankingPath {
  final int year;
  final int month;
  final String basePath;
  final String monthKeyPad;

  const _ResolvedMonthlyRankingPath({
    required this.year,
    required this.month,
    required this.basePath,
    required this.monthKeyPad,
  });
}