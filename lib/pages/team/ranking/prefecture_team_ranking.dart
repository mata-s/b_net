import 'package:b_net/pages/team/team_home.dart';
import 'package:b_net/common/profile_dialog.dart';
import 'package:b_net/pages/team/team_subscription_guard.dart';
import 'package:flutter/material.dart';
import 'package:b_net/widgets/b_net_floating_tab_bar.dart';
import 'package:b_net/widgets/ranking_next_update_label.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class PrefectureTeamRanking extends StatefulWidget {
  final String teamId;
  final String teamPrefecture;
  final bool hasActiveTeamSubscription;
  final TeamPlanTier teamPlanTier;

  const PrefectureTeamRanking(
      {super.key,
      required this.teamId,
      required this.teamPrefecture,
      required this.hasActiveTeamSubscription,
      required this.teamPlanTier});

  @override
  State<PrefectureTeamRanking> createState() => _PrefectureTeamRankingState();
}

class _PrefectureTeamRankingState extends State<PrefectureTeamRanking> {
  bool get _isLastMonth => !_isSeasonMode;
  List<Map<String, dynamic>> _teams = []; // チームデータを保持
  Map<String, dynamic>? _teamData; // チーム自身のデータを保持
  String _selectedRankingType = '勝率ランキング';
  int _year = DateTime.now().year;
  bool _isSeasonMode = true;
  String? _selectedAgeGroup = '全年齢';
  List<Map<String, dynamic>> _ctxAroundTeam = [];

