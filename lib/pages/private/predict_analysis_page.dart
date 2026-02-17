import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PredictAnalysisPage extends StatefulWidget {
  final String userUid;
  final List<String> userPosition;
  const PredictAnalysisPage({
    super.key, 
    required this.userUid,
    required this.userPosition,
    });

  @override
  State<PredictAnalysisPage> createState() => _PredictAnalysisPageState();
}

class _PredictAnalysisPageState extends State<PredictAnalysisPage> {
  bool get _isPitcherUser => widget.userPosition.contains('投手');
  List<FlSpot> _monthlySpots = [];
  bool _isMonthlyLoading = true;
  List<FlSpot> _yearlySpots = [];
  bool _isYearlySpotsLoading = true;
  _GraphMode _graphMode = _GraphMode.month;
  _StatMode _statMode = _StatMode.batting;

  // ===== Career (通算) =====
  double? _careerAvg;
  
  double? _careerEra;
  // ========================

  // ===== Pitching (ERA) state =====
  List<FlSpot> _monthlyEraSpots = [];
  bool _isMonthlyEraLoading = true;
  List<FlSpot> _yearlyEraSpots = [];
  bool _isYearlyEraSpotsLoading = true;
  double _yearlyEra = 0;
  bool _isYearlyEraLoading = true;

  String? _pitchPrevCompareMessage;
  bool _isPitchPrevCompareLoading = true;
  String? _pitchPrevYearCompareMessage;
  bool _isPitchPrevYearCompareLoading = true;
  double? _pitchPrevYearEra;

  double? _projectedMonthEra;
  bool _isPitchProjectionLoading = true;
  String? _pitchProjectionFormulaText;

  // --- Pitching challenge (vs prev month/year; LOWER is better) ---
  bool _isBeatPrevEraChallengeLoading = true;
  bool _isBeatingPrevEraNow = false;
  double? _prevMonthEraForChallenge;
  int? _currentErForChallenge;
  int? _currentOutsForChallenge;
  String? _prevMonthEraLabelForChallenge;

  bool _isBeatPrevYearEraChallengeLoading = true;
  bool _isBeatingPrevYearEraNow = false;
  double? _prevYearEraForChallenge;
  int? _currentYearErForChallenge;
  int? _currentYearOutsForChallenge;
  String? _prevYearEraLabelForChallenge;

  final TextEditingController _remainingIpController = TextEditingController();
  int? _customRemainingOuts;

  final TextEditingController _remainingErController = TextEditingController();
  int? _customRemainingEr;
  // -------------------------------
  // ================================
  Future<void> _loadYearlySpots() async {
    setState(() {
      _isYearlySpotsLoading = true;
    });

    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats');

      final snap = await col.get();

      final Map<int, double> byYear = {};

      for (final doc in snap.docs) {
        if (!doc.id.contains('_all')) continue;
        final parts = doc.id.split('_');
        if (parts.length < 3) continue;
        final year = int.tryParse(parts[2]);
        if (year == null) continue;

        final data = doc.data();
        final ba = _extractBattingAverage(data);
        if (ba == null) continue;

        byYear[year] = ba;
      }

      final years = byYear.keys.toList()..sort();
      final spots = years
          .map((y) => FlSpot(y.toDouble(), byYear[y]!))
          .toList();

      if (!mounted) return;
      setState(() {
        _yearlySpots = spots;
        _isYearlySpotsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yearlySpots = [];
        _isYearlySpotsLoading = false;
      });
    }
  }
  int _year = DateTime.now().year;
  String? _prevCompareMessage;
  bool _isPrevCompareLoading = true;
  double? _projectedMonthAvg;
  bool _isProjectionLoading = true;
  String? _projectionFormulaText;
  String? _prevYearCompareMessage;
  bool _isPrevYearCompareLoading = true;
  double? _prevYearAvg;
  Future<void> _loadPrevYearCompareMessage() async {
    setState(() {
      _isPrevYearCompareLoading = true;
      _prevYearCompareMessage = null;
      _prevYearAvg = null;
    });

    try {
      final thisYear = DateTime.now().year;
      final lastYear = thisYear - 1;

      final statsCol = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats');

      final thisId = 'results_stats_${thisYear}_all';
      final lastId = 'results_stats_${lastYear}_all';

      final thisSnap = await statsCol.doc(thisId).get();
      final lastSnap = await statsCol.doc(lastId).get();

      if (!mounted) return;

      if (!thisSnap.exists || !lastSnap.exists) {
        setState(() {
          _prevYearCompareMessage = null;
          _prevYearAvg = null;
          _isPrevYearCompareLoading = false;
        });
        return;
      }

      final thisData = thisSnap.data();
      final lastData = lastSnap.data();
      if (thisData == null || lastData == null) {
        setState(() {
          _prevYearCompareMessage = null;
          _prevYearAvg = null;
          _isPrevYearCompareLoading = false;
        });
        return;
      }

      final thisAvg = _extractBattingAverage(thisData);
      final lastAvg = _extractBattingAverage(lastData);

      if (thisAvg == null || lastAvg == null) {
        setState(() {
          _prevYearCompareMessage = null;
          _prevYearAvg = lastAvg;
          _isPrevYearCompareLoading = false;
        });
        return;
      }

      final diff = thisAvg - lastAvg;

      String msg;
      if (diff > 0.0005) {
        msg = '今年は去年（${lastYear}年）の打率を超えてます！';
      } else if (diff < -0.0005) {
        msg = '今年は去年（${lastYear}年）の打率に届いていません';
      } else {
        msg = '今年は去年（${lastYear}年）と同じくらいの打率です';
      }

      setState(() {
        _prevYearAvg = lastAvg;
        _prevYearCompareMessage = msg;
        _isPrevYearCompareLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prevYearCompareMessage = null;
        _prevYearAvg = null;
        _isPrevYearCompareLoading = false;
      });
    }
  }
bool _isBeatPrevChallengeLoading = true;
bool _isBeatingPrevNow = false;

final TextEditingController _remainingAbController = TextEditingController();
int? _customRemainingAB;

// Used when “超えるには” を計算する（達成できそう/できなさそう共通で入力）
final TextEditingController _remainingHitsController = TextEditingController();
int? _customRemainingHits;

// For custom remaining AB calculation
double? _prevMonthAvgForChallenge;
int? _currentHitsForChallenge;
int? _currentABForChallenge;
String? _prevMonthLabelForChallenge;

// ===== Year challenge (vs last year) =====
bool _isBeatPrevYearChallengeLoading = true;
bool _isBeatingPrevYearNow = false;
double? _prevYearAvgForChallenge;
int? _currentYearHitsForChallenge;
int? _currentYearABForChallenge;
String? _prevYearLabelForChallenge;
// =======================================

  // ===== No-compare calculator (when prev month/year data is missing) =====
  bool _hasPrevMonthData = true;
  int? _monthHitsForCalc;
  int? _monthABForCalc;

  bool _hasPrevYearData = true;
  int? _yearHitsForCalc;
  int? _yearABForCalc;
  // =====================================================================

  // ===== No-compare calculator (Pitching) =====
  bool _hasPrevMonthEraData = true;
  int? _monthErForCalc;
  int? _monthOutsForCalc;

  bool _hasPrevYearEraData = true;
  int? _yearErForCalcPitch;
  int? _yearOutsForCalcPitch;
