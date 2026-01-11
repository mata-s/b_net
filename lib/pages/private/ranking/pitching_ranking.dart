import 'package:b_net/common/profile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class PitchingRanking extends StatefulWidget {
  final String uid; // ユーザーのUID
  final String prefecture; // ユーザーの都道府県

  const PitchingRanking(
      {super.key, required this.uid, required this.prefecture});

  @override
  State<PitchingRanking> createState() => _PitchingRankingState();
}

class _PitchingRankingState extends State<PitchingRanking> {
  String? _selectedAgeGroup = '全年齢';
  List<Map<String, dynamic>> _players = []; // 選手データを保持
  Map<String, dynamic>? _userData; // ユーザー自身のデータを保持
  String _selectedRankingType = '防御率ランキング';
  int _year = DateTime.now().year;
  bool _isSeasonMode = true;
  bool _isPitcher = false;
  int _pitchersCount = 0;

  List<Map<String, dynamic>> _ctxAroundUser = []; 

  final List<String> rankingTypes = [
    // 選択肢リスト
    '防御率ランキング',
    '奪三振ランキング',
    'ホールドポイントランキング',
    'セーブランキング',
    '勝率ランキング',
  ];

  Map<String, String> ageGroupLabels = {
    '0_19': '10代未満',
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
    _fetchUserPositions();
    _fetchPlayersData();
    _fetchPitcherCount();
    _loadAvailableAgeGroups();
  }

  Future<void> _loadAvailableAgeGroups() async {
    String collectionPath;
    if (_isSeasonMode) {
      collectionPath = 'pitcherRanking/${_year}_total/${widget.prefecture}';
    } else {
      final now = DateTime.now();
      int y = now.year;
      int m = now.month - 1;
      if (m == 0) { m = 12; y -= 1; }
      final noPad = 'pitcherRanking/${y}_${m}/${widget.prefecture}';
      final pad = 'pitcherRanking/${y}_${m.toString().padLeft(2, '0')}/${widget.prefecture}';
      // try non-padded first; if empty, try padded
      var snapshot = await FirebaseFirestore.instance.collection(noPad).get();
      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance.collection(pad).get();
      }
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
    setState(() {
      _availableAgeGroups = foundGroups;
      if (!_availableAgeGroups.contains(_selectedAgeGroup)) {
        _selectedAgeGroup = '全年齢';
      }
    });
  }