  final List<String> rankingTypes = [
    // 選択肢リスト
    '勝率ランキング',
    '打率ランキング',
    '出塁率ランキング',
    '長打率ランキング',
    '防御率ランキング',
    '守備率ランキング',
  ];

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
    _fetchTeamsData(); // データを取得
    _loadAvailableAgeGroups();
  }

  Future<void> _loadAvailableAgeGroups() async {
    String collectionPath;
    if (_isSeasonMode) {
      collectionPath = 'teamRanking/${_year}_all/${widget.teamPrefecture}';
    } else {
      final now = DateTime.now();
      int y = now.year;
      int m = now.month - 1;
      if (m == 0) {
        m = 12;
        y -= 1;
      }
      final noPad = 'teamRanking/${y}_${m}/${widget.teamPrefecture}';
      final pad =
          'teamRanking/${y}_${m.toString().padLeft(2, '0')}/${widget.teamPrefecture}';
      // try non-padded first; if empty, try padded
      var snapshot = await FirebaseFirestore.instance.collection(noPad).get();
      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance.collection(pad).get();
      }
      List<String> foundGroups = ['全年齢'];
      for (String group in ageGroupLabels.keys) {
        final exists =
            snapshot.docs.any((doc) => doc.id.contains('_age_$group'));
        if (exists) foundGroups.add(group);
      }
      setState(() {
        _availableAgeGroups = foundGroups;
        if (!_availableAgeGroups.contains(_selectedAgeGroup)) {
          _selectedAgeGroup = '全年齢';
        }
      });
      return;
    }

    // season path
    final snapshot =
        await FirebaseFirestore.instance.collection(collectionPath).get();
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

  Future<void> _fetchTeamsData() async {
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

      setState(() {
        _year = year; // 年を設定
      });

      // Firestoreのパスを構築
      String basePath;
      if (_isSeasonMode) {
        basePath = 'teamRanking/${year}_all/${widget.teamPrefecture}';
      } else {
        basePath = 'teamRanking/${year}_${lastMonth}/${widget.teamPrefecture}';

        // 先月モードで「勝率ランキング」以外を選択している場合、何も表示しない
        if (_selectedRankingType != '勝率ランキング') {
          setState(() {
            _teams = [];
            _teamData = null;
          });
          return;
        }
      }

      List<Map<String, dynamic>> teams = [];
      Map<String, dynamic>? teamData;
      _ctxAroundTeam = [];

      if (_selectedRankingType == '勝率ランキング') {
        final ageSuffix =
            _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
                ? '_age_${_selectedAgeGroup}'
                : '';
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/winRateRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            teams = List<Map<String, dynamic>>.from(
              ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ?? [],
            );
          } else if (!_isSeasonMode) {
            // 非ゼロ埋めで無ければゼロ埋めを試す
            final altBase =
                basePath.replaceAllMapped(RegExp(r'_(\d{1,2})/'), (m) {
              final mm = m.group(1) ?? '';
              return '_${mm.padLeft(2, '0')}/';
            });
            final ageDocPad = await FirebaseFirestore.instance
                .doc('$altBase/winRateRank_age_${_selectedAgeGroup}')
                .get();
            if (ageDocPad.exists) {
              teams = List<Map<String, dynamic>>.from(
                ageDocPad.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ??
                    [],
              );
              basePath = altBase; // 以降の個人Doc参照も整合
            }
          }
          if (teams.isNotEmpty) {
            // 🔧 年齢別: rank -> winRateRank_age_XX
            for (final team in teams) {
              if (team.containsKey('rank') &&
                  !team.containsKey('winRateRank_age_${_selectedAgeGroup}')) {
                team['winRateRank_age_${_selectedAgeGroup}'] = team['rank'];
              }
            }
            loadedAgeData = true;
            if (!_isSeasonMode) {
              // print('📆 月別年齢別データ取得: PrefectureTop10_age_${_selectedAgeGroup} (base=$basePath) count=${teams.length}');
            }
          }
        }

        if (!loadedAgeData) {
          final docSnapshot = await FirebaseFirestore.instance
              .doc('$basePath/winRateRank')
              .get();
          if (docSnapshot.exists) {
            teams = List<Map<String, dynamic>>.from(
              docSnapshot.data()?['PrefectureTop10'] ?? [],
            );
          } else if (!_isSeasonMode) {
            // 非ゼロ埋めが無ければゼロ埋めへ
            final altBase =
                basePath.replaceAllMapped(RegExp(r'_(\d{1,2})/'), (m) {
              final mm = m.group(1) ?? '';
              return '_${mm.padLeft(2, '0')}/';
            });
            final docSnapshotPad = await FirebaseFirestore.instance
                .doc('$altBase/winRateRank')
                .get();
            if (docSnapshotPad.exists) {
              teams = List<Map<String, dynamic>>.from(
                docSnapshotPad.data()?['PrefectureTop10'] ?? [],
              );
              basePath = altBase; // 以降の個人Doc参照も整合
            }
          }
          if (teams.isNotEmpty) {
            for (final team in teams) {
              if (team.containsKey('rank') &&
                  !team.containsKey('winRateRank')) {
                team['winRateRank'] = team['rank'];
              }
            }
            if (!_isSeasonMode) {
              // print('📆 月別全年齢データ取得: winRateRank (base=$basePath) count=${teams.length}');
            }
          }
        }

        teams.sort((a, b) => (a['rank'] ?? a['winRateRank'] ?? double.infinity)
            .compareTo(b['rank'] ?? b['winRateRank'] ?? double.infinity));

        // ignore: unused_local_variable
        final dynamicRankKey = teams
                .firstWhere(
                  (p) => p.containsKey('winRateRank$ageSuffix'),
                  orElse: () => {'winRateRank$ageSuffix': 'winRateRank'},
                )
                .containsKey('winRateRank$ageSuffix')
            ? 'winRateRank$ageSuffix'
            : 'rank';

        final foundTeam = teams.firstWhere(
          (team) => team['id']?.toString() == widget.teamId.toString(),
          orElse: () => {},
        );

        if (foundTeam.isNotEmpty) {
          teamData = foundTeam;
        } else {
          // ユーザーがTOP10に含まれていない場合は rankingContext から補助取得
          if (_isSeasonMode) {
            // シーズン：従来の rankingContext（年間）を利用（軽量：_teamsへは入れない）
            final contextDocSnapshot = await FirebaseFirestore.instance
                .doc(
                    'teams/${widget.teamId}/rankingContext/winRateRank$ageSuffix')
                .get();
            if (contextDocSnapshot.exists) {
              final contextData = contextDocSnapshot.data()?['context'] ?? [];
              if (contextData is List) {
                final List<Map<String, dynamic>> contextTeams =
                    contextData.cast<Map<String, dynamic>>();
                // rank補完（UIでrankキーを使えるようにする）
                final String computedRankKey = 'winRateRank' + ageSuffix;
                for (final p in contextTeams) {
                  if (!p.containsKey('rank') &&
                      p.containsKey(computedRankKey)) {
                    p['rank'] = p[computedRankKey];
                  }
                }
                _ctxAroundTeam = contextTeams;
                final self = contextTeams.firstWhere(
                  (p) => p['id']?.toString() == widget.teamId.toString(),
                  orElse: () => <String, dynamic>{},
                );
                if (self.isNotEmpty) {
                  teamData = self;
                }
              }
            }
          } else {
            // 月次：月別 rankingContext のみを利用（年間コンテキストは使わない）
            final String monthKey = (DateTime.now().month - 1 == 0)
                ? '12'
                : (DateTime.now().month - 1).toString().padLeft(2, '0');
            final int y = (DateTime.now().month - 1 == 0)
                ? DateTime.now().year - 1
                : DateTime.now().year;
            final monthlyCtxPath =
                'teams/${widget.teamId}/rankingContext/month/${y}_${monthKey}/battingAverageRank$ageSuffix';
            final monthlyCtx =
                await FirebaseFirestore.instance.doc(monthlyCtxPath).get();
            if (monthlyCtx.exists) {
              final contextData = monthlyCtx.data()?['context'] ?? [];
              if (contextData is List) {
                final List<Map<String, dynamic>> contextTeams =
                    contextData.cast<Map<String, dynamic>>();
                // rank補完＆月キー一致のみ採用
                final String computedRankKey = 'winRateRank' + ageSuffix;
                final String expectKey = '${y}_${monthKey}';
                final filtered = <Map<String, dynamic>>[];
                for (final p in contextTeams) {
                  if (p['_monthKey']?.toString() == expectKey) {
                    if (!p.containsKey('rank') &&
                        p.containsKey(computedRankKey)) {
                      p['rank'] = p[computedRankKey];
                    }
                    filtered.add(p);
                  }
                }
                _ctxAroundTeam = filtered;
                final self = filtered.firstWhere(
                  (p) => p['id']?.toString() == widget.teamId.toString(),
                  orElse: () => <String, dynamic>{},
                );
                if (self.isNotEmpty) {
                  teamData = self;
                }
              }
            }
          }

          // 個人Doc（該当月/県パス）
          final teamsDocSnapshot = await FirebaseFirestore.instance
              .doc('$basePath/${widget.teamId}')
              .get();
          if (teamsDocSnapshot.exists) {
            final rawteamsData =
                teamsDocSnapshot.data() as Map<String, dynamic>;
            if (!rawteamsData.containsKey('winRateRank')) {
              rawteamsData['winRateRank'] = rawteamsData['rank'] ?? '圏外';
            }
            teamData = rawteamsData;
          } else {
            teamData = {
              'winRateRank': '圏外',
              'teamName': 'チーム名不明',
            };
          }
        }
      } else if (_selectedRankingType == '打率ランキング') {
        // 年齢別データが存在すればそちらを優先して取得
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/battingAverageRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            teams = List<Map<String, dynamic>>.from(
                ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ??
                    []);
            loadedAgeData = true;
          }
        }
        if (!loadedAgeData) {
          final docSnapshot = await FirebaseFirestore.instance
              .doc('$basePath/battingAverageRank')
              .get();
          if (docSnapshot.exists) {
            teams = List<Map<String, dynamic>>.from(
                docSnapshot.data()?['PrefectureTop10'] ?? []);
          }
        }
        teams.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDがtop10に含まれているか確認
        final teamInTop10 = teams.firstWhere(
          (team) => team['id']?.toString() == widget.teamId.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (teamInTop10.isNotEmpty) {
          teamData = teamInTop10;
        } else {
          // top10に含まれていない場合は rankingContext から取得
          final ageSuffix =
              _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
                  ? '_age_${_selectedAgeGroup}'
                  : '';
          final contextDoc = await FirebaseFirestore.instance
              .doc(
                  'teams/${widget.teamId}/rankingContext/battingAverageRank$ageSuffix')
              .get();
          if (contextDoc.exists) {
            final contextData = contextDoc.data()?['context'] ?? [];
            if (contextData is List) {
              final List<Map<String, dynamic>> contextTeams =
                  contextData.cast<Map<String, dynamic>>();
              final String computedRankKey = 'battingAverageRank' + ageSuffix;
              for (final p in contextTeams) {
                if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                  p['rank'] = p[computedRankKey];
                }
              }
              _ctxAroundTeam = contextTeams;
              final fromContext = contextTeams.firstWhere(
                (p) => p['id']?.toString() == widget.teamId.toString(),
                orElse: () => <String, dynamic>{},
              );
              if (fromContext.isNotEmpty) {
                teamData = fromContext;
              }
            }
          }
          // rankingContext にも無い場合は teamRanking 個別ドキュメントから取得
          if (teamData == null) {
            final teamDoc = await FirebaseFirestore.instance
                .doc('$basePath/${widget.teamId}')
                .get();
            if (teamDoc.exists) {
              final raw = teamDoc.data() as Map<String, dynamic>;
              if (!raw.containsKey('battingAverageRank')) {
                raw['battingAverageRank'] = raw['rank'] ?? '圏外';
              }
              teamData = raw;
            }
          }

          // 最終フォールバック
          teamData ??= {
            'teamName': 'チーム名不明',
            'battingAverage': 0,
            'battingAverageRank': '圏外',
          };
        }
      } else if (_selectedRankingType == '出塁率ランキング') {
        // 年齢別データが存在すればそちらを優先して取得
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/onBaseRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            teams = List<Map<String, dynamic>>.from(
                ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ??
                    []);
            loadedAgeData = true;
          }
        }
        if (!loadedAgeData) {
          final docSnapshot = await FirebaseFirestore.instance
              .doc('$basePath/onBaseRank')
              .get();
          if (docSnapshot.exists) {
            teams = List<Map<String, dynamic>>.from(
                docSnapshot.data()?['PrefectureTop10'] ?? []);
          }
        }
        teams.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDがtop10に含まれているか確認
        final teamInTop10 = teams.firstWhere(
          (team) => team['id']?.toString() == widget.teamId.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (teamInTop10.isNotEmpty) {
          teamData = teamInTop10;
        } else {
          // top10に含まれていない場合は rankingContext から取得
          final ageSuffix =
              _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
                  ? '_age_${_selectedAgeGroup}'
                  : '';
          final contextDoc = await FirebaseFirestore.instance
              .doc('teams/${widget.teamId}/rankingContext/onBaseRank$ageSuffix')
              .get();
          if (contextDoc.exists) {
            final contextData = contextDoc.data()?['context'] ?? [];
            if (contextData is List) {
              final List<Map<String, dynamic>> contextTeams =
                  contextData.cast<Map<String, dynamic>>();
              final String computedRankKey = 'onBaseRank' + ageSuffix;
              for (final p in contextTeams) {
                if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                  p['rank'] = p[computedRankKey];
                }
              }
              _ctxAroundTeam = contextTeams;
              final fromContext = contextTeams.firstWhere(
                (p) => p['id']?.toString() == widget.teamId.toString(),
                orElse: () => <String, dynamic>{},
              );
              if (fromContext.isNotEmpty) {
                teamData = fromContext;
              }
            }
          }
          // rankingContext にも無い場合は teamRanking 個別ドキュメントから取得
          if (teamData == null) {
            final teamDoc = await FirebaseFirestore.instance
                .doc('$basePath/${widget.teamId}')
                .get();
            if (teamDoc.exists) {
              final raw = teamDoc.data() as Map<String, dynamic>;
              if (!raw.containsKey('onBaseRank')) {
                raw['onBaseRank'] = raw['rank'] ?? '圏外';
              }
              teamData = raw;
            }
          }

          // 最終フォールバック
          teamData ??= {
            'teamName': 'チーム名不明',
            'onBasePercentage': 0,
            'onBaseRank': '圏外',
          };
        }
      } else if (_selectedRankingType == '長打率ランキング') {
        // 年齢別データが存在すればそちらを優先して取得
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/sluggingRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            teams = List<Map<String, dynamic>>.from(
                ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ??
                    []);
            loadedAgeData = true;
          }
        }
        if (!loadedAgeData) {
          final docSnapshot = await FirebaseFirestore.instance
              .doc('$basePath/sluggingRank')
              .get();
          if (docSnapshot.exists) {
            teams = List<Map<String, dynamic>>.from(
                docSnapshot.data()?['PrefectureTop10'] ?? []);
          }
        }
        teams.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDがtop10に含まれているか確認
        final teamInTop10 = teams.firstWhere(
          (team) => team['id']?.toString() == widget.teamId.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (teamInTop10.isNotEmpty) {
          teamData = teamInTop10;
        } else {
          // top10に含まれていない場合は rankingContext から取得
          final ageSuffix =
              _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
                  ? '_age_${_selectedAgeGroup}'
                  : '';
          final contextDoc = await FirebaseFirestore.instance
              .doc(
                  'teams/${widget.teamId}/rankingContext/sluggingRank$ageSuffix')
              .get();
          if (contextDoc.exists) {
            final contextData = contextDoc.data()?['context'] ?? [];
            if (contextData is List) {
              final List<Map<String, dynamic>> contextTeams =
                  contextData.cast<Map<String, dynamic>>();
              final String computedRankKey = 'sluggingRank' + ageSuffix;
              for (final p in contextTeams) {
                if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                  p['rank'] = p[computedRankKey];
                }
              }
              _ctxAroundTeam = contextTeams;
              final fromContext = contextTeams.firstWhere(
                (p) => p['id']?.toString() == widget.teamId.toString(),
                orElse: () => <String, dynamic>{},
              );
              if (fromContext.isNotEmpty) {
                teamData = fromContext;
              }
            }
          }
          // rankingContext にも無い場合は teamRanking 個別ドキュメントから取得
          if (teamData == null) {
            final teamDoc = await FirebaseFirestore.instance
                .doc('$basePath/${widget.teamId}')
                .get();
            if (teamDoc.exists) {
              final raw = teamDoc.data() as Map<String, dynamic>;
              if (!raw.containsKey('sluggingRank')) {
                raw['sluggingRank'] = raw['rank'] ?? '圏外';
              }
              teamData = raw;
            }
          }

          // 最終フォールバック
          teamData ??= {
            'teamName': 'チーム名不明',
            'sluggingPercentage': 0,
            'sluggingRank': '圏外',
          };
        }
      } else if (_selectedRankingType == '防御率ランキング') {
        // 年齢別データが存在すればそちらを優先して取得
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/eraRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            teams = List<Map<String, dynamic>>.from(
                ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ??
                    []);
            loadedAgeData = true;
          }
        }
        if (!loadedAgeData) {
          final docSnapshot =
              await FirebaseFirestore.instance.doc('$basePath/eraRank').get();
          if (docSnapshot.exists) {
            teams = List<Map<String, dynamic>>.from(
                docSnapshot.data()?['PrefectureTop10'] ?? []);
          }
        }
        teams.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDがtop10に含まれているか確認
        final teamInTop10 = teams.firstWhere(
          (team) => team['id']?.toString() == widget.teamId.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (teamInTop10.isNotEmpty) {
          teamData = teamInTop10;
        } else {
          // top10に含まれていない場合は rankingContext から取得
          final ageSuffix =
              _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
                  ? '_age_${_selectedAgeGroup}'
                  : '';
          final contextDoc = await FirebaseFirestore.instance
              .doc('teams/${widget.teamId}/rankingContext/eraRank$ageSuffix')
              .get();
          if (contextDoc.exists) {
            final contextData = contextDoc.data()?['context'] ?? [];
            if (contextData is List) {
              final List<Map<String, dynamic>> contextTeams =
                  contextData.cast<Map<String, dynamic>>();
              final String computedRankKey = 'eraRank' + ageSuffix;
              for (final p in contextTeams) {
                if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                  p['rank'] = p[computedRankKey];
                }
              }
              _ctxAroundTeam = contextTeams;
              final fromContext = contextTeams.firstWhere(
                (p) => p['id']?.toString() == widget.teamId.toString(),
                orElse: () => <String, dynamic>{},
              );
              if (fromContext.isNotEmpty) {
                teamData = fromContext;
              }
            }
          }
          // rankingContext にも無い場合は teamRanking 個別ドキュメントから取得
          if (teamData == null) {
            final teamDoc = await FirebaseFirestore.instance
                .doc('$basePath/${widget.teamId}')
                .get();
            if (teamDoc.exists) {
              final raw = teamDoc.data() as Map<String, dynamic>;
              if (!raw.containsKey('eraRank')) {
                raw['eraRank'] = raw['rank'] ?? '圏外';
              }
              teamData = raw;
            }
          }

          // 最終フォールバック
          teamData ??= {
            'teamName': 'チーム名不明',
            'era': 0,
            'eraRank': '圏外',
          };
        }
      } else if (_selectedRankingType == '守備率ランキング') {
        // 年齢別データが存在すればそちらを優先して取得
        bool loadedAgeData = false;
        if (_selectedAgeGroup != null && _selectedAgeGroup != '全年齢') {
          final ageDoc = await FirebaseFirestore.instance
              .doc('$basePath/fieldingPercentageRank_age_${_selectedAgeGroup}')
              .get();
          if (ageDoc.exists) {
            teams = List<Map<String, dynamic>>.from(
                ageDoc.data()?['PrefectureTop10_age_${_selectedAgeGroup}'] ??
                    []);
            loadedAgeData = true;
          }
        }
        if (!loadedAgeData) {
          final docSnapshot = await FirebaseFirestore.instance
              .doc('$basePath/fieldingPercentageRank')
              .get();
          if (docSnapshot.exists) {
            teams = List<Map<String, dynamic>>.from(
                docSnapshot.data()?['PrefectureTop10'] ?? []);
          }
        }
        teams.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDがtop10に含まれているか確認
        final teamInTop10 = teams.firstWhere(
          (team) => team['id']?.toString() == widget.teamId.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (teamInTop10.isNotEmpty) {
          teamData = teamInTop10;
        } else {
          // top10に含まれていない場合は rankingContext から取得
          final ageSuffix =
              _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
                  ? '_age_${_selectedAgeGroup}'
                  : '';
          final contextDoc = await FirebaseFirestore.instance
              .doc(
                  'teams/${widget.teamId}/rankingContext/fieldingPercentageRank$ageSuffix')
              .get();
          if (contextDoc.exists) {
            final contextData = contextDoc.data()?['context'] ?? [];
            if (contextData is List) {
              final List<Map<String, dynamic>> contextTeams =
                  contextData.cast<Map<String, dynamic>>();
              final String computedRankKey =
                  'fieldingPercentageRank' + ageSuffix;
              for (final p in contextTeams) {
                if (!p.containsKey('rank') && p.containsKey(computedRankKey)) {
                  p['rank'] = p[computedRankKey];
                }
              }
              _ctxAroundTeam = contextTeams;
              final fromContext = contextTeams.firstWhere(
                (p) => p['id']?.toString() == widget.teamId.toString(),
                orElse: () => <String, dynamic>{},
              );
              if (fromContext.isNotEmpty) {
                teamData = fromContext;
              }
            }
          }
          // rankingContext にも無い場合は teamRanking 個別ドキュメントから取得
          if (teamData == null) {
            final teamDoc = await FirebaseFirestore.instance
                .doc('$basePath/${widget.teamId}')
                .get();
            if (teamDoc.exists) {
              final raw = teamDoc.data() as Map<String, dynamic>;
              if (!raw.containsKey('fieldingPercentageRank')) {
                raw['fieldingPercentageRank'] = raw['rank'] ?? '圏外';
              }
              teamData = raw;
            }
          }

          // 最終フォールバック
          teamData ??= {
            'teamName': 'チーム名不明',
            'fieldingPercentage': 0,
            'fieldingPercentageRank': '圏外',
          };
        }
      }

      setState(() {
        _teams = teams;
        _teamData = teamData;
      });
    } catch (e) {
      print('Firestoreからのデータ取得中にエラーが発生しました: $e');
      setState(() {
        _teams = [];
        _teamData = null;
      });
    }
  }

  List<DataRow> _buildTop10Rows() {
    List<DataRow> result = [];

    if (_selectedRankingType == '勝率ランキング') {
      // TOP10を表示（圏外を除外し、rankが10以下の選手を表示）
      for (var team in _teams) {
        // rankが10以下で、かつ圏外でないことを確認
        final ageSuffix =
            _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
                ? '_age_${_selectedAgeGroup}'
                : '';
        final rankKey = 'winRateRank$ageSuffix';
        int teamRank = int.tryParse(team[rankKey]?.toString() ?? '') ?? -1;
        final isMyTeam = team['id'] == widget.teamId;
        if (teamRank != -1 && teamRank <= 10) {
          result.add(
            DataRow(
              color: MaterialStateProperty.resolveWith<Color?>(
                (states) {
                  if (isMyTeam) {
                    return const Color(0xFF1565C0).withOpacity(0.08);
                  }
                  return null;
                },
              ),
              cells: _buildDataCells(team, isTeam: isMyTeam),
            ),
          );
        }
      }
    } else if (_selectedRankingType == '打率ランキング' ||
        _selectedRankingType == '出塁率ランキング' ||
        _selectedRankingType == '長打率ランキング' ||
        _selectedRankingType == '防御率ランキング' ||
        _selectedRankingType == '守備率ランキング') {
      for (var team in _teams) {
        if (team['rank'] != null &&
            team['rank'] != '' &&
            (int.tryParse(team['rank'].toString()) ?? 0) <= 10) {
          final isMyTeam = team['id'] == widget.teamId;
          result.add(
            DataRow(
              color: MaterialStateProperty.resolveWith<Color?>(
                (states) {
                  if (isMyTeam) {
                    return const Color(0xFF1565C0).withOpacity(0.08);
                  }
                  return null;
                },
              ),
              cells: _buildDataCells(team, isTeam: isMyTeam),
            ),
          );
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.teamPlanTier != TeamPlanTier.platina) {
      return TeamSubscriptionGuard(
        isLocked: true,
        initialPage: 0,
        teamId: widget.teamId,
      );
    }
    // チームのランクを取得
    final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
        ? '_age_${_selectedAgeGroup}'
        : '';
    final rankKey = 'winRateRank$ageSuffix';

    int teamRank = -1; // デフォルト値として-1を設定

    if (_selectedRankingType == '勝率ランキング' && _teamData != null) {
      final String effectiveRankKey =
          _teamData!.containsKey(rankKey) ? rankKey : 'winRateRank';
      final dynamic rawRank = _teamData![effectiveRankKey];
      if (rawRank != '圏外' && rawRank != null && rawRank.toString().isNotEmpty) {
        teamRank = int.tryParse(rawRank.toString()) ?? -1;
      }
    }

    final bool _teamInAge = _isTeamInSelectedAgeGroup();

    final bool isTeamOutsideTop10 = (_selectedRankingType == '打率ランキング' ||
            _selectedRankingType == '出塁率ランキング' ||
            _selectedRankingType == '長打率ランキング' ||
            _selectedRankingType == '防御率ランキング' ||
            _selectedRankingType == '守備率ランキング') &&
        _teamData != null &&
        !_teams.any((team) =>
            team['id']?.toString() == widget.teamId.toString() &&
            (int.tryParse(team['rank']?.toString() ?? '0') ?? 0) <= 10);

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: BNetFloatingTabBar.bodyClearance(context),
        ),
        child: Column(
          children: [
            Container(
              alignment: Alignment.center,
              child: Text(
                '${widget.teamPrefecture}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            RankingNextUpdateLabel(
              isSeasonMode: _isSeasonMode,
              cycle: RankingUpdateCycle.monthlyFirstDay,
            ),
            const SizedBox(height: 2),
            RankingRequiredGamesLabel(
              currentGames:
                  int.tryParse(_teamData?['totalGames']?.toString() ?? '0') ??
                      0,
              isSeasonMode: _isSeasonMode,
            ),
            const SizedBox(height: 10),
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
                              : ageGroupLabels[_selectedAgeGroup!] ??
                                  _selectedAgeGroup!,
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
                    if (!_isLastMonth)
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
                            _fetchTeamsData();
                          });
                        },
                      ),
                    if (!_isLastMonth)
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
                    if (!_isLastMonth)
                      IconButton(
                        icon: Icon(Icons.navigate_next, size: 32.0),
                        onPressed: () {
                          final currentIndex =
                              rankingTypes.indexOf(_selectedRankingType);
                          final nextIndex =
                              (currentIndex + 1) % rankingTypes.length;
                          setState(() {
                            _selectedRankingType = rankingTypes[nextIndex];
                            _fetchTeamsData();
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(width: 5),
            (() {
              // Always fetch from /teamRanking/{_year}_all/{prefecture}/stats
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('teamRanking')
                    .doc('${_year}_all')
                    .collection(widget.teamPrefecture)
                    .doc('stats')
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  } else if (snapshot.hasError ||
                      !snapshot.hasData ||
                      !snapshot.data!.exists) {
                    return const SizedBox.shrink();
                  } else {
                    final data = snapshot.data!.data() as Map<String, dynamic>;

                    int teamsCount = 0;
                    // 全年齢のときは従来通り teamsCount を表示
                    if (_selectedAgeGroup == null ||
                        _selectedAgeGroup == '全年齢') {
                      teamsCount = (data['teamsCount'] ?? 0) as int;
                    } else {
                      // 年齢別のときは stats.totalTeams_age_XX_YY を使用
                      final statsMap = (data['stats'] ?? <String, dynamic>{})
                          as Map<String, dynamic>;
                      final key = 'totalTeams_age_${_selectedAgeGroup}';
                      teamsCount = (statsMap[key] ?? 0) as int;
                    }

                    return Container(
                      margin: const EdgeInsets.only(top: 5, bottom: 10),
                      alignment: Alignment.center,
                      child: Text(
                        '$teamsCountチームランキングに参加中',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                },
              );
            })(),
            // データがない場合の表示（全てのランキングに適用）
            if (_teams.isEmpty) ...[
              Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.only(top: 20),
                child: const Text(
                  'データが見つかりません',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ] else if (_selectedRankingType == '勝率ランキング') ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  columns: _buildDataColumns(),
                  rows: _buildTop10Rows(),
                ),
              ),
              // ユーザーがTOP10に入っていない場合のみ三つのドットを表示
              if (teamRank > 10 || teamRank == -1 && _teamInAge) ...[
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
                    rows: _buildTeamAndPreviousRows(teamRank),
                  ),
                ),
              ],
            ] else if (isTeamOutsideTop10 && _teamInAge) ...[
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
                  rows: [
                    DataRow(
                      color: MaterialStateProperty.resolveWith<Color?>(
                        (states) {
                          return const Color(0xFF1565C0).withOpacity(0.08);
                        },
                      ),
                      cells: _buildDataCells(_teamData!, isTeam: true),
                    ),
                  ],
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
        int tempIndex = _isSeasonMode ? 0 : 1; // シーズン=0, 先月=1

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
                          _selectedRankingType = '勝率ランキング';
                          _fetchTeamsData();
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
                  scrollController: FixedExtentScrollController(
                    initialItem: tempIndex,
                  ),
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
        int tempIndex =
            rankingTypes.indexOf(_selectedRankingType); // 一時的な選択インデックス

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
                          _fetchTeamsData();
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
                  scrollController: FixedExtentScrollController(
                    initialItem: tempIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    tempIndex = index;
                  },
                  children: rankingTypes.map((type) {
                    return Center(
                      child: Text(
                        type,
                        style: TextStyle(fontSize: 22),
                      ),
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
    if (_selectedRankingType == '勝率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ), // チーム
        DataColumn(label: Center(child: _buildVerticalText('勝率'))),
        DataColumn(label: Center(child: _buildVerticalText('試合'))),
        DataColumn(label: Center(child: _buildVerticalText('勝利'))),
        DataColumn(label: Center(child: _buildVerticalText('敗北'))),
        DataColumn(label: Center(child: _buildVerticalText('引き分'))),
        DataColumn(label: Center(child: _buildVerticalText('得点'))),
        DataColumn(label: Center(child: _buildVerticalText('失点'))),
        DataColumn(label: Center(child: _buildVerticalText('打率'))),
        DataColumn(label: Center(child: _buildVerticalText('出塁率'))),
        DataColumn(label: Center(child: _buildVerticalText('長打率'))),
        DataColumn(label: Center(child: _buildVerticalText('防御率'))),
        DataColumn(label: Center(child: _buildVerticalText('守備率'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '打率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('打率'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
        DataColumn(label: Center(child: _buildVerticalText('安打'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '出塁率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('出塁率'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '長打率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('長打率'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '防御率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('防御率'))),
        DataColumn(label: Center(child: _buildVerticalText('投球回'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '守備率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('守備率'))),
        DataColumn(label: Center(child: _buildVerticalText('刺殺'))),
        DataColumn(label: Center(child: _buildVerticalText('捕殺'))),
        DataColumn(label: Center(child: _buildVerticalText('失策'))),
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
      case '打率ランキング':
        return 'battingAverageRank';
      case '出塁率ランキング':
        return 'onBaseRank';
      case '長打率ランキング':
        return 'sluggingRank';
      case '防御率ランキング':
        return 'eraRank';
      case '守備率ランキング':
        return 'fieldingPercentageRank';
      default:
        return 'winRateRank';
    }
  }

  String _resolveRankKeyForCurrentMetric(Map<String, dynamic> team) {
    // teamに'rank'があればそれを優先。無ければ各指標のrankKey + ageSuffix
    if (team.containsKey('rank')) return 'rank';
    return _metricRankKeyBase() + _ageSuffixStr();
  }

  int _extractRankForCurrentMetric(Map<String, dynamic> team) {
    final key = _resolveRankKeyForCurrentMetric(team);
    final v = team[key]?.toString() ?? '';
    return int.tryParse(v) ?? -1;
  }

  bool _isTeamInSelectedAgeGroup() {
    if (_selectedAgeGroup == null || _selectedAgeGroup == '全年齢') return true;
    final teamAge = _teamData != null ? _teamData!['averageAge'] : null;
    if (teamAge is! int) return false; // 年齢不明なら対象外として扱う
    final parts = _selectedAgeGroup!.split('_');
    if (parts.length != 2) return true; // 想定外表記なら弾かない（安全側）
    final minAge = int.tryParse(parts[0]) ?? 0;
    final maxAge = int.tryParse(parts[1]) ?? 200;
    return teamAge >= minAge && teamAge <= maxAge;
  }

  List<DataRow> _buildTeamAndPreviousRows(int teamRank) {
    // 打率含む全指標で使える汎用版（centerは引数 or _userData）
    if (_teamData == null) return [];

    // context優先、無ければ従来の_playersを使う
    final List<Map<String, dynamic>> sourceList =
        _ctxAroundTeam.isNotEmpty ? _ctxAroundTeam : _teams;

    final int centerRank =
        teamRank > 0 ? teamRank : _extractRankForCurrentMetric(_teamData!);

    if (centerRank <= 0) {
      return [DataRow(cells: _buildDataCells(_teamData!, isTeam: true))];
    }

    List<DataRow> result = [];

    // 上位（自分より良い）: 降順→最後に追加されるよう reverse で2件
    final upper = sourceList.where((p) {
      final r = _extractRankForCurrentMetric(p);
      return r > 0 && r < centerRank;
    }).toList()
      ..sort((a, b) => _extractRankForCurrentMetric(b)
          .compareTo(_extractRankForCurrentMetric(a)));

    for (final p in upper.take(2).toList().reversed) {
      final isMyTeam = p['id'] == widget.teamId;
      result.add(
        DataRow(
          color: MaterialStateProperty.resolveWith<Color?>(
            (states) {
              if (isMyTeam) {
                return const Color(0xFF1565C0).withOpacity(0.08);
              }
              return null;
            },
          ),
          cells: _buildDataCells(p, isTeam: isMyTeam),
        ),
      );
    }

    // 自分
    result.add(
      DataRow(
        color: MaterialStateProperty.all(
          const Color(0xFF1565C0).withOpacity(0.08),
        ),
        cells: _buildDataCells(_teamData!, isTeam: true),
      ),
    );

    // 下位（自分より悪い）: 昇順で2件
    final lower = sourceList.where((p) {
      final r = _extractRankForCurrentMetric(p);
      return r > centerRank;
    }).toList()
      ..sort((a, b) => _extractRankForCurrentMetric(a)
          .compareTo(_extractRankForCurrentMetric(b)));

    for (final p in lower.take(2)) {
      final isMyTeam = p['id'] == widget.teamId;
      result.add(
        DataRow(
          color: MaterialStateProperty.resolveWith<Color?>(
            (states) {
              if (isMyTeam) {
                return const Color(0xFF1565C0).withOpacity(0.08);
              }
              return null;
            },
          ),
          cells: _buildDataCells(p, isTeam: isMyTeam),
        ),
      );
    }

    return result;
  }

  List<DataCell> _buildDataCells(Map<String, dynamic> team,
      {bool isTeam = false}) {
    final ageSuffix = _selectedAgeGroup != null && _selectedAgeGroup != '全年齢'
        ? '_age_${_selectedAgeGroup}'
        : '';

    final rankKey = _selectedRankingType == '打率ランキング'
        ? (team.containsKey('rank') ? 'rank' : 'battingAverageRank$ageSuffix')
        : _selectedRankingType == '出塁率ランキング'
            ? (team.containsKey('rank') ? 'rank' : 'onBaseRank$ageSuffix')
            : _selectedRankingType == '長打率ランキング'
                ? (team.containsKey('rank') ? 'rank' : 'sluggingRank$ageSuffix')
                : _selectedRankingType == '防御率ランキング'
                    ? (team.containsKey('rank') ? 'rank' : 'eraRank$ageSuffix')
                    : _selectedRankingType == '守備率ランキング'
                        ? (team.containsKey('rank')
                            ? 'rank'
                            : 'fieldingPercentageRank$ageSuffix')
                        : 'winRateRank$ageSuffix';

    final valueKey = _selectedRankingType == '打率ランキング'
        ? (team.containsKey('value') ? 'value' : 'battingAverage')
        : _selectedRankingType == '出塁率ランキング'
            ? (team.containsKey('value') ? 'value' : 'onBasePercentage')
            : _selectedRankingType == '長打率ランキング'
                ? (team.containsKey('value') ? 'value' : 'sluggingPercentage')
                : _selectedRankingType == '防御率ランキング'
                    ? (team.containsKey('value') ? 'value' : 'era')
                    : _selectedRankingType == '守備率ランキング'
                        ? (team.containsKey('value')
                            ? 'value'
                            : 'fieldingPercentage')
                        : 'winRate';

    if (_selectedRankingType == '勝率ランキング') {
      final String effectiveRankKey =
          team.containsKey(rankKey) ? rankKey : 'winRateRank';
      return [
        DataCell(Center(
          child: Text(
            team[effectiveRankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamId = team['id']?.toString() ?? '';
              if (teamId.isEmpty) return;

              showProfileDialog(
                context,
                teamId,
                true,
                currentUserUid: widget.teamId,
                currentUserName: 'チームメンバー',
              );
            },
            child: Center(
              child: Text(
                (team['teamName'] ?? 'チーム名不明').toString().length > 8
                    ? '${team['teamName'].toString().substring(0, 8)}…'
                    : team['teamName'].toString(),
                style: TextStyle(
                  fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
                  color: isTeam ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentage(team['winRate'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalGames']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalWins']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalLosses']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalDraws']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalScore']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalRunsAllowed']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(team['battingAverage'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(team['onBasePercentage'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(team['sluggingPercentage'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentageEra(team['era'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(team['fieldingPercentage'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['averageAge']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '打率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            team[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamId = team['id']?.toString() ?? '';
              if (teamId.isEmpty) return;

              showProfileDialog(
                context,
                teamId,
                true,
                currentUserUid: widget.teamId,
                currentUserName: 'チームメンバー',
              );
            },
            child: Center(
              child: Text(
                (team['teamName'] ?? 'チーム名不明').toString().length > 8
                    ? '${team['teamName'].toString().substring(0, 8)}…'
                    : team['teamName'].toString(),
                style: TextStyle(
                  fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
                  color: isTeam ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentage(
                num.tryParse(team[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['hits']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['averageAge']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '出塁率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            team[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamId = team['id']?.toString() ?? '';
              if (teamId.isEmpty) return;

              showProfileDialog(
                context,
                teamId,
                true,
                currentUserUid: widget.teamId,
                currentUserName: 'チームメンバー',
              );
            },
            child: Center(
              child: Text(
                (team['teamName'] ?? 'チーム名不明').toString().length > 8
                    ? '${team['teamName'].toString().substring(0, 8)}…'
                    : team['teamName'].toString(),
                style: TextStyle(
                  fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
                  color: isTeam ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentage(
                num.tryParse(team[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['averageAge']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '長打率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            team[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamId = team['id']?.toString() ?? '';
              if (teamId.isEmpty) return;

              showProfileDialog(
                context,
                teamId,
                true,
                currentUserUid: widget.teamId,
                currentUserName: 'チームメンバー',
              );
            },
            child: Center(
              child: Text(
                (team['teamName'] ?? 'チーム名不明').toString().length > 8
                    ? '${team['teamName'].toString().substring(0, 8)}…'
                    : team['teamName'].toString(),
                style: TextStyle(
                  fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
                  color: isTeam ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentage(
                num.tryParse(team[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['averageAge']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '防御率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            team[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamId = team['id']?.toString() ?? '';
              if (teamId.isEmpty) return;

              showProfileDialog(
                context,
                teamId,
                true,
                currentUserUid: widget.teamId,
                currentUserName: 'チームメンバー',
              );
            },
            child: Center(
              child: Text(
                (team['teamName'] ?? 'チーム名不明').toString().length > 8
                    ? '${team['teamName'].toString().substring(0, 8)}…'
                    : team['teamName'].toString(),
                style: TextStyle(
                  fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
                  color: isTeam ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentageEra(
                num.tryParse(team[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            (team['totalInningsPitched'] is num)
                ? (team['totalInningsPitched'] as num).toStringAsFixed(1)
                : '0.0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['averageAge']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '守備率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            team[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamId = team['id']?.toString() ?? '';
              if (teamId.isEmpty) return;

              showProfileDialog(
                context,
                teamId,
                true,
                currentUserUid: widget.teamId,
                currentUserName: 'チームメンバー',
              );
            },
            child: Center(
              child: Text(
                (team['teamName'] ?? 'チーム名不明').toString().length > 8
                    ? '${team['teamName'].toString().substring(0, 8)}…'
                    : team['teamName'].toString(),
                style: TextStyle(
                  fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
                  color: isTeam ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentage(
                num.tryParse(team[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalPutouts']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalAssists']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalErrors']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['averageAge']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
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

  // チーム名のヘッダー
  static Widget _buildTeamHeaderTeam() {
    return const Center(
      child: Text(
        'チーム',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

// 年齢別CupertinoPicker
  void _showAgePicker(BuildContext context) {
    int selectedIndex = _availableAgeGroups.indexOf(_selectedAgeGroup ?? '全年齢');

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        int tempIndex = selectedIndex;
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
                      child: const Text('キャンセル'),
                    ),
                    const Text('年齢を選択',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedAgeGroup = _availableAgeGroups[tempIndex];
                          _fetchTeamsData();
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
                  scrollController:
                      FixedExtentScrollController(initialItem: selectedIndex),
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