// ==========================================

  @override
  void dispose() {
    _remainingAbController.dispose();
    _remainingHitsController.dispose();
    _remainingIpController.dispose();
    _remainingErController.dispose();
    super.dispose();
  }

  int _countRemainingSundays(DateTime now) {
    final lastDay = DateTime(now.year, now.month + 1, 0);
    int count = 0;
    // count from tomorrow through month end (inclusive)
    for (DateTime d = now.add(const Duration(days: 1)); !d.isAfter(lastDay); d = d.add(const Duration(days: 1))) {
      if (d.weekday == DateTime.sunday) count++;
    }
    return count;
  }

  int? _extractGamesPlayed(Map<String, dynamic> data) {
    final v = data['totalGames'] ??
        data['gamesPlayed'] ??
        data['games'] ??
        data['gameCount'] ??
        data['gamesCount'] ??
        data['matchCount'] ??
        data['matches'] ??
        data['game'] ??
        data['試合数'] ??
        data['試合回数'];

    if (v == null) return null;

    // Common cases
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);

    // Sometimes aggregated docs store a list/map of games
    if (v is List) return v.length;
    if (v is Map) return v.length;

    return null;
  }
  Future<void> _loadMonthProjection() async {
    setState(() {
      _isProjectionLoading = true;
      _projectedMonthAvg = null;
      _projectionFormulaText = null;
    });

    try {
      final now = DateTime.now();
      final curYear = now.year;
      final curMonth = now.month;

      final docId = 'results_stats_${curYear}_${curMonth}';

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats')
          .doc(docId)
          .get();

      if (!mounted) return;

      if (!snap.exists) {
        setState(() {
          _projectedMonthAvg = null;
          _projectionFormulaText = null;
          _isProjectionLoading = false;
        });
        return;
      }

      final data = snap.data();
      if (data == null) {
        setState(() {
          _projectedMonthAvg = null;
          _projectionFormulaText = null;
          _isProjectionLoading = false;
        });
        return;
      }

      final hits = data['hits'] ?? data['H'] ?? data['hit'];
      final ab = data['atBats'] ?? data['atBat'] ?? data['AB'] ?? data['ab'];

      if (hits is! num || ab is! num || ab.toDouble() == 0) {
        setState(() {
          _projectedMonthAvg = null;
          _projectionFormulaText = null;
          _isProjectionLoading = false;
        });
        return;
      }

      final currentHits = hits.toDouble();
      final currentAB = ab.toDouble();

      // ====== 未来予測ロジック ======
      final totalDays = DateTime(curYear, curMonth + 1, 0).day;
      final currentDay = now.day;

      final currentAvg = currentHits / currentAB;

      // Prefer game-based projection for amateur baseball (e.g., weekly games).
      final gamesPlayed = _extractGamesPlayed(data);
      final remainingSundays = _countRemainingSundays(now);

      double projectedAB;
      String paceText;

      if (gamesPlayed != null && gamesPlayed > 0) {
        final abPerGame = currentAB / gamesPlayed;
        final projectedGames = gamesPlayed + remainingSundays;
        projectedAB = abPerGame * projectedGames;

        paceText =
            '試合ペース=AB/試合=${currentAB.toStringAsFixed(1)}/${gamesPlayed}=${abPerGame.toStringAsFixed(2)}\n'
            '月内残り日曜=${remainingSundays}回 → 月末予測試合数=${projectedGames}';
      } else {
        // Fallback to day-based projection when game count is unavailable.
        final abPerDay = currentAB / currentDay;
        projectedAB = abPerDay * totalDays;

        paceText =
            '（試合数が未設定のため日割り計算）\n'
            '打数ペース=AB/日=${currentAB.toStringAsFixed(1)}/${currentDay}=${abPerDay.toStringAsFixed(2)}\n'
            '月末予測打数=${projectedAB.round()}（${totalDays}日換算）';
      }

      // NOTE: batting average itself stays the same if the average stays the same.
      // We still show projected AB for "pace" context.
      final projectedAvg = currentAvg;

      final formulaText =
          '計算: 現在打率=H/AB=(${currentHits.toInt()}/${currentAB.toInt()})=${_formatAvg(currentAvg)}\n'
          '${paceText}';
      // =============================

      setState(() {
        _projectedMonthAvg = projectedAvg;
        _projectionFormulaText = formulaText;
        _isProjectionLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _projectedMonthAvg = null;
        _projectionFormulaText = null;
        _isProjectionLoading = false;
      });
    }
  }

  String _formatAvg(double v) {
    // 0.278 -> .278
    final s = v.toStringAsFixed(3);
    return s.startsWith('0') ? s.substring(1) : s;
  }

  String _prevMonthLabel({required int prevYear, required int prevMonth}) {
    final now = DateTime.now();
    if (prevYear < now.year) {
      return '去年${prevMonth}月';
    }
    return '先月（${prevMonth}月）';
  }

  int _neededHitsToBeatAvg({
    required int currentHits,
    required int currentAB,
    required double targetAvg,
    required int remainingAB,
  }) {
    // Need (H + x) / (AB + remainingAB) > targetAvg
    // x > targetAvg*(AB+remainingAB) - H
    final rhs = targetAvg * (currentAB + remainingAB) - currentHits;
    final needed = rhs.isFinite ? (rhs.floor() + 1) : remainingAB + 1;
    if (needed < 0) return 0;
    return needed;
  }


  double _maxYForAvg(List<FlSpot> spots) {
    if (spots.isEmpty) return 0.4;
    final maxV = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    // round up to the next 0.05, with a minimum of 0.35 and max 0.6
    final rounded = ((maxV / 0.05).ceil() * 0.05).toDouble();
    return rounded.clamp(0.35, 0.6);
  }

  double _maxSpotY(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    return spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
  }

  int? _extractMonthFromDocId(String id, int year) {
    final prefix = 'results_stats_${year}_';
    if (!id.startsWith(prefix)) return null;

    // exclude yearly/all and practice variants
    if (id.contains('_all') || id.contains('練習試合')) return null;

    final rest = id.substring(prefix.length);
    final m = int.tryParse(rest);
    if (m == null) return null;
    if (m < 1 || m > 12) return null;
    return m;
  }

  double? _extractBattingAverage(Map<String, dynamic> data) {
    final direct = data['battingAverage'] ?? data['avg'] ?? data['average'] ?? data['batting_average'];
    if (direct is num) return direct.toDouble();

    final hits = data['hits'] ?? data['H'] ?? data['hit'];
    final ab = data['atBats'] ?? data['atBat'] ?? data['AB'] ?? data['ab'];
    if (hits is num && ab is num && ab.toDouble() > 0) {
      return hits.toDouble() / ab.toDouble();
    }
    return null;
  }

  int? _extractEarnedRuns(Map<String, dynamic> data) {
    final v = data['earnedRuns'] ??
        data['totalEarnedRuns'] ??
        data['totalER'] ??
        data['ER'] ??
        data['earnedRun'] ??
        data['自責点'];
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Returns total outs pitched (IP*3).
  /// IMPORTANT: We must NOT use generic fields like `totalOuts`/`outs` because those often mean
  /// fielding putouts, not pitching outs. Use pitching-specific keys first, then fall back to IP.
  int? _extractOutsPitched(Map<String, dynamic> data) {
    // Pitching-specific outs fields
    final outs = data['outsPitched'] ??
        data['totalOutsPitched'] ??
        data['pitchingOuts'] ??
        data['totalPitchingOuts'] ??
        data['outPitched'];

    if (outs is num) {
      final o = outs.toInt();
      return o > 0 ? o : null;
    }
    if (outs is String) {
      final n = int.tryParse(outs.trim());
      if (n != null && n > 0) return n;
    }

    // Fall back to innings pitched
    final ip = data['inningsPitched'] ??
        data['totalInningsPitched'] ??
        data['IP'] ??
        data['inningPitched'] ??
        data['投球回'] ??
        data['innings'] ??
        data['inning'];

    if (ip is num) {
      final o = (ip.toDouble() * 3.0).round();
      return o > 0 ? o : null;
    }
    if (ip is String) {
      final d = double.tryParse(ip.trim());
      if (d != null) {
        final o = (d * 3.0).round();
        return o > 0 ? o : null;
      }
    }

    return null;
  }


  double _eraFromErAndOuts(int er, int outs) {
    if (outs <= 0) return 0.0;
    final ip = outs / 3.0;
    return er * 7.0 / ip;
  }

  /// Max additional ER allowed in remaining outs to make final ERA < targetEra.
  int _maxAllowedErToBeatEra({
    required int currentEr,
    required int currentOuts,
    required double targetEra,
    required int remainingOuts,
  }) {

    final denomOuts = currentOuts + remainingOuts;
    if (denomOuts <= 0) return -1;
    final limit = (targetEra * denomOuts / 21.0) - currentEr;
    // strict < : x < limit  => maxInt = floor(limit - eps)
    final maxInt = (limit - 1e-9).floor();
    return maxInt;
  }

  String _formatEra(double v) => v.toStringAsFixed(2);

  double? _extractEra(Map<String, dynamic> data) {
    final direct = data['era'] ?? data['ERA'] ?? data['earnedRunAverage'] ?? data['earned_run_average'];
    if (direct is num) return direct.toDouble();

    // Try to compute from ER and innings pitched: ERA = ER * 9 / IP
    final er = data['earnedRuns'] ?? data['totalEarnedRuns'] ?? data['totalER'] ?? data['ER'] ?? data['earnedRun'] ?? data['自責点'];
    final ip = data['inningsPitched'] ?? data['totalInningsPitched'] ?? data['IP'] ?? data['inningPitched'] ?? data['投球回'] ?? data['innings'] ?? data['inning'];

    if (er is num && ip is num) {
      final ipD = ip.toDouble();
      if (ipD <= 0) return null;
      return er.toDouble() * 7.0 / ipD;
    }

    // Some datasets store outs instead of innings
    final outs = data['outsPitched'] ??
        data['totalOutsPitched'] ??
        data['totalOuts'] ??
        data['outs'] ??
        data['outPitched'];
    if (er is num && outs is num) {
      final ipD = outs.toDouble() / 3.0;
      if (ipD <= 0) return null;
      return er.toDouble() * 7.0 / ipD;
    }

    return null;
  }

  double _maxYForEra(List<FlSpot> spots) {
    if (spots.isEmpty) return 9;
    final maxV = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final rounded = ((maxV / 0.5).ceil() * 0.5).toDouble();
    return rounded.clamp(1.0, 20.0);
  }
  Future<void> _loadPitchingMonthlyEras() async {
    setState(() {
      _isMonthlyEraLoading = true;
    });

    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats');

      final snap = await col.get();

      final Map<int, double> byMonth = {};
      for (final doc in snap.docs) {
        final m = _extractMonthFromDocId(doc.id, _year);
        if (m == null) continue;
        final data = doc.data();
        final era = _extractEra(data);
        if (era == null) continue;
        byMonth[m] = era;
      }

      final months = byMonth.keys.toList()..sort();
      final spots = months.map((m) => FlSpot(m.toDouble(), byMonth[m]!)).toList();

      if (!mounted) return;
      setState(() {
        _monthlyEraSpots = spots;
        _isMonthlyEraLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _monthlyEraSpots = [];
        _isMonthlyEraLoading = false;
      });
    }
  }

  Future<void> _loadPitchingYearlyEra() async {
    setState(() {
      _isYearlyEraLoading = true;
    });
    try {
      final docId = 'results_stats_${_year}_all';
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats')
          .doc(docId)
          .get();

      if (!doc.exists) {
        if (!mounted) return;
        setState(() {
          _yearlyEra = 0;
          _isYearlyEraLoading = false;
        });
        return;
      }

      final data = doc.data()!;
      final era = _extractEra(data);

      if (!mounted) return;
      setState(() {
        _yearlyEra = era ?? 0;
        _isYearlyEraLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yearlyEra = 0;
        _isYearlyEraLoading = false;
      });
    }
  }

  Future<void> _loadPitchingYearlySpots() async {
    setState(() {
      _isYearlyEraSpotsLoading = true;
    });

    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats');

      final snap = await col.get();

      final Map<int, double> byYear = {};

      for (final doc in snap.docs) {
        if (!doc.id.contains('_all')) continue;
        final parts = doc.id.split('_');
        if (parts.length < 3) continue;
        final year = int.tryParse(parts[2]);
        if (year == null) continue;

        final data = doc.data();
        final era = _extractEra(data);
        if (era == null) continue;

        byYear[year] = era;
      }

      final years = byYear.keys.toList()..sort();
      final spots = years.map((y) => FlSpot(y.toDouble(), byYear[y]!)).toList();

      if (!mounted) return;
      setState(() {
        _yearlyEraSpots = spots;
        _isYearlyEraSpotsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yearlyEraSpots = [];
        _isYearlyEraSpotsLoading = false;
      });
    }
  }

  Future<void> _loadPitchingMonthProjection() async {
    setState(() {
      _isPitchProjectionLoading = true;
      _projectedMonthEra = null;
      _pitchProjectionFormulaText = null;
    });

    try {
      final now = DateTime.now();
      final curYear = now.year;
      final curMonth = now.month;

      final docId = 'results_stats_${curYear}_${curMonth}';

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats')
          .doc(docId)
          .get();

      if (!mounted) return;

      if (!snap.exists) {
        setState(() {
          _projectedMonthEra = null;
          _pitchProjectionFormulaText = null;
          _isPitchProjectionLoading = false;
        });
        return;
      }

      final data = snap.data();
      if (data == null) {
        setState(() {
          _projectedMonthEra = null;
          _pitchProjectionFormulaText = null;
          _isPitchProjectionLoading = false;
        });
        return;
      }

      final era = _extractEra(data);
      if (era == null) {
        setState(() {
          _projectedMonthEra = null;
          _pitchProjectionFormulaText = null;
          _isPitchProjectionLoading = false;
        });
        return;
      }

      final erVal = _extractEarnedRuns(data);
      final outsVal = _extractOutsPitched(data);

      // If we can’t get ER/outs, fall back to showing current ERA only.
      if (erVal == null || outsVal == null || outsVal <= 0) {
        final formulaText = '計算: 現在防御率(ERA)=${_formatEra(era)}';
        setState(() {
          _projectedMonthEra = null;
          _pitchProjectionFormulaText = formulaText;
          _isPitchProjectionLoading = false;
        });
        return;
      }

      final currentEr = erVal;
      final currentOuts = outsVal;
      final currentIp = currentOuts / 3.0;

      final gamesPlayed = _extractGamesPlayed(data);
      final remainingSundays = _countRemainingSundays(now);

      double projectedOuts;
      double projectedEr;
      String paceText;

      if (gamesPlayed != null && gamesPlayed > 0) {
        final outsPerGame = currentOuts / gamesPlayed;
        final erPerGame = currentEr / gamesPlayed;
        final projectedGames = gamesPlayed + remainingSundays;

        projectedOuts = outsPerGame * projectedGames;
        projectedEr = erPerGame * projectedGames;

        paceText =
            '試合ペース=投球回/試合=${currentOuts}/${gamesPlayed}=${outsPerGame.toStringAsFixed(1)}\n'
            '自責ペース=ER/試合=${currentEr}/${gamesPlayed}=${erPerGame.toStringAsFixed(2)}\n'
            '月内残り日曜=${remainingSundays}回 → 月末予測試合数=${projectedGames}';
      } else {
        // Fallback to day-based projection when game count is unavailable.
        final totalDays = DateTime(curYear, curMonth + 1, 0).day;
        final currentDay = now.day;
        final outsPerDay = currentOuts / currentDay;
        final erPerDay = currentEr / currentDay;

        projectedOuts = outsPerDay * totalDays;
        projectedEr = erPerDay * totalDays;

        paceText =
            '（試合数が未設定のため日割り計算）\n'
            '投球回ペース=outs/日=${currentOuts}/${currentDay}=${outsPerDay.toStringAsFixed(1)}\n'
            '自責ペース=ER/日=${currentEr}/${currentDay}=${erPerDay.toStringAsFixed(2)}\n'
            '月末予測投球回=${projectedOuts.round()}（${totalDays}日換算）';
      }

      // ===== 小サンプル対策 =====
      // IPが少なすぎると、防御率が極端な値になりやすい。
      // 草野球基準：3回未満（=9アウト未満）の場合は月末予測を表示しない。
      if (currentOuts < 9) {
        final formulaText =
            '計算: 現在ERA=ER×7/IP=(${currentEr}×7/${currentIp.toStringAsFixed(1)})=${_formatEra(era)}\n'
            '※ 投球回が少ないため、月末予測は参考値になりやすいので表示しません';
        setState(() {
          _projectedMonthEra = null; // 予測値は出さない
          _pitchProjectionFormulaText = formulaText;
          _isPitchProjectionLoading = false;
        });
        return;
      }

      // Projected ERA from projected ER/outs
      // outs/ER を丸め過ぎるとIPが小さい時にERAが暴れるので、doubleで計算する
      final projOutsD = math.max(1.0, projectedOuts);
      final projIpD = projOutsD / 3.0;
      final projErD = projectedEr;
      final projectedEra = (projIpD > 0) ? (projErD * 7.0 / projIpD) : 0.0;

      final formulaText =
          '計算: 現在ERA=ER×7/IP=(${currentEr}×7/${currentIp.toStringAsFixed(1)})=${_formatEra(era)}\n'
          '${paceText}\n'
          '月末予測: ER≈${projErD.toStringAsFixed(1)}, IP≈${projIpD.toStringAsFixed(1)} → 予測ERA≈${_formatEra(projectedEra)}';

      setState(() {
        _projectedMonthEra = projectedEra;
        _pitchProjectionFormulaText = formulaText;
        _isPitchProjectionLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _projectedMonthEra = null;
        _pitchProjectionFormulaText = null;
        _isPitchProjectionLoading = false;
      });
    }
  }

  /// Parse innings text like "2", "2.0", "2.1", "2.2" into outs (IP*3).
