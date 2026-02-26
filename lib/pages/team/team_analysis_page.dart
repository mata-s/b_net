import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class TeamAnalysisPage extends StatelessWidget {
  final String teamId;

  const TeamAnalysisPage({
    super.key,
    required this.teamId,
  });

  int _currentSeasonYear() => DateTime.now().year;

  num? _numOrNull(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  num? _extractTotal(Map<String, dynamic> data) {
    // 1) provisional.total を優先
    final prov = data['provisional'];
    if (prov is Map<String, dynamic>) {
      final t = _numOrNull(prov['total']);
      if (t != null) return t;

      // 2) もし total が無い場合は batting/pitching/fielding の合計を試みる
      final bat = _numOrNull(prov['batting']);
      final pit = _numOrNull(prov['pitching']);
      final fld = _numOrNull(prov['fielding']);
      if (bat != null || pit != null || fld != null) {
        return (bat ?? 0) + (pit ?? 0) + (fld ?? 0);
      }
    }

    // 3) 旧/別形式の total
    final direct = _numOrNull(data['total']);
    if (direct != null) return direct;

    return null;
  }

  String _rankLabel(num? v) {
    if (v == null) return '-';
    final d = v.toDouble();
    if (d >= 85) return 'S';
    if (d >= 70) return 'A';
    if (d >= 55) return 'B';
    if (d >= 40) return 'C';
    return 'D';
  }

String _autoComment(num? bat, num? pit, num? fld) {
  final b = (bat ?? 0).toDouble();
  final p = (pit ?? 0).toDouble();
  final f = (fld ?? 0).toDouble();

  if (b == 0 && p == 0 && f == 0) {
    return 'まだデータが少ないため分析できません';
  }

  // ===== 総合評価 =====
  final avg = (b + p + f) / 3.0;

  String overall;
  if (avg >= 85) {
    overall = '総合的にはトップクラスのチームです。';
  } else if (avg >= 70) {
    overall = '総合的にかなり力のあるチームです。';
  } else if (avg >= 55) {
    overall = '総合的には平均以上のチームです。';
  } else if (avg >= 40) {
    overall = '総合的には平均前後で、伸ばせる余地がまだ多くあります。';
  } else {
    overall = '現状では課題が多く、これからの伸びに期待できるチームです。';
  }

  // ===== 強み判定（70点以上を強み扱い） =====
  final strengths = <String>[];
  if (b >= 70) strengths.add('打撃');
  if (p >= 70) strengths.add('投手');
  if (f >= 70) strengths.add('守備');

  String strengthText;
  if (strengths.length == 3) {
    strengthText = '打撃・投手・守備すべてが高水準です。';
  } else if (strengths.length == 2) {
    strengthText = '${strengths[0]}と${strengths[1]}が大きな強みです。';
  } else if (strengths.length == 1) {
    strengthText = '${strengths[0]}がチームの武器になっています。';
  } else {
    strengthText = '突出した強みはこれから作っていけそうです。';
  }

  // ===== 課題判定（40点未満なら課題） =====
  final weaknesses = <String>[];
  if (b < 40) weaknesses.add('打撃');
  if (p < 40) weaknesses.add('投手');
  if (f < 40) weaknesses.add('守備');

  String weaknessText = '';
  if (weaknesses.isNotEmpty) {
    weaknessText =
        '一方で${weaknesses.join('・')}にはまだ課題があり、ここを伸ばせるとさらに強くなれそうです。';
  }

  return [
    overall,
    strengthText,
    if (weaknessText.isNotEmpty) weaknessText,
  ].join('\n');
}
  Widget _scoreCard({
    required String title,
    required AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap,
  }) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!snap.hasData || !snap.data!.exists) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withOpacity(0.18)),
        ),
        child: Text(
          '$title: データがありません',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    final data = snap.data!.data() ?? <String, dynamic>{};

    final prov = (data['provisional'] is Map)
        ? Map<String, dynamic>.from(data['provisional'] as Map)
        : <String, dynamic>{};

    final total = _extractTotal(data);
    final bat = _numOrNull(prov['batting']);
    final pit = _numOrNull(prov['pitching']);
    final fld = _numOrNull(prov['fielding']);

    String fmtWithRank(num? v) {
      if (v == null) return '-';
      return '${v.toStringAsFixed(1)} (${_rankLabel(v)})';
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.auto_graph, size: 18),
              const SizedBox(width: 8),
              Text(
                '総合: ${fmtWithRank(total)} / 100',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _miniChip('打撃', fmtWithRank(bat)),
              _miniChip('投手', fmtWithRank(pit)),
              _miniChip('守備', fmtWithRank(fld)),
            ],
          ),
          const SizedBox(height: 12),
          _RadarChart(
            batting: bat ?? 0,
            pitching: pit ?? 0,
            fielding: fld ?? 0,
            maxValue: 100,
          ),
          const SizedBox(height: 10),
          Text(
            _autoComment(bat, pit, fld),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '参照: $title',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _miniChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seasonYear = _currentSeasonYear();

    final yearRef = FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .collection('powerScores')
        .doc(seasonYear.toString())
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );

    final allRef = FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .collection('powerScores')
        .doc('all')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('分析'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const Text(
            'チームのスコア',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '（打撃 / 投手 / 守備 の暫定スコア）',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: yearRef.get(),
            builder: (context, snap) {
              return _scoreCard(
                title: '$seasonYear年',
                snap: snap,
              );
            },
          ),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: allRef.get(),
            builder: (context, snap) {
              return _scoreCard(
                title: '通算',
                snap: snap,
              );
            },
          ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withOpacity(0.18)),
          ),
        child: Text(
            '''※スコアの考え方
・打撃：出塁＋長打の合計（OPS）をもとに「どれだけ打てているか」を 0〜100 点でスコア化しています。試合数が少ないうちは、点数が出すぎないよう少し控えめにしています。
・投手：防御率（ERA／自責点の少なさ）から「どれだけ失点を防げているか」を 0〜100 点にしています。投球回が少ないうちは、こちらも点数を抑えめにしています。
・守備：1 試合あたりのエラーの少なさと守備率から「どれだけ安定して守れているか」を 0〜100 点にしています。試合数が増えるほど、より本来の力に近いスコアになります。
・総合：打撃・投手・守備の 3 つをまとめた、チーム全体のバランススコアです。

※シーズン序盤などデータが少ない時期は、たまたまの好不調で数字が暴れすぎないよう、自動で「控えめ補正」がかかるようになっています。
''',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
              height: 1.35,
            ),
          ),
        ),
        ],
      ),
    );
  }
}