  Future<void> _fetchUserPositions() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      final positions = userDoc.data()?['positions'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _isPitcher = positions.contains('投手');
      });
      // print('ユーザーの positions: $positions');
    } catch (e) {
      print('positions 取得中にエラーが発生しました: $e');
    }
  }

  Future<void> _fetchPlayersData() async {
    try {
      DateTime currentDate = DateTime.now();
      int year;
      int lastMonth = 0; // 初期値を設定

      // シーズンまたは先月モードに基づいて年と月を設定
      if (_isSeasonMode) {
        year = currentDate.year;
        if (currentDate.month <= 3) {
          year -= 1; // シーズンの場合、1月〜3月は前年のデータを使用
        }
      } else {
        year = currentDate.year;
        lastMonth = currentDate.month - 1;
        if (lastMonth == 0) {
          lastMonth = 12;
          year -= 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _year = year; // 年を設定
      });

      // Firestoreのパスを構築
      String basePath;
      if (_isSeasonMode) {
        basePath = 'pitcherRanking/${year}_total/${widget.prefecture}';
      } else {
        final String monthKeyNoPad = lastMonth.toString();
        // ignore: unused_local_variable
        final String monthKeyPad = lastMonth.toString().padLeft(2, '0');
        // デフォは非ゼロ埋め（/2025_9/）だが、後続の取得で存在しなければゼロ埋め（/2025_09/）を試す
        basePath = 'pitcherRanking/${year}_${monthKeyNoPad}/${widget.prefecture}';

        // 先月モードで「打率ランキング」以外を選択している場合、何も表示しない
        if (_selectedRankingType != '防御率ランキング') {
          setState(() {
            _players = [];
            _userData = null;
          });
          return;
        }
      }
      // Clear context buffer before fetching
      _ctxAroundUser = [];
      List<Map<String, dynamic>> players = [];
      Map<String, dynamic>? userData;

      // ========================= 防御率ランキング =========================
if (_selectedRankingType == '防御率ランキング') {
  final String ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
      ? '_age_${_selectedAgeGroup}'
      : '';
  bool loadedAgeData = false;

  // 年齢別Top10データ優先
  if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
    final ageDoc = await FirebaseFirestore.instance
        .doc('$basePath/eraRank$ageSuffix')
        .get();
    if (ageDoc.exists) {
      players = List<Map<String, dynamic>>.from(
        ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? [],
      );
      loadedAgeData = true;
    }
  }

  // 年齢別が無ければ全年齢Top10
  if (!loadedAgeData) {
    final docSnapshot = await FirebaseFirestore.instance
        .doc('$basePath/eraRank')
        .get();
    if (docSnapshot.exists) {
      players = List<Map<String, dynamic>>.from(
        docSnapshot.data()?['PrefectureTop10'] ?? [],
      );
    }
  }

  // ソート
  players.sort((a, b) => (a['rank'] ?? a['eraRank'] ?? double.infinity)
      .compareTo(b['rank'] ?? b['eraRank'] ?? double.infinity));

  // ユーザーがTop10にいるか
  final found = players.firstWhere(
    (p) => p['id']?.toString() == widget.uid.toString(),
    orElse: () => <String, dynamic>{},
  );

  if (found.isNotEmpty) {
    userData = found;
  } else {
    // --- rankCtxPitcherから取得 ---
    final ctxDoc = await FirebaseFirestore.instance
        .doc('users/${widget.uid}/rankCtxPitcher/eraRank$ageSuffix')
        .get();
    if (ctxDoc.exists) {
      final ctx = ctxDoc.data()?['context'] ?? [];
      if (ctx is List) {
        final List<Map<String, dynamic>> ctxPlayers = ctx.cast<Map<String, dynamic>>();
        // ★ Keep context separate for lightweight ±2 rendering
        _ctxAroundUser = ctxPlayers;
        final me = ctxPlayers.firstWhere(
          (p) => p['id']?.toString() == widget.uid.toString(),
          orElse: () => <String, dynamic>{},
        );
        if (me.isNotEmpty) userData = me;
      }
    }

    // 保険（個人Doc）
    if (userData == null) {
      final userDocSnapshot =
          await FirebaseFirestore.instance.doc('$basePath/${widget.uid}').get();
      if (userDocSnapshot.exists) {
        final raw = userDocSnapshot.data() as Map<String, dynamic>;
        raw['eraRank'] ??= raw['rank'] ?? '圏外';
        userData = raw;
      } else {
        userData = {
          'name': '自分',
          'team': ['チーム名不明'],
          'eraRank': '圏外',
        };
      }
    }
  }
}

// ========================= 奪三振ランキング =========================
else if (_selectedRankingType == '奪三振ランキング') {
  final String ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
      ? '_age_${_selectedAgeGroup}'
      : '';
  bool loadedAgeData = false;

  if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
    final ageDoc = await FirebaseFirestore.instance
        .doc('$basePath/totalPStrikeoutsRank$ageSuffix')
        .get();
    if (ageDoc.exists) {
      players = List<Map<String, dynamic>>.from(
        ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? [],
      );
      loadedAgeData = true;
    }
  }

  if (!loadedAgeData) {
    final docSnapshot = await FirebaseFirestore.instance
        .doc('$basePath/totalPStrikeoutsRank')
        .get();
    if (docSnapshot.exists) {
      players = List<Map<String, dynamic>>.from(
        docSnapshot.data()?['PrefectureTop10'] ?? [],
      );
    }
  }

  players.sort((a, b) => (a['rank'] ?? double.infinity)
      .compareTo(b['rank'] ?? double.infinity));

  final found = players.firstWhere(
    (p) => p['id']?.toString() == widget.uid.toString(),
    orElse: () => <String, dynamic>{},
  );

  if (found.isNotEmpty) {
    userData = found;
  } else {
    final ctxDoc = await FirebaseFirestore.instance
        .doc('users/${widget.uid}/rankCtxPitcher/totalPStrikeoutsRank$ageSuffix')
        .get();
    if (ctxDoc.exists) {
      final ctx = ctxDoc.data()?['context'] ?? [];
      if (ctx is List) {
        final List<Map<String, dynamic>> ctxPlayers = ctx.cast<Map<String, dynamic>>();
        _ctxAroundUser = ctxPlayers;
        final me = ctxPlayers.firstWhere(
          (p) => p['id']?.toString() == widget.uid.toString(),
          orElse: () => <String, dynamic>{},
        );
        if (me.isNotEmpty) userData = me;
      }
    }

    userData ??= {
      'name': '自分',
      'team': ['チーム名不明'],
      'totalPStrikeoutsRank': '圏外',
    };
  }
}