/// Baseball notation: .1 = 1 out, .2 = 2 outs.
int? _parseInningsToOuts(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  if (s.contains('.')) {
    final parts = s.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null || whole < 0) return null;

    final fracStr = parts.length > 1 ? parts[1] : '';

    // baseball style .1 / .2
    if (fracStr == '1') return whole * 3 + 1;
    if (fracStr == '2') return whole * 3 + 2;
    if (fracStr.isEmpty || fracStr == '0') return whole * 3;

    // fallback: decimal innings (e.g. 6.3333)
    final d = double.tryParse(s);
    if (d == null || d < 0) return null;
    final outs = (d * 3.0).round();
    return outs > 0 ? outs : null;
  }

  final whole = int.tryParse(s);
  if (whole == null || whole < 0) return null;
  final outs = whole * 3;
  return outs > 0 ? outs : null;
}

/// Format outs (IP*3) back to baseball innings string like 6.1 / 6.2
String _formatInningsFromOuts(int outs) {
  final whole = outs ~/ 3;
  final rem = outs % 3;
  if (rem == 0) return whole.toString();
  return '$whole.$rem';
}

  Future<void> _loadPitchingPrevCompareMessage() async {
    setState(() {
      _isPitchPrevCompareLoading = true;
      _pitchPrevCompareMessage = null;
    });

    try {
      final now = DateTime.now();
      final curYear = now.year;
      final curMonth = now.month;

      int prevYear = curYear;
      int prevMonth = curMonth - 1;
      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear = curYear - 1;
      }

      final statsCol = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats');

      final curId = 'results_stats_${curYear}_${curMonth}';
      final prevId = 'results_stats_${prevYear}_${prevMonth}';

      final curSnap = await statsCol.doc(curId).get();
      final prevSnap = await statsCol.doc(prevId).get();

      if (!mounted) return;

      if (!curSnap.exists || !prevSnap.exists) {
        setState(() {
          _pitchPrevCompareMessage = null;
          _isPitchPrevCompareLoading = false;
        });
        return;
      }

      final curData = curSnap.data();
      final prevData = prevSnap.data();
      if (curData == null || prevData == null) {
        setState(() {
          _pitchPrevCompareMessage = null;
          _isPitchPrevCompareLoading = false;
        });
        return;
      }

      final prevEra = _extractEra(prevData);
      final curEra = _extractEra(curData);
      if (prevEra == null || curEra == null) {
        setState(() {
          _pitchPrevCompareMessage = null;
          _isPitchPrevCompareLoading = false;
        });
        return;
      }

      // ERA: lower is better
      final diff = curEra - prevEra;
      final label = _prevMonthLabel(prevYear: prevYear, prevMonth: prevMonth);

      String message;
      if (diff < -0.01) {
        message = 'このペースだと${label}より防御率が良くなりそう！';
      } else if (diff > 0.01) {
        message = '今のままだと${label}より防御率が悪くなるかも';
      } else {
        message = '${label}と同じくらいのペース';
      }

      setState(() {
        _pitchPrevCompareMessage = message;
        _isPitchPrevCompareLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pitchPrevCompareMessage = null;
        _isPitchPrevCompareLoading = false;
      });
    }
  }



  Future<void> _loadPitchingPrevYearCompareMessage() async {
    setState(() {
      _isPitchPrevYearCompareLoading = true;
      _pitchPrevYearCompareMessage = null;
      _pitchPrevYearEra = null;
    });

    try {
      final thisYear = DateTime.now().year;
      final lastYear = thisYear - 1;

      final statsCol = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats');

      final thisId = 'results_stats_${thisYear}_all';
      final lastId = 'results_stats_${lastYear}_all';

      final thisSnap = await statsCol.doc(thisId).get();
      final lastSnap = await statsCol.doc(lastId).get();

      if (!mounted) return;

      if (!thisSnap.exists || !lastSnap.exists) {
        setState(() {
          _pitchPrevYearCompareMessage = null;
          _pitchPrevYearEra = null;
          _isPitchPrevYearCompareLoading = false;
        });
        return;
      }

      final thisData = thisSnap.data();
      final lastData = lastSnap.data();
      if (thisData == null || lastData == null) {
        setState(() {
          _pitchPrevYearCompareMessage = null;
          _pitchPrevYearEra = null;
          _isPitchPrevYearCompareLoading = false;
        });
        return;
      }

      final thisEra = _extractEra(thisData);
      final lastEra = _extractEra(lastData);

      if (thisEra == null || lastEra == null) {
        setState(() {
          _pitchPrevYearCompareMessage = null;
          _pitchPrevYearEra = lastEra;
          _isPitchPrevYearCompareLoading = false;
        });
        return;
      }

      final diff = thisEra - lastEra;

      String msg;
      if (diff < -0.01) {
        msg = '今年は去年（${lastYear}年）の防御率より良いです！';
      } else if (diff > 0.01) {
        msg = '今年は去年（${lastYear}年）の防御率に届いていません';
      } else {
        msg = '今年は去年（${lastYear}年）と同じくらいの防御率です';
      }

      setState(() {
        _pitchPrevYearEra = lastEra;
        _pitchPrevYearCompareMessage = msg;
        _isPitchPrevYearCompareLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pitchPrevYearCompareMessage = null;
        _pitchPrevYearEra = null;
        _isPitchPrevYearCompareLoading = false;
      });
    }
  }

  Future<void> _loadMonthlyAverages() async {
    setState(() {
      _isMonthlyLoading = true;
    });

    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats');

      final snap = await col.get();

      final Map<int, double> byMonth = {};
      for (final doc in snap.docs) {
        final m = _extractMonthFromDocId(doc.id, _year);
        if (m == null) continue;
        final data = doc.data();
        final ba = _extractBattingAverage(data);
        if (ba == null) continue;
        byMonth[m] = ba;
      }

      final months = byMonth.keys.toList()..sort();
      final spots = months.map((m) => FlSpot(m.toDouble(), byMonth[m]!)).toList();

      if (!mounted) return;
      setState(() {
        _monthlySpots = spots;
        _isMonthlyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _monthlySpots = [];
        _isMonthlyLoading = false;
      });
    }
  }

  double _yearlyAvg = 0;
  bool _isYearlyLoading = true;
  Future<void> _loadYearlyAvg() async {
    setState(() {
      _isYearlyLoading = true;
    });
    try {
      final docId = 'results_stats_${_year}_all';
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats')
          .doc(docId)
          .get();
      if (!doc.exists) {
        if (!mounted) return;
        setState(() {
          _yearlyAvg = 0;
          _isYearlyLoading = false;
        });
        return;
      }
      final data = doc.data()!;
      final ba = _extractBattingAverage(data);
      if (!mounted) return;
      setState(() {
        _yearlyAvg = ba ?? 0;
        _isYearlyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yearlyAvg = 0;
        _isYearlyLoading = false;
      });
    }
  }

  Future<void> _loadBeatPrevChallenge() async {
    setState(() {
      _isBeatPrevChallengeLoading = true;
      _hasPrevMonthData = true;
      _monthHitsForCalc = null;
      _monthABForCalc = null;

      _prevMonthAvgForChallenge = null;
      _currentHitsForChallenge = null;
      _currentABForChallenge = null;
      _prevMonthLabelForChallenge = null;
      _isBeatingPrevNow = false;
    });

    try {
      final now = DateTime.now();
      final curYear = now.year;
      final curMonth = now.month;

      int prevYear = curYear;
      int prevMonth = curMonth - 1;
      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear = curYear - 1;
      }

      final statsCol = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats');

      final curId = 'results_stats_${curYear}_${curMonth}';
      final prevId = 'results_stats_${prevYear}_${prevMonth}';

      final curSnap = await statsCol.doc(curId).get();
      final prevSnap = await statsCol.doc(prevId).get();

      if (!mounted) return;

      // We need current month stats at least for the calculator
      if (!curSnap.exists || curSnap.data() == null) {
        setState(() {
          _hasPrevMonthData = false;
          _monthHitsForCalc = null;
          _monthABForCalc = null;
          _isBeatPrevChallengeLoading = false;
        });
        return;
      }

      final curData = curSnap.data()!;
      final hitsVal = curData['hits'] ?? curData['H'] ?? curData['hit'];
      final abVal = curData['atBats'] ?? curData['atBat'] ?? curData['AB'] ?? curData['ab'];

      if (hitsVal is! num || abVal is! num || abVal.toInt() <= 0) {
        setState(() {
          _hasPrevMonthData = false;
          _monthHitsForCalc = null;
          _monthABForCalc = null;
          _isBeatPrevChallengeLoading = false;
        });
        return;
      }

      final currentHits = hitsVal.toInt();
      final currentAB = abVal.toInt();

      // Store for calculator regardless
      _monthHitsForCalc = currentHits;
      _monthABForCalc = currentAB;

      // If previous month is missing, show no-compare calculator instead of challenge
      if (!prevSnap.exists || prevSnap.data() == null) {
        setState(() {
          _hasPrevMonthData = false;
          _prevMonthAvgForChallenge = null;
          _currentHitsForChallenge = null;
          _currentABForChallenge = null;
          _prevMonthLabelForChallenge = null;
          _isBeatingPrevNow = false;
          _isBeatPrevChallengeLoading = false;
        });
        return;
      }

      final prevData = prevSnap.data()!;
      final prevAvg = _extractBattingAverage(prevData);
      if (prevAvg == null || prevAvg <= 0) {
        setState(() {
          _hasPrevMonthData = false;
          _prevMonthAvgForChallenge = null;
          _currentHitsForChallenge = null;
          _currentABForChallenge = null;
          _prevMonthLabelForChallenge = null;
          _isBeatingPrevNow = false;
          _isBeatPrevChallengeLoading = false;
        });
        return;
      }

      final label = _prevMonthLabel(prevYear: prevYear, prevMonth: prevMonth);
      _prevMonthAvgForChallenge = prevAvg;
      _currentHitsForChallenge = currentHits;
      _currentABForChallenge = currentAB;
      _prevMonthLabelForChallenge = label;

      final currentAvg = currentHits / currentAB;
      final diff = currentAvg - prevAvg;
      final isBeatingNow = diff > 0.0005;

      setState(() {
        _hasPrevMonthData = true;
        _isBeatingPrevNow = isBeatingNow;
        _isBeatPrevChallengeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasPrevMonthData = false;
        _isBeatPrevChallengeLoading = false;
        _prevMonthAvgForChallenge = null;
        _currentHitsForChallenge = null;
        _currentABForChallenge = null;
        _prevMonthLabelForChallenge = null;
        _isBeatingPrevNow = false;
      });
    }
  }

  Future<void> _loadBeatPrevEraChallenge() async {
  setState(() {
    _isBeatPrevEraChallengeLoading = true;

    // no-compare state
    _hasPrevMonthEraData = true;
    _monthErForCalc = null;
    _monthOutsForCalc = null;

    // challenge state
    _prevMonthEraForChallenge = null;
    _currentErForChallenge = null;
    _currentOutsForChallenge = null;
    _prevMonthEraLabelForChallenge = null;
    _isBeatingPrevEraNow = false;
  });

  try {
    final now = DateTime.now();
    final curYear = now.year;
    final curMonth = now.month;

    int prevYear = curYear;
    int prevMonth = curMonth - 1;
    if (prevMonth == 0) {
      prevMonth = 12;
      prevYear = curYear - 1;
    }

    final statsCol = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('stats');

    final curId = 'results_stats_${curYear}_${curMonth}';
    final prevId = 'results_stats_${prevYear}_${prevMonth}';

    final curSnap = await statsCol.doc(curId).get();
    final prevSnap = await statsCol.doc(prevId).get();

    if (!mounted) return;

    // current month is required for calculator
    if (!curSnap.exists || curSnap.data() == null) {
      setState(() {
        _hasPrevMonthEraData = false;
        _monthErForCalc = null;
        _monthOutsForCalc = null;
        _isBeatPrevEraChallengeLoading = false;
      });
      return;
    }

    final curData = curSnap.data()!;
    final curEr = _extractEarnedRuns(curData);
    final curOuts = _extractOutsPitched(curData);

    if (curEr == null || curOuts == null || curOuts <= 0) {
      setState(() {
        _hasPrevMonthEraData = false;
        _monthErForCalc = null;
        _monthOutsForCalc = null;
        _isBeatPrevEraChallengeLoading = false;
      });
      return;
    }

    // store current for calculator regardless
    _monthErForCalc = curEr;
    _monthOutsForCalc = curOuts;

    // if prev month missing -> show calculator card
    if (!prevSnap.exists || prevSnap.data() == null) {
      setState(() {
        _hasPrevMonthEraData = false;
        _prevMonthEraForChallenge = null;
        _currentErForChallenge = null;
        _currentOutsForChallenge = null;
        _prevMonthEraLabelForChallenge = null;
        _isBeatingPrevEraNow = false;
        _isBeatPrevEraChallengeLoading = false;
      });
      return;
    }

    final prevData = prevSnap.data()!;
    final prevEra = _extractEra(prevData);
    if (prevEra == null || prevEra <= 0) {
      setState(() {
        _hasPrevMonthEraData = false;
        _prevMonthEraForChallenge = null;
        _currentErForChallenge = null;
        _currentOutsForChallenge = null;
        _prevMonthEraLabelForChallenge = null;
        _isBeatingPrevEraNow = false;
        _isBeatPrevEraChallengeLoading = false;
      });
      return;
    }

    final curEra = _eraFromErAndOuts(curEr, curOuts);
    final label = _prevMonthLabel(prevYear: prevYear, prevMonth: prevMonth);

    _prevMonthEraForChallenge = prevEra;
    _currentErForChallenge = curEr;
    _currentOutsForChallenge = curOuts;
    _prevMonthEraLabelForChallenge = label;

    final diff = curEra - prevEra; // lower is better
    final isBeatingNow = diff < -0.01;

    setState(() {
      _hasPrevMonthEraData = true;
      _isBeatingPrevEraNow = isBeatingNow;
      _isBeatPrevEraChallengeLoading = false;
    });
  } catch (_) {
    if (!mounted) return;
    setState(() {
      _hasPrevMonthEraData = false;
      _monthErForCalc = null;
      _monthOutsForCalc = null;

      _prevMonthEraForChallenge = null;
      _currentErForChallenge = null;
      _currentOutsForChallenge = null;
      _prevMonthEraLabelForChallenge = null;
      _isBeatingPrevEraNow = false;
      _isBeatPrevEraChallengeLoading = false;
    });
  }
}

