import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// Cloud Functionsのインポート
import 'batting_average_ranking.dart'; // Cloud Functionのファイルのパスに置き換えてください

void main() {
  late MockFirestore firestore; // MockFirestoreInstanceを使います

  setUp(() {
    // テスト用のFirestoreを初期化
    firestore = MockFirestoreInstance();
  });

  test('createBattingAverageRanking should run on schedule on November 1', () {
    FakeAsync().run((fakeAsync) async {
      // 現在の日付が10月1日だと仮定して、11月1日までの時間を進める
      final DateTime currentDate = DateTime(2024, 10, 1); // 10月1日と仮定
      final DateTime targetDate = DateTime(2024, 11, 1); // 11月1日が目標の日付
      final Duration durationToAdvance = targetDate.difference(currentDate);

      // Cloud Functionを呼び出して、MockFirestoreを渡します
      await createBattingAverageRanking(firestore); // ここでFirestoreインスタンスを渡す

      // 時間を進めてスケジュール実行をシミュレート
      fakeAsync.elapse(durationToAdvance);

      // Firestoreからデータを取得して、関数が実行されたかを確認
      final snapshot = await firestore
          .collection('battingAverageRanking/2024_11_prefecture')
          .get();

      // Firestore内にランキングデータが存在するかどうかのチェック
      expect(snapshot.docs.isNotEmpty, true); // ドキュメントが作成されていることを確認
    });
  });
}