class _RadarChart extends StatelessWidget {
  final num batting;
  final num pitching;
  final num fielding;
  final double maxValue;

  const _RadarChart({
    required this.batting,
    required this.pitching,
    required this.fielding,
    this.maxValue = 100,
  });

  double _clamp01(num v) {
    final d = v.toDouble();
    if (maxValue <= 0) return 0;
    final t = d / maxValue;
    if (t.isNaN || t.isInfinite) return 0;
    return t.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // 3軸（打撃/投手/守備）
    final values = <double>[
      _clamp01(batting),
      _clamp01(pitching),
      _clamp01(fielding),
    ];

    return AspectRatio(
      aspectRatio: 1.25,
      child: CustomPaint(
        painter: _RadarChartPainter(
          values: values,
          labels: const ['打撃', '投手', '守備'],
          levels: 5,
        ),
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<double> values; // 0..1
  final List<String> labels;
  final int levels;

  _RadarChartPainter({
    required this.values,
    required this.labels,
    this.levels = 5,
  }) : assert(values.length == 3),
       assert(labels.length == 3);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) * 0.72;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withOpacity(0.08);

    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withOpacity(0.12);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue.withOpacity(0.18);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.blue.withOpacity(0.55);

    // 3軸なので 120度ずつ
    const startAngle = -math.pi / 2; // 上から開始
    final angles = List<double>.generate(3, (i) => startAngle + (2 * math.pi / 3) * i);

    // グリッド（同心三角形）
    for (int l = 1; l <= levels; l++) {
      final t = l / levels;
      final path = Path();
      for (int i = 0; i < 3; i++) {
        final p = center + Offset(math.cos(angles[i]), math.sin(angles[i])) * (radius * t);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 軸線
    for (int i = 0; i < 3; i++) {
      final p = center + Offset(math.cos(angles[i]), math.sin(angles[i])) * radius;
      canvas.drawLine(center, p, axisPaint);
    }

    // 値のポリゴン
    final valuePath = Path();
    for (int i = 0; i < 3; i++) {
      final t = values[i].clamp(0.0, 1.0);
      final p = center + Offset(math.cos(angles[i]), math.sin(angles[i])) * (radius * t);
      if (i == 0) {
        valuePath.moveTo(p.dx, p.dy);
      } else {
        valuePath.lineTo(p.dx, p.dy);
      }
    }
    valuePath.close();
    canvas.drawPath(valuePath, fillPaint);
    canvas.drawPath(valuePath, linePaint);

    // ラベル
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: Colors.black.withOpacity(0.65),
    );

    for (int i = 0; i < 3; i++) {
      final labelPos = center + Offset(math.cos(angles[i]), math.sin(angles[i])) * (radius + 14);
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      // 簡易センタリング
      final offset = Offset(labelPos.dx - tp.width / 2, labelPos.dy - tp.height / 2);
      tp.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.labels != labels || oldDelegate.levels != levels;
  }
}