// ========================= ホールドポイントランキング =========================
else if (_selectedRankingType == 'ホールドポイントランキング') {
  final String ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
      ? '_age_${_selectedAgeGroup}'
      : '';
  bool loadedAgeData = false;

  if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
    final ageDoc = await FirebaseFirestore.instance
        .doc('$basePath/totalHoldPointsRank$ageSuffix')
        .get();
    if (ageDoc.exists) {
      players = List<Map<String, dynamic>>.from(
        ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? [],
      );
      loadedAgeData = true;
    }
  }

  if (!loadedAgeData) {
    final docSnapshot = await FirebaseFirestore.instance
        .doc('$basePath/totalHoldPointsRank')
        .get();
    if (docSnapshot.exists) {
      players = List<Map<String, dynamic>>.from(
        docSnapshot.data()?['PrefectureTop10'] ?? [],
      );
    }
  }

  players.sort((a, b) => (a['rank'] ?? double.infinity)
      .compareTo(b['rank'] ?? double.infinity));

  final found = players.firstWhere(
    (p) => p['id']?.toString() == widget.uid.toString(),
    orElse: () => <String, dynamic>{},
  );

  if (found.isNotEmpty) {
    userData = found;
  } else {
    final ctxDoc = await FirebaseFirestore.instance
        .doc('users/${widget.uid}/rankCtxPitcher/totalHoldPointsRank$ageSuffix')
        .get();
    if (ctxDoc.exists) {
      final ctx = ctxDoc.data()?['context'] ?? [];
      if (ctx is List) {
        final List<Map<String, dynamic>> ctxPlayers = ctx.cast<Map<String, dynamic>>();
        _ctxAroundUser = ctxPlayers;
        final me = ctxPlayers.firstWhere(
          (p) => p['id']?.toString() == widget.uid.toString(),
          orElse: () => <String, dynamic>{},
        );
        if (me.isNotEmpty) userData = me;
      }
    }

    userData ??= {
      'name': '自分',
      'team': ['チーム名不明'],
      'totalHoldPointsRank': '圏外',
    };
  }
}

// ========================= セーブランキング =========================
else if (_selectedRankingType == 'セーブランキング') {
  final String ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
      ? '_age_${_selectedAgeGroup}'
      : '';
  bool loadedAgeData = false;

  if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
    final ageDoc = await FirebaseFirestore.instance
        .doc('$basePath/totalSavesRank$ageSuffix')
        .get();
    if (ageDoc.exists) {
      players = List<Map<String, dynamic>>.from(
        ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? [],
      );
      loadedAgeData = true;
    }
  }

  if (!loadedAgeData) {
    final docSnapshot = await FirebaseFirestore.instance
        .doc('$basePath/totalSavesRank')
        .get();
    if (docSnapshot.exists) {
      players = List<Map<String, dynamic>>.from(
        docSnapshot.data()?['PrefectureTop10'] ?? [],
      );
    }
  }

  players.sort((a, b) => (a['rank'] ?? double.infinity)
      .compareTo(b['rank'] ?? double.infinity));

  final found = players.firstWhere(
    (p) => p['id']?.toString() == widget.uid.toString(),
    orElse: () => <String, dynamic>{},
  );

  if (found.isNotEmpty) {
    userData = found;
  } else {
    final ctxDoc = await FirebaseFirestore.instance
        .doc('users/${widget.uid}/rankCtxPitcher/totalSavesRank$ageSuffix')
        .get();
    if (ctxDoc.exists) {
      final ctx = ctxDoc.data()?['context'] ?? [];
      if (ctx is List) {
        final List<Map<String, dynamic>> ctxPlayers = ctx.cast<Map<String, dynamic>>();
        _ctxAroundUser = ctxPlayers;
        final me = ctxPlayers.firstWhere(
          (p) => p['id']?.toString() == widget.uid.toString(),
          orElse: () => <String, dynamic>{},
        );
        if (me.isNotEmpty) userData = me;
      }
    }

    userData ??= {
      'name': '自分',
      'team': ['チーム名不明'],
      'totalSavesRank': '圏外',
    };
  }
}