Future<void> _loadBeatPrevYearEraChallenge() async {
  setState(() {
    _isBeatPrevYearEraChallengeLoading = true;

    // no-compare state
    _hasPrevYearEraData = true;
    _yearErForCalcPitch = null;
    _yearOutsForCalcPitch = null;

    // challenge state
    _prevYearEraForChallenge = null;
    _currentYearErForChallenge = null;
    _currentYearOutsForChallenge = null;
    _prevYearEraLabelForChallenge = null;
    _isBeatingPrevYearEraNow = false;
  });

  try {
    final thisYear = DateTime.now().year;
    final lastYear = thisYear - 1;

    final statsCol = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('stats');

    final thisId = 'results_stats_${thisYear}_all';
    final lastId = 'results_stats_${lastYear}_all';

    final thisSnap = await statsCol.doc(thisId).get();
    final lastSnap = await statsCol.doc(lastId).get();

    if (!mounted) return;

    // current year is required for calculator
    if (!thisSnap.exists || thisSnap.data() == null) {
      setState(() {
        _hasPrevYearEraData = false;
        _yearErForCalcPitch = null;
        _yearOutsForCalcPitch = null;
        _isBeatPrevYearEraChallengeLoading = false;
      });
      return;
    }

    final thisData = thisSnap.data()!;
    final curEr = _extractEarnedRuns(thisData);
    final curOuts = _extractOutsPitched(thisData);

    if (curEr == null || curOuts == null || curOuts <= 0) {
      setState(() {
        _hasPrevYearEraData = false;
        _yearErForCalcPitch = null;
        _yearOutsForCalcPitch = null;
        _isBeatPrevYearEraChallengeLoading = false;
      });
      return;
    }

    // store current for calculator regardless
    _yearErForCalcPitch = curEr;
    _yearOutsForCalcPitch = curOuts;

    // if last year missing -> show calculator card
    if (!lastSnap.exists || lastSnap.data() == null) {
      setState(() {
        _hasPrevYearEraData = false;
        _prevYearEraForChallenge = null;
        _currentYearErForChallenge = null;
        _currentYearOutsForChallenge = null;
        _prevYearEraLabelForChallenge = null;
        _isBeatingPrevYearEraNow = false;
        _isBeatPrevYearEraChallengeLoading = false;
      });
      return;
    }

    final lastData = lastSnap.data()!;
    final prevEra = _extractEra(lastData);
    if (prevEra == null || prevEra <= 0) {
      setState(() {
        _hasPrevYearEraData = false;
        _prevYearEraForChallenge = null;
        _currentYearErForChallenge = null;
        _currentYearOutsForChallenge = null;
        _prevYearEraLabelForChallenge = null;
        _isBeatingPrevYearEraNow = false;
        _isBeatPrevYearEraChallengeLoading = false;
      });
      return;
    }

    final curEra = _eraFromErAndOuts(curEr, curOuts);

    _prevYearEraForChallenge = prevEra;
    _currentYearErForChallenge = curEr;
    _currentYearOutsForChallenge = curOuts;
    _prevYearEraLabelForChallenge = '去年（${lastYear}年）';

    final diff = curEra - prevEra; // lower is better
    final isBeatingNow = diff < -0.01;

    setState(() {
      _hasPrevYearEraData = true;
      _isBeatingPrevYearEraNow = isBeatingNow;
      _isBeatPrevYearEraChallengeLoading = false;
    });
  } catch (_) {
    if (!mounted) return;
    setState(() {
      _hasPrevYearEraData = false;
      _yearErForCalcPitch = null;
      _yearOutsForCalcPitch = null;

      _prevYearEraForChallenge = null;
      _currentYearErForChallenge = null;
      _currentYearOutsForChallenge = null;
      _prevYearEraLabelForChallenge = null;
      _isBeatingPrevYearEraNow = false;
      _isBeatPrevYearEraChallengeLoading = false;
    });
  }
}


  Future<void> _loadBeatPrevYearChallenge() async {
    setState(() {
      _isBeatPrevYearChallengeLoading = true;
      _hasPrevYearData = true;
      _yearHitsForCalc = null;
      _yearABForCalc = null;
      _prevYearAvgForChallenge = null;
      _currentYearHitsForChallenge = null;
      _currentYearABForChallenge = null;
      _prevYearLabelForChallenge = null;
      _isBeatingPrevYearNow = false;
    });

    try {
      final thisYear = DateTime.now().year;
      final lastYear = thisYear - 1;

      final statsCol = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats');

      final thisId = 'results_stats_${thisYear}_all';
      final lastId = 'results_stats_${lastYear}_all';

      final thisSnap = await statsCol.doc(thisId).get();
      final lastSnap = await statsCol.doc(lastId).get();

      if (!mounted) return;

      // If current year data is missing, cannot even calculate
      if (!thisSnap.exists || thisSnap.data() == null) {
        setState(() {
          _hasPrevYearData = false;
          _yearHitsForCalc = null;
          _yearABForCalc = null;
          _isBeatPrevYearChallengeLoading = false;
          _prevYearAvgForChallenge = null;
          _currentYearHitsForChallenge = null;
          _currentYearABForChallenge = null;
          _prevYearLabelForChallenge = null;
          _isBeatingPrevYearNow = false;
        });
        return;
      }

      final thisData = thisSnap.data()!;
      final hitsVal = thisData['hits'] ?? thisData['H'] ?? thisData['hit'];
      final abVal = thisData['atBats'] ?? thisData['atBat'] ?? thisData['AB'] ?? thisData['ab'];

      if (hitsVal is! num || abVal is! num || abVal.toInt() <= 0) {
        setState(() {
          _hasPrevYearData = false;
          _yearHitsForCalc = null;
          _yearABForCalc = null;
          _isBeatPrevYearChallengeLoading = false;
          _prevYearAvgForChallenge = null;
          _currentYearHitsForChallenge = null;
          _currentYearABForChallenge = null;
          _prevYearLabelForChallenge = null;
          _isBeatingPrevYearNow = false;
        });
        return;
      }

      final currentHits = hitsVal.toInt();
      final currentAB = abVal.toInt();
      _yearHitsForCalc = currentHits;
      _yearABForCalc = currentAB;
      final currentAvg = currentHits / currentAB;

      // If last year is missing, show calculator only
      if (!lastSnap.exists || lastSnap.data() == null) {
        setState(() {
          _hasPrevYearData = false;
          _isBeatPrevYearChallengeLoading = false;
          _prevYearAvgForChallenge = null;
          _currentYearHitsForChallenge = null;
          _currentYearABForChallenge = null;
          _prevYearLabelForChallenge = null;
          _isBeatingPrevYearNow = false;
        });
        return;
      }

      final lastData = lastSnap.data()!;
      final prevAvg = _extractBattingAverage(lastData);
      if (prevAvg == null || prevAvg <= 0) {
        setState(() {
          _hasPrevYearData = false;
          _isBeatPrevYearChallengeLoading = false;
          _prevYearAvgForChallenge = null;
          _currentYearHitsForChallenge = null;
          _currentYearABForChallenge = null;
          _prevYearLabelForChallenge = null;
          _isBeatingPrevYearNow = false;
        });
        return;
      }

      final label = '去年（${lastYear}年）';
      _prevYearAvgForChallenge = prevAvg;
      _currentYearHitsForChallenge = currentHits;
      _currentYearABForChallenge = currentAB;
      _prevYearLabelForChallenge = label;

      final diff = currentAvg - prevAvg;
      final isBeatingNow = diff > 0.0005;

      setState(() {
        _hasPrevYearData = true;
        _isBeatingPrevYearNow = isBeatingNow;
        _isBeatPrevYearChallengeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasPrevYearData = false;
        _isBeatPrevYearChallengeLoading = false;
        _prevYearAvgForChallenge = null;
        _currentYearHitsForChallenge = null;
        _currentYearABForChallenge = null;
        _prevYearLabelForChallenge = null;
        _isBeatingPrevYearNow = false;
      });
    }
  }
  Widget _buildNoCompareBattingCard({
    required String title,
    required String subtitle,
    required int currentHits,
    required int currentAB,
    required String resultLabel,
  }) {
    final remainingAB = _customRemainingAB;
    final remainingHits = _customRemainingHits;

    String? error;
    if (remainingAB != null && remainingAB < 0) error = '残り打数は0以上にしてください';
    if (remainingHits != null && remainingHits < 0) error = '安打は0以上にしてください';
    if (remainingAB != null && remainingHits != null && remainingHits > remainingAB) {
      error = '安打は打数を超えられません';
    }

    final totalAB = (remainingAB ?? 0) + currentAB;
    final totalHits = (remainingHits ?? 0) + currentHits;
    final canCalc = remainingAB != null && remainingHits != null && error == null && totalAB > 0;
    final avg = canCalc ? (totalHits / totalAB) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25)),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('残り打数', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              height: 34,
              child: TextField(
                controller: _remainingAbController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  setState(() {
                    _customRemainingAB = (n != null && n >= 0) ? n : null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('打', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('安打', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              height: 34,
              child: TextField(
                controller: _remainingHitsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  setState(() {
                    _customRemainingHits = (n != null && n >= 0) ? n : null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('本', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        if (error != null)
          Text(error, style: const TextStyle(fontSize: 12, color: Colors.redAccent, height: 1.25))
        else if (!canCalc)
          const Text('※ 残り打数と安打を入れると計算します',
              style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.25))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${resultLabel}：${_formatAvg(avg!)}（$totalHits/$totalAB）',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '現在：${_formatAvg(currentHits / currentAB)}（$currentHits/$currentAB）',
                style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildNoComparePitchingCard({
    required String title,
    required String subtitle,
    required int currentEr,
    required int currentOuts,
    required String resultLabel,
  }) {
    final remainingOuts = _customRemainingOuts;
    final remainingEr = _customRemainingEr;

    String? error;
    if (remainingOuts != null && remainingOuts < 0) error = '残り投球回は0以上にしてください';
    if (remainingEr != null && remainingEr < 0) error = '自責点は0以上にしてください';

    final totalOuts = (remainingOuts ?? 0) + currentOuts;
    final totalEr = (remainingEr ?? 0) + currentEr;
    final canCalc = remainingOuts != null && remainingEr != null && error == null && totalOuts > 0;
    final era = canCalc ? _eraFromErAndOuts(totalEr, totalOuts) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25)),
        const SizedBox(height: 10),

        Row(
          children: [
            const Text('残り投球回', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              height: 34,
              child: TextField(
                controller: _remainingIpController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) {
                  final o = _parseInningsToOuts(v);
                  setState(() {
                    _customRemainingOuts = (o != null && o >= 0) ? o : null;
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
        Row(
          children: [
            const Text('自責点', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              height: 34,
              child: TextField(
                controller: _remainingErController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  setState(() {
                    _customRemainingEr = (n != null && n >= 0) ? n : null;
                  });
                },
              ),
            ),
            const SizedBox(width: 6),
            const Text('点', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),

        const SizedBox(height: 10),
        if (error != null)
          Text(error, style: const TextStyle(fontSize: 12, color: Colors.redAccent, height: 1.25))
        else if (!canCalc)
          const Text('※ 残り投球回と自責点を入れると計算します',
              style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.25))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$resultLabel：${_formatEra(era!)}（自責$totalEr / ${_formatInningsFromOuts(totalOuts)}回）',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '現在：${_formatEra(_eraFromErAndOuts(currentEr, currentOuts))}（自責$currentEr / ${_formatInningsFromOuts(currentOuts)}回）',
                style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _loadCareerAvg() async {
    setState(() {
      _careerAvg = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats')
          .doc('results_stats_all')
          .get();

      if (!mounted) return;

      if (!doc.exists || doc.data() == null) {
        setState(() {
          _careerAvg = null;
        });
        return;
      }

      final data = doc.data()!;
      final avg = _extractBattingAverage(data);

      setState(() {
        _careerAvg = avg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _careerAvg = null;
      });
    }
  }

  Future<void> _loadCareerEra() async {
    setState(() {
      _careerEra = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats')
          .doc('results_stats_all')
          .get();

      if (!mounted) return;

      if (!doc.exists || doc.data() == null) {
        setState(() {
          _careerEra = null;
        });
        return;
      }

      final data = doc.data()!;
      final era = _extractEra(data);

      setState(() {
        _careerEra = era;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _careerEra = null;
      });
    }
  }

  Future<void> _loadPrevCompareMessage() async {
    setState(() {
      _isPrevCompareLoading = true;
      _prevCompareMessage = null;
    });

    try {
      final now = DateTime.now();
      final curYear = now.year;
      final curMonth = now.month;

      int prevYear = curYear;
      int prevMonth = curMonth - 1;
      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear = curYear - 1;
      }

      final statsCol = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('stats');

      final curId = 'results_stats_${curYear}_${curMonth}';
      final prevId = 'results_stats_${prevYear}_${prevMonth}';

      final curSnap = await statsCol.doc(curId).get();
      final prevSnap = await statsCol.doc(prevId).get();

      if (!mounted) return;

      // If there is no previous month data, do not show anything.
      if (!curSnap.exists || !prevSnap.exists) {
        setState(() {
          _prevCompareMessage = null;
          _isPrevCompareLoading = false;
        });
        return;
      }

      final curData = curSnap.data();
      final prevData = prevSnap.data();
      if (curData == null || prevData == null) {
        setState(() {
          _prevCompareMessage = null;
          _isPrevCompareLoading = false;
        });
        return;
      }

      final prevAvg = _extractBattingAverage(prevData);
if (prevAvg == null) {
  setState(() {
    _prevCompareMessage = null;
    _isPrevCompareLoading = false;
  });
  return;
}

// 今月データ（hits/ab）から“月末予測打率”を算出（_loadMonthProjection と同じ基準）
final hitsVal = curData['hits'] ?? curData['H'] ?? curData['hit'];
final abVal = curData['atBats'] ?? curData['atBat'] ?? curData['AB'] ?? curData['ab'];

if (hitsVal is! num || abVal is! num || abVal.toDouble() <= 0) {
  setState(() {
    _prevCompareMessage = null;
    _isPrevCompareLoading = false;
  });
  return;
}

final currentHits = hitsVal.toDouble();
final currentAB = abVal.toDouble();
final currentAvg = currentHits / currentAB;

// ここは「月末予測打率」なので projectedAvg を使う（現仕様では avg は同じだけど、判定の根拠をここに寄せる）
final projectedAvg = currentAvg;

final diff = projectedAvg - prevAvg;
      final label = _prevMonthLabel(prevYear: prevYear, prevMonth: prevMonth);

      String message;
      if (diff > 0.0005) {
        message =
            'このペースだと${label}の打率を超えそう！';
      } else if (diff < -0.0005) {
        message =
            '今のままだと${label}の打率に届かないかも';
      } else {
        message = '${label}と同じくらいのペース';
      }

      setState(() {
        _prevCompareMessage = message;
        _isPrevCompareLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prevCompareMessage = null;
        _isPrevCompareLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _loadMonthlyAverages();
    _loadYearlyAvg();
    _loadPrevCompareMessage();
    _loadPrevYearCompareMessage();
    _loadMonthProjection();
    _loadBeatPrevChallenge();
    _loadBeatPrevYearChallenge();
    _loadYearlySpots();
    _loadCareerAvg();
    if (_isPitcherUser) {
      _loadPitchingMonthlyEras();
      _loadPitchingYearlyEra();
      _loadPitchingPrevCompareMessage();
      _loadPitchingPrevYearCompareMessage();
      _loadPitchingMonthProjection();
      _loadPitchingYearlySpots();
      _loadBeatPrevEraChallenge();
      _loadBeatPrevYearEraChallenge();
      _loadCareerEra();
    }
  }

  bool _shouldShowInfoPanel(bool isBattingMode) {
    if (_graphMode == _GraphMode.month) {
      if (isBattingMode) {
        final hasCompare = (!_isPrevCompareLoading && _prevCompareMessage != null);
        final hasProjection = (!_isProjectionLoading && _projectedMonthAvg != null);
        final hasNoCompareCalc = (!_isBeatPrevChallengeLoading &&
            !_hasPrevMonthData &&
            _monthHitsForCalc != null &&
            _monthABForCalc != null);
        final hasChallenge = (!_isBeatPrevChallengeLoading &&
            _prevMonthAvgForChallenge != null &&
            _currentHitsForChallenge != null &&
            _currentABForChallenge != null &&
            _prevMonthLabelForChallenge != null);
        return hasCompare || hasProjection || hasNoCompareCalc || hasChallenge;
      }

      // pitching (month)
      final hasCompare = (!_isPitchPrevCompareLoading && _pitchPrevCompareMessage != null);
      final hasProjection = (!_isPitchProjectionLoading && _projectedMonthEra != null);
      final hasNoCompareCalc = (!_isBeatPrevEraChallengeLoading &&
          !_hasPrevMonthEraData &&
          _monthErForCalc != null &&
          _monthOutsForCalc != null);
      final hasChallenge = (!_isBeatPrevEraChallengeLoading &&
          _prevMonthEraForChallenge != null &&
          _currentErForChallenge != null &&
          _currentOutsForChallenge != null &&
          _prevMonthEraLabelForChallenge != null);
      return hasCompare || hasProjection || hasNoCompareCalc || hasChallenge;
    }

    // year
    if (isBattingMode) {
      final hasYearAvg = !_isYearlyLoading;
      final hasCompareMsg = (!_isPrevYearCompareLoading && _prevYearCompareMessage != null);
      final hasPrevYearAvg = _prevYearAvg != null;
      final hasNoCompareCalc = (!_isBeatPrevYearChallengeLoading &&
          !_hasPrevYearData &&
          _yearHitsForCalc != null &&
          _yearABForCalc != null);
      final hasChallenge = (!_isBeatPrevYearChallengeLoading &&
          _prevYearAvgForChallenge != null &&
          _currentYearHitsForChallenge != null &&
          _currentYearABForChallenge != null &&
          _prevYearLabelForChallenge != null);
      return hasYearAvg || hasCompareMsg || hasPrevYearAvg || hasNoCompareCalc || hasChallenge;
    }

    // pitching (year)
    final hasCompareMsg = (!_isPitchPrevYearCompareLoading && _pitchPrevYearCompareMessage != null);
    final hasPrevYearEra = _pitchPrevYearEra != null;
    final hasNoCompareCalc = (!_isBeatPrevYearEraChallengeLoading &&
        !_hasPrevYearEraData &&
        _yearErForCalcPitch != null &&
        _yearOutsForCalcPitch != null);
    final hasChallenge = (!_isBeatPrevYearEraChallengeLoading &&
        _prevYearEraForChallenge != null &&
        _currentYearErForChallenge != null &&
        _currentYearOutsForChallenge != null &&
        _prevYearEraLabelForChallenge != null);
    return hasCompareMsg || hasPrevYearEra || hasNoCompareCalc || hasChallenge;
  }

  @override
  Widget build(BuildContext context) {
    final bool isBattingMode = !_isPitcherUser || _statMode == _StatMode.batting;
    final bool showInfoPanel = _shouldShowInfoPanel(isBattingMode);
    return Scaffold(
      appBar: AppBar(
        title: const Text('予測・分析'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SegmentedButton<_GraphMode>(
                segments: const <ButtonSegment<_GraphMode>>[
                  ButtonSegment<_GraphMode>(
                    value: _GraphMode.month,
                    label: Text('月'),
                  ),
                  ButtonSegment<_GraphMode>(
                    value: _GraphMode.year,
                    label: Text('年'),
                  ),
                ],
                selected: <_GraphMode>{_graphMode},
                onSelectionChanged: (value) {
                  setState(() {
                    _graphMode = value.first;
                    // clear inputs when switching modes
                    _customRemainingAB = null;
                    _customRemainingHits = null;
                    _remainingAbController.text = '';
                    _remainingHitsController.text = '';
                    _customRemainingOuts = null;
                    _customRemainingEr = null;
                    _remainingIpController.text = '';
                    _remainingErController.text = '';
                  });
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_isPitcherUser) ...[
              const SizedBox(height: 6),
              Center(
                child: SegmentedButton<_StatMode>(
                  segments: const <ButtonSegment<_StatMode>>[
                    ButtonSegment<_StatMode>(
                      value: _StatMode.batting,
                      label: Text('打撃'),
                    ),
                    ButtonSegment<_StatMode>(
                      value: _StatMode.pitching,
                      label: Text('投手'),
                    ),
                  ],
                  selected: <_StatMode>{_statMode},
                  onSelectionChanged: (value) {
                    setState(() {
                      _statMode = value.first;
                      // clear inputs when switching modes
                      _customRemainingAB = null;
                      _customRemainingHits = null;
                      _remainingAbController.text = '';
                      _remainingHitsController.text = '';
                      _customRemainingOuts = null;
                      _customRemainingEr = null;
                      _remainingIpController.text = '';
                      _remainingErController.text = '';
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (showInfoPanel) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x22000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBattingMode) ...[
                      if (_graphMode == _GraphMode.month) ...[
                        // (keep existing month batting UI exactly)
                        if (!_isPrevCompareLoading && _prevCompareMessage != null) ...[
                          Text(
                            _prevCompareMessage!,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (!_isProjectionLoading && _projectedMonthAvg != null) ...[
                          Text(
                            'このペースでいくと月末予測打率：${_formatAvg(_projectedMonthAvg!)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          if (_projectionFormulaText != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _projectionFormulaText!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ],
                        if (!_isBeatPrevChallengeLoading && !_hasPrevMonthData && _monthHitsForCalc != null && _monthABForCalc != null) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          _buildNoCompareBattingCard(
                            title: '先月のデータがないので、計算だけできます',
                            subtitle: '残り打数と安打を入力すると、月末の打率を計算します',
                            currentHits: _monthHitsForCalc!,
                            currentAB: _monthABForCalc!,
                            resultLabel: '月末の打率',
                          ),
                        ],
                        // --- Challenge UI inserted here ---
                        if (!_isBeatPrevChallengeLoading &&
                            _prevMonthAvgForChallenge != null &&
                            _currentHitsForChallenge != null &&
                            _currentABForChallenge != null &&
                            _prevMonthLabelForChallenge != null) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Text(
                            _isBeatingPrevNow ? '先月超えキープ！' : '先月超えチャレンジ',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isBeatingPrevNow
                                ? '※ 残り打数と安打を入れると、月末の打率と先月超えの維持を判定します'
                                : '※ 残り打数を入れると「超えるのに必要な安打数」を計算します',
                            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('残り打数', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                height: 34,
                                child: TextField(
                                  controller: _remainingAbController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onChanged: (v) {
                                    final n = int.tryParse(v.trim());
                                    setState(() {
                                      _customRemainingAB = (n != null && n > 0) ? n : null;
                                      _customRemainingHits = null;
                                      _remainingHitsController.text = '';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('打', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final target = _prevMonthAvgForChallenge;
                              final ch = _currentHitsForChallenge;
                              final cab = _currentABForChallenge;
                              final lbl = _prevMonthLabelForChallenge;
                              final r = _customRemainingAB;

                              if (target == null || ch == null || cab == null || lbl == null) {
                                return const SizedBox.shrink();
                              }

                              if (r == null) {
                                return const Text(
                                  '※ 数字を入れると必要安打数を計算します',
                                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                                );
                              }

                              final need = _neededHitsToBeatAvg(
                                currentHits: ch,
                                currentAB: cab,
                                targetAvg: target,
                                remainingAB: r,
                              );

                              final ok = need <= r;

                              if (!_isBeatingPrevNow) {
                                if (!ok) {
                                  return Text(
                                    '残り$r打数だと、超えるには$r安打以上（厳しめ）',
                                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                                  );
                                }

                                final denom = cab + r;
                                final afterAvg = denom > 0 ? ((ch + need) / denom) : 0.0;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '残り$r打数なら、$need安打で${lbl}超え',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.3),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '達成時の打率：${_formatAvg(afterAvg)}（${ch + need}/$denom）',
                                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Text('安打', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 90,
                                        height: 34,
                                        child: TextField(
                                          controller: _remainingHitsController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onChanged: (v) {
                                            final n = int.tryParse(v.trim());
                                            setState(() {
                                              _customRemainingHits = (n != null && n >= 0) ? n : null;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('安打', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Builder(
                                    builder: (_) {
                                      final inputHits = _customRemainingHits;
                                      if (inputHits == null) {
                                        return const Text(
                                          '※ 安打を入れると、月末の打率と先月超えの維持を判定します',
                                          style: TextStyle(fontSize: 12, color: Colors.black54),
                                        );
                                      }

                                      final totalHits = ch + inputHits;
                                      final totalAB = cab + r;
                                      final avg = totalAB > 0 ? totalHits / totalAB : 0.0;
                                      final keep = avg - target > 0.0005;

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '月末の打率：${_formatAvg(avg)}（$totalHits/$totalAB）',
                                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            keep
                                                ? 'この入力なら、${lbl}超えをキープできそう！'
                                                : 'この入力だと、${lbl}超えをキープできないかも',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ] else ...[
                        // (keep existing year batting UI exactly)
                        if (!_isPrevYearCompareLoading && _prevYearCompareMessage != null) ...[
                          Text(
                            _prevYearCompareMessage!,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          '${DateTime.now().year}年の年間打率：${_formatAvg(_yearlyAvg)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        if (_prevYearAvg != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '去年（${DateTime.now().year - 1}年）の年間打率：${_formatAvg(_prevYearAvg!)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                          ),
                        ],
                        const SizedBox(height: 10),

                        if (!_isBeatPrevYearChallengeLoading && !_hasPrevYearData && _yearHitsForCalc != null && _yearABForCalc != null) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          _buildNoCompareBattingCard(
                            title: '去年のデータがないので、計算だけできます',
                            subtitle: '残り打数と安打を入力すると、年末の打率を計算します',
                            currentHits: _yearHitsForCalc!,
                            currentAB: _yearABForCalc!,
                            resultLabel: '年末の打率',
                          ),
                        ],
                        // --- Year challenge UI ---
                        if (!_isBeatPrevYearChallengeLoading &&
                            _prevYearAvgForChallenge != null &&
                            _currentYearHitsForChallenge != null &&
                            _currentYearABForChallenge != null &&
                            _prevYearLabelForChallenge != null) ...[
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Text(
                            _isBeatingPrevYearNow ? '去年超えキープ！' : '去年超えチャレンジ',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isBeatingPrevYearNow
                                ? '※ 残り打数と安打を入れると、年末の打率と去年超えの維持を判定します'
                                : '※ 残り打数を入れると「超えるのに必要な安打数」を計算します',
                            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('残り打数', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                height: 34,
                                child: TextField(
                                  controller: _remainingAbController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onChanged: (v) {
                                    final n = int.tryParse(v.trim());
                                    setState(() {
                                      _customRemainingAB = (n != null && n > 0) ? n : null;
                                      _customRemainingHits = null;
                                      _remainingHitsController.text = '';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('打', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final target = _prevYearAvgForChallenge;
                              final ch = _currentYearHitsForChallenge;
                              final cab = _currentYearABForChallenge;
                              final lbl = _prevYearLabelForChallenge;
                              final r = _customRemainingAB;

                              if (target == null || ch == null || cab == null || lbl == null) {
                                return const SizedBox.shrink();
                              }

                              if (r == null) {
                                return const Text(
                                  '※ 数字を入れると必要安打数を計算します',
                                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                                );
                              }

                              final need = _neededHitsToBeatAvg(
                                currentHits: ch,
                                currentAB: cab,
                                targetAvg: target,
                                remainingAB: r,
                              );

                              final ok = need <= r;

                              if (!_isBeatingPrevYearNow) {
                                if (!ok) {
                                  return Text(
                                    '残り$r打数だと、超えるには$r安打以上（厳しめ）',
                                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                                  );
                                }

                                final denom = cab + r;
                                final afterAvg = denom > 0 ? ((ch + need) / denom) : 0.0;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '残り$r打数なら、$need安打で${lbl}超え',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.3),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '達成時の打率：${_formatAvg(afterAvg)}（${ch + need}/$denom）',
                                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Text('安打', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 90,
                                        height: 34,
                                        child: TextField(
                                          controller: _remainingHitsController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onChanged: (v) {
                                            final n = int.tryParse(v.trim());
                                            setState(() {
                                              _customRemainingHits = (n != null && n >= 0) ? n : null;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('安打', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Builder(
                                    builder: (_) {
                                      final inputHits = _customRemainingHits;
                                      if (inputHits == null) {
                                        return const Text(
                                          '※ 安打を入れると、年末の打率と去年超えの維持を判定します',
                                          style: TextStyle(fontSize: 12, color: Colors.black54),
                                        );
                                      }

                                      final totalHits = ch + inputHits;
                                      final totalAB = cab + r;
                                      final avg = totalAB > 0 ? totalHits / totalAB : 0.0;
                                      final keep = avg - target > 0.0005;

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '年末の打率：${_formatAvg(avg)}（$totalHits/$totalAB）',
                                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            keep
                                                ? 'この入力なら、${lbl}超えをキープできそう！'
                                                : 'この入力だと、${lbl}超えをキープできないかも',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                        // --- end Year challenge UI ---

                        const SizedBox(height: 6),
                        const Text(
                          '※ 年モードでは、前年との比較を表示します',
                          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                        ),
                      ],
                    ] else ...[
                      if (_graphMode == _GraphMode.month) ...[
                        if (!_isPitchPrevCompareLoading && _pitchPrevCompareMessage != null) ...[
                          Text(
                            _pitchPrevCompareMessage!,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (!_isPitchProjectionLoading && _projectedMonthEra != null) ...[
                          Text(
                            'このペースでいくと月末予測防御率：${_formatEra(_projectedMonthEra!)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          if (_pitchProjectionFormulaText != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _pitchProjectionFormulaText!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ],
                        if (!_isBeatPrevEraChallengeLoading &&
                            !_hasPrevMonthEraData &&
                            _monthErForCalc != null &&
                            _monthOutsForCalc != null) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          _buildNoComparePitchingCard(
                            title: '先月のデータがないので、計算だけできます',
                            subtitle: '残り投球回と自責点を入力すると、月末の防御率を計算します',
                            currentEr: _monthErForCalc!,
                            currentOuts: _monthOutsForCalc!,
                            resultLabel: '月末の防御率',
                          ),
                        ],
                        // --- Challenge UI for pitching month goes here (unchanged) ---
                        if (!_isBeatPrevEraChallengeLoading &&
                            _prevMonthEraForChallenge != null &&
                            _currentErForChallenge != null &&
                            _currentOutsForChallenge != null &&
                            _prevMonthEraLabelForChallenge != null) ...[
                          // Existing challenge UI for pitching month...
                          // (leave unchanged)
                        ],
                      ] else ...[
                        if (!_isPitchPrevYearCompareLoading && _pitchPrevYearCompareMessage != null) ...[
                          Text(
                            _pitchPrevYearCompareMessage!,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (_pitchPrevYearEra != null) ...[
                          Text(
                            '去年（${DateTime.now().year - 1}年）の年間防御率：${_formatEra(_pitchPrevYearEra!)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (!_isBeatPrevYearEraChallengeLoading &&
                            !_hasPrevYearEraData &&
                            _yearErForCalcPitch != null &&
                            _yearOutsForCalcPitch != null) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          _buildNoComparePitchingCard(
                            title: '去年のデータがないので、計算だけできます',
                            subtitle: '残り投球回と自責点を入力すると、年末の防御率を計算します',
                            currentEr: _yearErForCalcPitch!,
                            currentOuts: _yearOutsForCalcPitch!,
                            resultLabel: '年末の防御率',
                          ),
                        ],
                        // --- Challenge UI for pitching year goes here (unchanged) ---
                        if (!_isBeatPrevYearEraChallengeLoading &&
                            _prevYearEraForChallenge != null &&
                            _currentYearErForChallenge != null &&
                            _currentYearOutsForChallenge != null &&
                            _prevYearEraLabelForChallenge != null) ...[
                          // Existing challenge UI for pitching year...
                          // (leave unchanged)
                        ],
                      ],
                      if (_graphMode == _GraphMode.month) ...[

                        if (!_isPitchProjectionLoading && _projectedMonthEra == null && _pitchProjectionFormulaText != null) ...[
                          Text(
                            '計算',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _pitchProjectionFormulaText!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.25,
                            ),
                          ),
                        ],
                        if (!_isBeatPrevEraChallengeLoading &&
                            _prevMonthEraForChallenge != null &&
                            _currentErForChallenge != null &&
                            _currentOutsForChallenge != null &&
                            _prevMonthEraLabelForChallenge != null) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Text(
                            _isBeatingPrevEraNow ? '先月より防御率を下げキープ！' : '先月より防御率を下げられるかチャレンジ',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isBeatingPrevEraNow
                                ? '※ 残り投球回と自責点を入れると、月末の防御率と先月より良い防御率の維持を判定します'
                                : '※ 残り投球回を入れると「先月より良くするために許される自責点」を計算します',
                            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('残り投球回', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                height: 34,
                                child: TextField(
                                  controller: _remainingIpController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onChanged: (v) {
                                     final outs = _parseInningsToOuts(v);
                                    setState(() {
                                     _customRemainingOuts = outs;
                                      _customRemainingEr = null;
                                      _remainingErController.text = '';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('回', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (_) {
                              final target = _prevMonthEraForChallenge;
                              final curEr = _currentErForChallenge;
                              final curOuts = _currentOutsForChallenge;
                              final lbl = _prevMonthEraLabelForChallenge;
                              final rOuts = _customRemainingOuts;
                              final rIpText = (rOuts != null) ? _formatInningsFromOuts(rOuts) : null;

                              if (target == null || curEr == null || curOuts == null || lbl == null) {
                                return const SizedBox.shrink();
                              }
                              if (rOuts == null || rIpText == null) {
                                return const Text(
                                  '※ 数字を入れると判定します',
                                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                                );
                              }

                              if (!_isBeatingPrevEraNow) {
                                final maxEr = _maxAllowedErToBeatEra(
                                  currentEr: curEr,
                                  currentOuts: curOuts,
                                  targetEra: target,
                                  remainingOuts: rOuts,
                                );

                                if (maxEr < 0) {
                                  return Text(
                                    '残り${rIpText}回だと、先月より防御率を下げるのは厳しめ',
                                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                                  );
                                }

                                final totalEr = curEr + maxEr;
                                final totalOuts = curOuts + rOuts;
                                final afterEra = _eraFromErAndOuts(totalEr, totalOuts);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '残り${rIpText}回なら、自責点$maxEr以内で${lbl}より防御率を下げられる',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.3),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '達成時の防御率：${_formatEra(afterEra)}（ER=$totalEr / IP=${_formatInningsFromOuts(totalOuts)}）',
                                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Text('自責点', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 90,
                                        height: 34,
                                        child: TextField(
                                          controller: _remainingErController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onChanged: (v) {
                                            final n = int.tryParse(v.trim());
                                            setState(() {
                                              _customRemainingEr = (n != null && n >= 0) ? n : null;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('点', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Builder(
                                    builder: (_) {
                                      final inputEr = _customRemainingEr;
                                      if (inputEr == null) {
                                        return const Text(
                                          '※ 自責点を入れると、月末の防御率と先月より良い防御率の維持を判定します',
                                          style: TextStyle(fontSize: 12, color: Colors.black54),
                                        );
                                      }

                                      final totalEr = curEr + inputEr;
                                      final totalOuts = curOuts + rOuts;
                                      final era = _eraFromErAndOuts(totalEr, totalOuts);
                                      final keep = (era - target) < -0.01;

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '月末の防御率：${_formatEra(era)}（ER=$totalEr / IP=${_formatInningsFromOuts(totalOuts)}）',
                                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            keep
                                                ? 'この入力なら、${lbl}より良い防御率をキープできそう！'
                                                : 'この入力だと、${lbl}より良い防御率をキープできないかも',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ] else ...[
                        // Text(
                        //   '${DateTime.now().year}年の年間防御率：${_formatEra(_yearlyEra)}',
                        //   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        // ),
                        // if (_pitchPrevYearEra != null) ...[
                        //   const SizedBox(height: 4),
                        //   Text(
                        //     '去年（${DateTime.now().year - 1}年）の年間防御率：${_formatEra(_pitchPrevYearEra!)}',
                        //     style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                        //   ),
                        // ],
                        if (!_isBeatPrevYearEraChallengeLoading &&
                            _prevYearEraForChallenge != null &&
                            _currentYearErForChallenge != null &&
                            _currentYearOutsForChallenge != null &&
                            _prevYearEraLabelForChallenge != null) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Text(
                            _isBeatingPrevYearEraNow ? '去年より防御率を下げキープ！' : '去年より防御率を下げられるかチャレンジ',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isBeatingPrevYearEraNow
                                ? '※ 残り投球回と自責点を入れると、年末の防御率と去年より良い防御率の維持を判定します'
                                : '※ 残り投球回を入れると「去年より良くするために許される自責点」を計算します',
                            style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('残り投球回', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                height: 34,
                                child: TextField(
                                  controller: _remainingIpController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onChanged: (v) {
                                    final outs = _parseInningsToOuts(v);
                                    setState(() {
                                     _customRemainingOuts = outs;
                                      _customRemainingEr = null;
                                      _remainingErController.text = '';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('回', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (_) {
                              final target = _prevYearEraForChallenge;
                              final curEr = _currentYearErForChallenge;
                              final curOuts = _currentYearOutsForChallenge;
                              final lbl = _prevYearEraLabelForChallenge;
                              final rOuts = _customRemainingOuts;
                              final rIpText = (rOuts != null) ? _formatInningsFromOuts(rOuts) : null;

                              if (target == null || curEr == null || curOuts == null || lbl == null) {
                                return const SizedBox.shrink();
                              }
                              if (rOuts == null || rIpText == null) {
                                return const Text(
                                  '※ 数字を入れると判定します',
                                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                                );
                              }

                              if (!_isBeatingPrevYearEraNow) {
                                final maxEr = _maxAllowedErToBeatEra(
                                  currentEr: curEr,
                                  currentOuts: curOuts,
                                  targetEra: target,
                                  remainingOuts: rOuts,
                                );

                                if (maxEr < 0) {
                                  return Text(
                                    '残り${rIpText}回だと、去年より防御率を下げるのは厳しめ',
                                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                                  );
                                }

                                final totalEr = curEr + maxEr;
                                final totalOuts = curOuts + rOuts;
                                final afterEra = _eraFromErAndOuts(totalEr, totalOuts);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '残り${rIpText}回なら、自責点$maxEr以内で${lbl}より防御率を下げられる',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.3),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '達成時の防御率：${_formatEra(afterEra)}（ER=$totalEr / IP=${_formatInningsFromOuts(totalOuts)}）',
                                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Text('自責点', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 90,
                                        height: 34,
                                        child: TextField(
                                          controller: _remainingErController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onChanged: (v) {
                                            final n = int.tryParse(v.trim());
                                            setState(() {
                                              _customRemainingEr = (n != null && n >= 0) ? n : null;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('点', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Builder(
                                    builder: (_) {
                                      final inputEr = _customRemainingEr;
                                      if (inputEr == null) {
                                        return const Text(
                                          '※自責点を入れると、年末の防御率と去年より良い防御率の維持を判定します',
                                          style: TextStyle(fontSize: 12, color: Colors.black54),
                                        );
                                      }

                                      final totalEr = curEr + inputEr;
                                      final totalOuts = curOuts + rOuts;
                                      final era = _eraFromErAndOuts(totalEr, totalOuts);
                                      final keep = (era - target) < -0.01;

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '年末の防御率：${_formatEra(era)}（ER=$totalEr / IP=${_formatInningsFromOuts(totalOuts)}）',
                                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            keep
                                                ? 'この入力なら、${lbl}より良い防御率をキープできそう！'
                                                : 'この入力だと、${lbl}より良い防御率をキープできないかも',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 6),
                        const Text(
                          '※ 年モードでは、前年との比較を表示します',
                          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.25),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (isBattingMode) ...[
              _SectionTitle('推移グラフ'),
              const SizedBox(height: 6),
              if (_isYearlyLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    (_graphMode == _GraphMode.year)
                    ? '通算打率: ${_formatAvg(_careerAvg ?? _yearlyAvg)}'
                    : '年間打率: ${_formatAvg(_yearlyAvg)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              SizedBox(
                height: 330,
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 240,
                        child: ((_graphMode == _GraphMode.year) ? _isYearlySpotsLoading : _isMonthlyLoading)
                            ? const Center(child: CircularProgressIndicator())
                            : (((_graphMode == _GraphMode.year) ? _yearlySpots.isEmpty : _monthlySpots.isEmpty)
                                ? Center(
                                    child: Text(
                                      (_graphMode == _GraphMode.year) ? '年別データがありません' : '月別データがありません',
                                      style: const TextStyle(color: Colors.black54),
                                    ),
                                  )
                                : LineChart(
                                    LineChartData(
                                      minY: 0,
                                      maxY: _maxYForAvg((_graphMode == _GraphMode.year) ? _yearlySpots : _monthlySpots),
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        horizontalInterval: 0.1,
                                      ),
                                      titlesData: FlTitlesData(
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            interval: 0.1,
                                            getTitlesWidget: (value, meta) {
                                              return Text(
                                                _formatAvg(value),
                                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                                              );
                                            },
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 28,
                                            interval: 1,
                                            getTitlesWidget: (value, meta) {
                                              if (_graphMode == _GraphMode.year) {
                                                final y = value.toInt();
                                                return Text(
                                                  '$y',
                                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                                );
                                              } else {
                                                final m = value.toInt();
                                                if (m < 1 || m > 12) return const SizedBox.shrink();
                                                return Text(
                                                  '${m}月',
                                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      lineTouchData: LineTouchData(
                                        enabled: true,
                                        touchTooltipData: LineTouchTooltipData(
                                          tooltipRoundedRadius: 10,
                                          getTooltipItems: (touchedSpots) {
                                            return touchedSpots.map((s) {
                                              final label = (_graphMode == _GraphMode.year)
                                                  ? '${s.x.toInt()}年'
                                                  : '${s.x.toInt()}月';
                                              return LineTooltipItem(
                                                '$label  ${_formatAvg(s.y)}',
                                                const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              );
                                            }).toList();
                                          },
                                        ),
                                      ),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: (_graphMode == _GraphMode.year) ? _yearlySpots : _monthlySpots,
                                          isCurved: false,
                                          barWidth: 3,
                                          color: Colors.blue,
                                          dotData: FlDotData(
                                            show: true,
                                            getDotPainter: (spot, percent, barData, index) {
                                              final maxY = _maxSpotY((_graphMode == _GraphMode.year) ? _yearlySpots : _monthlySpots);
                                              final isMax = (spot.y - maxY).abs() < 0.0000001;

                                              if (isMax) {
                                                return const _StarDotPainter(
                                                  radius: 7,
                                                  color: Colors.amber,
                                                  strokeColor: Colors.white,
                                                  strokeWidth: 2,
                                                );
                                              }

                                              return FlDotCirclePainter(
                                                radius: 4,
                                                color: Colors.blue,
                                                strokeWidth: 2,
                                                strokeColor: Colors.white,
                                              );
                                            },
                                          ),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: Colors.blue.withOpacity(0.08),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (_graphMode == _GraphMode.year)
                            ? '横軸：年　縦軸：打率（.000）'
                            : '横軸：月　縦軸：打率（.000）',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _SectionTitle('推移グラフ'),
              const SizedBox(height: 6),
              if (_isYearlyEraLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    (_graphMode == _GraphMode.year)
                        ? '通算防御率: ${_formatEra(_careerEra ?? _yearlyEra)}'
                        : '年間防御率: ${_formatEra(_yearlyEra)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              SizedBox(
                height: 330,
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 240,
                        child: ((_graphMode == _GraphMode.year) ? _isYearlyEraSpotsLoading : _isMonthlyEraLoading)
                            ? const Center(child: CircularProgressIndicator())
                            : (((_graphMode == _GraphMode.year) ? _yearlyEraSpots.isEmpty : _monthlyEraSpots.isEmpty)
                                ? Center(
                                    child: Text(
                                      (_graphMode == _GraphMode.year) ? '年別データがありません' : '月別データがありません',
                                      style: const TextStyle(color: Colors.black54),
                                    ),
                                  )
                                : LineChart(
                                    LineChartData(
                                      minY: 0,
                                      maxY: _maxYForEra((_graphMode == _GraphMode.year) ? _yearlyEraSpots : _monthlyEraSpots),
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        horizontalInterval: 1,
                                      ),
                                      titlesData: FlTitlesData(
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 44,
                                            interval: 1,
                                            getTitlesWidget: (value, meta) {
                                              return Text(
                                                _formatEra(value),
                                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                                              );
                                            },
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 28,
                                            interval: 1,
                                            getTitlesWidget: (value, meta) {
                                              if (_graphMode == _GraphMode.year) {
                                                final y = value.toInt();
                                                return Text(
                                                  '$y',
                                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                                );
                                              } else {
                                                final m = value.toInt();
                                                if (m < 1 || m > 12) return const SizedBox.shrink();
                                                return Text(
                                                  '${m}月',
                                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      lineTouchData: LineTouchData(
                                        enabled: true,
                                        touchTooltipData: LineTouchTooltipData(
                                          tooltipRoundedRadius: 10,
                                          getTooltipItems: (touchedSpots) {
                                            return touchedSpots.map((s) {
                                              final label = (_graphMode == _GraphMode.year)
                                                  ? '${s.x.toInt()}年'
                                                  : '${s.x.toInt()}月';
                                              return LineTooltipItem(
                                                '$label  ${_formatEra(s.y)}',
                                                const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              );
                                            }).toList();
                                          },
                                        ),
                                      ),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: (_graphMode == _GraphMode.year) ? _yearlyEraSpots : _monthlyEraSpots,
                                          isCurved: false,
                                          barWidth: 3,
                                          color: Colors.blue,
                                          dotData: FlDotData(
                                            show: true,
                                          ),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: Colors.blue.withOpacity(0.08),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (_graphMode == _GraphMode.year)
                            ? '横軸：年　縦軸：防御率（ERA）'
                            : '横軸：月　縦軸：防御率（ERA）',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: 44,
                color: Colors.grey[100],
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: const Text(
                        '完了',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _StarDotPainter extends FlDotPainter {
  final double radius;
  final Color color;
  final Color strokeColor;
  final double strokeWidth;

  const _StarDotPainter({
    this.radius = 6,
    required this.color,
    this.strokeColor = Colors.white,
    this.strokeWidth = 2,
  });

  @override
  Color get mainColor => color;

  @override
  List<Object?> get props => [radius, color, strokeColor, strokeWidth];

  @override
  Size getSize(FlSpot spot) => Size(radius * 2, radius * 2);

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    final center = offsetInCanvas;

    // 5-point star
    final outerR = radius;
    final innerR = radius * 0.45;
    final path = Path();

    for (int i = 0; i < 10; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? outerR : innerR;
      final angle = -math.pi / 2 + (math.pi / 5) * i;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    if (a is _StarDotPainter && b is _StarDotPainter) {
      return _StarDotPainter(
        radius: a.radius + (b.radius - a.radius) * t,
        color: Color.lerp(a.color, b.color, t) ?? b.color,
        strokeColor: Color.lerp(a.strokeColor, b.strokeColor, t) ?? b.strokeColor,
        strokeWidth: a.strokeWidth + (b.strokeWidth - a.strokeWidth) * t,
      );
    }
    // Fallback: return whichever is closer.
    return t < 0.5 ? a : b;
  }

}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x11000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

enum _StatMode { batting, pitching }
enum _GraphMode { month, year }