// ========================= 勝率ランキング =========================
else if (_selectedRankingType == '勝率ランキング') {
  final String ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
      ? '_age_${_selectedAgeGroup}'
      : '';
  bool loadedAgeData = false;

  if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
    final ageDoc = await FirebaseFirestore.instance
        .doc('$basePath/winRateRank$ageSuffix')
        .get();
    if (ageDoc.exists) {
      players = List<Map<String, dynamic>>.from(
        ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? [],
      );
      loadedAgeData = true;
    }
  }

  if (!loadedAgeData) {
    final docSnapshot = await FirebaseFirestore.instance
        .doc('$basePath/winRateRank')
        .get();
    if (docSnapshot.exists) {
      players = List<Map<String, dynamic>>.from(
        docSnapshot.data()?['PrefectureTop10'] ?? [],
      );
    }
  }

  players.sort((a, b) => (a['rank'] ?? double.infinity)
      .compareTo(b['rank'] ?? double.infinity));

  final found = players.firstWhere(
    (p) => p['id']?.toString() == widget.uid.toString(),
    orElse: () => <String, dynamic>{},
  );

  if (found.isNotEmpty) {
    userData = found;
  } else {
    final ctxDoc = await FirebaseFirestore.instance
        .doc('users/${widget.uid}/rankCtxPitcher/winRateRank$ageSuffix')
        .get();
    if (ctxDoc.exists) {
      final ctx = ctxDoc.data()?['context'] ?? [];
      if (ctx is List) {
        final List<Map<String, dynamic>> ctxPlayers = ctx.cast<Map<String, dynamic>>();
        _ctxAroundUser = ctxPlayers;
        final me = ctxPlayers.firstWhere(
          (p) => p['id']?.toString() == widget.uid.toString(),
          orElse: () => <String, dynamic>{},
        );
        if (me.isNotEmpty) userData = me;
      }
    }

    userData ??= {
      'name': '自分',
      'team': ['チーム名不明'],
      'winRateRank': '圏外',
    };
  }
}
      if (!mounted) return;
      setState(() {
        _players = players;
        _userData = userData;
      });

    } catch (e) {
      print('Firestoreからのデータ取得中にエラーが発生しました: $e');
      if (!mounted) return;
      setState(() {
        _players = [];
        _userData = null;
      });
    }
  }

  Future<void> _fetchPitcherCount() async {
    try {
      final now = DateTime.now();
      int year;
      int lastMonth = 0;
      String docPath;

      if (_isSeasonMode) {
        // シーズンモード：1〜3月は前年扱い
        year = now.year;
        if (now.month <= 3) {
          year -= 1;
        }
        docPath = 'pitcherRanking/${year}_total/${widget.prefecture}/stats';
      } else {
        // 先月モード
        year = now.year;
        lastMonth = now.month - 1;
        if (lastMonth == 0) {
          lastMonth = 12;
          year -= 1;
        }
        final monthKeyNoPad = lastMonth.toString();
        docPath = 'pitcherRanking/${year}_${monthKeyNoPad}/${widget.prefecture}/stats';
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

        // 「全年齢」のときは pitchersCount
        if (_selectedAgeGroup == null || _selectedAgeGroup == '全年齢') {
          count = (data?['pitchersCount'] ?? 0) as int;
        } else {
          // 年齢別のときは stats.totalPitchers_age_XX_YY または totalPlayers_age_XX_YY を使用
          final String keyPitcher = 'totalPitchers_age_${_selectedAgeGroup}';
          final String keyPlayer = 'totalPlayers_age_${_selectedAgeGroup}';

          int? ageCount;

          // 1. ネストされた stats マップ内を確認
          final rawStats = data?['stats'];
          if (rawStats is Map<String, dynamic>) {
            if (rawStats.containsKey(keyPitcher)) {
              ageCount = rawStats[keyPitcher] as int?;
            } else if (rawStats.containsKey(keyPlayer)) {
              ageCount = rawStats[keyPlayer] as int?;
            }
          }

          // 2. まだ取れていなければトップレベルのフィールドも確認
          if (ageCount == null) {
            if ((data?.containsKey(keyPitcher) ?? false)) {
              ageCount = data?[keyPitcher] as int?;
            } else if ((data?.containsKey(keyPlayer) ?? false)) {
              ageCount = data?[keyPlayer] as int?;
            }
          }

          count = ageCount ?? 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _pitchersCount = count;
      });
    } catch (e) {
      print('pitcher stats取得エラー: $e');
      if (!mounted) return;
      setState(() {
        _pitchersCount = 0;
      });
    }
  }

  List<DataRow> _buildTop10Rows() {
    List<DataRow> result = [];

  final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
      ? '_age_${_selectedAgeGroup}'
      : '';

  if (_selectedRankingType == '防御率ランキング') {
    final rankKey = 'eraRank$ageSuffix';
    for (var player in _players) {
      final rk = player.containsKey('rank') ? 'rank' : rankKey;
      final playerRank = int.tryParse(player[rk]?.toString() ?? '') ?? -1;
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
          ),
        );
      }
    }
  } else if (_selectedRankingType == '奪三振ランキング') {
    final rankKey = 'totalPStrikeoutsRank$ageSuffix';
    for (var player in _players) {
      final rk = player.containsKey('rank') ? 'rank' : rankKey;
      final playerRank = int.tryParse(player[rk]?.toString() ?? '') ?? -1;
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
          ),
        );
      }
    }
  } else if (_selectedRankingType == 'ホールドポイントランキング') {
    final rankKey = 'totalHoldPointsRank$ageSuffix';
    for (var player in _players) {
      final rk = player.containsKey('rank') ? 'rank' : rankKey;
      final playerRank = int.tryParse(player[rk]?.toString() ?? '') ?? -1;
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
          ),
        );
      }
    }
  } else if (_selectedRankingType == 'セーブランキング') {
    final rankKey = 'totalSavesRank$ageSuffix';
    for (var player in _players) {
      final rk = player.containsKey('rank') ? 'rank' : rankKey;
      final playerRank = int.tryParse(player[rk]?.toString() ?? '') ?? -1;
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
          ),
        );
      }
    }
  } else if (_selectedRankingType == '勝率ランキング') {
    final rankKey = 'winRateRank$ageSuffix';
    for (var player in _players) {
      final rk = player.containsKey('rank') ? 'rank' : rankKey;
      final playerRank = int.tryParse(player[rk]?.toString() ?? '') ?? -1;
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
          ),
        );
      }
    }
  }

  return result;
}

  @override
  Widget build(BuildContext context) {
    // ユーザーのランクを取得（現在の指標＆年齢帯に応じて自動判定）
    int userRank = -1;
    if (_userData != null) {
      userRank = _extractRankForCurrentMetric(_userData!);
    }

    final bool _userInAge = _isUserInSelectedAgeGroup();

    final bool isUserOutsideTop10 =
  (_selectedRankingType == '奪三振ランキング' ||
   _selectedRankingType == 'ホールドポイントランキング' ||
   _selectedRankingType == 'セーブランキング' ||
   _selectedRankingType == '勝率ランキング') &&
  _userData != null &&
  (() {
    final r = _extractRankForCurrentMetric(_userData!); // rank or xxxRank_age_YY
    return r == -1 || r > 10;
  })();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              alignment: Alignment.center,
              child: Text(
                '${widget.prefecture}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showModePicker(context), // モード選択ピッカーを表示
                  child: Container(
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.black54, width: 1), // 控えめな枠線
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Text(
                          _isSeasonMode ? 'シーズン' : '先月',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  _isSeasonMode
                      ? '$_year年' // シーズンの場合は「年」のみ表示
                      : '${_year}年${DateTime.now().month - 1 == 0 ? 12 : DateTime.now().month - 1}月', // 先月の場合「年+月」
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            // 年齢別
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showAgePicker(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedAgeGroup == '全年齢'
                              ? '全年齢'
                              : ageGroupLabels[_selectedAgeGroup!] ?? _selectedAgeGroup!,
                          style: TextStyle(fontSize: 16),
                        ),
                        Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSeasonMode)
                      IconButton(
                        icon: Icon(Icons.navigate_before, size: 32.0),
                        onPressed: () {
                          final currentIndex =
                              rankingTypes.indexOf(_selectedRankingType);
                          final previousIndex =
                              (currentIndex - 1 + rankingTypes.length) %
                                  rankingTypes.length;
                          setState(() {
                            _selectedRankingType = rankingTypes[previousIndex];
                            _fetchPlayersData();
                          });
                        },
                      ),
                    if (_isSeasonMode)
                      InkWell(
                        onTap: () => _showCupertinoPicker(context),
                        child: Row(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(color: Colors.grey)),
                              ),
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                _selectedRankingType,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Colors.grey)),
                            ),
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              _selectedRankingType,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_isSeasonMode)
                      IconButton(
                        icon: Icon(Icons.navigate_next, size: 32.0),
                        onPressed: () {
                          final currentIndex =
                              rankingTypes.indexOf(_selectedRankingType);
                          final nextIndex =
                              (currentIndex + 1) % rankingTypes.length;
                          setState(() {
                            _selectedRankingType = rankingTypes[nextIndex];
                            _fetchPlayersData();
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(width: 5),
            Container(
              margin: const EdgeInsets.only(top: 5, bottom: 10),
              alignment: Alignment.center,
              child: Text(
                '$_pitchersCount人ランキングに参加中',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
            ] else if (_selectedRankingType == '防御率ランキング' && _isPitcher) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  columns: _buildDataColumns(),
                  rows: _buildTop10Rows(),
                ),
              ),
              // ユーザーがTOP10に入っていない場合のみ三つのドットを表示
              if ((userRank > 10 || userRank == -1) && _userInAge) ...[
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
            ] else if (_isPitcher && isUserOutsideTop10 && _userInAge) ...[
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
                  rows: _buildUserAndPreviousRows(userRank)
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

        return Container(
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
                          _selectedRankingType = '防御率ランキング';
                          _fetchPlayersData();
                          _fetchPitcherCount();
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
                    Center(child: Text('先月', style: TextStyle(fontSize: 24))),
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

        return Container(
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
                      child: Text(type, style: TextStyle(fontSize: 22)),
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
    if (_selectedRankingType == '防御率ランキング') {
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
        DataColumn(label: Center(child: _buildVerticalText('防御率'))),
        DataColumn(label: Center(child: _buildVerticalText('登板'))),
        DataColumn(label: Center(child: _buildVerticalText('投球回'))),
        DataColumn(label: Center(child: _buildVerticalText('勝利'))),
        DataColumn(label: Center(child: _buildVerticalText('敗北'))),
        DataColumn(label: Center(child: _buildVerticalText('完投'))),
        DataColumn(label: Center(child: _buildVerticalText('完封'))),
        DataColumn(label: Center(child: _buildVerticalText('ホール'))),
        DataColumn(label: Center(child: _buildVerticalText('セーブ'))),
        DataColumn(label: Center(child: _buildVerticalText('勝率'))),
        DataColumn(label: Center(child: _buildVerticalText('打者'))),
        DataColumn(label: Center(child: _buildVerticalText('安打'))),
        DataColumn(label: Center(child: _buildVerticalText('四球'))),
        DataColumn(label: Center(child: _buildVerticalText('死球'))),
        DataColumn(label: Center(child: _buildVerticalText('奪三振'))),
        DataColumn(label: Center(child: _buildVerticalText('失点'))),
        DataColumn(label: Center(child: _buildVerticalText('自責点'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '奪三振ランキング') {
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
        DataColumn(label: Center(child: _buildVerticalText('奪三振'))),
        DataColumn(label: Center(child: _buildVerticalText('登板'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == 'ホールドポイントランキング') {
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
        DataColumn(label: Center(child: _buildVerticalText('HD'))),
        DataColumn(label: Center(child: _buildVerticalText('登板'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == 'セーブランキング') {
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
        DataColumn(label: Center(child: _buildVerticalText('セーブ'))),
        DataColumn(label: Center(child: _buildVerticalText('登板'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '勝率ランキング') {
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
        DataColumn(label: Center(child: _buildVerticalText('勝率'))),
        DataColumn(label: Center(child: _buildVerticalText('登板'))),
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

  List<DataRow> _buildTopRankedRows() {
    List<DataRow> result = [];

    if (_selectedRankingType == '防御率ランキング') {
      // rankが10以下の選手を表示
      for (var player in _players) {
        int playerRank = int.tryParse(player['eraRank'].toString()) ?? -1;
        if (playerRank <= 10) {
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


    // ==== 共通ヘルパー（前後±2表示用）====
String _ageSuffixStr() {
  return _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
      ? '_age_${_selectedAgeGroup}'
      : '';
}

String _metricRankKeyBase() {
  switch (_selectedRankingType) {
    case '防御率ランキング':
      return 'eraRank';
    case '奪三振ランキング':
      return 'totalPStrikeoutsRank';
    case 'ホールドポイントランキング':
      return 'totalHoldPointsRank';
    case 'セーブランキング':
      return 'totalSavesRank';
    case '勝率ランキング':
      return 'winRateRank';
    default:
      return 'eraRank';
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
    if (_userData == null) return [];

    final int centerRank =
        userRank > 0 ? userRank : _extractRankForCurrentMetric(_userData!);

    if (centerRank <= 0) {
      // Always highlight user row
      const isUser = true;
      return [
        DataRow(
          color: MaterialStateProperty.all(
            const Color(0xFF1565C0).withOpacity(0.08),
          ),
          cells: _buildDataCells(_userData!, isUser: isUser),
        ),
      ];
    }

    // Prefer lightweight context if available
    final List<Map<String, dynamic>> source =
        _ctxAroundUser.isNotEmpty ? List<Map<String, dynamic>>.from(_ctxAroundUser)
                                  : List<Map<String, dynamic>>.from(_players);

    final upper = source
        .where((p) {
          final r = _extractRankForCurrentMetric(p);
          return r > 0 && r < centerRank;
        })
        .toList()
      ..sort((a, b) =>
          _extractRankForCurrentMetric(b).compareTo(_extractRankForCurrentMetric(a)));

    final lower = source
        .where((p) {
          final r = _extractRankForCurrentMetric(p);
          return r > centerRank;
        })
        .toList()
      ..sort((a, b) =>
          _extractRankForCurrentMetric(a).compareTo(_extractRankForCurrentMetric(b)));

    final rows = <DataRow>[];

    for (var i = 0; i < upper.length && i < 2; i++) {
      rows.add(DataRow(cells: _buildDataCells(upper[i])));
    }

    // Highlight the user row
    const isUser = true;
    rows.add(
      DataRow(
        color: MaterialStateProperty.all(
          const Color(0xFF1565C0).withOpacity(0.08),
        ),
        cells: _buildDataCells(_userData!, isUser: isUser),
      ),
    );

    for (var i = 0; i < lower.length && i < 2; i++) {
      rows.add(DataRow(cells: _buildDataCells(lower[i])));
    }

    return rows;
  }

  List<DataCell> _buildDataCells(Map<String, dynamic> player,
      {bool isUser = false}) {
            final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
        ? '_age_${_selectedAgeGroup}'
        : '';

    final rankKey = _selectedRankingType == '奪三振ランキング'
        ? (player.containsKey('rank') ? 'rank' : 'totalPStrikeoutsRank$ageSuffix')
        : _selectedRankingType == 'ホールドポイントランキング'
            ? (player.containsKey('rank') ? 'rank' : 'totalHoldPointsRank$ageSuffix')
            : _selectedRankingType == 'セーブランキング'
                ? (player.containsKey('rank') ? 'rank' : 'totalSavesRank$ageSuffix')
                : _selectedRankingType == '勝率ランキング'
                    ? (player.containsKey('rank') ? 'rank' : 'winRateRank$ageSuffix')
                    : 'battingAverageRank$ageSuffix';

    final valueKey = _selectedRankingType == '奪三振ランキング'
        ? (player.containsKey('value') ? 'value' : 'totalPStrikeouts')
        : _selectedRankingType == 'ホールドポイントランキング'
            ? (player.containsKey('value') ? 'value' : 'totalHoldPoints')
            : _selectedRankingType == 'セーブランキング'
                ? (player.containsKey('value') ? 'value' : 'totalSaves')
                : _selectedRankingType == '勝率ランキング'
                    ? (player.containsKey('value') ? 'value' : 'winRate')
                    : 'battingAverage';

    if (_selectedRankingType == '防御率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            // player['eraRank']?.toString() ?? '圏外',
            (player['rank'] ?? player['eraRank$ageSuffix'] ?? player['eraRank'] ?? '圏外').toString(),
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
                showProfileDialog(context, player['id'].toString(), false);
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
                // 最初の teamID を使用してチームプロフィールを表示
                showProfileDialog(context, teamIDs.first.toString(), true);
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
            formatPercentageEra((player['era'] ?? player['value'] ?? 0.0) as num),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalAppearances']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            ((player['totalInningsPitched'] ?? 0) as num).toStringAsFixed(1),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalWins']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalLosses']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalCompleteGames']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalShutouts']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalHolds']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalSaves']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(player['winRate'] ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalBattersFaced']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalHitsAllowed']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalWalks']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalHitByPitch']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalPStrikeouts']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalRunsAllowed']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalEarnedRuns']?.toString() ?? '0',
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
    } else if (_selectedRankingType == '奪三振ランキング') {
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
                showProfileDialog(context, player['id'].toString(), false);
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
                // 最初の teamID を使用してチームプロフィールを表示
                showProfileDialog(context, teamIDs.first.toString(), true);
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
            player['totalAppearances']?.toString() ?? '0',
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
    } else if (_selectedRankingType == 'ホールドポイントランキング') {
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
                showProfileDialog(context, player['id'].toString(), false);
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
                // 最初の teamID を使用してチームプロフィールを表示
                showProfileDialog(context, teamIDs.first.toString(), true);
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
            player['totalAppearances']?.toString() ?? '0',
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
    } else if (_selectedRankingType == 'セーブランキング') {
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
                showProfileDialog(context, player['id'].toString(), false);
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
                // 最初の teamID を使用してチームプロフィールを表示
                showProfileDialog(context, teamIDs.first.toString(), true);
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
            player['totalAppearances']?.toString() ?? '0',
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
    } else if (_selectedRankingType == '勝率ランキング') {
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
                showProfileDialog(context, player['id'].toString(), false);
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
                // 最初の teamID を使用してチームプロフィールを表示
                showProfileDialog(context, teamIDs.first.toString(), true);
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
            player['totalAppearances']?.toString() ?? '0',
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

  String formatPercentageEra(num value) {
    double doubleValue = value.toDouble(); // num を double に変換
    return doubleValue.toStringAsFixed(2); // 小数点第2位までフォーマット
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
              child: Transform.rotate(
                angle: char == 'ー' ? 90 * 3.14159 / 180 : 0, // 「ー」の場合90度回転
                child: Text(
                  char,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
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
                          _fetchPitcherCount();
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