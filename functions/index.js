import {initializeApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as functions from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import {onCall} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {CloudTasksClient} from "@google-cloud/tasks";

initializeApp();
const db = getFirestore();
const client = new CloudTasksClient();
const messaging = getMessaging();

const project =
  process.env.GCLOUD_PROJECT ||
  (functions.config().gcp && functions.config().gcp.project) ||
  "b-net-9bdc2";
const location = "asia-northeast1";

/**
 * HTTP経由でゲームデータをFirestoreに追加する関数（v2）
 */
export const addGameData = onCall(async (request) => {
  const data = request.data;
  console.log("Received data:", data); // 追加した部分
  const {
    uid,
    matchIndex,
    gameDate,
    gameType,
    location,
    opponent,
    steals,
    rbis,
    runs,
    memo,
    inningsThrow,
    strikeouts,
    walks,
    hitByPitch,
    earnedRuns,
    runsAllowed,
    hitsAllowed,
    resultGame,
    outFraction,
    putouts,
    assists,
    errors,
    atBats,
    isCompleteGame,
    isShutoutGame,
    isSave,
    isHold,
    appearanceType,
    battersFaced,
    positions,
    caughtStealingByRunner,
    caughtStealing,
    stolenBaseAttempts,
    stealsAttempts,
    homeRunsAllowed,
    pitchCount,
  } = data;

  if (!uid || typeof uid !== "string") {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "UID is required and must be a string.",
    );
  }

  if (!gameDate) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Game date is required.",
    );
  }

  // const gameDateUTC = new Date(gameDate);
  const gameDateObj = new Date(gameDate);
  const isPitcher = Array.isArray(positions) && positions.includes("投手");
  const gameDateUTC = new Date(Date.UTC(gameDateObj.getFullYear(), gameDateObj
      .getMonth(), gameDateObj.getDate(), 0, 0, 0));
  const gameDateTimestamp = Timestamp.fromDate(gameDateUTC);
  const gameData = {
    uid: uid,
    matchIndex: matchIndex || 0,
    gameDate: gameDateTimestamp,
    gameType: gameType || "",
    location: location || "",
    opponent: opponent || "",
    steals: steals || 0,
    rbis: rbis || 0,
    runs: runs || 0,
    memo: memo || "",
    resultGame: resultGame || "",
    outFraction: outFraction || "",
    putouts: putouts || 0,
    assists: assists || 0,
    errors: errors || 0,
    atBats: atBats || [],
    caughtStealingByRunner: caughtStealingByRunner || 0,
    stealsAttempts: stealsAttempts || 0,
  };


  if (isPitcher) {
    Object.assign(gameData, {
      inningsThrow: inningsThrow || 0,
      strikeouts: strikeouts || 0,
      walks: walks || 0,
      hitByPitch: hitByPitch || 0,
      earnedRuns: earnedRuns || 0,
      runsAllowed: runsAllowed || 0,
      hitsAllowed: hitsAllowed || 0,
      isCompleteGame: isCompleteGame || false,
      isShutoutGame: isShutoutGame || false,
      isSave: isSave || false,
      isHold: isHold || false,
      appearanceType: appearanceType || "",
      battersFaced: battersFaced || 0,
      homeRunsAllowed: homeRunsAllowed || 0,
      pitchCount: pitchCount || 0,
    });
  }

  const isCatcher = Array.isArray(positions) && positions.includes("捕手");
  if (isCatcher) {
    Object.assign(gameData, {
      caughtStealing: caughtStealing || 0,
      stolenBaseAttempts: stolenBaseAttempts || 0,
    });
  }

  try {
    await db.collection("users").doc(uid).collection("games").add(gameData);
    return {success: true, message: "ゲームデータが正常に追加されました"};
  } catch (error) {
    throw new Error("Error saving game data: " + error.message);
  }
});

/**
 * Firestoreに新しいゲームデータが追加されたときに実行されるトリガー（v2）
 */
export const onGameDataAdded = onDocumentCreated(
    "users/{uid}/games/{gameId}",
    async (event) => {
      const gameData = event.data.data();
      const uid = event.params.uid;
      const gameId = event.params.gameId;

      // 統計を更新
      try {
        await updateStatistics(uid, gameData, gameId);
        console.log("Finished updateStatistics for user:", uid);
      } catch (error) {
        console.error("統計の更新中にエラーが発生しました: ", error);
      }
    });

/**
 * 指定したユーザーの統計を更新する関数
 * @param {string} uid - ユーザーID
 * @param {Object} gameData - ゲームデータ
 * @param {string} gameId - ゲームID
 */
async function updateStatistics(uid, gameData, gameId) {
  let gameDate;
  if (gameData.gameDate instanceof Timestamp) {
    gameDate = gameData.gameDate.toDate();
  } else {
    gameDate = new Date(gameData.gameDate);
  }


  const year = gameDate.getFullYear();
  const month = gameDate.getMonth() + 1;
  const gameType = gameData.gameType || "unknown";

  const userDoc = await db.collection("users").doc(uid).get();
  const userData = userDoc.data() || {};
  const userPositions = userData.positions || [];
  const isPitcher = userPositions.includes("投手");

  const now = new Date();
  const nowDateStr = now.toISOString().split("T")[0]; // 'YYYY-MM-DD'
  const currentYear = now.getFullYear();

  const pitchingDocs = isPitcher ? [gameData] : [];
  const fieldingDocs = [gameData];

  if (isPitcher) {
    await updateStatsByCategory(
        uid,
        "results_stats_all", gameData, pitchingDocs, fieldingDocs, gameId,
    );
    await updateStatsByCategory(
        uid,
        `results_stats_${year}_${month}`, gameData, pitchingDocs, fieldingDocs,
        gameId,
    );
    await updateStatsByCategory(
        uid,
        `results_stats_${year}_all`, gameData, pitchingDocs, fieldingDocs,
        gameId,
    );
    await updateStatsByCategory(
        uid,
        `results_stats_${year}_${month}_${gameType}`,
        gameData, pitchingDocs, fieldingDocs, gameId,
    );
    await updateStatsByCategory(
        uid,
        `results_stats_${year}_${gameType}_all`,
        gameData, pitchingDocs, fieldingDocs, gameId,
    );
    await updateStatsByCategory(
        uid,
        `results_stats_${gameType}_all`, gameData, pitchingDocs, fieldingDocs,
        gameId,
    );
  } else {
    await updateStatsByCategory(
        uid,
        "results_stats_all", gameData, [], fieldingDocs, gameId,
    );
    await updateStatsByCategory(
        uid,
        `results_stats_${year}_${month}`, gameData, [], fieldingDocs, gameId,
    );
    await updateStatsByCategory(
        uid,
        `results_stats_${year}_all`, gameData, [], fieldingDocs, gameId,
    );
    await updateStatsByCategory(
        uid,
        `results_stats_${year}_${month}_${gameType}`,
        gameData, [], fieldingDocs, gameId,
    );
    await updateStatsByCategory(
        uid,
        `results_stats_${year}_${gameType}_all`, gameData, [], fieldingDocs,
        gameId,
    );
    await updateStatsByCategory(
        uid,
        `results_stats_${gameType}_all`, gameData, [], fieldingDocs, gameId,
    );
  }
  // --- 連続記録（安打・出塁・ノー三振）更新処理 ---
  const streaks = calculateStreaks(gameData.atBats || []);
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    const user = userDoc.exists ? userDoc.data() : {};

    const updates = {};

    // 🔥 連続安打記録
    if (streaks.hitStreakContinues) {
      updates.currentHitStreak = (user.currentHitStreak || 0) + 1;
    } else {
      const current = user.currentHitStreak || 0;
      const best = user.bestHitStreak || 0;
      if (current > best) {
        updates.bestHitStreak = current;
        updates.bestHitStreakYear = currentYear;
      }
      updates.currentHitStreak = 0;
    }

    // 🟢 連続出塁記録
    if (streaks.onBaseStreakContinues) {
      updates.currentOnBaseStreak = (user.currentOnBaseStreak || 0) + 1;
    } else {
      const current = user.currentOnBaseStreak || 0;
      const best = user.bestOnBaseStreak || 0;
      if (current > best) {
        updates.bestOnBaseStreak = current;
        updates.bestOnBaseStreakYear = currentYear;
      }
      updates.currentOnBaseStreak = 0;
    }

    // ⚡ ノー三振連続記録
    if (streaks.noStrikeoutStreakContinues) {
      updates.currentNoStrikeoutStreak =
      (user.currentNoStrikeoutStreak || 0) + 1;
    } else {
      const current = user.currentNoStrikeoutStreak || 0;
      const best = user.bestNoStrikeoutStreak || 0;
      if (current > best) {
        updates.bestNoStrikeoutStreak = current;
        updates.bestNoStrikeoutStreakYear = currentYear;
      }
      updates.currentNoStrikeoutStreak = 0;
    }

    // 猛打賞（3安打以上）
    const hitsThisGame = (gameData.atBats || []).filter((ab) =>
      ["内野安打", "単打", "二塁打", "三塁打", "本塁打"].includes(ab.result),
    ).length;
    if (hitsThisGame >= 3) {
      const multiHitDates = new Set(user.multiHitAwardDates || []);
      multiHitDates.add(nowDateStr);
      updates.multiHitAwardDates = Array.from(multiHitDates);
    }

    // サイクルヒット（単打/内野安打、2塁打、3塁打、本塁打）
    const results = (gameData.atBats || []).map((ab) => ab.result);
    const has1b = results.some((r) => ["内野安打", "単打"].includes(r));
    const has2b = results.includes("二塁打");
    const has3b = results.includes("三塁打");
    const hasHr = results.includes("本塁打");

    if (has1b && has2b && has3b && hasHr) {
      const cycleDates = new Set(user.cycleHitAwardDates || []);
      cycleDates.add(nowDateStr);
      updates.cycleHitAwardDates = Array.from(cycleDates);
    }

    // 連続打席ヒット・出塁・三振なしの記録更新
    const plateResults = gameData.atBats || [];

    // 打席連続ヒット（1打席ずつ見て、途切れたらリセット）
    let hitCount = user.consecutiveHitCount || 0;
    for (const ab of plateResults) {
      if (["内野安打", "単打", "二塁打", "三塁打", "本塁打"].includes(ab.result)) {
        hitCount++;
      } else {
        hitCount = 0;
      }
    }
    updates.consecutiveHitCount = hitCount;
    if (hitCount > (user.bestConsecutiveHitCount || 0)) {
      updates.bestConsecutiveHitCount = hitCount;
      updates.bestConsecutiveHitCountYear = currentYear;
    }

    // 出塁（ヒット or 四死球）連続記録
    let onBaseCount = user.consecutiveOnBaseCount || 0;
    for (const ab of plateResults) {
      if (["内野安打", "単打", "二塁打", "三塁打", "本塁打", "四球", "死球"].includes(ab.result)) {
        onBaseCount++;
      } else {
        onBaseCount = 0;
      }
    }
    updates.consecutiveOnBaseCount = onBaseCount;
    if (onBaseCount > (user.bestConsecutiveOnBaseCount || 0)) {
      updates.bestConsecutiveOnBaseCount = onBaseCount;
      updates.bestConsecutiveOnBaseCountYear = currentYear;
    }

    // 打席連続三振なし（リセット/加算方式に変更）
    if (plateResults.length > 0) {
      let currentCount = user.consecutiveNoStrikeoutCount || 0;
      for (const ab of plateResults) {
        const result = ab.result || "";
        const isStrikeout =
          ["空振り三振", "見逃し三振", "振り逃げ", "スリーバント失敗"].includes(result) ||
          ab.buntDetail === "スリーバント失敗";
        if (isStrikeout) {
          currentCount = 0; // リセット
        } else {
          currentCount++;
        }
      }
      updates.consecutiveNoStrikeoutCount = currentCount;
      if (currentCount > (user.bestConsecutiveNoStrikeoutCount || 0)) {
        updates.bestConsecutiveNoStrikeoutCount = currentCount;
        updates.bestConsecutiveNoStrikeoutCountYear = currentYear;
      }
    } else {
      updates.consecutiveNoStrikeoutCount = 0;
    }

    transaction.set(userRef, updates, {merge: true});
  });
}


/**
 * 特定の統計カテゴリを更新する関数
 * @param {string} uid - ユーザーID
 * @param {string} categoryPath - Firestore内のカテゴリパス
 * @param {Object} gameData - ゲームデータ
 * @param {Array} pitchingDocs - 投球と守備のデータ
 * @param {Array} fieldingDocs - 守備データ
 * @param {string} gameId - ゲームID
 */
async function updateStatsByCategory(
    uid, categoryPath, gameData, pitchingDocs, fieldingDocs, gameId,
) {
  const userStatsCollection =
  db.collection("users").doc(uid).collection("stats");
  const statsRef = userStatsCollection.doc(categoryPath);

  await db.runTransaction(async (transaction) => {
    const statsDoc = await transaction.get(statsRef);
    const currentStats = statsDoc.exists ? statsDoc.data() : {};
    const includedGameIds = currentStats.includedGameIds || [];
    if (includedGameIds.includes(gameId)) {
      console.log(`Game ${gameId} already included in ${categoryPath}`);
      return;
    }
    const updatedStats =
     calculateUpdatedStatistics(
         currentStats, gameData, pitchingDocs, fieldingDocs);
    updatedStats.includedGameIds = [...includedGameIds, gameId];
    if (currentStats.gameDate) {
      const currentGameDate = currentStats.gameDate.toDate();
      if (currentGameDate >= gameData.gameDate.toDate()) {
        // 現在の日付が新しい日付よりも過去の場合は上書きしない
        updatedStats.gameDate = gameData.gameDate;
      }
    } else {
      // gameDateが未定義の場合は設定
      updatedStats.gameDate = gameData.gameDate;
    }

    transaction.set(statsRef, updatedStats, {merge: true});
  });
}

/**
 * 与えられた打席データから統計を計算する関数
 * @param {Array} atBats - 打席の配列
 * @return {Object} 計算された統計データ
 */
function calculateStats(atBats) {
  const stats = {
    atBats: 0,
    totalBats: 0,
    hits: 0,
    totalBases: 0,
    totalOnBase: 0,
    totalInfieldHits: 0,
    total1hits: 0,
    total2hits: 0,
    total3hits: 0,
    totalHomeRuns: 0,
    totalFourBalls: 0,
    totalHitByAPitch: 0,
    totalStrikeouts: 0,
    totalSacrificeFly: 0,
    totalGrounders: 0,
    totalLiners: 0,
    totalFlyBalls: 0,
    totalDoublePlays: 0,
    totalErrorReaches: 0,
    totalInterferences: 0,
    totalSteals: 0,
    totalRbis: 0,
    totalRuns: 0,
    totalSwingingStrikeouts: 0,
    totalOverlookStrikeouts: 0,
    totalSwingAwayStrikeouts: 0,
    totalOuts: 0,
    totalBuntFailures: 0,
    totalThreeBuntFailures: 0,
    totalBuntDoublePlays: 0,
    totalSqueezeSuccesses: 0,
    totalSqueezeFailures: 0,
    swingCount: 0,
    missSwingCount: 0,
    batterPitchCount: 0,
    firstPitchSwingCount: 0,
    totalCaughtStealingByRunner: 0,
    totalstealsAttempts: 0,
    totalBuntAttempts: 0,
    totalThreeBuntFoulFailures: 0,
    totalThreeBuntMissFailures: 0,
    totalBuntOuts: 0,
    totalStrikeInterferences: 0,
    totalAllBuntSuccess: 0,
    firstPitchSwingHits: 0,
    hitDirectionCounts: {},
  };

  if (Array.isArray(atBats)) {
    // バント方向別カウントの初期化（必要な場合のみ）を最初に一度だけ
    if (!stats.buntDirectionCounts) {
      stats.buntDirectionCounts = {
        sacSuccess: {},
        sacFail: {},
        squeezeSuccess: {},
        squeezeFail: {},
        threeBuntFoulFail: {},
        threeBuntMissFail: {},
      };
    }
    atBats.forEach((atBat) => {
      const result = atBat.result || "";

      // 新しいバント詳細のカウント
      if (atBat.buntDetail) {
        switch (atBat.buntDetail) {
          case "犠打成功":
            stats.totalBuntSuccesses = (stats.totalBuntSuccesses || 0) + 1;
            stats.totalBats++;
            stats.totalBuntAttempts++;
            stats.totalAllBuntSuccess++;
            break;
          case "犠打失敗":
            stats.totalBuntFailures = (stats.totalBuntFailures || 0) + 1;
            stats.totalOuts++;
            stats.atBats++;
            stats.totalBats++;
            stats.totalBuntAttempts++;
            stats.totalBuntOuts++;
            break;
          case "バント併殺":
            stats.totalBuntDoublePlays = (stats.totalBuntDoublePlays || 0) + 1;
            stats.totalDoublePlays++;
            stats.totalOuts++;
            stats.atBats++;
            stats.totalBats++;
            stats.totalBuntAttempts++;
            stats.totalBuntOuts++;
            break;
          case "スクイズ成功":
            stats.totalSqueezeSuccesses =
              (stats.totalSqueezeSuccesses || 0) + 1;
            stats.totalBats++;
            stats.totalBuntAttempts++;
            stats.totalAllBuntSuccess++;
            break;
          case "スクイズ失敗":
            stats.totalSqueezeFailures = (stats.totalSqueezeFailures || 0) + 1;
            stats.totalOuts++;
            stats.atBats++;
            stats.totalBats++;
            stats.totalBuntAttempts++;
            stats.totalBuntOuts++;
            break;
          case "スリーバント失敗":
            stats.totalThreeBuntFailures++;
            stats.totalThreeBuntFoulFailures++;
            stats.totalOuts++;
            stats.atBats++;
            stats.totalBats++;
            stats.totalStrikeouts++;
            stats.totalBuntAttempts++;
            break;
        }
      }
      // --- バント方向別カウント（バント詳細・スリーバント失敗） ---
      if (
        ((atBat.buntDetail && atBat.position) ||
         (result === "スリーバント失敗" && !atBat.buntDetail && atBat.position))
      ) {
        const pos = atBat.position;

        if (atBat.buntDetail) {
          switch (atBat.buntDetail) {
            case "犠打成功":
              stats.buntDirectionCounts.sacSuccess[pos] =
                (stats.buntDirectionCounts.sacSuccess[pos] || 0) + 1;
              break;
            case "犠打失敗":
            case "バント併殺":
              stats.buntDirectionCounts.sacFail[pos] =
                (stats.buntDirectionCounts.sacFail[pos] || 0) + 1;
              break;
            case "スクイズ成功":
              stats.buntDirectionCounts.squeezeSuccess[pos] =
                (stats.buntDirectionCounts.squeezeSuccess[pos] || 0) + 1;
              break;
            case "スクイズ失敗":
              stats.buntDirectionCounts.squeezeFail[pos] =
                (stats.buntDirectionCounts.squeezeFail[pos] || 0) + 1;
              break;
            case "スリーバント失敗":
              stats.buntDirectionCounts.threeBuntFoulFail[pos] =
                (stats.buntDirectionCounts.threeBuntFoulFail[pos] || 0) + 1;
              break;
          }
        } else if (result === "スリーバント失敗") {
          stats.buntDirectionCounts.threeBuntMissFail[pos] =
            (stats.buntDirectionCounts.threeBuntMissFail[pos] || 0) + 1;
        }
      }
      stats.swingCount += atBat.swingCount || 0;
      stats.missSwingCount += atBat.missSwingCount || 0;
      stats.batterPitchCount += atBat.batterPitchCount || 0;

      if (atBat.firstPitchSwing) {
        stats.firstPitchSwingCount++;

        const isFirstPitch =
          atBat.batterPitchCount === 1 || atBat.swingCount === 1;
        const isHit = [
          "内野安打", "単打", "二塁打", "三塁打", "本塁打",
        ].includes(atBat.result);

        if (typeof stats.firstPitchSwingHits !== "number") {
          stats.firstPitchSwingHits = 0;
        }
        if (isFirstPitch && isHit) {
          stats.firstPitchSwingHits += 1;
        }
      }

      // --- 打球方向（position）を収集（カウント集計） ---
      if (
        typeof atBat.position === "string" && atBat.position.trim() !== ""
      ) {
        const pos = atBat.position;
        const validHitDirections = {
          "投": ["ゴロ", "ライナー", "フライ", "内野安打", "犠打", "失策出塁", "併殺"],
          "捕": ["ゴロ", "フライ", "内野安打", "犠打", "失策出塁", "併殺"],
          "一": ["ゴロ", "ライナー", "フライ", "内野安打", "犠打", "失策出塁", "併殺"],
          "二": ["ゴロ", "ライナー", "フライ", "内野安打", "犠打", "失策出塁", "併殺"],
          "三": ["ゴロ", "ライナー", "フライ", "内野安打", "犠打", "失策出塁", "併殺"],
          "遊": ["ゴロ", "ライナー", "フライ", "内野安打", "犠打", "失策出塁", "併殺"],
          "左": ["ライナー", "フライ", "単打", "二塁打", "三塁打", "本塁打", "犠飛", "失策出塁"],
          "中": ["ライナー", "フライ", "単打", "二塁打", "三塁打", "本塁打", "犠飛", "失策出塁"],
          "右": ["ライナー", "フライ", "単打", "二塁打", "三塁打", "本塁打", "犠飛", "失策出塁"],
        };
        const result = atBat.result;
        if (
          validHitDirections[pos] && validHitDirections[pos].includes(result)
        ) {
          stats.hitDirectionCounts[pos] =
            (stats.hitDirectionCounts[pos] || 0) + 1;
        }
      }
      // --- 打球方向 × 結果別集計 ---
      if (!stats.hitDirectionDetails) {
        stats.hitDirectionDetails = {};
      }
      if (
        typeof atBat.position === "string" &&
        atBat.position.trim() !== "" &&
        atBat.position !== "打" // 除外対象
      ) {
        const pos = atBat.position;
        const result = atBat.result || "";
        if (!stats.hitDirectionDetails[pos]) {
          stats.hitDirectionDetails[pos] = {};
        }
        stats.hitDirectionDetails[pos][result] =
          (stats.hitDirectionDetails[pos][result] || 0) + 1;
      }
      // --- 犠飛方向（position）を収集（カウント集計） ---
      if (
        result === "犠飛" && typeof atBat.position === "string" &&
        atBat.position.trim() !== ""
      ) {
        const pos = atBat.position;
        if (!stats.sacFlyDirectionCounts) {
          stats.sacFlyDirectionCounts = {};
        }
        stats.sacFlyDirectionCounts[pos] =
        (stats.sacFlyDirectionCounts[pos] || 0) + 1;
      }

      // 各打席の結果に応じてカウント
      switch (result) {
        case "内野安打":
          stats.hits++;
          stats.totalBases += 1;
          stats.totalOnBase++;
          stats.totalInfieldHits++;
          stats.atBats++;
          stats.totalBats++;
          break;
        case "単打":
          stats.hits++;
          stats.totalBases += 1;
          stats.totalOnBase++;
          stats.total1hits++;
          stats.atBats++;
          stats.totalBats++;
          break;
        case "二塁打":
          stats.hits++;
          stats.totalBases += 2;
          stats.totalOnBase++;
          stats.total2hits++;
          stats.atBats++;
          stats.totalBats++;
          break;
        case "三塁打":
          stats.hits++;
          stats.totalBases += 3;
          stats.totalOnBase++;
          stats.total3hits++;
          stats.atBats++;
          stats.totalBats++;
          break;
        case "本塁打":
          stats.hits++;
          stats.totalBases += 4;
          stats.totalOnBase++;
          stats.totalHomeRuns++;
          stats.atBats++;
          stats.totalBats++;
          break;
        case "四球":
          stats.totalFourBalls++;
          stats.totalOnBase++;
          stats.totalBats++;
          break;
        case "死球":
          stats.totalHitByAPitch++;
          stats.totalOnBase++;
          stats.totalBats++;
          break;
        case "空振り三振":
          stats.totalStrikeouts++;
          stats.totalSwingingStrikeouts++;
          stats.atBats++;
          stats.totalBats++;
          break;
        case "見逃し三振":
          stats.totalStrikeouts++;
          stats.totalOverlookStrikeouts++;
          stats.atBats++;
          stats.totalBats++;
          break;
        case "振り逃げ":
          stats.totalStrikeouts++;
          stats.totalSwingAwayStrikeouts++;
          stats.atBats++;
          stats.totalBats++;
          break;
        case "スリーバント失敗":
          stats.totalThreeBuntFailures++;
          stats.totalThreeBuntMissFailures++;
          stats.totalOuts++;
          stats.atBats++;
          stats.totalBats++;
          stats.totalStrikeouts++;
          stats.totalBuntAttempts++;
          break;
        case "犠飛":
          stats.totalSacrificeFly++;
          stats.totalBats++;
          break;
        case "ゴロ":
          stats.totalGrounders++;
          stats.atBats++;
          stats.totalBats++;
          stats.totalOuts++;
          break;
        case "ライナー":
          stats.totalLiners++;
          stats.atBats++;
          stats.totalBats++;
          stats.totalOuts++;
          break;
        case "フライ":
          stats.totalFlyBalls++;
          stats.atBats++;
          stats.totalBats++;
          stats.totalOuts++;
          break;
        case "併殺":
          stats.totalDoublePlays++;
          stats.atBats++;
          stats.totalBats++;
          stats.totalOuts++;
          break;
        case "失策出塁":
          stats.totalErrorReaches++;
          stats.atBats++;
          stats.totalBats++;
          stats.totalOuts++;
          break;
        case "守備妨害":
          stats.totalInterferences++;
          stats.atBats++;
          stats.totalBats++;
          stats.totalOuts++;
          break;
        case "打撃妨害":
          stats.totalBats++;
          stats.totalStrikeInterferences++;
          break;
      }
    });
  }
  return stats;
}

/**
* 現在の試合における連続記録（ヒット・出塁・ノー三振）を計算する
* @param {Array} atBats - 打席データの配列
* @return {Object} - 連続記録の更新結果
*/
function calculateStreaks(atBats) {
  let isHitInThisGame = false;
  let isOnBaseInThisGame = false;
  let isStrikeoutInThisGame = false;

  if (!Array.isArray(atBats)) {
    return {
      hitStreakContinues: false,
      onBaseStreakContinues: false,
      noStrikeoutStreakContinues: false,
    };
  }

  for (const atBat of atBats) {
    const result = atBat.result || "";

    if (["内野安打", "単打", "二塁打", "三塁打", "本塁打"].includes(result)) {
      isHitInThisGame = true;
      isOnBaseInThisGame = true;
    } else if (["四球", "死球"].includes(result)) {
      isOnBaseInThisGame = true;
    }

    // 三振チェック
    if (
      ["空振り三振", "見逃し三振", "振り逃げ", "スリーバント失敗"].includes(result) ||
      atBat.buntDetail === "スリーバント失敗"
    ) {
      isStrikeoutInThisGame = true;
    }
  }

  return {
    hitStreakContinues: isHitInThisGame,
    onBaseStreakContinues: isOnBaseInThisGame,
    noStrikeoutStreakContinues: !isStrikeoutInThisGame,
  };
}

/**
 * 投手成績を計算する関数
 * @param {Array} pitchingDocs - 投球データの配列
 * @return {Object} 投手成績
 */
function calculatePitchingStats(pitchingDocs) {
  let totalInningsPitched = 0.0;
  let totalEarnedRuns = 0;
  let totalPStrikeouts = 0;
  let totalWalks = 0;
  let totalHitsAllowed = 0;
  let totalHitByPitch = 0;
  let totalRunsAllowed = 0;
  let totalWins = 0;
  let totalLosses = 0;
  let totalSaves = 0;
  let totalHolds = 0;
  let totalCompleteGames = 0;
  let totalShutouts = 0;
  let totalStarts = 0;
  let totalReliefs = 0;
  let totalClosures = 0;
  let totalBattersFaced = 0;
  let totalReliefWins = 0;
  let totalHoldPoints = 0;
  let totalAppearances = 0;
  let totalHomeRunsAllowed = 0;
  let totalPitchCount = 0;
  let qualifyingStarts = 0;

  pitchingDocs.forEach((doc) => {
    const inningsThrow = parseFloat(doc["inningsThrow"] || 0);
    const outFraction = convertOutsToInnings(doc["outFraction"] || "");
    const inningsPitched = inningsThrow + outFraction;
    totalInningsPitched += inningsPitched;
    const appearanceType = doc["appearanceType"] || "";

    const isQualifyingStart =
      appearanceType === "先発" &&
      inningsPitched >= 4 &&
      (doc["earnedRuns"] || 0) <= 2;
    if (isQualifyingStart) qualifyingStarts++;

    if (["先発", "中継ぎ", "抑え"].includes(appearanceType)) {
      totalAppearances++;
    }

    totalEarnedRuns += doc["earnedRuns"] || 0;
    totalPStrikeouts += doc["strikeouts"] || 0;
    totalWalks += doc["walks"] || 0;
    totalHitsAllowed += doc["hitsAllowed"] || 0;
    totalHitByPitch += doc["hitByPitch"] || 0;
    totalRunsAllowed += doc["runsAllowed"] || 0;

    const resultGame = doc["resultGame"] || "";
    if (resultGame === "勝利") totalWins++;
    if (resultGame === "敗北") totalLosses++;

    if (doc["isSave"]) totalSaves++;
    if (doc["isHold"]) totalHolds++;
    if (doc["isCompleteGame"]) totalCompleteGames++;
    if (doc["isShutoutGame"]) totalShutouts++;

    totalBattersFaced += doc["battersFaced"] || 0;
    totalHomeRunsAllowed += doc["homeRunsAllowed"] || 0;
    totalPitchCount += doc["pitchCount"] || 0;

    if (appearanceType === "先発") totalStarts++;
    if (appearanceType === "中継ぎ") {
      totalReliefs++;
      if (resultGame === "勝利") totalReliefWins++;
    }
    if (appearanceType === "抑え") totalClosures++;
  });

  totalHoldPoints = totalReliefWins + totalHolds;

  return {
    totalInningsPitched,
    totalEarnedRuns,
    totalPStrikeouts,
    totalWalks,
    totalHitsAllowed,
    totalHitByPitch,
    totalRunsAllowed,
    totalWins,
    totalLosses,
    totalSaves,
    totalHolds,
    totalCompleteGames,
    totalShutouts,
    totalStarts,
    totalReliefs,
    totalClosures,
    totalBattersFaced,
    totalReliefWins,
    totalHoldPoints,
    totalAppearances,
    totalHomeRunsAllowed,
    totalPitchCount,
    qualifyingStarts,
  };
}

/**
 * 守備成績を計算する関数
 * @param {Array} fieldingDocs - 守備データの配列
 * @return {Object} 守備成績
 */
function calculateFieldingStats(fieldingDocs) {
  let totalPutouts = 0;
  let totalAssists = 0;
  let totalErrors = 0;
  let totalCaughtStealing = 0;
  let totalStolenBaseAttempts = 0;

  fieldingDocs.forEach((doc) => {
    const positions = doc.positions || [];

    totalPutouts += doc["putouts"] || 0;
    totalAssists += doc["assists"] || 0;
    totalErrors += doc["errors"] || 0;

    // 捕手のときだけ盗塁刺・盗塁企図を加算
    if (Array.isArray(positions) && positions.includes("捕手")) {
      totalCaughtStealing += doc["caughtStealing"] || 0;
      totalStolenBaseAttempts += doc["stolenBaseAttempts"] || 0;
    }
  });

  const catcherStealingRate = totalStolenBaseAttempts > 0 ?
    totalCaughtStealing / totalStolenBaseAttempts :
    0.0;

  return {
    totalPutouts,
    totalAssists,
    totalErrors,
    totalCaughtStealing,
    totalStolenBaseAttempts,
    catcherStealingRate,
  };
}

/**
 * 防御率を計算する関数
 * @param {int} earnedRuns - 自責点
 * @param {double} inningsPitched - 総投球回
 * @return {double} 防御率
 */
function calculateERA(earnedRuns, inningsPitched) {
  if (inningsPitched == 0) {
    return 0.0; // 投球回が0の場合、防御率は0として扱います
  }
  return (earnedRuns * 7) / inningsPitched; // 草野球用に7イニング制で計算
}

/**
 * outs（アウト数）をイニングに変換する関数
 * @param {String} outs - アウト数の文字列
 * @return {double} イニング数
 */
function convertOutsToInnings(outs) {
  switch (outs) {
    case "0":
      return 0.0;
    case "1/3":
      return 1.0 / 3.0;
    case "2/3":
      return 2.0 / 3.0;
    default:
      return parseFloat(outs) || 0.0; // 変換できなければ0.0を返す
  }
}

/**
 * 統計を更新するための関数
 * @param {Object} currentStats - 現在の統計データ
 * @param {Object} gameData - 新しいゲームデータ
 * @param {Array} pitchingDocs - 投球と守備のデータ
 * @param {Array} fieldingDocs - 守備データ
 * @return {Object} 更新された統計データ
 */
function calculateUpdatedStatistics(
    currentStats, gameData, pitchingDocs, fieldingDocs,
) {
  const updatedStats = {...currentStats};

  const newStats =
  Array.isArray(gameData.atBats) ? calculateStats(gameData.atBats) : {};

  updatedStats.hits =
   (currentStats.hits || 0) + newStats.hits;
  updatedStats.totalBases =
  (currentStats.totalBases || 0) + newStats.totalBases;
  updatedStats.totalOnBase =
  (currentStats.totalOnBase || 0) + newStats.totalOnBase;
  updatedStats.totalInfieldHits =
  (currentStats.totalInfieldHits || 0) +
  newStats.totalInfieldHits;
  updatedStats.total1hits =
  (currentStats.total1hits || 0) + newStats.total1hits;
  updatedStats.total2hits =
  (currentStats.total2hits || 0) + newStats.total2hits;
  updatedStats.total3hits =
  (currentStats.total3hits || 0) + newStats.total3hits;
  updatedStats.totalHomeRuns =
  (currentStats.totalHomeRuns || 0) + newStats.totalHomeRuns;
  updatedStats.totalFourBalls =
  (currentStats.totalFourBalls || 0) + newStats.totalFourBalls;
  updatedStats.totalHitByAPitch =
  (currentStats.totalHitByAPitch || 0) + newStats.totalHitByAPitch;
  updatedStats.totalStrikeouts =
  (currentStats.totalStrikeouts || 0) + newStats.totalStrikeouts;
  updatedStats.totalSacrificeFly =
  (currentStats.totalSacrificeFly || 0) + newStats.totalSacrificeFly;
  updatedStats.totalGrounders =
  (currentStats.totalGrounders || 0) + newStats.totalGrounders;
  updatedStats.totalLiners =
  (currentStats.totalLiners || 0) + newStats.totalLiners;
  updatedStats.totalFlyBalls =
  (currentStats.totalFlyBalls || 0) + newStats.totalFlyBalls;
  updatedStats.totalDoublePlays =
  (currentStats.totalDoublePlays || 0) + newStats.totalDoublePlays;
  updatedStats.totalErrorReaches =
  (currentStats.totalErrorReaches || 0) + newStats.totalErrorReaches;
  updatedStats.totalInterferences =
   (currentStats.totalInterferences || 0) + newStats.totalInterferences;
  updatedStats.totalSwingingStrikeouts =
   (currentStats.totalSwingingStrikeouts || 0) +
    newStats.totalSwingingStrikeouts;
  updatedStats.totalOverlookStrikeouts =
    (currentStats.totalOverlookStrikeouts || 0) +
     newStats.totalOverlookStrikeouts;
  updatedStats.totalSwingAwayStrikeouts =
     (currentStats.totalSwingAwayStrikeouts || 0) +
      newStats.totalSwingAwayStrikeouts;
  updatedStats.totalOuts =
      (currentStats.totalOuts || 0) + newStats.totalOuts;
  updatedStats.swingCount =
  (currentStats.swingCount || 0) + newStats.swingCount;
  updatedStats.missSwingCount =
  (currentStats.missSwingCount || 0) + newStats.missSwingCount;
  updatedStats.batterPitchCount =
  (currentStats.batterPitchCount || 0) + newStats.batterPitchCount;
  updatedStats.firstPitchSwingCount =
  (currentStats.firstPitchSwingCount || 0) + newStats.firstPitchSwingCount;
  updatedStats.firstPitchSwingHits =
  (currentStats.firstPitchSwingHits || 0) + newStats.firstPitchSwingHits;
  updatedStats.totalBuntAttempts =
  (currentStats.totalBuntAttempts || 0) + (newStats.totalBuntAttempts || 0);
  updatedStats.totalBuntSuccesses =
  (currentStats.totalBuntSuccesses || 0) + (newStats.totalBuntSuccesses || 0);
  updatedStats.totalBuntFailures =
  (currentStats.totalBuntFailures || 0) + (newStats.totalBuntFailures || 0);
  updatedStats.totalBuntDoublePlays =
  (currentStats.totalBuntDoublePlays || 0) +
  (newStats.totalBuntDoublePlays || 0);
  updatedStats.totalSqueezeSuccesses =
  (currentStats.totalSqueezeSuccesses || 0) +
  (newStats.totalSqueezeSuccesses || 0);
  updatedStats.totalSqueezeFailures =
  (currentStats.totalSqueezeFailures || 0) +
  (newStats.totalSqueezeFailures || 0);
  updatedStats.totalThreeBuntFailures =
    (currentStats.totalThreeBuntFailures || 0) +
    (newStats.totalThreeBuntFailures || 0);
  updatedStats.totalThreeBuntFoulFailures =
    (currentStats.totalThreeBuntFoulFailures || 0) +
    (newStats.totalThreeBuntFoulFailures || 0);
  updatedStats.totalThreeBuntMissFailures =
    (currentStats.totalThreeBuntMissFailures || 0) +
    (newStats.totalThreeBuntMissFailures || 0);
  updatedStats.totalBuntOuts =
    (currentStats.totalBuntOuts || 0) + (newStats.totalBuntOuts || 0);
  updatedStats.totalStrikeInterferences =
    (currentStats.totalStrikeInterferences || 0) +
    (newStats.totalStrikeInterferences || 0);
  updatedStats.totalAllBuntSuccess =
    (currentStats.totalAllBuntSuccess || 0) +
    (newStats.totalAllBuntSuccess || 0);

  updatedStats.hitDirectionCounts = {
    ...(currentStats.hitDirectionCounts || {}),
  };
  for (
    const [key, count] of Object.entries(
        newStats.hitDirectionCounts || {},
    )
  ) {
    updatedStats.hitDirectionCounts[key] =
      (updatedStats.hitDirectionCounts[key] || 0) + count;
  }
  // --- 打球方向 × 結果別集計の加算 ---
  updatedStats.hitDirectionDetails = {
    ...(currentStats.hitDirectionDetails || {}),
  };
  for (
    const [pos, resultsMap] of Object.entries(
        newStats.hitDirectionDetails || {},
    )
  ) {
    if (!updatedStats.hitDirectionDetails[pos]) {
      updatedStats.hitDirectionDetails[pos] = {};
    }
    for (const [result, count] of Object.entries(resultsMap)) {
      updatedStats.hitDirectionDetails[pos][result] =
        (updatedStats.hitDirectionDetails[pos][result] || 0) + count;
    }
  }
  // 犠飛方向の加算
  updatedStats.sacFlyDirectionCounts = {
    ...(currentStats.sacFlyDirectionCounts || {}),
  };
  for (
    const [key, count] of Object.entries(newStats.sacFlyDirectionCounts || {})
  ) {
    updatedStats.sacFlyDirectionCounts[key] =
    (updatedStats.sacFlyDirectionCounts[key] || 0) + count;
  }

  const buntKeys = [
    "sacSuccess",
    "sacFail",
    "squeezeSuccess",
    "squeezeFail",
    "threeBuntFoulFail",
    "threeBuntMissFail",
  ];

  const buntDirectionCounts = currentStats.buntDirectionCounts || {};
  const newBuntDirectionCounts = newStats.buntDirectionCounts || {};

  for (const key of buntKeys) {
    const currentMap = buntDirectionCounts[key] || {};
    const newMap = newBuntDirectionCounts[key] || {};

    for (
      const pos of new Set(
          [...Object.keys(currentMap), ...Object.keys(newMap)],
      )
    ) {
      const currentVal = currentMap[pos] || 0;
      const newVal = newMap[pos] || 0;

      if (!updatedStats.buntDirectionCounts) {
        updatedStats.buntDirectionCounts = {};
      }
      if (!updatedStats.buntDirectionCounts[key]) {
        updatedStats.buntDirectionCounts[key] = {};
      }
      updatedStats.buntDirectionCounts[key][pos] = currentVal + newVal;
    }
  }

  updatedStats.atBats =
      (currentStats.atBats || 0) + newStats.atBats;
  updatedStats.totalBats =
      (currentStats.totalBats || 0) + newStats.totalBats;

  // 盗塁、打点、得点の更新
  updatedStats.totalSteals =
  (currentStats.totalSteals || 0) + (gameData.steals || 0);
  updatedStats.totalstealsAttempts =
  (currentStats.totalstealsAttempts || 0) +
  (gameData.stealsAttempts || 0);
  updatedStats.totalRbis =
  (currentStats.totalRbis || 0) + (gameData.rbis || 0);
  updatedStats.totalRuns =
  (currentStats.totalRuns || 0) + (gameData.runs || 0);
  updatedStats.totalCaughtStealingByRunner =
  (currentStats.totalCaughtStealingByRunner || 0) +
  (gameData.caughtStealingByRunner || 0);

  // 出塁率・打率・長打率の再計算
  updatedStats.battingAverage =
  updatedStats.atBats > 0 ? updatedStats.hits /
  updatedStats.atBats : 0.0;

  // 試合数の統計を追加
  updatedStats.totalGames = (currentStats.totalGames || 0) + 1;

  updatedStats.onBasePercentage =
  (updatedStats.hits + updatedStats.totalFourBalls +
    updatedStats.totalHitByAPitch) > 0 ?
  (updatedStats.hits + updatedStats.totalFourBalls +
    updatedStats.totalHitByAPitch) /
    (updatedStats.atBats + updatedStats.totalFourBalls +
      updatedStats.totalHitByAPitch + updatedStats.totalSacrificeFly) :
  0.0;

  updatedStats.sluggingPercentage =
  updatedStats.atBats > 0 ? updatedStats.totalBases / updatedStats.atBats : 0.0;

  // OPSの計算
  updatedStats.ops =
    updatedStats.onBasePercentage + updatedStats.sluggingPercentage;

  // RCの計算
  updatedStats.rc =
    ((updatedStats.hits + updatedStats.totalFourBalls) *
    updatedStats.totalBases) /
      (updatedStats.totalBats + updatedStats.totalFourBalls) || 0;

  // 守備成績
  const fieldingStats = calculateFieldingStats(fieldingDocs);
  updatedStats.totalPutouts =
        (currentStats.totalPutouts || 0) + fieldingStats.totalPutouts;
  updatedStats.totalAssists =
        (currentStats.totalAssists || 0) + fieldingStats.totalAssists;
  updatedStats.totalErrors =
        (currentStats.totalErrors || 0) + fieldingStats.totalErrors;

  const totalChances =
        updatedStats.totalPutouts + updatedStats.totalAssists +
        updatedStats.totalErrors;

  updatedStats.fieldingPercentage =
        totalChances > 0 ?
        (updatedStats.totalPutouts + updatedStats.totalAssists) /
        totalChances : 0.0;

  updatedStats.totalCaughtStealing =
    (currentStats.totalCaughtStealing || 0) +
    (gameData.caughtStealing || 0) +
    (fieldingStats.totalCaughtStealing || 0);

  updatedStats.totalStolenBaseAttempts =
    (currentStats.totalStolenBaseAttempts || 0) +
    (gameData.stolenBaseAttempts || 0) +
    (fieldingStats.totalStolenBaseAttempts || 0);
  updatedStats.catcherStealingRate = updatedStats.totalStolenBaseAttempts > 0 ?
    updatedStats.totalCaughtStealing / updatedStats.totalStolenBaseAttempts :
    0.0;

  // 投手成績
  if (pitchingDocs.length > 0) {
    const pitchingStats = calculatePitchingStats(pitchingDocs);
    updatedStats.isPitcher = true;
    updatedStats.totalInningsPitched =
        (currentStats.totalInningsPitched || 0) +
        pitchingStats.totalInningsPitched;
    updatedStats.totalEarnedRuns =
        (currentStats.totalEarnedRuns || 0) +
        pitchingStats.totalEarnedRuns;
    updatedStats.totalPStrikeouts =
        (currentStats.totalPStrikeouts || 0) +
        pitchingStats.totalPStrikeouts;
    updatedStats.totalWalks =
        (currentStats.totalWalks || 0) + pitchingStats.totalWalks;
    updatedStats.totalHitsAllowed =
        (currentStats.totalHitsAllowed || 0) +
        pitchingStats.totalHitsAllowed;
    updatedStats.totalHitByPitch =
        (currentStats.totalHitByPitch || 0) +
        pitchingStats.totalHitByPitch;
    updatedStats.totalRunsAllowed =
        (currentStats.totalRunsAllowed || 0) +
        pitchingStats.totalRunsAllowed;
    updatedStats.totalWins =
        (currentStats.totalWins || 0) + pitchingStats.totalWins;
    updatedStats.totalLosses =
        (currentStats.totalLosses || 0) + pitchingStats.totalLosses;
    updatedStats.totalSaves =
        (currentStats.totalSaves || 0) + pitchingStats.totalSaves;
    updatedStats.totalHolds =
        (currentStats.totalHolds || 0) + pitchingStats.totalHolds;
    updatedStats.totalCompleteGames =
        (currentStats.totalCompleteGames || 0) +
        pitchingStats.totalCompleteGames;
    updatedStats.totalShutouts =
        (currentStats.totalShutouts || 0) + pitchingStats.totalShutouts;
    updatedStats.totalStarts =
        (currentStats.totalStarts || 0) + pitchingStats.totalStarts;
    updatedStats.totalReliefs =
        (currentStats.totalReliefs || 0) + pitchingStats.totalReliefs;
    updatedStats.totalClosures =
        (currentStats.totalClosures || 0) + pitchingStats.totalClosures;
    updatedStats.totalBattersFaced =
        (currentStats.totalBattersFaced || 0) + pitchingStats.totalBattersFaced;
    updatedStats.totalReliefWins =
        (currentStats.totalReliefWins || 0) + pitchingStats.totalReliefWins;
    updatedStats.totalHoldPoints =
        updatedStats.totalReliefWins + updatedStats.totalHolds;
    updatedStats.totalAppearances =
        (currentStats.totalAppearances || 0) + pitchingStats.totalAppearances;
    updatedStats.totalHomeRunsAllowed =
        (currentStats.totalHomeRunsAllowed || 0) +
        pitchingStats.totalHomeRunsAllowed;
    updatedStats.totalPitchCount =
        (currentStats.totalPitchCount || 0) + pitchingStats.totalPitchCount;
    updatedStats.qualifyingStarts =
        (currentStats.qualifyingStarts || 0) +
        (pitchingStats.qualifyingStarts || 0);

    updatedStats.winRate =
        updatedStats.totalWins +
         updatedStats.totalLosses > 0 ? updatedStats.totalWins /
        (updatedStats.totalWins + updatedStats.totalLosses) : 0.0;

    // 防御率・フィールディングパーセンテージ・勝率は再計算
    updatedStats.era =
        calculateERA(
            updatedStats.totalEarnedRuns, updatedStats.totalInningsPitched,
        );
  }
  return updatedStats;
}

/**
 * 循環参照を回避するための安全なJSON.stringify関数
 * @param {Object} obj - JSONに変換するオブジェクト
 * @return {string} - 循環参照を回避したJSON文字列
 */
function safeStringify(obj) {
  const seen = new Set();
  return JSON.stringify(obj, (key, value) => {
    if (typeof value === "object" && value !== null) {
      if (seen.has(value)) {
        return; // 循環参照を避ける
      }
      seen.add(value);
    }
    return value;
  });
}

// 試合保存後発火
export const onGameDataCreated =
onDocumentCreated("users/{uid}/games/{gameId}", async (event) => {
  const uid = event.params.uid;
  const gameId = event.params.gameId;

  // Cloud Tasks のキューとリージョンを設定
  const teamLocationQueue = "team-location-stats-queue";

  // Cloud Function のエンドポイント URL
  const teamLocationUrl = "https://updateteamandlocationstats-etndg3x4ra-uc.a.run.app";

  // Cloud Task のペイロード
  const payload = {
    uid,
    gameId,
  };

  // Cloud Task を作成
  const parent = client.queuePath(
      project, location, teamLocationQueue,
  );
  const task = {
    httpRequest: {
      httpMethod: "POST",
      url: teamLocationUrl,
      headers: {
        "Content-Type": "application/json",
      },
      body: Buffer.from(JSON.stringify(payload)).toString("base64"),
    },
  };

  // 既存のCloud Taskを作成
  await client.createTask({parent, task});

  // 追加: 高度なスタッツ計算クラウド関数へのタスク
  const advancedStatsUrl = "https://calculateadvancedstats-etndg3x4ra-uc.a.run.app";
  const advancedStatsPayload = {
    uid,
    gameId,
  };
  const advancedStatsTask = {
    httpRequest: {
      httpMethod: "POST",
      url: advancedStatsUrl,
      headers: {
        "Content-Type": "application/json",
      },
      body: Buffer.from(JSON.stringify(advancedStatsPayload))
          .toString("base64"),
    },
  };
  await client.createTask({parent, task: advancedStatsTask});

  // 目標
  const userGoalTask = {
    httpRequest: {
      httpMethod: "POST",
      url: "https://usergoalprogresshandler-etndg3x4ra-uc.a.run.app",
      headers: {
        "Content-Type": "application/json",
      },
      body: Buffer.from(JSON.stringify({uid})).toString("base64"),
    },
  };
  await client.createTask({parent, task: userGoalTask});
});


// 新しいCloud Function: calculateAdvancedStats
export const calculateAdvancedStats = onRequest(async (req, res) => {
  try {
    // POSTリクエストbody
    let body = req.body;
    // Cloud Tasks経由の場合はbase64デコード
    if (typeof body === "string") {
      body = JSON.parse(Buffer.from(body, "base64").toString());
    }
    const {uid, gameId} = body;
    if (!uid) return res.status(400).send("Missing uid");

    // どの年のデータか取得
    let year = null;
    try {
      const gameSnap =
      await db.collection("users").doc(uid)
          .collection("games").doc(gameId).get();
      if (!gameSnap.exists) return res.status(404).send("Game not found");
      const gameData = gameSnap.data();
      let gameDate;
      if (gameData.gameDate instanceof Timestamp) {
        gameDate = gameData.gameDate.toDate();
      } else {
        gameDate = new Date(gameData.gameDate);
      }
      year = gameDate.getFullYear();
    } catch (e) {
      return res.status(400).send("Failed to get game year");
    }

    // 対象statsドキュメントID
    const statDocIds = [
      `results_stats_${year}_all`,
      `results_stats_${year}_公式戦_all`,
      `results_stats_${year}_練習試合_all`,
      `results_stats_all`,
      `results_stats_練習試合_all`,
      `results_stats_公式戦_all`,
    ];

    // 全ドキュメントを取得
    const statsDocs = await Promise.all(
        statDocIds.map((id) =>
          db.collection("users").doc(uid).collection("stats").doc(id).get(),
        ),
    );

    // 公式戦/練習試合/全体/今年全体: データごとに計算
    for (let i = 0; i < statDocIds.length; i++) {
      const statsDoc = statsDocs[i];
      if (!statsDoc.exists) continue;
      const stats = statsDoc.data() || {};
      const adv = {};
      // 打者共通
      const totalGames = stats.totalGames || 0;
      const totalBats = stats.totalBats || 0;
      const atBats = stats.atBats || 0;
      const totalStrikeouts = stats.totalStrikeouts || 0;
      const totalFourBalls = stats.totalFourBalls || 0;
      const totalHitByAPitch = stats.totalHitByAPitch || 0;
      const runs = stats.totalRuns || 0;
      const firstPitchSwingCount = stats.firstPitchSwingCount || 0;
      const firstPitchSwingHits = stats.firstPitchSwingHits || 0;
      const totalSteals = stats.totalSteals || 0;
      const totalstealsAttempts = stats.totalstealsAttempts || 0;
      const totalBuntAttempts = stats.totalBuntAttempts || 0;
      const swingCount = stats.swingCount || 0;
      const missSwingCount = stats.missSwingCount || 0;
      const batterPitchCount = stats.batterPitchCount || 0;
      const hits = stats.hits || 0;
      const homeRuns = stats.totalHomeRuns || 0;
      const sacrificeFly = stats.totalSacrificeFly || 0;
      const totalBases = stats.totalBases || 0;
      const totalAllBuntSuccess = stats.totalAllBuntSuccess || 0;
      const totalStrikeInterferences = stats.totalStrikeInterferences || 0;
      // 三振率
      adv.strikeoutRate = atBats > 0 ? totalStrikeouts / atBats : 0;
      // 出塁後得点率
      const onBaseCount =
      hits + totalFourBalls + totalHitByAPitch + totalStrikeInterferences;
      adv.runAfterOnBaseRate = onBaseCount > 0 ? runs / onBaseCount : 0;
      // 初球スイング率
      adv.firstPitchSwingRate =
      totalBats > 0 ? firstPitchSwingCount / totalBats : 0;
      // 初球打率成功率 (firstPitchSwingHitsがなければ0)
      const safeFirstPitchSwingHits = firstPitchSwingHits || 0;
      adv.firstPitchSwingSuccessRate =
      firstPitchSwingCount > 0 ?
      safeFirstPitchSwingHits / firstPitchSwingCount : 0;
      // 初球ヒット率（firstPitchHitRate）: 全打席に対する初球ヒット割合
      adv.firstPitchHitRate =
      totalBats > 0 ? firstPitchSwingHits / totalBats : 0;
      // 盗塁成功率
      adv.stealSuccessRate =
      totalstealsAttempts > 0 ? totalSteals / totalstealsAttempts : 0;
      // バント成功率
      adv.buntSuccessRate =
      totalBuntAttempts > 0 ? totalAllBuntSuccess / totalBuntAttempts : 0;
      // スイング率
      adv.swingRate = batterPitchCount > 0 ? swingCount / batterPitchCount : 0;
      // 空振り率
      adv.missSwingRate = swingCount > 0 ? missSwingCount / swingCount : 0;
      // 平均球数
      adv.avgPitchesPerAtBat = totalBats > 0 ? batterPitchCount / totalBats : 0;
      // BABIP
      adv.babip =
        (atBats - totalStrikeouts - homeRuns + sacrificeFly) > 0 ?
          (hits - homeRuns) /
          (atBats - totalStrikeouts - homeRuns + sacrificeFly) :
          0;
      // BB/K
      adv.bbPerK = totalStrikeouts > 0 ? totalFourBalls / totalStrikeouts : 0;
      // ISO
      adv.iso = atBats > 0 ? (totalBases / atBats) - (hits / atBats) : 0;

      // 投手限定
      if (stats.isPitcher) {
        const totalInningsPitched = stats.totalInningsPitched || 0;
        const totalPStrikeouts = stats.totalPStrikeouts || 0;
        const totalBattersFaced = stats.totalBattersFaced || 0;
        const totalHitsAllowed = stats.totalHitsAllowed || 0;
        const totalWalks = stats.totalWalks || 0;
        const runsAllowed = stats.totalRunsAllowed || 0;
        const qualifyingStarts = stats.qualifyingStarts || 0;
        const totalStarts = stats.totalStarts || 0;
        const totalHomeRunsAllowed = stats.totalHomeRunsAllowed || 0;
        const totalPitchCount = stats.totalPitchCount || 0;
        const totalHitByPitch = stats.totalHitByPitch || 0;
        // 奪三振率１イニングあたり
        adv.pitcherStrikeoutsPerInning = totalInningsPitched > 0 ?
        totalPStrikeouts / totalInningsPitched : 0;
        // 奪三振率7イニングあたり
        adv.strikeoutsPerNineInnings = totalInningsPitched > 0 ?
        (totalPStrikeouts * 7) / totalInningsPitched : 0;
        // 被打率 本来は(四球・死球・犠打などは除いた「打数」**で割るのが理想的。)
        adv.battingAverageAllowed = totalBattersFaced > 0 ?
        totalHitsAllowed / totalBattersFaced : 0;
        // WHIP
        adv.whip = totalInningsPitched > 0 ?
        (totalWalks + totalHitsAllowed) / totalInningsPitched : 0;
        // QS
        adv.qsRate = totalStarts > 0 ? qualifyingStarts / totalStarts : 0;
        // 被本塁打率
        adv.homeRunRate = totalInningsPitched > 0 ?
        (totalHomeRunsAllowed / totalInningsPitched) * 7 : 0;
        // 平均球数（1人あたり）
        adv.avgPitchesPerBatter = totalBattersFaced > 0 ?
        totalPitchCount / totalBattersFaced : 0;
        // 平均球数（1試合あたり）
        adv.avgPitchesPerGame =
        totalGames > 0 ? totalPitchCount / totalGames : 0;

        // 1試合あたりの与死球・与四球
        adv.avgHitByPitchPerGame = totalGames > 0 ?
        stats.totalHitByPitch / totalGames : 0;
        adv.avgWalksPerGame = totalGames > 0 ? totalWalks / totalGames : 0;

        // 1試合あたりの打者数
        adv.avgBattersFacedPerGame = totalGames > 0 ?
        totalBattersFaced / totalGames : 0;

        // 1試合あたりの失点
        adv.avgRunsAllowedPerGame = totalGames >
        0 ? runsAllowed / totalGames : 0;

        // LOB%
        const runnersOnBase =
        totalHitsAllowed + totalWalks + totalHitByPitch;
        const adjustedDenominator =
        runnersOnBase - (1.4 * totalHomeRunsAllowed);
        adv.lobRate = adjustedDenominator > 0 ?
        (runnersOnBase - runsAllowed) / adjustedDenominator :
        0;
      //   adv.lobRate =
      //     (totalBattersFaced - totalHitsAllowed) > 0 ?
      //       (totalBattersFaced - runsAllowed) /
      //       (totalBattersFaced - totalHitsAllowed) :
      //       0;
      }

      // --- 打球方向（position）集計（カウントベース） ---
      const directionCounts = stats.hitDirectionCounts || {};
      const totalDirections =
      Object.values(directionCounts).reduce((sum, val) => sum + val, 0);
      const directionPercentages = {};
      for (const [dir, count] of Object.entries(directionCounts)) {
        directionPercentages[dir] = totalDirections > 0 ?
          count / totalDirections :
          0;
      }
      // adv.hitDirectionCounts = directionCounts;
      adv.hitDirectionPercentage = directionPercentages;

      // ① hitsに対する割合
      adv.hitBreakdown = {
        infieldHitsRate: hits > 0 ? stats.totalInfieldHits / hits : 0,
        oneBaseHitsRate: hits > 0 ? stats.total1hits / hits : 0,
        twoBaseHitsRate: hits > 0 ? stats.total2hits / hits : 0,
        threeBaseHitsRate: hits > 0 ? stats.total3hits / hits : 0,
        homeRunsRate: hits > 0 ? stats.totalHomeRuns / hits : 0,
      };

      // ② 四球・死球の割合
      adv.walkHitByPitchRate = {
        fourBallsRate: totalBats > 0 ? stats.totalFourBalls / totalBats : 0,
        hitByPitchRate: totalBats > 0 ? stats.totalHitByAPitch / totalBats : 0,
      };

      // ③ 三振の内訳
      adv.strikeoutBreakdown = {
        swinging: totalStrikeouts > 0 ?
        stats.totalSwingingStrikeouts / totalStrikeouts : 0,
        overlooking: totalStrikeouts > 0 ?
        stats.totalOverlookStrikeouts / totalStrikeouts : 0,
        swingAway: totalStrikeouts > 0 ?
        stats.totalSwingAwayStrikeouts / totalStrikeouts : 0,
        threeBuntFail: totalStrikeouts > 0 ?
        stats.totalThreeBuntFailures / totalStrikeouts : 0,
      };

      // ⑤ アウト内訳
      adv.outBreakdown = {
        grounderRate: stats.totalOuts > 0 ?
        stats.totalGrounders / stats.totalOuts : 0,
        linerRate: stats.totalOuts > 0 ?
        stats.totalLiners / stats.totalOuts : 0,
        flyBallRate: stats.totalOuts > 0 ?
        stats.totalFlyBalls / stats.totalOuts : 0,
        doublePlayRate: stats.totalOuts > 0 ?
        stats.totalDoublePlays / stats.totalOuts : 0,
        errorReachRate: stats.totalOuts > 0 ?
        stats.totalErrorReaches / stats.totalOuts : 0,
        interferenceRate: stats.totalOuts > 0 ?
        stats.totalInterferences / stats.totalOuts : 0,
        buntOutsRate: stats.totalOuts > 0 ?
        stats.totalBuntOuts / stats.totalOuts : 0,
      };

      // advancedStatsとして保存
      await db
          .collection("users")
          .doc(uid)
          .collection("stats")
          .doc(statDocIds[i])
          .set({advancedStats: adv}, {merge: true});
    }
    res.status(200).send("Advanced stats calculated and saved.");
  } catch (err) {
    console.error("Error in calculateAdvancedStats:", err);
    res.status(500).send("Internal error in calculateAdvancedStats");
  }
});

// Cloud Function: updateTeamAndLocationStats
export const updateTeamAndLocationStats = onRequest(async (req, res) => {
  const {uid, gameId} = req.body;

  if (!uid || !gameId) {
    res.status(400).send("Missing uid or gameId");
    return;
  }

  try {
    const gameRef =
    db.collection("users").doc(uid).collection("games").doc(gameId);
    const gameSnap = await gameRef.get();

    if (!gameSnap.exists) {
      res.status(404).send("Game data not found");
      return;
    }

    const gameData = gameSnap.data();
    const opponent = gameData.opponent || "unknown";
    const location = gameData.location || "unknown";

    // opponentごと・locationごとに別々に統計保存
    await updateStatsFor(uid, `team_${opponent}`, gameData);
    await updateStatsFor(uid, `location_${location}`, gameData);

    res.status(200).send("Team and location stats updated.");
  } catch (err) {
    console.error("Error updating stats:", err);
    res.status(500).send("Error updating stats");
  }
});

/**
 * 与えられた gameData に基づき、指定されたドキュメント（チーム or 球場）へ統計を加算保存する
 * @param {string} uid - ユーザーID
 * @param {string} docId - 保存先ドキュメントID（例: team_〇〇, location_〇〇）
 * @param {Object} gameData - ゲームデータ
 */
async function updateStatsFor(uid, docId, gameData) {
  const statsRef =
    db.collection("users").doc(uid).collection("teamLocationStats").doc(docId);

  await db.runTransaction(async (transaction) => {
    const statsDoc = await transaction.get(statsRef);
    const currentStats = statsDoc.exists ? statsDoc.data() : {};

    const pitchingDocs = [gameData];
    const fieldingDocs = [gameData];

    const updatedStats = calculateUpdatedStatistics(
        currentStats,
        gameData,
        pitchingDocs,
        fieldingDocs,
    );

    transaction.set(statsRef, updatedStats, {merge: true});
  });
}

// チームデータ
/**
 * チームのゲームデータをFirestoreに保存するCloud Function
 * @param {Object} request - onCallリクエストオブジェクト
 * @return {Object} 保存成功・失敗のメッセージ
 */
export const saveTeamGameData = onCall(async (request) => {
  console.log("saveTeamGameData function is triggered");

  // Use request.data throughout
  console.log("Received data:", safeStringify(request.data));

  const data = request.data;
  const teamId = data.teamId;
  const games = data.games;
  // teamId と games が正しく取り出せるか確認
  console.log("Received teamId:", teamId);
  console.log("Received games:", games);

  try {
    // 入力データのバリデーション
    if (!teamId || typeof teamId !== "string") {
      console.error("Invalid teamId:", teamId);
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Team ID is required and must be a string.",
      );
    }

    if (!games || !Array.isArray(games)) {
      console.error("Invalid games:", games);
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Games must be a valid array of game objects.",
      );
    }
  } catch (e) {
    console.error("Validation error:", e);
    throw new functions.https.HttpsError(
        "internal", "Failed to save team data",
    );
  }

  try {
    const firestore = db;
    const teamGamesRef =
      firestore.collection("teams").doc(teamId).collection("team_games");
    const statsRef =
      firestore.collection("teams").doc(teamId).collection("stats");

    console.log("Firestore references initialized");

    // バッチ書き込みにおける処理分割
    const writeBatchWithLimit = async (batchOps) => {
      let batch = firestore.batch();
      let operationCount = 0;

      for (const op of batchOps) {
        op(batch);
        operationCount++;

        if (operationCount === 500) {
          await batch.commit();
          batch = firestore.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }
    };

    const batchOps = [];

    // 各ゲームデータをFirestoreに追加
    for (const game of games) {
      const gameRef = teamGamesRef.doc();
      const gameDate = new Date(game.game_date);
      const gameDateJST = new Date(
          gameDate.getFullYear(),
          gameDate.getMonth(),
          gameDate.getDate(),
          0, 0, 0,
      );
      const gameDateUTC = new Date(Date.UTC(
          gameDateJST.getFullYear(),
          gameDateJST.getMonth(),
          gameDateJST.getDate(),
          0, 0, 0,
      ));

      console.log("Processing game data:", game);
      console.log("JST Date:", gameDateJST);
      console.log("UTC Date:", gameDateUTC);

      // --- Win streak tracking per game ---
      // Inserted win streak logic here (per instructions)
      const teamDocRef = firestore.collection("teams").doc(teamId);
      const teamDoc = await teamDocRef.get();
      const teamData = teamDoc.exists ? teamDoc.data() : {};
      let currentStreak = teamData.currentWinStreak || 0;
      let maxStreak = teamData.maxWinStreak || 0;
      let maxStreakYear = teamData.maxWinStreakYear || null;

      if (game.result === "勝利") {
        currentStreak += 1;
      } else {
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
          maxStreakYear = gameDateJST.getFullYear();
        }
        currentStreak = 0;
      }

      await teamDocRef.set({
        currentWinStreak: currentStreak,
        maxWinStreak: maxStreak,
        maxWinStreakYear: maxStreakYear,
      }, {merge: true});
      // --- End win streak tracking per game ---

      batchOps.push((batch) => {
        batch.set(gameRef, {
          game_date: Timestamp.fromDate(gameDateUTC),
          location: game.location || "",
          opponent: game.opponent || "",
          game_type: game.game_type || "",
          score: typeof game.score === "object" ?
            parseInt(game.score.value || 0) :
            Number(game.score) || 0,
          runs_allowed: typeof game.runs_allowed === "object" ?
            parseInt(game.runs_allowed.value || 0) :
            Number(game.runs_allowed) || 0,
          result: game.result || "",
        });
      });

      const year = gameDateJST.getFullYear();
      const month = gameDateJST.getMonth() + 1;
      const gameType = game.game_type || "unknown";

      const categories = [
        "results_stats_all",
        `results_stats_${year}_${month}`,
        `results_stats_${year}_${month}_${gameType}`,
        `results_stats_${year}_${gameType}_all`,
        `results_stats_${gameType}_all`,
        `results_stats_${year}_all`,
      ];

      for (const categoryPath of categories) {
        const statsDocRef = statsRef.doc(categoryPath);

        batchOps.push(async (batch) => {
          await firestore.runTransaction(async (transaction) => {
            const statsDoc = await transaction.get(statsDocRef);
            const currentStats = statsDoc.exists ? statsDoc.data() : {};

            const normalizedScore = typeof game.score === "object" ?
              parseInt(game.score.value || 0) :
              Number(game.score) || 0;
            const normalizedRunsAllowed =
            typeof game.runs_allowed === "object" ?
              parseInt(game.runs_allowed.value || 0) :
              Number(game.runs_allowed) || 0;

            const updatedStats = {
              totalGames: (currentStats.totalGames || 0) + 1,
              totalWins: (currentStats.totalWins || 0) +
                (game.result === "勝利" ? 1 : 0),
              totalLosses: (currentStats.totalLosses || 0) +
                (game.result === "敗北" ? 1 : 0),
              totalDraws: (currentStats.totalDraws || 0) +
                (game.result === "引き分け" ? 1 : 0),
              totalScore:
                Number(currentStats.totalScore || 0) +
                normalizedScore,
              totalRunsAllowed:
                Number(currentStats.totalRunsAllowed || 0) +
                normalizedRunsAllowed,
            };

            if (currentStats.gameDate) {
              const currentGameDate = currentStats.gameDate.toDate();
              if (currentGameDate >= gameDateJST) {
                updatedStats.gameDate = Timestamp.fromDate(gameDateJST);
              }
            } else {
              updatedStats.gameDate = Timestamp.fromDate(gameDateJST);
            }

            updatedStats.winRate = updatedStats.totalWins /
              (updatedStats.totalGames - updatedStats.totalDraws || 1);

            transaction.set(statsDocRef, updatedStats, {merge: true});
          });
        });
      }
    }

    // バッチ書き込みを実行
    await writeBatchWithLimit(batchOps);

    // Cloud Tasks による統計集計リクエスト（チームの相手別・場所別）
    const queue = "team-summary-stats-queue"; // Cloud Tasks のキュー名（あとで作成）
    const url = "https://updateTeamOpponentAndLocationStats-etndg3x4ra-uc.a.run.app";

    const payload = {teamId};

    const parent = client.queuePath(project, location, queue);
    const task = {
      httpRequest: {
        httpMethod: "POST",
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: Buffer.from(JSON.stringify(payload)).toString("base64"),
      },
    };

    await client.createTask({parent, task});

    return {
      success: true,
      message: "Games successfully saved and stats updated.",
    };
  } catch (error) {
    console.error("Error saving games:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to save games: " + error.message,
    );
  }
});

// チーム試合保存したら発火
export const updateTeamOpponentAndLocationStats =
onRequest(async (req, res) => {
  const {teamId} = req.body;

  if (!teamId) {
    res.status(400).send("Missing teamId");
    return;
  }

  try {
    const gamesSnap = await db.collection("teams").doc(teamId)
        .collection("team_games").get();

    const opponentStats = {};
    const locationStats = {};

    gamesSnap.forEach((doc) => {
      const game = doc.data();
      const {
        opponent = "unknown",
        location = "unknown",
        score = 0,
        runs_allowed: runsAllowed = 0,
        result = "",
      } = game;

      const update = (obj) => {
        obj.totalGames = (obj.totalGames || 0) + 1;
        obj.totalScore = (obj.totalScore || 0) + score;
        obj.totalRunsAllowed = (obj.totalRunsAllowed || 0) + runsAllowed;
        obj.totalWins = (obj.totalWins || 0) + (result === "勝利" ? 1 : 0);
        obj.totalLosses = (obj.totalLosses || 0) + (result === "敗北" ? 1 : 0);
        obj.totalDraws = (obj.totalDraws || 0) + (result === "引き分け" ? 1 : 0);
      };

      opponentStats[opponent] = opponentStats[opponent] || {};
      locationStats[location] = locationStats[location] || {};
      update(opponentStats[opponent]);
      update(locationStats[location]);
    });

    const saveStats = async (base, statsMap) => {
      for (const key in statsMap) {
        if (Object.prototype.hasOwnProperty.call(statsMap, key)) {
          const ref = db.collection("teams").doc(teamId)
              .collection("summary_stats").doc(`${base}_${key}`);

          const stats = statsMap[key];
          stats.winRate =
          stats.totalWins / (stats.totalGames - stats.totalDraws || 1);

          await ref.set(stats, {merge: true});
        }
      }
    };

    await Promise.all([
      saveStats("opponent", opponentStats),
      saveStats("location", locationStats),
    ]);

    res.status(200).send("Opponent and location stats updated.");
  } catch (err) {
    console.error("Error updating team stats:", err);
    res.status(500).send("Error updating stats");
  }
});

// 毎日サブスク確認
export const checkSubscriptionExpiry = onSchedule(
    {
      schedule: "0 0 * * *", // 毎日1:00AM
      timeZone: "Asia/Tokyo",
      timeoutSeconds: 1800,
    },
    async () => {
      console.log("🔄 サブスクの有効期限チェック開始");

      const usersSnapshot = await db.collection("users").get();

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const subscriptionRef =
      db.collection("users").doc(userId).collection("subscription");

        const subsSnapshot = await subscriptionRef.get();

        for (const subDoc of subsSnapshot.docs) {
          const subData = subDoc.data();

          let expiryDate = null;
          if (
            subData.expiryDate &&
            typeof subData.expiryDate.toDate === "function"
          ) {
            expiryDate = subData.expiryDate.toDate();
          }

          if (expiryDate && expiryDate < new Date()) {
            await subDoc.ref.update({status: "inactive"});
            console.log(`❌ サブスク期限切れ: ${userId} - ${subDoc.id}`);
          }
        }
      }

      console.log("✅ サブスクの有効期限チェック完了");
    },
);

// 毎日チームサブスク確認
export const checkTeamSubscriptionExpiry = onSchedule(
    {
      schedule: "0 1 * * *", // 毎日2:00AM
      timeZone: "Asia/Tokyo",
      timeoutSeconds: 1800,
    },
    async () => {
      console.log("🔄 チームサブスクの有効期限チェック開始");

      const teamSnapshot = await db.collection("teams").get();

      for (const teamDoc of teamSnapshot.docs) {
        const teamId = teamDoc.id;
        const subscriptionRef =
        db.collection("teams").doc(teamId).collection("subscription");

        const subsSnapshot = await subscriptionRef.get();

        for (const subDoc of subsSnapshot.docs) {
          const subData = subDoc.data();

          let expiryDate = null;
          if (
            subData.expiryDate &&
          typeof subData.expiryDate.toDate === "function"
          ) {
            expiryDate = subData.expiryDate.toDate();
          }

          if (expiryDate && expiryDate < new Date()) {
            await subDoc.ref.update({status: "inactive"});
            console.log(`❌ チームサブスク期限切れ: ${teamId} - ${subDoc.id}`);
          }
        }
      }

      console.log("✅ チームサブスクの有効期限チェック完了");
    },
);

// 週一チーム成績
const gradesQueue = "team-grades-queue"; // 使用するキューの名前
const gradesUrl = "https://processteamstats-etndg3x4ra-uc.a.run.app";

export const weeklyTeamStatsBatch = onSchedule(
    {
      schedule: "0 0 * * 1", // 毎週月曜日の午前0時に実行
      timeZone: "Asia/Tokyo", // 日本時間でスケジュール
      timeoutSeconds: 1800,
    },
    async () => {
      console.log("Starting weekly batch process...");

      try {
        const teamsSnapshot = await db.collection("teams").get();
        console.log(`Found ${teamsSnapshot.size} teams to process.`);

        for (const teamDoc of teamsSnapshot.docs) {
          const teamID = teamDoc.id;

          // Cloud Tasks にタスクをスケジュール
          await scheduleTeamProcessing(teamID);
        }

        console.log("Weekly team stats batch completed successfully.");
      } catch (error) {
        console.error("Error in weekly team stats batch:", error);
      }
    },
);

/**
 * Cloud Tasks でチームの処理タスクをスケジュールする
 * @param {string} teamID チームのID
 */
async function scheduleTeamProcessing(teamID) {
  console.log("🔥 Project ID:", project);
  if (!project) {
    console.error("Error: `project` is undefined. Check Firebase config.");
    return;
  }
  if (! gradesQueue) {
    console.error("Error: gradesQueue` is undefined. Check gradesQueue name.");
    return;
  }

  try {
    // Cloud Tasks のキューのパスを取得
    const parent = client.queuePath(project, location, gradesQueue);
    console.log("✅ Using Cloud Tasks gradesQueue path:", parent);

    const task = {
      httpRequest: {
        httpMethod: "POST",
        url: gradesUrl,
        headers: {
          "Content-Type": "application/json",
        },
        body: Buffer.from(JSON.stringify({teamID})),
      },
      scheduleTime: {
        seconds: Date.now() / 1000 + 10, // 10秒後に実行
      },
    };
    console.log("🚀 Creating task:", task);

    // Cloud Tasks にタスクを作成
    const [response] = await client.createTask({parent, task});

    console.log("✅ Task scheduled for team:",
        teamID, "Task name:", response.name);
  } catch (error) {
    console.error("🚨 Error creating task:", error);
  }
}

// チームの統計処理を実行
export const processTeamStats = onRequest(
    {
      timeoutSeconds: 1800,
    },
    async (req, res) => {
      console.log("🚀 Received request on processTeamStats");

      const {teamID} = req.body;
      console.log(`Processing team stats for team: ${teamID}`);

      try {
        const teamDoc = await db.collection("teams").doc(teamID).get();
        const teamData = teamDoc.data();

        if (!teamData) {
          return res.status(404).send(`Team ${teamID} not found.`);
        }

        const userIDs = teamData.members || [];
        if (userIDs.length === 0) {
          console.log(`Found 0 members for team ${teamID}. Skipping...`);
          return res.status(200)
              .send(`No members to process for team ${teamID}`);
        }

        const teamStats = {}; // チーム統計データの集計用オブジェクト

        // ユーザーデータの取得
        for (const userID of userIDs) {
          const userDoc = await db.collection("users").doc(userID).get();
          const userData = userDoc.data();

          if (!userData) {
            console.warn(`No data found for user ${userID}. Skipping...`);
            continue;
          }

          const isPitcher =
          userData.positions && userData.positions.includes("投手");

          // 個人統計を取得
          const statsSnapshot =
       await db.collection("users").doc(userID).collection("stats").get();

          for (const statsDoc of statsSnapshot.docs) {
            const statsData = statsDoc.data();
            const categoryPath = statsDoc.id;

            // チーム統計に集計
            if (!teamStats[categoryPath]) {
              teamStats[categoryPath] = initializeStats(); // 初期化
            }

            aggregateStats(teamStats[categoryPath], statsData, isPitcher);
          }
        }

        const teamStatsCollectionRef =
    db.collection("teams").doc(teamID).collection("stats");
        await saveWithBatch(teamStats, teamStatsCollectionRef);
        // チームごとの統計処理の後、すべてのチームの統計統合が完了した後に呼び出す
        console.log(
            "now calculating advanced team stats...",
        );
        await calculateAdvancedTeamStats();
        // 週次目標進捗確認タスクをエンキュー
        await enqueueWeeklyGoalProgressTask(teamID);

        console.log(`✅ Successfully processed stats for team ${teamID}`);
        return res.status(200).send(
            `Successfully processed stats for team ${teamID}`);
      } catch (error) {
        console.error("Error processing team stats:", error);

        if (!res.headersSent) {
          return res.status(500).send("Failed to process team stats.");
        }
      }
    });

/**
 * Firestore にバッチ保存を行う
 * @param {Object} statsData 統計データ
 * @param {Object} collectionRef Firestoreのコレクション参照
 */
async function saveWithBatch(statsData, collectionRef) {
  let batch = db.batch();
  let operationCount = 0;

  for (const [categoryPath, stats] of Object.entries(statsData)) {
    const docRef = collectionRef.doc(categoryPath);
    batch.set(docRef, stats, {merge: true});
    operationCount++;

    if (operationCount === 500) {
      await batch.commit(); // 500件でバッチをコミット
      batch = db.batch(); // 新しいバッチを開始
      operationCount = 0; // カウントリセット
    }
  }

  if (operationCount > 0) {
    await batch.commit(); // 残りのデータをコミット
  }
}

/**
 * 統計データを初期化
 * @return {Object} 初期化された統計データ
 */
function initializeStats() {
  return {
    atBats: 0,
    hits: 0,
    totalBats: 0,
    battingAverage: 0,
    total1hits: 0,
    totalInfieldHits: 0,
    total2hits: 0,
    total3hits: 0,
    totalHomeRuns: 0,
    totalRbis: 0,
    totalSteals: 0,
    totalAllBuntSuccess: 0,
    totalThreeBuntFailures: 0,
    totalStolenBaseAttempts: 0,
    totalThreeBuntMissFailures: 0,
    totalThreeBuntFoulFailures: 0,
    totalBuntSuccesses: 0,
    totalBuntFailures: 0,
    totalBuntDoublePlays: 0,
    totalSacrificeFly: 0,
    totalFourBalls: 0,
    totalHitByAPitch: 0,
    totalStrikeouts: 0,
    totalDoublePlays: 0,
    sluggingPercentage: 0,
    onBasePercentage: 0,
    fieldingPercentage: 0,
    totalAssists: 0,
    totalPutouts: 0,
    totalErrors: 0,
    era: 0,
    totalPStrikeouts: 0,
    totalInningsPitched: 0,
    totalBattersFaced: 0,
    totalHitByPitch: 0,
    totalWalks: 0,
    totalHitsAllowed: 0,
    totalSwingingStrikeouts: 0,
    totalOverlookStrikeouts: 0,
    totalSwingAwayStrikeouts: 0,
    totalGrounders: 0,
    totalLiners: 0,
    totalFlyBalls: 0,
    totalErrorReaches: 0,
    totalInterferences: 0,
    totalOuts: 0,
    totalEarnedRuns: 0,
    totalBuntOuts: 0,
    totalCaughtStealing: 0,
    hitDirectionCounts: {},
    hitDirectionDetails: {},
    buntDirectionCounts: {
      sacSuccess: {},
      sacFail: {},
      squeezeSuccess: {},
      squeezeFail: {},
      threeBuntFoulFail: {},
      threeBuntMissFail: {},
    },
    batterPitchCount: 0,
    totalstealsAttempts: 0,
    totalPitchCount: 0,

    swingCount: 0,
    missSwingCount: 0,
    firstPitchSwingCount: 0,
    firstPitchSwingHits: 0,
    totalStrikeInterferences: 0,
    totalRuns: 0,
    totalBases: 0,
    totalStarts: 0,
    qualifyingStarts: 0,
    ops: 0,
    rc: 0,
    totalBuntAttempts: 0,
    sacFlyDirectionCounts: {},
    totalHomeRunsAllowed: 0,
  };
}

/**
 * 統計データを集計する
 * @param {Object} teamStats チームの統計データ
 * @param {Object} userStats ユーザーの統計データ
 * @param {boolean} isPitcher 投手かどうか
 */
function aggregateStats(teamStats, userStats, isPitcher) {
  teamStats.atBats += userStats.atBats || 0;
  teamStats.hits += userStats.hits || 0;
  teamStats.totalBats += userStats.totalBats || 0;
  teamStats.battingAverage = teamStats.atBats > 0 ?
    teamStats.hits / teamStats.atBats :
    0;
  teamStats.total1hits += userStats.total1hits || 0;
  teamStats.totalInfieldHits += userStats.totalInfieldHits || 0;
  teamStats.total2hits += userStats.total2hits || 0;
  teamStats.total3hits += userStats.total3hits || 0;
  teamStats.totalHomeRuns += userStats.totalHomeRuns || 0;
  teamStats.totalRbis += userStats.totalRbis || 0;
  teamStats.totalSteals += userStats.totalSteals || 0;
  teamStats.totalAllBuntSuccess += userStats.totalAllBuntSuccess|| 0;
  teamStats.totalSacrificeFly += userStats.totalSacrificeFly || 0;
  teamStats.totalFourBalls += userStats.totalFourBalls || 0;
  teamStats.totalHitByAPitch += userStats.totalHitByAPitch || 0;
  teamStats.totalStrikeouts += userStats.totalStrikeouts || 0;
  teamStats.totalDoublePlays += userStats.totalDoublePlays || 0;
  teamStats.totalBuntOuts += userStats.totalBuntOuts || 0;
  teamStats.totalThreeBuntFailures += userStats.totalThreeBuntFailures || 0;
  teamStats.totalStolenBaseAttempts += userStats.totalStolenBaseAttempts || 0;
  teamStats.totalCaughtStealing += userStats.totalCaughtStealing || 0;
  teamStats.onBasePercentage =
    (teamStats.hits + teamStats.totalFourBalls +
      teamStats.totalHitByAPitch) > 0 ?
      (teamStats.hits + teamStats.totalFourBalls + teamStats.totalHitByAPitch) /
      (teamStats.atBats + teamStats.totalFourBalls +
        teamStats.totalHitByAPitch + teamStats.totalSacrificeFly) :
      0;
  const totalBases =
    teamStats.totalInfieldHits +
    teamStats.total1hits +
    (teamStats.total2hits * 2) +
    (teamStats.total3hits * 3) +
    (teamStats.totalHomeRuns * 4);

  teamStats.sluggingPercentage = teamStats.atBats > 0 ?
    totalBases / teamStats.atBats :
    0;

  const totalChances =
    teamStats.totalPutouts + teamStats.totalAssists +
    teamStats.totalErrors;
  teamStats.fieldingPercentage = totalChances > 0 ?
    (teamStats.totalPutouts + teamStats.totalAssists) / totalChances :
    0;

  teamStats.totalAssists += userStats.totalAssists || 0;
  teamStats.totalPutouts += userStats.totalPutouts || 0;
  teamStats.totalErrors += userStats.totalErrors || 0;
  teamStats.totalSwingingStrikeouts += userStats.totalSwingingStrikeouts || 0;
  teamStats.totalOverlookStrikeouts += userStats.totalOverlookStrikeouts || 0;
  teamStats.totalSwingAwayStrikeouts += userStats.totalSwingAwayStrikeouts || 0;
  teamStats.totalGrounders += userStats.totalGrounders || 0;
  teamStats.totalLiners += userStats.totalLiners || 0;
  teamStats.totalFlyBalls += userStats.totalFlyBalls || 0;
  teamStats.totalErrorReaches += userStats.totalErrorReaches || 0;
  teamStats.totalInterferences += userStats.totalInterferences || 0;
  teamStats.totalOuts += userStats.totalOuts || 0;

  teamStats.batterPitchCount += userStats.batterPitchCount || 0;
  teamStats.totalstealsAttempts += userStats.totalstealsAttempts || 0;
  teamStats.totalPitchCount += userStats.totalPitchCount || 0;
  teamStats.totalBuntAttempts += userStats.totalBuntAttempts || 0;
  teamStats.totalHomeRunsAllowed += userStats.totalHomeRunsAllowed || 0;

  teamStats.totalThreeBuntMissFailures +=
  userStats.totalThreeBuntMissFailures || 0;
  teamStats.totalThreeBuntFoulFailures +=
  userStats.totalThreeBuntFoulFailures || 0;
  teamStats.totalBuntSuccesses += userStats.totalBuntSuccesses || 0;
  teamStats.totalBuntFailures += userStats.totalBuntFailures || 0;
  teamStats.totalBuntDoublePlays += userStats.totalBuntDoublePlays || 0;
  teamStats.swingCount += userStats.swingCount || 0;
  teamStats.missSwingCount += userStats.missSwingCount || 0;
  teamStats.firstPitchSwingCount += userStats.firstPitchSwingCount || 0;
  teamStats.firstPitchSwingHits += userStats.firstPitchSwingHits || 0;
  teamStats.totalStrikeInterferences += userStats.totalStrikeInterferences || 0;
  teamStats.totalRuns += userStats.totalRuns || 0;
  teamStats.totalBases += userStats.totalBases || 0;
  teamStats.totalStarts += userStats.totalStarts || 0;
  teamStats.qualifyingStarts += userStats.qualifyingStarts || 0;

  teamStats.catcherStealingRate = teamStats.totalStolenBaseAttempts > 0 ?
    teamStats.totalCaughtStealing / teamStats.totalStolenBaseAttempts :
    0;

  // OPSの計算
  teamStats.ops =
    (teamStats.onBasePercentage || 0) + (teamStats.sluggingPercentage || 0);

  // RCの計算（分母が0のときは0）
  const rcDenominator =
  (teamStats.totalBats || 0) + (teamStats.totalFourBalls || 0);
  teamStats.rc = rcDenominator > 0 ?
    ((teamStats.hits || 0) + (teamStats.totalFourBalls || 0)) *
    (teamStats.totalBases || 0) / rcDenominator :
    0;

  // --- sacFlyDirectionCounts
  teamStats.sacFlyDirectionCounts = teamStats.sacFlyDirectionCounts || {};
  for (
    const [pos, count] of Object.entries(userStats.sacFlyDirectionCounts || {})
  ) {
    teamStats.sacFlyDirectionCounts[pos] =
      (teamStats.sacFlyDirectionCounts[pos] || 0) + count;
  }

  if (isPitcher) {
    teamStats.totalPStrikeouts += userStats.totalPStrikeouts || 0;
    teamStats.totalInningsPitched =
      (teamStats.totalInningsPitched || 0) +
      (userStats.totalInningsPitched || 0);
    teamStats.totalBattersFaced += userStats.totalBattersFaced || 0;
    teamStats.totalHitByPitch += userStats.totalHitByPitch || 0;
    teamStats.totalWalks += userStats.totalWalks || 0;
    teamStats.totalHitsAllowed += userStats.totalHitsAllowed || 0;
    teamStats.totalEarnedRuns += userStats.totalEarnedRuns || 0;
    teamStats.era = teamStats.totalInningsPitched > 0 ?
      (teamStats.totalEarnedRuns / teamStats.totalInningsPitched) * 7 :
      0;
  }

  // --- hitDirectionCounts
  teamStats.hitDirectionCounts = teamStats.hitDirectionCounts || {};
  for (
    const [key, value] of Object.entries(userStats.hitDirectionCounts || {})
  ) {
    teamStats.hitDirectionCounts[key] =
    (teamStats.hitDirectionCounts[key] || 0) + value;
  }

  // --- hitDirectionDetails
  teamStats.hitDirectionDetails = teamStats.hitDirectionDetails || {};
  for (const [pos, resultCounts] of
    Object.entries(userStats.hitDirectionDetails || {})) {
    teamStats.hitDirectionDetails[pos] =
    teamStats.hitDirectionDetails[pos] || {};
    for (const [result, count] of Object.entries(resultCounts)) {
      teamStats.hitDirectionDetails[pos][result] =
      (teamStats.hitDirectionDetails[pos][result] || 0) + count;
    }
  }

  // --- buntDirectionCounts
  const buntKeys = [
    "sacSuccess", "sacFail", "squeezeSuccess",
    "squeezeFail", "threeBuntFoulFail", "threeBuntMissFail",
  ];
  teamStats.buntDirectionCounts = teamStats.buntDirectionCounts || {};
  for (const key of buntKeys) {
    teamStats.buntDirectionCounts[key] =
      teamStats.buntDirectionCounts[key] || {};
    const userMap = (userStats.buntDirectionCounts || {})[key] || {};
    for (const [pos, count] of Object.entries(userMap)) {
      teamStats.buntDirectionCounts[key][pos] =
        (teamStats.buntDirectionCounts[key][pos] || 0) + count;
    }
  }
}

/**
 * チーム統計ドキュメントを対象に、高度なスタッツを計算し保存します。
 * 事前に aggregateStats() による統合が完了している必要があります。
 */
async function calculateAdvancedTeamStats() {
  console.log("✅ calculateAdvancedTeamStats started");
  const teamsSnapshot = await db.collection("teams").get();

  for (const teamDoc of teamsSnapshot.docs) {
    const teamId = teamDoc.id;
    const statsSnapshot =
    await db.collection("teams").doc(teamId).collection("stats").get();

    for (const statsDoc of statsSnapshot.docs) {
      const stats = statsDoc.data() || {};
      const adv = {};

      const hits = stats.hits || 0;
      const totalBats = stats.totalBats || 0;
      const totalStrikeouts = stats.totalStrikeouts || 0;
      const totalOuts = stats.totalOuts || 0;
      const totalGames = stats.totalGames || 0;
      const totalPitchCount = stats.totalPitchCount || 0;
      const totalInningsPitched = stats.totalInningsPitched || 0;
      const totalBattersFaced = stats.totalBattersFaced || 0;
      const runsAllowed = stats.totalRunsAllowed || 0;
      const totalWalks = stats.totalWalks || 0;
      const totalHitByPitch = stats.totalHitByPitch || 0;
      const totalPStrikeouts = stats.totalPStrikeouts || 0;
      const totalHitsAllowed = stats.totalHitsAllowed || 0;
      const totalHomeRunsAllowed = stats.totalHomeRunsAllowed || 0;
      const totalSteals = stats.totalSteals || 0;
      const totalstealsAttempts = stats.totalstealsAttempts || 0;
      const totalBuntAttempts = stats.totalBuntAttempts || 0;
      const totalAllBuntSuccess = stats.totalAllBuntSuccess || 0;
      const atBats = stats.atBats || 0;
      const batterPitchCount = stats.batterPitchCount || 0;
      const homeRuns = stats.totalHomeRuns || 0;
      const sacrificeFly = stats.sacrificeFly || 0;
      const totalFourBalls = stats.totalFourBalls || 0;
      const totalHitByAPitch = stats.totalHitByPitch || 0;
      const totalStrikeInterferences = stats.totalStrikeInterferences || 0;
      const runs = stats.totalRuns || 0;
      const swingCount = stats.swingCount || 0;
      const missSwingCount = stats.missSwingCount || 0;
      const firstPitchSwingCount = stats.firstPitchSwingCount || 0;
      const firstPitchSwingHits = stats.firstPitchSwingHits || 0;
      const totalBases = stats.totalBases || 0;
      const totalStarts = stats.totalStarts || 0;
      const qualifyingStarts = stats.qualifyingStarts || 0;

      const directionCounts = stats.hitDirectionCounts || {};
      const totalDirections =
      Object.values(directionCounts).reduce((sum, val) => sum + val, 0);
      const directionPercentages = {};
      for (const [dir, count] of Object.entries(directionCounts)) {
        directionPercentages[dir] =
        totalDirections > 0 ? count / totalDirections : 0;
      }

      adv.hitDirectionPercentage = directionPercentages;
      adv.hitBreakdown = {
        infieldHitsRate: hits > 0 ? stats.totalInfieldHits / hits : 0,
        oneBaseHitsRate: hits > 0 ? stats.total1hits / hits : 0,
        twoBaseHitsRate: hits > 0 ? stats.total2hits / hits : 0,
        threeBaseHitsRate: hits > 0 ? stats.total3hits / hits : 0,
        homeRunsRate: hits > 0 ? stats.totalHomeRuns / hits : 0,
      };

      adv.strikeoutBreakdown = {
        swinging:
        totalStrikeouts >
        0 ? stats.totalSwingingStrikeouts / totalStrikeouts : 0,
        overlooking:
        totalStrikeouts >
        0 ? stats.totalOverlookStrikeouts / totalStrikeouts : 0,
        swingAway:
        totalStrikeouts >
        0 ? stats.totalSwingAwayStrikeouts / totalStrikeouts : 0,
        threeBuntFail:
        totalStrikeouts >
        0 ? stats.totalThreeBuntFailures / totalStrikeouts : 0,
      };
      adv.outBreakdown = {
        grounderRate: totalOuts > 0 ? stats.totalGrounders / totalOuts : 0,
        linerRate: totalOuts > 0 ? stats.totalLiners / totalOuts : 0,
        flyBallRate: totalOuts > 0 ? stats.totalFlyBalls / totalOuts : 0,
        doublePlayRate: totalOuts > 0 ? stats.totalDoublePlays / totalOuts : 0,
        errorReachRate: totalOuts > 0 ? stats.totalErrorReaches / totalOuts : 0,
        interferenceRate: totalOuts > 0 ?
        stats.totalInterferences / totalOuts : 0,
        buntOutsRate: totalOuts > 0 ? stats.totalBuntOuts / totalOuts : 0,
      };
      // 奪三振率１イニングあたり
      adv.pitcherStrikeoutsPerInning = totalInningsPitched > 0 ?
        totalPStrikeouts / totalInningsPitched : 0;
      // 奪三振率7イニングあたり
      adv.strikeoutsPerNineInnings = totalInningsPitched > 0 ?
        (totalPStrikeouts * 7) / totalInningsPitched : 0;
      // 被打率 本来は(四球・死球・犠打などは除いた「打数」**で割るのが理想的。)
      adv.battingAverageAllowed = totalBattersFaced > 0 ?
        totalHitsAllowed / totalBattersFaced : 0;
      // WHIP
      adv.whip = totalInningsPitched > 0 ?
        (totalWalks + totalHitsAllowed) / totalInningsPitched : 0;
      // QS
      adv.qsRate = totalStarts > 0 ? qualifyingStarts / totalStarts : 0;
      // 被本塁打率
      adv.homeRunRate = totalInningsPitched > 0 ?
        (totalHomeRunsAllowed / totalInningsPitched) * 7 : 0;
      // 平均球数（1人あたり）
      adv.avgPitchesPerBatter = totalBattersFaced > 0 ?
        totalPitchCount / totalBattersFaced : 0;
      // 平均球数（1試合あたり）
      adv.avgPitchesPerGame =
        totalGames > 0 ? totalPitchCount / totalGames : 0;

      // 1試合あたりの与死球・与四球
      adv.avgHitByPitchPerGame = totalGames > 0 ?
        stats.totalHitByPitch / totalGames : 0;
      adv.avgWalksPerGame = totalGames > 0 ? totalWalks / totalGames : 0;

      // 1試合あたりの打者数
      adv.avgBattersFacedPerGame = totalGames > 0 ?
        totalBattersFaced / totalGames : 0;

      // 1試合あたりの失点
      adv.avgRunsAllowedPerGame = totalGames >
        0 ? runsAllowed / totalGames : 0;

      // 投手：被打率（打者1人あたりの被安打率）
      adv.battingAverageAllowed =
      totalBattersFaced > 0 ? totalHitsAllowed / totalBattersFaced : 0;

      // 試合平均の対戦打者数（投手のイニング消化力）
      adv.avgBattersFacedPerGame =
      totalGames > 0 ? totalBattersFaced / totalGames : 0;
      // 試合平均の失点（防御力の指標）
      adv.avgRunsAllowedPerGame = totalGames > 0 ? runsAllowed / totalGames : 0;

      // LOB率：走者をどれだけ残塁させたか（＝失点を防げたか）
      const runnersOnBase = totalHitsAllowed + totalWalks + totalHitByPitch;
      const adjustedDenominator = runnersOnBase - (1.4 * totalHomeRunsAllowed);
      adv.lobRate =
      adjustedDenominator > 0 ?
      (runnersOnBase - runsAllowed) / adjustedDenominator : 0;

      // 打者1人あたりの投球数（球数の多さや無駄の指標）
      adv.avgPitchesPerBatter =
      totalBattersFaced > 0 ? totalPitchCount / totalBattersFaced : 0;
      // 試合あたりの平均投球数（スタミナ消費・球数管理）
      adv.avgPitchesPerGame = totalGames > 0 ? totalPitchCount / totalGames : 0;
      // 盗塁成功率（走塁の積極性と成功精度）
      adv.stealSuccessRate =
      totalstealsAttempts > 0 ? totalSteals / totalstealsAttempts : 0;
      // バント成功率（戦術実行力）
      adv.buntSuccessRate =
      totalBuntAttempts > 0 ? totalAllBuntSuccess / totalBuntAttempts : 0;
      // 三振率（打席あたりの三振の割合）
      adv.strikeoutRate = atBats > 0 ? totalStrikeouts / atBats : 0;

      // 1試合あたりの与死球・与四球
      adv.avgHitByPitchPerGame = totalGames > 0 ?
        stats.totalHitByPitch / totalGames : 0;
      adv.avgWalksPerGame = totalGames > 0 ? totalWalks / totalGames : 0;

      // 被本塁打率
      adv.homeRunRate = totalInningsPitched > 0 ?
        (totalHomeRunsAllowed / totalInningsPitched) * 7 : 0;

      // 打者
      // 平均球数
      adv.avgPitchesPerAtBat = totalBats > 0 ? batterPitchCount / totalBats : 0;
      // BABIP
      adv.babip =
        (atBats - totalStrikeouts - homeRuns + sacrificeFly) > 0 ?
          (hits - homeRuns) /
          (atBats - totalStrikeouts - homeRuns + sacrificeFly) :
          0;
      // BB/K
      adv.bbPerK = totalStrikeouts > 0 ? totalFourBalls / totalStrikeouts : 0;
      // ISO
      adv.iso = atBats > 0 ? (totalBases / atBats) - (hits / atBats) : 0;

      // 三振率
      adv.strikeoutRate = atBats > 0 ? totalStrikeouts / atBats : 0;
      // 出塁後得点率
      const onBaseCount =
      hits + totalFourBalls + totalHitByAPitch + totalStrikeInterferences;
      adv.runAfterOnBaseRate = onBaseCount > 0 ? runs / onBaseCount : 0;
      // 初球スイング率
      adv.firstPitchSwingRate =
      totalBats > 0 ? firstPitchSwingCount / totalBats : 0;
      // 初球打率成功率 (firstPitchSwingHitsがなければ0)
      const safeFirstPitchSwingHits = firstPitchSwingHits || 0;
      adv.firstPitchSwingSuccessRate =
      firstPitchSwingCount > 0 ?
      safeFirstPitchSwingHits / firstPitchSwingCount : 0;
      // 初球ヒット率（firstPitchHitRate）: 全打席に対する初球ヒット割合
      adv.firstPitchHitRate =
      totalBats > 0 ? firstPitchSwingHits / totalBats : 0;
      // バント成功率
      adv.buntSuccessRate =
      totalBuntAttempts > 0 ? totalAllBuntSuccess / totalBuntAttempts : 0;
      // スイング率
      adv.swingRate = batterPitchCount > 0 ? swingCount / batterPitchCount : 0;
      // 空振り率
      adv.missSwingRate = swingCount > 0 ? missSwingCount / swingCount : 0;

      // 四球・死球の割合
      adv.walkHitByPitchRate = {
        fourBallsRate: totalBats > 0 ? stats.totalFourBalls / totalBats : 0,
        hitByPitchRate: totalBats > 0 ? stats.totalHitByAPitch / totalBats : 0,
      };

      await db.collection("teams").doc(teamId)
          .collection("stats").doc(statsDoc.id).update({
            advancedStats: adv,
          });
      console.log(
          `✅ saved advanced stats for team ${teamId}, doc ${statsDoc.id}`,
      );
    }
  }
}

// ユーザー目標更新
export const userGoalProgressHandler = onRequest(async (req, res) => {
  try {
    const {uid} = req.body;
    if (!uid) {
      res.status(400).send("Missing uid");
      return;
    }

    await userGoalProgressUpdate(uid);
    res.status(200).send("User goal progress updated");
  } catch (error) {
    functions.logger.error("userGoalProgressHandler Error:", error);
    res.status(500).send("Internal Server Error");
  }
});

const userGoalQueue = "user-goal-queue";
export const enqueueUserGoalProgressTask = async (uid) => {
  const task = {
    httpRequest: {
      httpMethod: "POST",
      url: "https://usergoalprogresshandler-etndg3x4ra-uc.a.run.app",
      headers: {
        "Content-Type": "application/json",
      },
      body: Buffer.from(JSON.stringify({uid})).toString("base64"),
    },
  };

  const parent = client.queuePath(project, location, userGoalQueue);
  await client.createTask({parent, task});
};


export const userGoalProgressUpdate = async (uid) => {
  const today = new Date();

  const goalsSnapshot =
  await db.collection("users").doc(uid).collection("goals").get();

  if (goalsSnapshot.empty) return;

  const updates = [];


  for (const doc of goalsSnapshot.docs) {
    const goal = doc.data();
    const goalId = doc.id;

    console.log(`⚙️ Checking goal: ${goalId}`);

    if (goal.statField === "custom") {
      console.log(`⏭ Skipping custom goal: ${goalId}`);
      continue;
    }

    if (!goal.period || !goal.statField || !goal.compareType || !goal.target) {
      console.log(`⏭ Skipping due to missing field:`, goal);
      continue;
    }

    const deadlineRaw = goal.deadline || goal.endDate;
    const deadlineDate =
    deadlineRaw.toDate ? deadlineRaw.toDate() : new Date(deadlineRaw);
    deadlineDate.setHours(23, 59, 59, 999);
    if (deadlineDate < today) {
      console.log(`⏭ Skipping due to past deadline: ${deadlineRaw}`);
      continue;
    }

    const year = deadlineDate.getFullYear();
    const month = (deadlineDate.getMonth() + 1).toString();

    let statsDocPath = "";
    if (goal.period === "year") {
      statsDocPath = `users/${uid}/stats/results_stats_${year}_all`;
    } else if (goal.period === "month") {
      statsDocPath = `users/${uid}/stats/results_stats_${year}_${month}`;
    } else {
      console.log(`⏭ Skipping unknown period: ${goal.period}`);
      continue;
    }

    console.log(`📊 Checking statsDocPath: ${statsDocPath}`);
    const statsDoc = await db.doc(statsDocPath).get();
    if (!statsDoc.exists) {
      console.log(`❌ Stats doc not found: ${statsDocPath}`);
      continue;
    }

    const stats = statsDoc.data();
    const actualValue =
    stats && goal.statField in stats ? stats[goal.statField] : null;

    if (actualValue === undefined || actualValue === null) {
      console.log(`❌ Stat field not found or null: ${goal.statField}`);
      continue;
    }

    const target = goal.target;
    const compareType = goal.compareType;
    const isAchieved =
    (compareType === "greater" && actualValue >= target) ||
    (compareType === "less" && actualValue <= target);

    let achievementRate = 0;
    if (target !== 0) {
      achievementRate = compareType === "greater" ?
    Math.min((actualValue / target) * 100, 100) :
    Math.min((target / actualValue) * 100, 100);
    }

    console.log(
        `✅ Updating goal ${goalId}: actual=${actualValue}, 
    target=${target}, rate=${achievementRate.toFixed(1)}%`,
    );

    updates.push(
        db.collection("users")
            .doc(uid)
            .collection("goals")
            .doc(goalId)
            .update({
              actualValue,
              achievementRate: Math.round(achievementRate * 10) / 10,
              isAchieved,
            }),
    );
  }

  await Promise.all(updates);
};

// 月一ユーザー目標
const monthlyUserGoalQueue = "monthly-user-goal-queue";
export const scheduleMonthlyUserGoalDispatcher = onSchedule(
    {
      schedule: "15 0 1 * *", // チームとは時間ずらすとわかりやすい
      timeZone: "Asia/Tokyo",
      timeoutSeconds: 60,
    },
    async () => {
      const now = new Date();
      const prevMonth = new Date(now.getFullYear(), now.getMonth() - 1);
      const targetYear = prevMonth.getFullYear();
      const targetMonth = prevMonth.getMonth() + 1;

      const usersSnap = await db.collection("users").get();

      for (const userDoc of usersSnap.docs) {
        const uid = userDoc.id;
        const payload = {
          uid,
          targetYear,
          targetMonth,
        };

        const task = {
          httpRequest: {
            httpMethod: "POST",
            url: "https://evaluatemonthlygoalsforuser-etndg3x4ra-uc.a.run.app",
            headers: {
              "Content-Type": "application/json",
            },
            body: Buffer.from(JSON.stringify(payload)).toString("base64"),
          },
        };

        await client.createTask({
          parent: client.queuePath(project, location, monthlyUserGoalQueue),
          task,
        });

        console.log(`✅ Task created for user ${uid}`);
      }
    },
);

export const evaluateMonthlyGoalsForUser = onRequest(async (req, res) => {
  const {uid, targetYear, targetMonth} = req.body;

  if (!uid || !targetYear || !targetMonth) {
    res.status(400).send("Missing uid / year / month");
    return;
  }

  const targetStr = `${targetYear}-${targetMonth}`;
  const goalsRef = db.collection("users").doc(uid).collection("goals");

  const snapshot = await goalsRef
      .where("period", "==", "month")
      .where("month", "==", targetStr)
      .where("update", "!=", true)
      .get();

  for (const doc of snapshot.docs) {
    const goal = doc.data();
    const statField = goal.statField;
    const target = goal.target || 0;
    const compareType = goal.compareType || "greater";

    const statDocId = `results_stats_${targetYear}_${targetMonth}`;
    const statSnap = await db
        .collection("users")
        .doc(uid)
        .collection("stats")
        .doc(statDocId)
        .get();

    let actualValue = 0;
    if (statSnap.exists && statSnap.data()[statField] != null) {
      actualValue = statSnap.data()[statField];
    }

    const rawRate = target > 0 ? (actualValue / target) * 100 : 0;
    const achievementRate = Math.min(100, rawRate);

    const isAchieved =
      compareType === "greater" ? actualValue >= target : actualValue <= target;

    await doc.ref.update({
      actualValue,
      achievementRate,
      isAchieved,
      update: true,
    });

    console.log(`✅ Goal ${doc.id} updated for user ${uid}`);
  }

  res.status(200).send("ok");
});

// 年更新ユーザー目標更新
const yearlyUserGoalQueue = "yearly-user-goal-queue";
export const scheduleYearlyUserGoalDispatcher = onSchedule(
    {
      schedule: "25 0 1 1 *", // 毎年1月1日 00:25 JST（チームとずらしておく）
      timeZone: "Asia/Tokyo",
      timeoutSeconds: 180,
    },
    async () => {
      console.log("📅 Starting yearly user goal tasks dispatch");

      const now = new Date();
      const targetYear = now.getFullYear() - 1;

      const usersSnap = await db.collection("users").get();

      for (const userDoc of usersSnap.docs) {
        const uid = userDoc.id;
        const payload = {
          uid,
          year: targetYear,
        };

        const task = {
          httpRequest: {
            httpMethod: "POST",
            url: "https://evaluateyearlygoalsforuser-etndg3x4ra-uc.a.run.app",
            headers: {
              "Content-Type": "application/json",
            },
            body: Buffer.from(JSON.stringify(payload)).toString("base64"),
          },
        };

        const [response] = await client.createTask({
          parent: client.queuePath(project, location, yearlyUserGoalQueue),
          task,
        });

        console.log(
            `🚀 Dispatched yearly goal task for user ${uid}: ${response.name}`,
        );
      }

      console.log("✅ All yearly user goal tasks dispatched");
    },
);

export const evaluateYearlyGoalsForUser = onRequest(async (req, res) => {
  const {uid, year} = req.body;

  console.log(`📌 Evaluating yearly goals for user ${uid} (${year})`);

  const goalsRef = db.collection("users").doc(uid).collection("goals");

  const snapshot = await goalsRef
      .where("period", "==", "year")
      .where("year", "==", year)
      .where("update", "!=", true)
      .get();

  for (const doc of snapshot.docs) {
    const goal = doc.data();
    const statField = goal.statField;
    const target = goal.target || 0;
    const compareType = goal.compareType || "greater";

    const statDocId = `results_stats_${year}_all`;
    const statRef = db.collection("users").doc(uid)
        .collection("stats").doc(statDocId);

    const statSnap = await statRef.get();

    let actualValue = 0;

    if (statSnap.exists) {
      const stats = statSnap.data();
      if (stats && stats[statField] != null) {
        actualValue = stats[statField];
      }
    }

    const rawRate = target > 0 ? (actualValue / target) * 100 : 0;
    const achievementRate = Math.min(100, rawRate);

    const isAchieved =
      compareType === "greater" ?
        actualValue >= target :
        actualValue <= target;

    await doc.ref.update({
      actualValue,
      achievementRate,
      isAchieved,
      update: true,
    });

    console.log(`✅ Updated goal ${doc.id} for user ${uid}`);
  }

  res.status(200).send("✅ User goals evaluated");
});

// 週一チーム目標
export const weeklyGoalProgressHandler = onRequest(async (req, res) => {
  try {
    const {teamId} = req.body;
    if (!teamId) {
      res.status(400).send("Missing teamId");
      return;
    }

    await weeklyGoalProgressUpdate(teamId);
    res.status(200).send("Goal progress updated");
  } catch (error) {
    functions.logger.error("weeklyGoalProgressHandler Error:", error);
    res.status(500).send("Internal Server Error");
  }
});

const weeklyGoalQueue = "weekly-goal-queue";
export const enqueueWeeklyGoalProgressTask = async (teamId) => {
  const task = {
    httpRequest: {
      httpMethod: "POST",
      url: "https://weeklygoalprogresshandler-etndg3x4ra-uc.a.run.app",
      headers: {
        "Content-Type": "application/json",
      },
      body: Buffer.from(JSON.stringify({teamId})).toString("base64"),
    },
  };

  const parent = client.queuePath(project, location, weeklyGoalQueue);
  await client.createTask({parent, task});
};


export const weeklyGoalProgressUpdate = async (teamId) => {
  const today = new Date();

  const goalsSnapshot =
  await db.collection("teams").doc(teamId).collection("goals").get();

  if (goalsSnapshot.empty) return;

  const updates = [];


  for (const doc of goalsSnapshot.docs) {
    const goal = doc.data();
    const goalId = doc.id;

    console.log(`⚙️ Checking goal: ${goalId}`);

    if (goal.statField === "custom") {
      console.log(`⏭ Skipping custom goal: ${goalId}`);
      continue;
    }

    if (!goal.period || !goal.statField || !goal.compareType || !goal.target) {
      console.log(`⏭ Skipping due to missing field:`, goal);
      continue;
    }

    const deadlineRaw = goal.deadline || goal.endDate;
    const deadlineDate =
    deadlineRaw.toDate ? deadlineRaw.toDate() : new Date(deadlineRaw);
    deadlineDate.setHours(23, 59, 59, 999);
    if (deadlineDate < today) {
      console.log(`⏭ Skipping due to past deadline: ${deadlineRaw}`);
      continue;
    }

    const year = deadlineDate.getFullYear();
    const month = (deadlineDate.getMonth() + 1).toString();

    let statsDocPath = "";
    if (goal.period === "year") {
      statsDocPath = `teams/${teamId}/stats/results_stats_${year}_all`;
    } else if (goal.period === "month") {
      statsDocPath = `teams/${teamId}/stats/results_stats_${year}_${month}`;
    } else {
      console.log(`⏭ Skipping unknown period: ${goal.period}`);
      continue;
    }

    console.log(`📊 Checking statsDocPath: ${statsDocPath}`);
    const statsDoc = await db.doc(statsDocPath).get();
    if (!statsDoc.exists) {
      console.log(`❌ Stats doc not found: ${statsDocPath}`);
      continue;
    }

    const stats = statsDoc.data();
    const actualValue =
    stats && goal.statField in stats ? stats[goal.statField] : null;

    if (actualValue === undefined || actualValue === null) {
      console.log(`❌ Stat field not found or null: ${goal.statField}`);
      continue;
    }

    const target = goal.target;
    const compareType = goal.compareType;
    const isAchieved =
    (compareType === "greater" && actualValue >= target) ||
    (compareType === "less" && actualValue <= target);

    let achievementRate = 0;
    if (target !== 0) {
      achievementRate = compareType === "greater" ?
    Math.min((actualValue / target) * 100, 100) :
    Math.min((target / actualValue) * 100, 100);
    }

    console.log(
        `✅ Updating goal ${goalId}: actual=${actualValue}, 
    target=${target}, rate=${achievementRate.toFixed(1)}%`,
    );

    updates.push(
        db.collection("teams")
            .doc(teamId)
            .collection("goals")
            .doc(goalId)
            .update({
              actualValue,
              achievementRate: Math.round(achievementRate * 10) / 10,
              isAchieved,
            }),
    );
  }

  await Promise.all(updates);
};

// 月一チーム目標更新
const monthlyGoalQueue = "monthly-goal-queue";
export const scheduleMonthlyGoalDispatcher = onSchedule(
    {
      schedule: "10 0 1 * *",
      timeZone: "Asia/Tokyo",
      timeoutSeconds: 60,
    },
    async () => {
      const now = new Date();
      const prevMonthDate = new Date(now.getFullYear(), now.getMonth() - 1);
      const targetYear = prevMonthDate.getFullYear();
      const targetMonth = prevMonthDate.getMonth() + 1;

      const teamsSnap = await db.collection("teams").get();

      for (const teamDoc of teamsSnap.docs) {
        const teamId = teamDoc.id;
        const payload = {
          teamId,
          targetYear,
          targetMonth,
        };

        const task = {
          httpRequest: {
            httpMethod: "POST",
            url: "https://evaluatemonthlygoalsforteam-etndg3x4ra-uc.a.run.app",
            headers: {
              "Content-Type": "application/json",
            },
            body: Buffer.from(JSON.stringify(payload)).toString("base64"),
          },
        };

        const [response] = await client.createTask({
          parent: client.queuePath(project, location, monthlyGoalQueue),
          task,
        });

        console.log(`✅ Task created for team ${teamId}: ${response.name}`);
      }
    },
);

export const evaluateMonthlyGoalsForTeam = onRequest(async (req, res) => {
  const {teamId, targetYear, targetMonth} = req.body;

  if (!teamId || !targetYear || !targetMonth) {
    res.status(400).send("Missing teamId / year / month");
    return;
  }

  const targetStr = `${targetYear}-${targetMonth}`;
  const goalsRef = db.collection("teams").doc(teamId).collection("goals");

  const snapshot = await goalsRef
      .where("period", "==", "month")
      .where("month", "==", targetStr)
      .where("update", "!=", true)
      .get();

  for (const doc of snapshot.docs) {
    const goal = doc.data();
    const statField = goal.statField;
    const target = goal.target || 0;
    const compareType = goal.compareType || "greater";

    const statDocId = `results_stats_${targetYear}_${targetMonth}`;
    const statSnap = await db
        .collection("teams")
        .doc(teamId)
        .collection("stats")
        .doc(statDocId)
        .get();

    let actualValue = 0;
    if (statSnap.exists && statSnap.data()[statField] != null) {
      actualValue = statSnap.data()[statField];
    }

    const rawRate = target > 0 ? (actualValue / target) * 100 : 0;
    const achievementRate = Math.min(100, rawRate);

    const isAchieved =
      compareType === "greater" ?
        actualValue >= target :
        actualValue <= target;

    await doc.ref.update({
      actualValue,
      achievementRate,
      isAchieved,
      update: true,
    });

    console.log(`✅ Goal ${doc.id} updated for team ${teamId}`);
  }

  res.status(200).send("ok");
});

// 毎年チーム目標更新
const yearlyGoalQueue = "yearly-goal-queue";
export const scheduleYearlyGoalDispatcher = onSchedule(
    {
      schedule: "20 0 1 1 *", // 毎年1月1日 00:20 JST
      timeZone: "Asia/Tokyo",
      timeoutSeconds: 180,
    },
    async () => {
      console.log("📅 Starting yearly goal tasks dispatch");

      const now = new Date();
      const targetYear = now.getFullYear() - 1;

      const teamsSnap = await db.collection("teams").get();

      for (const teamDoc of teamsSnap.docs) {
        const teamId = teamDoc.id;
        const payload = {
          teamId,
          year: targetYear,
        };

        const task = {
          httpRequest: {
            httpMethod: "POST",
            url: "https://evaluateyearlygoalsforteam-etndg3x4ra-uc.a.run.app",
            headers: {
              "Content-Type": "application/json",
            },
            body: Buffer.from(JSON.stringify(payload)).toString("base64"),
          },
        };

        const [response] = await client.createTask({
          parent: client.queuePath(project, location, yearlyGoalQueue),
          task,
        });

        console.log(
            `🚀 Dispatched yearly goal task for team ${teamId}: 
            ${response.name}`,
        );
      }

      console.log("✅ All yearly goal tasks dispatched");
    },
);

export const evaluateYearlyGoalsForTeam = onRequest(async (req, res) => {
  const {teamId, year} = req.body;

  console.log(`📌 Evaluating yearly goals for team ${teamId} (${year})`);

  const goalsRef = db.collection("teams").doc(teamId).collection("goals");

  const snapshot = await goalsRef
      .where("period", "==", "year")
      .where("year", "==", year)
      .where("update", "!=", true)
      .get();

  for (const doc of snapshot.docs) {
    const goal = doc.data();
    const statField = goal.statField;
    const target = goal.target || 0;
    const compareType = goal.compareType || "greater";

    const statDocId = `results_stats_${year}_all`;
    const statRef = db.collection("teams").doc(teamId)
        .collection("stats").doc(statDocId);

    const statSnap = await statRef.get();

    let actualValue = 0;

    if (statSnap.exists) {
      const stats = statSnap.data();
      if (stats && stats[statField] != null) {
        actualValue = stats[statField];
      }
    }

    const rawRate = target > 0 ? (actualValue / target) * 100 : 0;
    const achievementRate = Math.min(100, rawRate);

    const isAchieved =
      compareType === "greater" ?
        actualValue >= target :
        actualValue <= target;

    await doc.ref.update({
      actualValue,
      achievementRate,
      isAchieved,
      update: true,
    });

    console.log(`✅ Updated goal ${doc.id} for team ${teamId}`);
  }

  res.status(200).send("✅ Team goals evaluated");
});

// 週一チーム内ランキング
const teamRankingsQueue = "team-rankings-queue";
const teamRankingsurl = "https://processteamrankings-etndg3x4ra-uc.a.run.app";

export const weeklyTeamRankingsBatch = onSchedule(
    {
      schedule: "40 0 * * 1", // 毎週月曜日0時に実行
      timeZone: "Asia/Tokyo",
      timeoutSeconds: 1800,
    },
    async () => {
      console.log("🏆 チームランキングのスケジュール開始");

      try {
        const teamsSnapshot = await db.collection("teams").get();
        console.log(`📌 ${teamsSnapshot.size} チームを処理`);

        for (const teamDoc of teamsSnapshot.docs) {
          const teamID = teamDoc.id;

          // Cloud Tasks にタスクをスケジュール
          await scheduleTeamRankingProcessing(teamID);
        }

        console.log("✅ 全チームのランキング処理をスケジュール完了");
      } catch (error) {
        console.error("🚨 チームランキングのスケジュール中にエラー:", error);
      }
    },
);

/**
 * Cloud Tasks でチームのランキング処理をスケジュール
 * @param {string} teamID チームのID
 */
async function scheduleTeamRankingProcessing(teamID) {
  if (!project || !teamRankingsQueue) {
    console.error("🚨 Error: `project` または `queue` が未定義です。");
    return;
  }

  try {
    const parent = client.queuePath(project, location, teamRankingsQueue);
    console.log("✅ Cloud Tasks queue path:", parent);

    const task = {
      httpRequest: {
        httpMethod: "POST",
        url: teamRankingsurl,
        headers: {
          "Content-Type": "application/json",
        },
        body: Buffer.from(JSON.stringify({teamID})).toString("base64"),
      },
      scheduleTime: {
        seconds: Date.now() / 1000 + 10, // 10秒後に実行
      },
    };

    const [response] = await client.createTask({parent, task});

    console.log("🚀 タスクスケジュール成功: ", teamID, "Task Name:", response.name);
  } catch (error) {
    console.error("🚨 タスクスケジュールエラー:", error);
  }
}

/**
 * チームのランキング作成処理 (Cloud Tasks で呼び出し)
 */
export const processTeamRankings = onRequest(
    {
      timeoutSeconds: 1800,
    },
    async (req, res) => {
      const {teamID} = req.body;
      console.log(`🚀 チームランキング作成開始: ${teamID}`);

      try {
        const teamDoc = await db.collection("teams").doc(teamID).get();
        const teamData = teamDoc.data();
        if (!teamData) {
          res.status(404).send(`チーム ${teamID} が見つかりません`);
          return;
        }

        const userIDs = teamData.members || [];
        if (userIDs.length === 0) {
          console.log(`❌ チーム ${teamID} にメンバーがいないためスキップ`);
          res.status(200).send(`No members to process for team ${teamID}`);
          return;
        }

        console.log(`🚀 チーム ${teamID} のメンバー数: ${userIDs.length}`);

        const now = new Date();
        const year = now.getFullYear();
        const month = now.getMonth() + 1;
        const gameTypes = ["練習試合", "公式戦"];
        const periods = [
          "results_stats_all",
          `results_stats_${year}_${month}`,
          `results_stats_${year}_all`,
          ...gameTypes.flatMap((gameType) => [
            `results_stats_${year}_${month}_${gameType}`,
            `results_stats_${year}_${gameType}_all`,
            `results_stats_${gameType}_all`,
          ]),
        ];


        // 🔹 チームの統計データを取得
        const teamStatsSnapshot =
        await db.collection("teams").doc(teamID).collection("stats").get();
        const teamStats = teamStatsSnapshot.docs.reduce((acc, doc) => {
          acc[doc.id] = doc.data();
          return acc;
        }, {});

        const rankings = {}; // 🔹 ランキングデータを格納するオブジェクト

        for (const period of periods) {
          rankings[period] = {batting: {}, pitching: {}};

          // 🔹 チームの `totalGames` を取得
          const totalGames =
          (teamStats[period] && teamStats[period].totalGames) ?
         teamStats[period].totalGames : 0;
          const requiredTotalBats = totalGames * 1; // 規定打席
          const requiredInnings = totalGames * 2; // 規定投球回

          const playerStats = [];
          const pitcherStats = [];

          for (const userID of userIDs) {
            const userDoc = await db.collection("users").doc(userID).get();
            const userData = userDoc.data();
            if (!userData) continue;

            const statsDoc =
            await db.collection("users").doc(userID)
                .collection("stats").doc(period).get();
            if (!statsDoc.exists) continue;

            const stats = statsDoc.data();
            const isPitcher =
            userData.positions && userData.positions.includes("投手");


            if (stats.totalBats) {
              playerStats.push({
                uid: userID,
                name: userData.name || "名無し",
                atBats: stats.atBats || 0,
                hits: stats.hits || 0,
                battingAverage: stats.battingAverage || 0,
                onBasePercentage: stats.onBasePercentage || 0,
                sluggingPercentage: stats.sluggingPercentage || 0,
                totalHomeRuns: stats.totalHomeRuns || 0,
                totalSteals: stats.totalSteals || 0,
                totalRbis: stats.totalRbis || 0,
                total1hits:
                (stats.totalInfieldHits || 0) + (stats.total1hits || 0),
                total2hits: stats.total2hits || 0,
                total3hits: stats.total3hits || 0,
                totalBats: stats.totalBats || 0,
                requiredTotalBats,
              });
            }

            if (isPitcher && stats.totalInningsPitched) {
              pitcherStats.push({
                uid: userID,
                name: userData.name || "名無し",
                totalInningsPitched: stats.totalInningsPitched || 0,
                era: stats.era || 99.99,
                winRate: stats.winRate || 0,
                totalPStrikeouts: stats.totalPStrikeouts || 0,
                totalSaves: stats.totalSaves || 0,
                totalHoldPoints: stats.totalHoldPoints || 0,
                totalAppearances: stats.totalAppearances || 0,
                requiredInnings,
              });
            }
          }

          rankings[period].batting = {
            battingAverage: createRanking(
                playerStats, "battingAverage", "totalBats",
                ["battingAverage", "atBats", "hits", "name", "rank"],
                false, requiredTotalBats),
            homeRuns: createRanking(playerStats, "totalHomeRuns", null,
                ["totalHomeRuns", "name", "rank"]),
            steals: createRanking(playerStats, "totalSteals", null,
                ["totalSteals", "name", "rank"]),
            rbis: createRanking(playerStats, "totalRbis", null,
                ["totalRbis", "name", "rank"]),
            sluggingPercentage: createRanking(
                playerStats, "sluggingPercentage",
                "totalBats",
                ["sluggingPercentage", "totalHomeRuns",
                  "total1hits", "total2hits",
                  "total3hits", "name", "rank"],
                false, requiredTotalBats),
            onBasePercentage: createRanking(playerStats,
                "onBasePercentage", "totalBats",
                ["onBasePercentage", "totalBats", "name", "rank"],
                false, requiredTotalBats),
          };

          rankings[period].pitching = {
            era: createRanking(pitcherStats, "era", "totalInningsPitched",
                ["era", "totalInningsPitched", "name", "rank"],
                true, requiredInnings),
            strikeouts: createRanking(pitcherStats, "totalPStrikeouts", null,
                ["totalPStrikeouts", "name", "rank"]),
            winRate: createRanking(pitcherStats, "winRate",
                "totalInningsPitched",
                ["winRate", "totalAppearances", "name", "rank"],
                false, requiredInnings),
            holds: createRanking(pitcherStats, "totalHoldPoints", null,
                ["totalHoldPoints", "totalAppearances", "name", "rank"]),
            saves: createRanking(pitcherStats, "totalSaves", null,
                ["totalSaves", "totalAppearances", "name", "rank"]),
          };
          await batchWriteData(db, `teams/${teamID}/rankings`, rankings);
        }

        for (const period of periods) {
          await db.collection("teams").doc(teamID)
              .collection("rankings").doc(period).set(
                  {
                    rankings: rankings[period],
                    updatedAt: Timestamp.now(),
                  },
                  {merge: true},
              );
        }


        console.log(`✅ チーム ${teamID} のランキング保存完了`);
        res.status(200).send(
            `Successfully processed rankings for team ${teamID}`,
        );
      } catch (error) { // 🔹 **ここが必要！**
        console.error("🚨 ランキング作成中にエラー発生:", error);
        res.status(500).send("Failed to process rankings.");
      }
    },
);

/**
 * プレイヤーの統計データを元にランキングを作成する関数。
 *
 * @param {Array<Object>} players - ランキング対象のプレイヤーデータの配列
 * @param {string} key - ランキング基準となる統計データのキー
 * @param {string|null} [requiredKey=null] - ランキングに必要な最低条件のキー
 * @param {Array<string>} [selectedProps=[]] - ランキングデータとして格納するプロパティ
 * @param {boolean} [asc=false] - 昇順（true）または降順（false）でソートするか
 * @param {number|null} [requiredValueOverride=null] - 必要最低値を上書きする場合の値
 * @return {Array<Object>} - ソートされたランキングデータの配列
 */
function createRanking(
    players, key, requiredKey = null, selectedProps = [],
    asc = false, requiredValueOverride = null) {
  if (players.length === 0) return [];

  const eligiblePlayers = [];
  const ineligiblePlayers = [];

  players.forEach((player) => {
    let meetsRequirement = true;

    if (requiredKey) {
      const requiredValue = requiredValueOverride !== undefined &&
      requiredValueOverride !== null ?
            requiredValueOverride :
            (player[`required${requiredKey.charAt(0).toUpperCase() +
              requiredKey.slice(1)}`] !== undefined ?
              player[`required${requiredKey.charAt(0).toUpperCase() +
                requiredKey.slice(1)}`] :
              0);

      const actualValue =
      player[requiredKey] !== undefined ? player[requiredKey] : 0;

      meetsRequirement = actualValue >= requiredValue;
    }


    if (meetsRequirement) {
      eligiblePlayers.push(player);
    } else {
      ineligiblePlayers.push(player);
    }
  });

  // ランキング対象者のみソート
  const sortedPlayers = [...eligiblePlayers].sort((a, b) =>
    (asc ? a[key] - b[key] : b[key] - a[key]));

  let rank = 1;
  let prevValue = null;

  const rankedPlayers = sortedPlayers.map((player, index) => {
    const playerData = {};

    selectedProps.forEach((prop) => {
      playerData[prop] = player[prop] !== undefined &&
      player[prop] !== null ? player[prop] : 0;
    });

    if (prevValue !== player[key]) rank = index + 1;
    prevValue = player[key];

    return {...playerData, rank};
  });

  // 規定未達成の選手は `rank: null` で保存
  const unrankedPlayers = ineligiblePlayers.map((player) => {
    const playerData = {};
    selectedProps.forEach((prop) => {
      playerData[prop] = player[prop] !== undefined &&
      player[prop] !== null ? player[prop] : 0;
    });

    return {...playerData, rank: null};
  });

  return [...rankedPlayers, ...unrankedPlayers];
}


/**
 * Firestore にデータをバッチ書き込みする
 * @param {FirebaseFirestore.Firestore} db Firestore インスタンス
 * @param {string} collectionPath Firestore のコレクションパス
 * @param {Object} data 書き込むデータ
 */
async function batchWriteData(db, collectionPath, data) {
  const batchSize = 500;
  let batch = db.batch();
  let batchCounter = 0;

  for (const [docID, docData] of Object.entries(data)) {
    const docRef = db.collection(collectionPath).doc(docID);
    batch.set(docRef, {rankings: docData, updatedAt:
      Timestamp.now()}, {merge: true});

    batchCounter++;
    if (batchCounter >= batchSize) {
      await batch.commit();
      batch = db.batch();
      batchCounter = 0;
    }
  }

  if (batchCounter > 0) {
    await batch.commit();
  }
}

/**
 * 年齢から年齢グループ（例: '30_39'）を返す
 * @param {number} age - ユーザーの年齢
 * @return {string} 年齢グループ（例: '30_39'）
 */
function getAgeGroup(age) {
  if (age >= 0 && age <= 17) return "0_17";
  if (age >= 18 && age <= 29) return "18_29";
  if (age >= 30 && age <= 39) return "30_39";
  if (age >= 40 && age <= 49) return "40_49";
  if (age >= 50 && age <= 59) return "50_59";
  if (age >= 60 && age <= 69) return "60_69";
  if (age >= 70 && age <= 79) return "70_79";
  if (age >= 80 && age <= 89) return "80_89";
  if (age >= 90 && age <= 100) return "90_100";
  return "unknown";
}

/**
   * 月一にプレイヤーランキングを作成する
   */
export const createPrayerRanking = onSchedule(
    {
      schedule: "30 1 1 * *",
      timeZone: "Asia/Tokyo",
      timeoutSeconds: 3600,
    },
    async () => {
      const date = new Date();
      date.setMonth(date.getMonth() - 1);

      const year = date.getFullYear();
      const month = date.getMonth() + 1;

      const monthPrayerRankingQueuePath =
  client.queuePath(project, location, "monthly-ranking-queue");
      const annualPrayerRankingQueuePath =
  client.queuePath(project, location, "yearly-ranking-queue");

      const skipAnnualUpdate = (month === 12 || month === 1 || month === 2);
      if (skipAnnualUpdate) {
        console.log("📌 年間データの更新はこの月では行われません。");
      }

      if (!skipAnnualUpdate) {
        const battingRef =
        db.collection(`battingAverageRanking`).doc(`${year}_total`);
        const pitchingRef =
        db.collection(`pitcherRanking`).doc(`${year}_total`);

        try {
          console.log(`🧹 年間ランキングを初期化中...`);
          await getFirestore().recursiveDelete(battingRef);
          console.log("✅ Batting ranking deleted");
          await getFirestore().recursiveDelete(pitchingRef);
          console.log("✅ Pitching ranking deleted");
        } catch (err) {
          console.error("⚠️ 初期化失敗", err);
        }
      }

      const allUsersSnapshot = await db.collection("users").get();
      console.log(`Retrieved ${allUsersSnapshot.size} users from Firestore.`);

      const teamsSnapshot = await db.collection("teams").get();
      const teamIdToNameMap = {};
      teamsSnapshot.forEach((doc) => {
        const teamData = doc.data();
        teamIdToNameMap[doc.id] = teamData.teamName || "名前不明";
      });


      for (const userDoc of allUsersSnapshot.docs) {
        const uid = userDoc.id;
        const isSubscribed = await checkSubscriptionStatus(uid);
        if (!isSubscribed) {
          console.log(`Skipping user ${uid} due to inactive subscription.`);
          continue;
        }

        const userData = userDoc.data();
        const birthday = userData.birthday;
        let age = null;
        if (birthday && typeof birthday.toDate === "function") {
          const birthDate = birthday.toDate();
          const today = new Date();
          age = today.getFullYear() - birthDate.getFullYear();
          const hasHadBirthdayThisYear =
            today.getMonth() > birthDate.getMonth() ||
            (today.getMonth() === birthDate.getMonth() &&
            today.getDate() >= birthDate.getDate());
          if (!hasHadBirthdayThisYear) {
            age -= 1;
          }
        }

        const userPrefecture = userData.prefecture || "不明";
        const isPitcher =
        userData.positions && userData.positions.includes("投手");
        const teamIds = userData.teams || [];
        const playerName = userData.name || "不明";

        const teamNames =
    teamIds.map((teamId) => teamIdToNameMap[teamId] || "名前不明");

        // **📌 Cloud Tasks に月次ランキングのタスクを追加**
        const taskPayload = {
          uid,
          year,
          month,
          userPrefecture,
          teamNames,
          teamIds,
          playerName,
          isPitcher,
          age,
        };

        await client.createTask({
          parent: monthPrayerRankingQueuePath,
          task: {
            httpRequest: {
              httpMethod: "POST",
              url: "https://processmonthlyranking-etndg3x4ra-uc.a.run.app",
              body: Buffer.from(JSON.stringify(taskPayload)).toString("base64"),
              headers: {"Content-Type": "application/json"},
            },
          },
        });

        // **📌 年間ランキングのタスクを追加（12月・1月・２月はスキップ）**
        if (!skipAnnualUpdate) {
          await client.createTask({
            parent: annualPrayerRankingQueuePath,
            task: {
              httpRequest: {
                httpMethod: "POST",
                url:
                "https://processyearlyranking-etndg3x4ra-uc.a.run.app",
                body: Buffer
                    .from(JSON.stringify(taskPayload)).toString("base64"),
                headers: {"Content-Type": "application/json"},
              },
            },
          });
        }
      }
    });

/**
 * ユーザーのサブスクリプション状態を確認
 * @param {string} uid - ユーザーの一意識別子 (UID)
 * @return {Promise<boolean>} - ユーザーがアクティブなサブスクリプションを持っているか
 */
async function checkSubscriptionStatus(uid) {
  const subscriptionRef =
  db.collection("users").doc(uid).collection("subscription");
  const [iosSub, androidSub] = await Promise.all([
    subscriptionRef.doc("iOS").get(),
    subscriptionRef.doc("android").get(),
  ]);

  let iosActive = false;
  let androidActive = false;

  if (iosSub.exists) {
    const iosData = iosSub.data();
    iosActive = iosData && iosData.status === "active";
  }

  if (androidSub.exists) {
    const androidData = androidSub.data();
    androidActive = androidData && androidData.status === "active";
  }

  return iosActive || androidActive;
}

export const processMonthlyRanking = onRequest(async (req, res) => {
  const {
    uid, year, month, userPrefecture, teamIds, teamNames, playerName, isPitcher,
    age,
  } = req.body;

  // 月次データ取得
  const monthlyStatsDocRef =
  db.doc(`/users/${uid}/stats/results_stats_${year}_${month}`);
  const monthlyStatsDoc = await monthlyStatsDocRef.get();
  if (!monthlyStatsDoc.exists) {
    console.log(`No monthly stats for ${uid}`);
    return res.status(400).send("No monthly stats found");
  }

  const monthlyData = monthlyStatsDoc.data();

  const requiredBats = (month === 12 || month === 1 || month === 2) ? 4 : 8;

  // 月次プレイヤーデータ作成
  const playerMonthlyData = {
    id: uid,
    name: playerName,
    teamID: teamIds,
    team: teamNames,
    battingAverage: monthlyData.battingAverage,
    totalGames: monthlyData.totalGames,
    totalBats: monthlyData.totalBats,
    atBats: monthlyData.atBats,
    totalRbis: monthlyData.totalRbis,
    single: (monthlyData.total1hits || 0) + (monthlyData.totalInfieldHits || 0),
    doubles: monthlyData.total2hits,
    triples: monthlyData.total3hits,
    homeRuns: monthlyData.totalHomeRuns,
    totalBases: monthlyData.totalBases,
    runs: monthlyData.totalRuns,
    steals: monthlyData.totalSteals,
    sacrificeBunts: monthlyData.totalAllBuntSuccess,
    sacrificeFlies: monthlyData.totalSacrificeFly,
    walks: monthlyData.totalFourBalls,
    hitByPitch: monthlyData.totalHitByAPitch,
    strikeouts: monthlyData.totalStrikeouts,
    doublePlays: monthlyData.totalDoublePlays,
    sluggingPercentage: monthlyData.sluggingPercentage,
    onBasePercentage: monthlyData.onBasePercentage,
    ops: monthlyData.ops,
    rc: monthlyData.rc,
    age,
    isEligible: monthlyData.totalBats >= requiredBats, // 月次の規定打席
  };

  await db.collection(
      `battingAverageRanking/${year}_${month}/${userPrefecture}`,
  )
      .doc(uid).set(playerMonthlyData);

  // **投手データ**
  if (isPitcher) {
    const requiredInnings =
    (month === 12 || month === 1 || month === 2) ? 6 : 12;
    const pitcherMonthlyData = {
      id: uid,
      name: playerName,
      teamID: teamIds,
      team: teamNames,
      totalInningsPitched: monthlyData.totalInningsPitched,
      era: monthlyData.era,
      totalEarnedRuns: monthlyData.totalEarnedRuns,
      totalPStrikeouts: monthlyData.totalPStrikeouts,
      totalHitsAllowed: monthlyData.totalHitsAllowed,
      totalWalks: monthlyData.totalWalks,
      totalHitByPitch: monthlyData.totalHitByPitch,
      totalRunsAllowed: monthlyData.totalRunsAllowed,
      totalCompleteGames: monthlyData.totalCompleteGames,
      totalShutouts: monthlyData.totalShutouts,
      totalHolds: monthlyData.totalHolds,
      totalSaves: monthlyData.totalSaves,
      totalBattersFaced: monthlyData.totalBattersFaced,
      totalWins: monthlyData.totalWins,
      totalLosses: monthlyData.totalLosses,
      winRate: monthlyData.winRate,
      totalHoldPoints: monthlyData.totalHoldPoints,
      totalAppearances: monthlyData.totalAppearances,
      age,
      isEligible: monthlyData.totalInningsPitched >= requiredInnings,
    };

    await db.collection(`pitcherRanking/${year}_${month}/${userPrefecture}`)
        .doc(uid).set(pitcherMonthlyData);
  }

  console.log(`Monthly ranking updated for ${uid}`);
  return res.status(200).send("Monthly ranking processed");
});

export const processYearlyRanking = onRequest(async (req, res) => {
  const {
    uid, year, month, userPrefecture, teamIds, teamNames, playerName, isPitcher,
    age,
  } = req.body;

  // 年間データ取得
  const totalStatsDocRef =
  db.doc(`/users/${uid}/stats/results_stats_${year}_all`);
  const totalStatsDoc = await totalStatsDocRef.get();
  if (!totalStatsDoc.exists) {
    console.log(`No yearly stats for ${uid}`);
    return res.status(400).send("No yearly stats found");
  }

  const totalData = totalStatsDoc.data();

  const requiredBatsTotal = (month >= 3) ? Math.min((month - 2) * 8, 72) : 72;

  // 年間プレイヤーデータ作成
  const playerTotalData = {
    id: uid,
    name: playerName,
    teamID: teamIds,
    team: teamNames,
    prefecture: userPrefecture,
    battingAverage: totalData.battingAverage,
    totalGames: totalData.totalGames,
    totalBats: totalData.totalBats,
    atBats: totalData.atBats,
    totalHits: totalData.hits,
    totalRbis: totalData.totalRbis,
    single: (totalData.total1hits || 0) + (totalData.totalInfieldHits || 0),
    doubles: totalData.total2hits,
    triples: totalData.total3hits,
    homeRuns: totalData.totalHomeRuns,
    totalBases: totalData.totalBases,
    runs: totalData.totalRuns,
    steals: totalData.totalSteals,
    sacrificeBunts: totalData.totalAllBuntSuccess,
    sacrificeFlies: totalData.totalSacrificeFly,
    walks: totalData.totalFourBalls,
    hitByPitch: totalData.totalHitByAPitch,
    strikeouts: totalData.totalStrikeouts,
    doublePlays: totalData.totalDoublePlays,
    sluggingPercentage: totalData.sluggingPercentage,
    onBasePercentage: totalData.onBasePercentage,
    ops: totalData.ops,
    age,
    rc: totalData.rc,
    isEligibleAll: totalData.totalBats >= requiredBatsTotal, // 年間の規定打席
  };

  await db.collection(`battingAverageRanking/${year}_total/${userPrefecture}`)
      .doc(uid).set(playerTotalData);

  // **投手データ**
  if (isPitcher) {
    const requiredInningsTotal =
    (month >= 3) ? Math.min((month - 2) * 12, 108) : 108;
    console.log(`現在の月: ${month + 1}月`);
    console.log(`必要なイニング: ${requiredInningsTotal}`);
    const pitcherTotalData = {
      id: uid,
      name: playerName,
      teamID: teamIds,
      team: teamNames,
      prefecture: userPrefecture,
      totalInningsPitched: totalData.totalInningsPitched,
      era: totalData.era,
      totalEarnedRuns: totalData.totalEarnedRuns,
      totalPStrikeouts: totalData.totalPStrikeouts,
      totalHitsAllowed: totalData.totalHitsAllowed,
      totalWalks: totalData.totalWalks,
      totalHitByPitch: totalData.totalHitByPitch,
      totalRunsAllowed: totalData.totalRunsAllowed,
      totalCompleteGames: totalData.totalCompleteGames,
      totalShutouts: totalData.totalShutouts,
      totalHolds: totalData.totalHolds,
      totalSaves: totalData.totalSaves,
      totalBattersFaced: totalData.totalBattersFaced,
      totalWins: totalData.totalWins,
      totalLosses: totalData.totalLosses,
      winRate: totalData.winRate,
      age,
      totalHoldPoints: totalData.totalHoldPoints,
      totalAppearances: totalData.totalAppearances,
      isEligibleAll: totalData.totalInningsPitched >= requiredInningsTotal,
    };

    await db.collection(`pitcherRanking/${year}_total/${userPrefecture}`)
        .doc(uid).set(pitcherTotalData);
  }

  console.log(`Yearly ranking updated for ${uid}`);


  // **✅ 各都道府県の選手数を Firestore から取得 & 加算**
  const battingStatsRef =
  db.doc(`battingAverageRanking/${year}_total/${userPrefecture}/stats`);
  const battingStatsDoc =
  await battingStatsRef.get();
  const currentBattingCount =
   battingStatsDoc.exists ? (battingStatsDoc.data().playersCount || 0) : 0;
  await battingStatsRef
      .set({playersCount: currentBattingCount + 1}, {merge: true});
  console.log(
      `バッティングランキング: ${userPrefecture} の選手数 
      (${currentBattingCount + 1}) を保存しました。`,
  );

  if (isPitcher) {
    const pitcherStatsRef =
    db.doc(`pitcherRanking/${year}_total/${userPrefecture}/stats`);
    const pitcherStatsDoc = await pitcherStatsRef.get();
    const currentPitcherCount =
    pitcherStatsDoc.exists ? (pitcherStatsDoc.data().pitchersCount || 0) : 0;
    await pitcherStatsRef
        .set({pitchersCount: currentPitcherCount + 1}, {merge: true});
    console.log(
        `ピッチャー: ${userPrefecture} の選手数 (${currentPitcherCount + 1}) を保存しました。`,
    );
  }

  // **全国の合計人数を Firestore から取得 & 加算**
  const nationwideStatsRef =
  db.doc(`battingAverageRanking/${year}_total/全国/stats`);
  const nationwideStatsDoc =
  await nationwideStatsRef.get();
  const currentTotalPlayers =
  nationwideStatsDoc.exists ?
  (nationwideStatsDoc.data().totalPlayersCount || 0) : 0;
  await nationwideStatsRef
      .set({totalPlayersCount: currentTotalPlayers + 1}, {merge: true});
  console.log(`全国のバッティング選手合計人数 (${currentTotalPlayers + 1}) を保存しました。`);

  if (isPitcher) {
    const nationwidePitchersRef =
    db.doc(`pitcherRanking/${year}_total/全国/stats`);
    const nationwidePitchersDoc =
    await nationwidePitchersRef.get();
    const currentTotalPitchers =
    nationwidePitchersDoc.exists ?
    (nationwidePitchersDoc.data().totalPitchersCount || 0) : 0;
    await nationwidePitchersRef
        .set({totalPitchersCount: currentTotalPitchers + 1}, {merge: true});
    console.log(`全国のピッチャー選手合計人数 (${currentTotalPitchers + 1}) を保存しました。`);
  }


  return res.status(200).send("Yearly ranking processed and stats updated.");
});


// 月一プレイヤーランク付
const batterQueuePath =
client.queuePath(project, location, "batter-ranking-queue");
const pitcherQueuePath =
client.queuePath(project, location, "pitcher-ranking-queue");
const batterYearlyQueuePath =
client.queuePath(project, location, "batter-yearly-ranking-queue");
const pitcherYearlyQueuePath =
client.queuePath(project, location, "pitcher-yearly-ranking-queue");
const nationwideBatterQueuePath =
client.queuePath(project, location, "nationwide-batter-queue");
const nationwidePitcherQueuePath =
client.queuePath(project, location, "nationwide-pitcher-queue");

export const scheduleRankingProcessing = onSchedule(
    {
      schedule: "40 2 1 * *",
      timeZone: "Asia/Tokyo",
      timeoutSeconds: 3600,
    },
    async () => {
      const now = new Date();
      now.setMonth(now.getMonth() - 1); // ←先月のデータを処理
      const year = now.getFullYear();
      const month = now.getMonth() + 1;

      console.log(`🚀 ランキング処理開始: ${year}年 ${month}月`);

      // 🔁 年間と全国の処理スキップ判定（対象が12月,1月,2月ならスキップ）
      const skipAnnualUpdate = [12, 1, 2].includes(month);
      if (skipAnnualUpdate) {
        console.log("⏭ 年間・全国ランキングの更新はスキップされます");
      }


      // 🔍 Firestore から都道府県リストを取得
      const prefectureRefs = await db
          .doc(`battingAverageRanking/${year}_${month}`)
          .listCollections();

      const prefectures = prefectureRefs.map((col) => col.id);

      console.log(`🏆 都道府県数: ${prefectures.length}`);

      for (const prefecture of prefectures) {
        const payload = {
          year,
          month,
          prefecture,
        };

        // バッターランキングのタスク
        await client.createTask({
          parent: batterQueuePath,
          task: {
            httpRequest: {
              httpMethod: "POST",
              url: "https://processbatterranking-etndg3x4ra-uc.a.run.app",
              body: Buffer.from(JSON.stringify(payload)).toString("base64"),
              headers: {
                "Content-Type": "application/json",
              },
            },
          },
        });
        console.log(`✅ Batterタスク追加: ${prefecture}`);

        // 🔹 ピッチャーランキングのタスク
        await client.createTask({
          parent: pitcherQueuePath,
          task: {
            httpRequest: {
              httpMethod: "POST",
              url: "https://processpitcherranking-etndg3x4ra-uc.a.run.app",
              body: Buffer.from(JSON.stringify(payload)).toString("base64"),
              headers: {
                "Content-Type": "application/json",
              },
            },
          },
        });
        console.log(`✅ Pitcherタスク追加: ${prefecture}`);

        if (!skipAnnualUpdate) {
        // 年間バッター
          await client.createTask({
            parent: batterYearlyQueuePath,
            task: {
              httpRequest: {
                httpMethod: "POST",
                url: "https://processbatteryearly-etndg3x4ra-uc.a.run.app",
                body: Buffer.from(JSON.stringify(payload)).toString("base64"),
                headers: {"Content-Type": "application/json"},
              },
            },
          });

          // 年間ピッチャー
          await client.createTask({
            parent: pitcherYearlyQueuePath,
            task: {
              httpRequest: {
                httpMethod: "POST",
                url: "https://processpitcheryearly-etndg3x4ra-uc.a.run.app",
                body: Buffer.from(JSON.stringify(payload)).toString("base64"),
                headers: {"Content-Type": "application/json"},
              },
            },
          });
        }
      }

      // 全国ランキングタスク（最後に追加
      if (!skipAnnualUpdate) {
        await client.createTask({
          parent: nationwideBatterQueuePath,
          task: {
            httpRequest: {
              httpMethod: "POST",
              url: "https://processnationwidebatterranking-etndg3x4ra-uc.a.run.app",
              body: Buffer.from(JSON.stringify({year})).toString("base64"),
              headers: {"Content-Type": "application/json"},
            },
          },
        });

        // 全国ランキングタスク（最後に追加）
        await client.createTask({
          parent: nationwidePitcherQueuePath,
          task: {
            httpRequest: {
              httpMethod: "POST",
              url: "https://processnationwidepitcherranking-etndg3x4ra-uc.a.run.app",
              body: Buffer.from(JSON.stringify({year})).toString("base64"),
              headers: {"Content-Type": "application/json"},
            },
          },
        });
      }
      console.log("📌 全タスクのスケジューリング完了");
    });

export const processBatterRanking = onRequest(
    {
      timeoutSeconds: 3600,
    },
    async (req, res) => {
      try {
        const {year, month, prefecture} = req.body;

        console.log(
            `📦 processBatterRanking: ${year}年 ${month}月 - ${prefecture}`,
        );

        // プレイヤーデータを取得
        const monthlySnapshot = await db
            .collection(`battingAverageRanking/${year}_${month}/${prefecture}`)
            .get();

        const players = [];
        monthlySnapshot.forEach((doc) => {
          players.push(doc.data());
        });

        if (players.length === 0) {
          console.log("⚠️ 該当プレイヤーなし");
          return res.status(200).send("No players found for monthly ranking");
        }

        // 月次ランキングを保存
        await saveRankingByPrefecture({[prefecture]: players}, year, month);

        res.status(200).send("✅ Batter ranking processed successfully");
      } catch (error) {
        console.error("🚨 processBatterRanking Error:", error);
        res.status(500).send("❌ Failed to process batter ranking");
      }
    });

export const processPitcherRanking = onRequest(
    {
      timeoutSeconds: 3600,
    },
    async (req, res) => {
      try {
        const {year, month, prefecture} = req.body;

        console.log(
            `📦 processPitcherRanking: ${year}年 ${month}月 - ${prefecture}`,
        );

        // 🌕 月次データ取得
        const monthlySnapshot = await db
            .collection(`pitcherRanking/${year}_${month}/${prefecture}`)
            .get();

        const monthlyPitchers = [];
        monthlySnapshot.forEach((doc) => {
          monthlyPitchers.push(doc.data());
        });

        if (monthlyPitchers.length > 0) {
          await saveRankingByPrefecturePitcher(
              {[prefecture]: monthlyPitchers},
              year,
              month,
              "pitcherRanking",
              true,
          );
        } else {
          console.log(`⚠️ ${prefecture} に月次ピッチャーデータが見つかりませんでした。`);
        }

        res.status(200).send("✅ Pitcher ranking processed successfully");
      } catch (error) {
        console.error("🚨 processPitcherRanking Error:", error);
        res.status(500).send("❌ Failed to process pitcher ranking");
      }
    });

export const processBatterYearly = onRequest(
    {
      timeoutSeconds: 3600,
    },
    async (req, res) => {
      try {
        const {year, prefecture} = req.body;

        console.log(`📦 processBatterYearly: ${year}年 - ${prefecture}`);

        const snapshot = await db
            .collection(`battingAverageRanking/${year}_total/${prefecture}`)
            .get();

        const players = [];
        snapshot.forEach((doc) => {
          players.push({...doc.data(), id: doc.id});
        });


        if (players.length === 0) {
          console.log(`⚠️ ${prefecture} に年間データがありません`);
          return res.status(200).send("No yearly data found");
        }

        await saveTotalRankingByPrefecture({[prefecture]: players}, year);
        await saveTop10RanksByPrefecture({[prefecture]: players}, year);

        res.status(200).send("✅ Batter yearly ranking processed successfully");
      } catch (error) {
        console.error("🚨 processBatterYearly Error:", error);
        res.status(500).send("❌ Failed to process batter yearly ranking");
      }
    });

export const processPitcherYearly = onRequest(
    {
      timeoutSeconds: 3600,
    },
    async (req, res) => {
      try {
        const {year, prefecture} = req.body;

        console.log(`📦 processPitcherYearly: ${year}年 - ${prefecture}`);

        const snapshot = await db
            .collection(`pitcherRanking/${year}_total/${prefecture}`)
            .get();

        const players = [];
        snapshot.forEach((doc) => {
          players.push({...doc.data(), id: doc.id});
        });


        if (players.length === 0) {
          console.log(`⚠️ ${prefecture} に年間データがありません`);
          return res.status(200).send("No yearly pitcher data found");
        }

        await calculateAndSaveRanksPitcher(
            players, `pitcherRanking/${year}_total/${prefecture}`, false,
        );
        await saveTop10RanksByPrefecturePitcher({[prefecture]: players}, year);

        res.status(200).send("✅ Pitcher yearly ranking processed successfully");
      } catch (error) {
        console.error("🚨 processPitcherYearly Error:", error);
        res.status(500).send("❌ Failed to process pitcher yearly ranking");
      }
    });

export const processNationwideBatterRanking = onRequest(
    {
      timeoutSeconds: 3600,
    },
    async (req, res) => {
      try {
        const {year} = req.body;

        const prefectureRefs = await db
            .doc(`battingAverageRanking/${year}_total`)
            .listCollections();

        const allPlayersByPrefecture = {};
        let totalHitsForNation = 0;
        const prefectureHitsList = [];

        for (const col of prefectureRefs) {
          const prefecture = col.id;

          if (prefecture === "全国") continue;

          const snapshot = await db
              .collection(`battingAverageRanking/${year}_total/${prefecture}`)
              .get();

          const players = [];
          let prefectureHitSum = 0;

          snapshot.forEach((doc) => {
            const data = doc.data();
            players.push({...data, id: doc.id});


            if (doc.id !== "stats") {
              prefectureHitSum += data.totalHits || 0;
            }
          });

          allPlayersByPrefecture[prefecture] = players;


          // 各都道府県のヒット数をリストに追加（Firestoreには保存しない）
          prefectureHitsList.push({
            prefecture,
            totalHits: prefectureHitSum,
          });

          // 全国合計に加算
          totalHitsForNation += prefectureHitSum;
        }

        // 🔽 最後に全国の合計も追加
        prefectureHitsList.push({
          prefecture: "全国",
          totalHits: totalHitsForNation,
        });

        // 🔽 Firestore に保存（全国のみ）
        const nationwideHitsRef = db.doc(
            `battingAverageRanking/${year}_total/全国/hits`,
        );
        await nationwideHitsRef.set({
          prefectureHits: prefectureHitsList,
        });

        console.log("✅ 全国ヒット数データを保存しました");


        // ✅ 通常の全国ランキング保存
        await saveNationwideTopRanks(allPlayersByPrefecture, year);

        res.status(200).send("✅ 全国バッターランキングを更新しました");
      } catch (error) {
        console.error("🚨 processNationwideBatterRanking Error:", error);
        res.status(500).send("❌ 全国ランキング処理に失敗しました");
      }
    });

export const processNationwidePitcherRanking = onRequest(
    {
      timeoutSeconds: 3600,
    },
    async (req, res) => {
      try {
        const {year} = req.body;

        // ✅ ドキュメントパスで listCollections を使う
        const prefectureRefs = await db
            .doc(`pitcherRanking/${year}_total`)
            .listCollections();

        const allPitchersByPrefecture = {};

        for (const col of prefectureRefs) {
          const prefecture = col.id;

          const snapshot = await db
              .collection(`pitcherRanking/${year}_total/${prefecture}`)
              .get();

          const pitchers = [];
          snapshot.forEach((doc) => {
            pitchers.push({...doc.data(), id: doc.id});
          });

          allPitchersByPrefecture[prefecture] = pitchers;
        }

        await saveNationwideTopRanksPitcher(allPitchersByPrefecture, year);

        res.status(200).send("✅ 全国ピッチャーランキングを更新しました");
      } catch (error) {
        console.error("🚨 processNationwidePitcherRanking Error:", error);
        res.status(500).send("❌ 全国ピッチャーランキング処理に失敗しました");
      }
    });

/**
      * 月次ランキングを保存
      * @param {Object} playersByPrefecture - プレイヤーが都道府県ごとにグループ化されたオブジェクト。
      * @param {number} year - 現在の年。
      * @param {number} month - 現在の月。
      */
async function saveRankingByPrefecture(playersByPrefecture, year, month) {
  for (const [prefecture, players] of Object.entries(playersByPrefecture)) {
    const monthlyCollectionPath =
         `battingAverageRanking/${year}_${month}/${prefecture}`;
    await calculateAndSaveRanks(players, monthlyCollectionPath, true); // 月次の場合
    // 🔽 月次 Top10（打率）と年齢別 Top10 を保存
    await saveMonthlyTop10RanksByPrefecture(
        {[prefecture]: players}, year, month,
    );
  }
}

/**
 * 月次バッターTop10（打率）と年齢別Top10を保存
 * @param {Object} playersByPrefecture - 都道府県ごとにグループ化されたプレイヤーデータ
 * @param {number} year - 年
 * @param {number|string} month - 月（ゼロ埋め・非ゼロ埋めどちらでも可）
 */
async function saveMonthlyTop10RanksByPrefecture(
    playersByPrefecture, year, month) {
  const ageGroups = [
    "0_17", "18_29", "30_39", "40_49", "50_59",
    "60_69", "70_79", "80_89", "90_100",
  ];

  for (const [prefecture, players] of Object.entries(playersByPrefecture)) {
    const monthlyCollectionPath =
    `battingAverageRanking/${year}_${month}/${prefecture}`;
    const batch = db.batch();

    // ▼ 打率 Top10（全体）
    const top10 = players
        .filter((p) =>
          p.battingAverageRank != null && p.battingAverageRank <= 10)
        .map((p) => ({
          id: p.id || "",
          name: p.name || "",
          team: p.team || "",
          teamID: p.teamID || "",
          rank: p.battingAverageRank || null,
          value: p.battingAverage ? p.battingAverage : null,
          age: p.age ? p.age : null,
          totalGames: p.totalGames || 0,
          totalBats: p.totalBats || 0,
          atBats: p.atBats || 0,
          totalHits: p.totalHits || 0,
          totalRbis: p.totalRbis || 0,
          single: p.single || 0,
          doubles: p.doubles || 0,
          triples: p.triples || 0,
          homeRuns: p.homeRuns || 0,
          totalBases: p.totalBases || 0,
          runs: p.runs || 0,
          steals: p.steals || 0,
          sacrificeBunts: p.sacrificeBunts || 0,
          sacrificeFlies: p.sacrificeFlies || 0,
          walks: p.walks || 0,
          hitByPitch: p.hitByPitch || 0,
          strikeouts: p.strikeouts || 0,
          doublePlays: p.doublePlays || 0,
          sluggingPercentage: p.sluggingPercentage || 0,
          onBasePercentage: p.onBasePercentage || 0,
          ops: p.ops || 0,
          rc: p.rc || 0,
        }));

    if (top10.length > 0) {
      const docRef = db.doc(`${monthlyCollectionPath}/battingAverageRank`);
      batch.set(docRef, {PrefectureTop10: top10});
    }

    // ▼ 年齢別 Top10
    for (const group of ageGroups) {
      const key = `battingAverageRank_age_${group}`;
      const top10Age = players
          .filter((p) => p[key] != null && p[key] <= 10)
          .map((p) => ({
            id: p.id || "",
            name: p.name || "",
            team: p.team || "",
            teamID: p.teamID || "",
            rank: p[key] || null,
            value: p.battingAverage ? p.battingAverage : null,
            age: p.age ? p.age : null,
            totalGames: p.totalGames || 0,
            totalBats: p.totalBats || 0,
            atBats: p.atBats || 0,
            totalHits: p.totalHits || 0,
            totalRbis: p.totalRbis || 0,
            single: p.single || 0,
            doubles: p.doubles || 0,
            triples: p.triples || 0,
            homeRuns: p.homeRuns || 0,
            totalBases: p.totalBases || 0,
            runs: p.runs || 0,
            steals: p.steals || 0,
            sacrificeBunts: p.sacrificeBunts || 0,
            sacrificeFlies: p.sacrificeFlies || 0,
            walks: p.walks || 0,
            hitByPitch: p.hitByPitch || 0,
            strikeouts: p.strikeouts || 0,
            doublePlays: p.doublePlays || 0,
            sluggingPercentage: p.sluggingPercentage || 0,
            onBasePercentage: p.onBasePercentage || 0,
            ops: p.ops || 0,
            rc: p.rc || 0,
          }));

      if (top10Age.length > 0) {
        const docRef =
        db.doc(`${monthlyCollectionPath}/battingAverageRank_age_${group}`);
        batch.set(docRef, {[`PrefectureTop10_age_${group}`]: top10Age});
      }
    }

    await batch.commit();
    console.log(
        `✅ Saved monthly Top10 (BA) for 
        ${prefecture} at ${monthlyCollectionPath}`,
    );
  }
}

/**
 * 月次ピッチャー Top10（ERA）と年齢別 Top10 を保存（rankCtxPitcher は使わない）
 * @param {Object} pitchersByPrefecture - 都道府県ごとにグループ化されたピッチャーデータ
 * @param {number} year - 年
 * @param {number|string} month - 月（ゼロ埋め・非ゼロ埋めどちらでも可）
 */
async function saveMonthlyTop10RanksByPrefecturePitcher(
    pitchersByPrefecture,
    year,
    month,
) {
  const ageGroups = [
    "0_17",
    "18_29",
    "30_39",
    "40_49",
    "50_59",
    "60_69",
    "70_79",
    "80_89",
    "90_100",
  ];

  for (const [prefecture, pitchers] of Object.entries(pitchersByPrefecture)) {
    const monthlyCollectionPath =
    `pitcherRanking/${year}_${month}/${prefecture}`;
    const batch = db.batch();

    // ▼ ERA Top10（全体）: calculateAndSaveRanksPitcher で eraRank を付与済み
    const top10 = pitchers
        .filter((p) => p.eraRank != null && p.eraRank <= 10)
        .map((p) => ({
          id: p.id || "",
          name: p.name || "",
          team: p.team || "",
          teamID: p.teamID || "",
          rank: p.eraRank || null,
          value: p.era || null,
          age: p.age || null,
          totalInningsPitched: p.totalInningsPitched || 0,
          totalEarnedRuns: p.totalEarnedRuns || 0,
          totalPStrikeouts: p.totalPStrikeouts || 0,
          totalHitsAllowed: p.totalHitsAllowed || 0,
          totalWalks: p.totalWalks || 0,
          totalHitByPitch: p.totalHitByPitch || 0,
          totalRunsAllowed: p.totalRunsAllowed || 0,
          totalCompleteGames: p.totalCompleteGames || 0,
          totalShutouts: p.totalShutouts || 0,
          totalHolds: p.totalHolds || 0,
          totalSaves: p.totalSaves || 0,
          totalBattersFaced: p.totalBattersFaced || 0,
          totalWins: p.totalWins || 0,
          totalLosses: p.totalLosses || 0,
          winRate: p.winRate || 0,
          totalHoldPoints: p.totalHoldPoints || 0,
          totalAppearances: p.totalAppearances || 0,
        }));

    if (top10.length > 0) {
      const docRef = db.doc(`${monthlyCollectionPath}/eraRank`);
      // batter 側に合わせるなら {PrefectureTop10: top10} で保存
      batch.set(docRef, {PrefectureTop10: top10});
    }

    // ▼ 年齢別 Top10（ERA）
    for (const group of ageGroups) {
      const key = `eraRank_age_${group}`;
      const top10Age = pitchers
          .filter((p) => p[key] != null && p[key] <= 10)
          .map((p) => ({
            id: p.id || "",
            name: p.name || "",
            team: p.team || "",
            teamID: p.teamID || "",
            rank: p[key] || null,
            value: p.era || null,
            age: p.age || null,
            totalInningsPitched: p.totalInningsPitched || 0,
            totalEarnedRuns: p.totalEarnedRuns || 0,
            totalPStrikeouts: p.totalPStrikeouts || 0,
            totalHitsAllowed: p.totalHitsAllowed || 0,
            totalWalks: p.totalWalks || 0,
            totalHitByPitch: p.totalHitByPitch || 0,
            totalRunsAllowed: p.totalRunsAllowed || 0,
            totalCompleteGames: p.totalCompleteGames || 0,
            totalShutouts: p.totalShutouts || 0,
            totalHolds: p.totalHolds || 0,
            totalSaves: p.totalSaves || 0,
            totalBattersFaced: p.totalBattersFaced || 0,
            totalWins: p.totalWins || 0,
            totalLosses: p.totalLosses || 0,
            winRate: p.winRate || 0,
            totalHoldPoints: p.totalHoldPoints || 0,
            totalAppearances: p.totalAppearances || 0,
          }));

      if (top10Age.length > 0) {
        const docRef = db.doc(`${monthlyCollectionPath}/eraRank_age_${group}`);
        // batter 側に合わせるなら PrefectureTop10_age_{group} キーで保存
        batch.set(docRef, {[`PrefectureTop10_age_${group}`]: top10Age});
      }
    }

    await batch.commit();
    console.log(
        `✅ Saved monthly Top10 (ERA) for 
        ${prefecture} at ${monthlyCollectionPath}`,
    );
  }
}

/**
      * 保存するピッチャーの月次ランキングを計算し、Firestoreに保存します。
      * @param {Object} playersByPrefecture - 都道府県ごとにグループ化されたピッチャーデータ。
      * @param {number} year - 現在の年。
      * @param {number} month - 現在の月。
      * @param {string} collectionPathBase - Firestoreのコレクションパスのベース。
      * @param {boolean} isMonthly - 月次ランキングかどうかのフラグ。
      */
async function saveRankingByPrefecturePitcher(
    playersByPrefecture, year, month, collectionPathBase, isMonthly,
) {
  for (const [prefecture, players] of Object.entries(playersByPrefecture)) {
    const collectionPath = isMonthly ?
      `${collectionPathBase}/${year}_${month}/${prefecture}` :
      `${collectionPathBase}/${year}_total/${prefecture}`;

    // ① ランク計算（ERA 等）
    await calculateAndSaveRanksPitcher(players, collectionPath, isMonthly);

    // ② 月次の場合のみ、ERA の Top10 と年齢別 Top10 を保存（rankCtxPitcher は使わない）
    if (isMonthly) {
      await saveMonthlyTop10RanksByPrefecturePitcher(
          {[prefecture]: players},
          year,
          month,
      );
    }
  }
}

/**
      * 年間ランキングを保存
      * @param {Object} totalPlayersByPrefecture
      * @param {number} year - 現在の年。
      */
async function saveTotalRankingByPrefecture(totalPlayersByPrefecture, year) {
  for (
    const [prefecture, players] of Object.entries(totalPlayersByPrefecture)
  ) {
    const totalCollectionPath =
         `battingAverageRanking/${year}_total/${prefecture}`;
    await calculateAndSaveRanks(players, totalCollectionPath, false); // 年間の場合
  }
}

/**
      * ランク付けを計算して保存
      * @param {Array} players - ランク付けを行うプレイヤーのリスト。
      * @param {string} collectionPath - Firestoreのコレクションパス。
      * @param {boolean} isMonthly - 月次ランキングかどうかを示すフラグ。
      */
async function calculateAndSaveRanks(players, collectionPath, isMonthly) {
  const excludedIds = [
    "stats", "stealsRank", "totalRbisRank",
    "homeRunsRank", "onBaseRank", "sluggingRank",
  ];

  const filteredPlayers = players.filter((p) => !excludedIds.includes(p.id));

  if (isMonthly) {
    calculateBattingAverageRank(players, true);
  } else {
    calculateBattingAverageRank(filteredPlayers, false);
    calculateHomeRunsRank(filteredPlayers);
    calculateSluggingRank(filteredPlayers);
    calculateOnBaseRank(filteredPlayers);
    calculateStealsRank(filteredPlayers);
    calculateTotalRbisRank(filteredPlayers);
  }

  await batchWriteWithRank(collectionPath, players, filteredPlayers);
}

/**
      * バッティング平均のランクを計算
      * @param {Array} players - プレイヤーのリスト。
      * @param {boolean} isMonthly - 月次ランキングかどうかを示すフラグ。
      */
function calculateBattingAverageRank(players, isMonthly) {
  players.sort((a, b) => b.battingAverage - a.battingAverage);
  let currentRank = 0;
  let previousBattingAverage = null;
  let eligibleCount = 0;

  for (let i = 0; i < players.length; i++) {
    const player = players[i];
    const isEligibleField =
         isMonthly ? player.isEligible : player.isEligibleAll;

    if (!isEligibleField) {
      player.battingAverageRank = null;
      continue;
    }

    if (
      previousBattingAverage === null || previousBattingAverage !==
           player.battingAverage
    ) {
      currentRank = eligibleCount + 1;
    }

    player.battingAverageRank = currentRank;
    eligibleCount++;
    previousBattingAverage = player.battingAverage;
  }

  // 年齢別ランキング
  const groups = {};
  for (const player of players) {
    const group = getAgeGroup(player.age);
    if (!groups[group]) groups[group] = [];
    groups[group].push(player);
  }

  for (const [group, groupPlayers] of Object.entries(groups)) {
    const eligible = groupPlayers.filter((p) =>
      p.battingAverage !== null &&
    (isMonthly ? p.isEligible : p.isEligibleAll),
    );

    eligible.sort((a, b) => b.battingAverage - a.battingAverage);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const player = eligible[i];
      if (prevValue === null || prevValue !== player.battingAverage) {
        groupRank = count + 1;
      }
      player[`battingAverageRank_age_${group}`] = groupRank;
      count++;
      prevValue = player.battingAverage;
    }

    for (const p of groupPlayers) {
      if (!eligible.includes(p)) {
        p[`battingAverageRank_age_${group}`] = null;
      }
    }
  }
}

/**
      * スラッギングパーセンテージのランクを計算
      * @param {Array} players - プレイヤーのリスト。
      */
function calculateSluggingRank(players) {
  // スラッギングパーセンテージで降順にソート
  players.sort((a, b) => b.sluggingPercentage - a.sluggingPercentage);

  let currentRank = 0;
  let previousSlugging = null;
  let eligibleCount = 0;

  for (let i = 0; i < players.length; i++) {
    const player = players[i];

    // sluggingPercentageがnullまたは規定打席に満たない場合、ランクをnullに設定
    if (player.sluggingPercentage === null || !player.isEligibleAll) {
      player.sluggingRank = null; // データベースにnullとして保存される
      continue;
    }

    // ランクを計算（同じsluggingPercentageの場合は同じランク）
    if (
      previousSlugging === null || previousSlugging !==
           player.sluggingPercentage
    ) {
      currentRank = eligibleCount + 1;
    }

    player.sluggingRank = currentRank;
    eligibleCount++;
    previousSlugging = player.sluggingPercentage;
  }

  // 年齢別ランキング
  const groups = {};
  for (const player of players) {
    const group = getAgeGroup(player.age);
    if (!groups[group]) groups[group] = [];
    groups[group].push(player);
  }

  for (const [group, groupPlayers] of Object.entries(groups)) {
    const eligible =
    groupPlayers.filter((p) =>
      p.sluggingPercentage !== null && p.isEligibleAll);
    eligible.sort((a, b) => b.sluggingPercentage - a.sluggingPercentage);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const player = eligible[i];
      if (prevValue === null || prevValue !== player.sluggingPercentage) {
        groupRank = count + 1;
      }
      player[`sluggingRank_age_${group}`] = groupRank;
      count++;
      prevValue = player.sluggingPercentage;
    }
    for (const p of groupPlayers) {
      if (!eligible.includes(p)) {
        p[`sluggingRank_age_${group}`] = null;
      }
    }
  }
}

/**
      * 出塁率のランクを計算
      * @param {Array} players - プレイヤーのリスト。
      */
function calculateOnBaseRank(players) {
  // 出塁率で降順にソート
  players.sort((a, b) => b.onBasePercentage - a.onBasePercentage);

  let currentRank = 0;
  let previousOnBase = null;
  let eligibleCount = 0;

  for (let i = 0; i < players.length; i++) {
    const player = players[i];

    // onBasePercentageがnullまたは規定打席に満たない場合、ランクをnullに設定
    if (player.onBasePercentage === null || !player.isEligibleAll) {
      player.onBaseRank = null; // データベースにnullとして保存される
      continue;
    }

    // ランクを計算（同じonBasePercentageの場合は同じランク）
    if (previousOnBase === null || previousOnBase !== player.onBasePercentage) {
      currentRank = eligibleCount + 1;
    }

    player.onBaseRank = currentRank;
    eligibleCount++;
    previousOnBase = player.onBasePercentage;
  }

  // 年齢別ランキング
  const groups = {};
  for (const player of players) {
    const group = getAgeGroup(player.age);
    if (!groups[group]) groups[group] = [];
    groups[group].push(player);
  }

  for (const [group, groupPlayers] of Object.entries(groups)) {
    const eligible =
    groupPlayers.filter((p) => p.onBasePercentage !== null && p.isEligibleAll);
    eligible.sort((a, b) => b.onBasePercentage - a.onBasePercentage);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const player = eligible[i];
      if (prevValue === null || prevValue !== player.onBasePercentage) {
        groupRank = count + 1;
      }
      player[`onBaseRank_age_${group}`] = groupRank;
      count++;
      prevValue = player.onBasePercentage;
    }
    for (const p of groupPlayers) {
      if (!eligible.includes(p)) {
        p[`onBaseRank_age_${group}`] = null;
      }
    }
  }
}

/**
      * ホームランのランクを計算
      * @param {Array} players - プレイヤーのリスト。
      */
function calculateHomeRunsRank(players) {
  players.sort((a, b) => b.homeRuns - a.homeRuns);
  let currentRank = 0;
  let previousHomeRuns = null;

  for (let i = 0; i < players.length; i++) {
    const player = players[i];
    if (previousHomeRuns === null || previousHomeRuns !== player.homeRuns) {
      currentRank = i + 1;
    }
    player.homeRunsRank = currentRank;
    previousHomeRuns = player.homeRuns;
  }

  // 年齢別ランキング
  const groups = {};
  for (const player of players) {
    const group = getAgeGroup(player.age);
    if (!groups[group]) groups[group] = [];
    groups[group].push(player);
  }

  for (const [group, groupPlayers] of Object.entries(groups)) {
    const eligible = groupPlayers.filter((p) => p.homeRuns !== null);
    eligible.sort((a, b) => b.homeRuns - a.homeRuns);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const player = eligible[i];
      if (prevValue === null || prevValue !== player.homeRuns) {
        groupRank = count + 1;
      }
      player[`homeRunsRank_age_${group}`] = groupRank;
      count++;
      prevValue = player.homeRuns;
    }
  }
}

/**
      * 盗塁のランクを計算
      * @param {Array} players - プレイヤーのリスト。
      */
function calculateStealsRank(players) {
  players.sort((a, b) => b.steals - a.steals);
  let currentRank = 0;
  let previousSteals = null;

  for (let i = 0; i < players.length; i++) {
    const player = players[i];
    if (previousSteals === null || previousSteals !== player.steals) {
      currentRank = i + 1;
    }
    player.stealsRank = currentRank;
    previousSteals = player.steals;
  }

  // 年齢別ランキング
  const groups = {};
  for (const player of players) {
    const group = getAgeGroup(player.age);
    if (!groups[group]) groups[group] = [];
    groups[group].push(player);
  }

  for (const [group, groupPlayers] of Object.entries(groups)) {
    const eligible = groupPlayers.filter((p) => p.steals !== null);
    eligible.sort((a, b) => b.steals - a.steals);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const player = eligible[i];
      if (prevValue === null || prevValue !== player.steals) {
        groupRank = count + 1;
      }
      player[`stealsRank_age_${group}`] = groupRank;
      count++;
      prevValue = player.steals;
    }
  }
}

/**
      * 打点のランクを計算
      * @param {Array} players - プレイヤーのリスト。
      */
function calculateTotalRbisRank(players) {
  players.sort((a, b) => b.totalRbis - a.totalRbis);
  let currentRank = 0;
  let previousRbis = null;

  for (let i = 0; i < players.length; i++) {
    const player = players[i];
    if (previousRbis === null || previousRbis !== player.totalRbis) {
      currentRank = i + 1;
    }
    player.totalRbisRank = currentRank;
    previousRbis = player.totalRbis;
  }

  // 年齢別ランキング
  const groups = {};
  for (const player of players) {
    const group = getAgeGroup(player.age);
    if (!groups[group]) groups[group] = [];
    groups[group].push(player);
  }

  for (const [group, groupPlayers] of Object.entries(groups)) {
    const eligible = groupPlayers.filter((p) => p.totalRbis !== null);
    eligible.sort((a, b) => b.totalRbis - a.totalRbis);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const player = eligible[i];
      if (prevValue === null || prevValue !== player.totalRbis) {
        groupRank = count + 1;
      }
      player[`totalRbisRank_age_${group}`] = groupRank;
      count++;
      prevValue = player.totalRbis;
    }
  }
}

/**
      * 指定したランキングカテゴリの上位10位の選手を保存
      * @param {Object} totalPlayersByPrefecture - 都道府県ごとにグループ化されたプレイヤーデータ
      * @param {number} year - 対象の年
      */
async function saveTop10RanksByPrefecture(totalPlayersByPrefecture, year) {
  const categoryToFieldMapping = {
    battingAverageRank: "battingAverage",
    homeRunsRank: "homeRuns",
    onBaseRank: "onBasePercentage",
    sluggingRank: "sluggingPercentage",
    stealsRank: "steals",
    totalRbisRank: "totalRbis",
  };

  const ageGroups = [
    "0_17", "18_29", "30_39", "40_49", "50_59",
    "60_69", "70_79", "80_89", "90_100",
  ];

  for (
    const [prefecture, players] of Object.entries(totalPlayersByPrefecture)
  ) {
    console.log(`🗾 都道府県: ${prefecture}`);
    console.log("🏷 Top10候補:", JSON.stringify(players, null, 2));

    const totalCollectionPath =
    `battingAverageRanking/${year}_total/${prefecture}`;
    const batch = db.batch();

    const rankCategories = Object.keys(categoryToFieldMapping);

    for (const category of rankCategories) {
      const field = categoryToFieldMapping[category];

      const top10 = players
          .filter((player) => player[category] && player[category] <= 10)
          .map((player) => {
            const value = player[field] !== undefined ? player[field] : null;
            const entry = {
              id: player.id || "",
              name: player.name || "",
              team: player.team || "",
              teamID: player.teamID || "",
              rank: player[category] || null,
              value: value,
              age: player.age || null,
            };

            if (category !== "stealsRank" && category !== "onBaseRank") {
              entry.atBats = player.atBats || 0;
            }
            if (category === "sluggingRank") {
              entry.single = player.single || 0;
              entry.doubles = player.doubles || 0;
              entry.triples = player.triples || 0;
              entry.homeRuns = player.homeRuns || 0;
            }
            if (category === "onBaseRank") {
              entry.totalBats = player.totalBats || 0;
            }

            if (category === "battingAverageRank") {
              entry.totalGames = player.totalGames || 0;
              entry.totalBats = player.totalBats || 0;
              entry.atBats = player.atBats || 0;
              entry.totalHits = player.totalHits || 0;
              entry.totalRbis = player.totalRbis || 0;
              entry.single = player.single || 0;
              entry.doubles = player.doubles || 0;
              entry.triples = player.triples || 0;
              entry.homeRuns = player.homeRuns || 0;
              entry.totalBases = player.totalBases || 0;
              entry.runs = player.runs || 0;
              entry.steals = player.steals || 0;
              entry.sacrificeBunts = player.sacrificeBunts || 0;
              entry.sacrificeFlies = player.sacrificeFlies || 0;
              entry.walks = player.walks || 0;
              entry.hitByPitch = player.hitByPitch || 0;
              entry.strikeouts = player.strikeouts || 0;
              entry.doublePlays = player.doublePlays || 0;
              entry.sluggingPercentage = player.sluggingPercentage || 0;
              entry.onBasePercentage = player.onBasePercentage || 0;
              entry.ops = player.ops || 0;
              entry.rc = player.rc || 0;
            }

            return entry;
          });

      if (top10.length > 0) {
        const docRef = db.doc(`${totalCollectionPath}/${category}`);
        batch.set(docRef, {PrefectureTop10: top10});
      }

      // 年齢別
      for (const group of ageGroups) {
        const ageCategory = `${category}_age_${group}`;

        const top10ForAge = players
            .filter((player) => player[ageCategory] &&
            player[ageCategory] <= 10)
            .map((player) => {
              const value = player[field] !== undefined ? player[field] : null;
              const entry = {
                id: player.id || "",
                name: player.name || "",
                team: player.team || "",
                teamID: player.teamID || "",
                rank: player[ageCategory] || null,
                value: value,
                age: player.age || null,
              };

              if (category !== "stealsRank" && category !== "onBaseRank") {
                entry.atBats = player.atBats || 0;
              }
              if (category === "sluggingRank") {
                entry.single = player.single || 0;
                entry.doubles = player.doubles || 0;
                entry.triples = player.triples || 0;
                entry.homeRuns = player.homeRuns || 0;
              }
              if (category === "onBaseRank") {
                entry.totalBats = player.totalBats || 0;
              }

              if (category === "battingAverageRank") {
                entry.totalGames = player.totalGames || 0;
                entry.totalBats = player.totalBats || 0;
                entry.atBats = player.atBats || 0;
                entry.totalHits = player.totalHits || 0;
                entry.totalRbis = player.totalRbis || 0;
                entry.single = player.single || 0;
                entry.doubles = player.doubles || 0;
                entry.triples = player.triples || 0;
                entry.homeRuns = player.homeRuns || 0;
                entry.totalBases = player.totalBases || 0;
                entry.runs = player.runs || 0;
                entry.steals = player.steals || 0;
                entry.sacrificeBunts = player.sacrificeBunts || 0;
                entry.sacrificeFlies = player.sacrificeFlies || 0;
                entry.walks = player.walks || 0;
                entry.hitByPitch = player.hitByPitch || 0;
                entry.strikeouts = player.strikeouts || 0;
                entry.doublePlays = player.doublePlays || 0;
                entry.sluggingPercentage = player.sluggingPercentage || 0;
                entry.onBasePercentage = player.onBasePercentage || 0;
                entry.ops = player.ops || 0;
                entry.rc = player.rc || 0;
              }

              return entry;
            });

        if (top10ForAge.length > 0) {
          const docRef =
          db.doc(`${totalCollectionPath}/${category}_age_${group}`);
          batch.set(docRef, {[`PrefectureTop10_age_${group}`]: top10ForAge});
        }

        const sortedByRank = players
            .filter((p) => p[category] !== undefined && p[category] !== null)
            .sort((a, b) => (a[category] || 9999) - (b[category] || 9999));

        for (const player of sortedByRank) {
          const uid = player.id;
          if (uid) {
            const ref = db.doc(`users/${uid}/rankingContext/${category}`);
            batch.delete(ref);
          }
        }

        for (const player of sortedByRank) {
          const userId = player.id;
          const rankValue = player[category];
          if (!userId || !rankValue || rankValue <= 10) continue;

          const idx = sortedByRank.findIndex((p) => p.id === userId);
          if (idx === -1) continue;

          const context = [];
          for (
            let i = Math.max(0, idx - 3); i <=
            Math.min(sortedByRank.length - 1, idx + 3); i++
          ) {
            context.push(sortedByRank[i]);
          }

          const oneBelow = sortedByRank.slice(idx + 1).find(
              (p) => (p[category] !== undefined &&
                p[category] !== null ? p[category] : 9999) > rankValue,
          );
          if (oneBelow) {
            context.push(oneBelow);
          }

          const userDocRef =
          db.doc(`users/${userId}/rankingContext/${category}`);
          batch.set(userDocRef, {context}, {merge: true});
        }

        const sortedByAgeRank = players
            .filter((p) =>
              p[ageCategory] !== undefined && p[ageCategory] !== null)
            .sort((a, b) =>
              (a[ageCategory] || 9999) - (b[ageCategory] || 9999));

        for (const player of sortedByAgeRank) {
          const userId = player.id;
          const rankValue = player[ageCategory];
          if (!userId || !rankValue || rankValue <= 10) continue;

          const idx = sortedByAgeRank.findIndex((p) => p.id === userId);
          if (idx === -1) continue;

          const context = [];
          for (
            let i = Math.max(0, idx - 3); i <=
            Math.min(sortedByAgeRank.length - 1, idx + 3); i++
          ) {
            context.push(sortedByAgeRank[i]);
          }

          const oneBelow = sortedByAgeRank.slice(idx + 1).find(
              (p) => (p[ageCategory] !== undefined &&
                p[ageCategory] !== null ? p[ageCategory] : 9999) > rankValue,
          );
          if (oneBelow) {
            context.push(oneBelow);
          }

          const userDocRef =
          db.doc(`users/${userId}/rankingContext/${ageCategory}`);
          batch.set(userDocRef, {context}, {merge: true});
        }
      }
    }


    await batch.commit();

    // 年齢別人数のカウントと stats への保存（上書きせずマージ）
    const ageGroupCounts = {};
    for (const group of ageGroups) {
      const count = players.filter((p) => {
        const key = `totalRbisRank_age_${group}`;
        return p[key] !== undefined && p[key] !== null;
      }).length;
      ageGroupCounts[`totalPlayers_age_${group}`] = count;
    }

    const statsRef = db.doc(`${totalCollectionPath}/stats`);
    await statsRef.set({stats: ageGroupCounts}, {merge: true});
  }
}


/**
  * 各県のランク1の選手を集計して全国ランキングとして保存
  * @param {Object} totalPlayersByPrefecture - プレイヤーが都道府県ごとにグループ化されたオブジェクト。
  * @param {number} year - 保存対象の年。
*/
async function saveNationwideTopRanks(totalPlayersByPrefecture, year) {
  console.log("🏁 [全国ランキング処理開始]");
  console.log("対象都道府県:", Object.keys(totalPlayersByPrefecture));

  const nationwideRanks = {
    battingAverageRank: [],
    homeRunsRank: [],
    sluggingRank: [],
    onBaseRank: [],
    stealsRank: [],
    totalRbisRank: [],
  };

  // 年齢別カテゴリごとの重複防止用（全体スコープで持つ）
  const addedIdsByAgeCategory = {};

  const statKeyMapping = {
    battingAverageRank: "battingAverage",
    homeRunsRank: "homeRuns",
    sluggingRank: "sluggingPercentage",
    onBaseRank: "onBasePercentage",
    stealsRank: "steals",
    totalRbisRank: "totalRbis",
  };

  for (
    const [prefecture, players] of Object.entries(totalPlayersByPrefecture)
  ) {
    console.log(`Processing prefecture: ${prefecture}`);

    for (const category of Object.keys(nationwideRanks)) {
      // 年齢別カテゴリごとの重複防止用セットを初期化
      const ageGroups = [
        "0_17", "18_29", "30_39", "40_49", "50_59",
        "60_69", "70_79", "80_89", "90_100",
      ];
      for (const group of ageGroups) {
        const ageCategoryKey = `${category}_age_${group}`;
        if (!addedIdsByAgeCategory[ageCategoryKey]) {
          addedIdsByAgeCategory[ageCategoryKey] = new Set();
        }
      }
      const topPlayers = players.filter((player) => {
        const isOverallTop = player[category] === 1;
        const ageGroup = getAgeGroup(player.age);
        const isAgeTop = player[`${category}_age_${ageGroup}`] === 1;
        return isOverallTop || isAgeTop;
      });

      topPlayers.forEach((player) => {
        const ageGroup = getAgeGroup(player.age);
        const ageCategoryKey = `${category}_age_${ageGroup}`;

        // 🔧 修正：baseCategoryを取り出す（_age_がある場合用）
        const baseCategory = category.includes("_age_") ?
        category.split("_age_")[0] :
        category;
        const statKey = statKeyMapping[baseCategory];
        const value =
        statKey ?
        (player[statKey] !== undefined ? player[statKey] : null) : null;

        const uniqueKey = `${player.id}_${ageCategoryKey}`;

        const entry = {
          id: player.id || "",
          name: player.name || "",
          team: player.team || "",
          teamID: player.teamID || "",
          prefecture: player.prefecture,
          value: value,
          age: player.age,
        };

        if (baseCategory !== "stealsRank" && baseCategory !== "onBaseRank") {
          entry.atBats = player.atBats || 0;
        }

        if (baseCategory === "sluggingRank") {
          entry.single = player.single || 0;
          entry.doubles = player.doubles || 0;
          entry.triples = player.triples || 0;
          entry.homeRuns = player.homeRuns || 0;
        }

        if (baseCategory === "onBaseRank") {
          entry.totalBats = player.totalBats || 0;
        }

        if (baseCategory === "battingAverageRank") {
          entry.atBats = player.atBats;
          entry.totalHits = player.totalHits;
        }

        if (
          player[category] === 1 &&
          !category.includes("_age_") && // 🔧 年齢カテゴリには入れない
          !nationwideRanks[category].some((e) => e.id === player.id)
        ) {
          nationwideRanks[category].push(entry);
        }

        const playerAgeRank = player[ageCategoryKey];

        // 年齢別登録
        if (playerAgeRank === 1) {
          if (!nationwideRanks[ageCategoryKey]) {
            nationwideRanks[ageCategoryKey] = [];
          }
          if (!addedIdsByAgeCategory[ageCategoryKey]) {
            addedIdsByAgeCategory[ageCategoryKey] = new Set();
          }
          if (!addedIdsByAgeCategory[ageCategoryKey].has(uniqueKey)) {
            const ageEntry = {...entry}; // 新たにクローン
            ageEntry.ageGroup = ageGroup;
            ageEntry.rank = playerAgeRank;

            nationwideRanks[ageCategoryKey].push(ageEntry);
            addedIdsByAgeCategory[ageCategoryKey].add(uniqueKey);
          }
        }
      });
    }
  }

  // Firestoreへ一括保存
  const nationwideCollectionPath = `battingAverageRanking/${year}_total/全国`;
  const batch = db.batch();

  for (const [category, data] of Object.entries(nationwideRanks)) {
    console.log(`Saving category: ${category}, count: ${data.length}`);
    if (data.length > 0) {
      const docRef = db.doc(`${nationwideCollectionPath}/${category}`);
      const sanitizedData = data.map((entry) =>
        Object.fromEntries(
            Object.entries(entry).map(([key, value]) =>
              [key, value === undefined ? null : value]),
        ),
      );
      batch.set(docRef, {top: sanitizedData});
    }
  }

  await batch.commit();

  const ageGroups = [
    "0_17", "18_29", "30_39", "40_49", "50_59",
    "60_69", "70_79", "80_89", "90_100",
  ];

  const ageCounts = {};
  for (const group of ageGroups) {
    ageCounts[`totalPlayers_age_${group}`] = 0;
  }

  for (const prefecture of Object.keys(totalPlayersByPrefecture)) {
    const statsRef =
    db.doc(`battingAverageRanking/${year}_total/${prefecture}/stats`);
    const statsSnap = await statsRef.get();
    if (statsSnap.exists) {
      const statsData = (statsSnap.exists && statsSnap.data().stats) || {};
      for (const group of ageGroups) {
        const key = `totalPlayers_age_${group}`;
        ageCounts[key] += statsData[key] || 0;
      }
    }
  }

  const nationwideStatsRef =
  db.doc(`battingAverageRanking/${year}_total/全国/stats`);
  await nationwideStatsRef.set({stats: ageCounts}, {merge: true});
}

/**
      * 指定されたランキングを計算してFirestoreに保存します。
      * @param {Array<Object>} players - ランク付けを行うピッチャーデータのリスト。
      * @param {string} collectionPath - Firestoreの保存先コレクションパス。
      * @param {boolean} isMonthly - 月次ランキングかどうかのフラグ。
      */
async function calculateAndSaveRanksPitcher(
    players, collectionPath, isMonthly,
) {
  const excludedIds = ["stats", "winRateRank", "totalEarnedRunsRank",
    "totalPStrikeoutsRank", "totalHoldPointsRank", "totalSavesRank",
  ];

  const filteredPlayers = players.filter((p) => !excludedIds.includes(p.id));

  if (isMonthly) {
    // 月次データでは規定投球回を考慮
    calculatePitcherRank(
        players, "era", (a, b) => a.era - b.era, (player) => player.isEligible,
    );
  } else {
    // 年間データでは規定投球回を考慮
    calculatePitcherRank(
        filteredPlayers, "era", (a, b) => a.era - b.era,
        (player) => player.isEligibleAll,
    );
    calculatePitcherRank(
        filteredPlayers, "winRate", (a, b) => b.winRate - a.winRate,
        (player) => player.isEligibleAll,
    );

    // 規定投球回に関係なくランク付け
    calculatePitcherRank(
        filteredPlayers, "totalPStrikeouts", (a, b) =>
          b.totalPStrikeouts - a.totalPStrikeouts,
    );
    calculatePitcherRank(
        filteredPlayers, "totalHoldPoints", (a, b) =>
          b.totalHoldPoints - a.totalHoldPoints,
    );
    calculatePitcherRank(
        filteredPlayers, "totalSaves", (a, b) => b.totalSaves - a.totalSaves,
    );
  }
  await batchWriteWithRank(collectionPath, players, filteredPlayers);
}

/**
      * ランクフィールドを指定してプレイヤーのリストをソートし、ランクを割り当てます。
      * @param {Array<Object>} players - ランク付けを行うピッチャーデータのリスト。
      * @param {string} rankField - ランクを保存するフィールド名。
      * @param {Function} sortFunction - プレイヤーをソートするための比較関数。
      * @param {Function} [filterFunction] - ランク付けに含めるプレイヤーを判定する関数（オプション）。
      */
function calculatePitcherRank(
    players, rankField, sortFunction, filterFunction = () => true,
) {
  const filteredPlayers = players.filter(filterFunction); // フィルタリング

  filteredPlayers.sort(sortFunction);
  let currentRank = 0;
  let previousValue = null;

  for (let i = 0; i < filteredPlayers.length; i++) {
    const player = filteredPlayers[i];
    const value = player[rankField];
    if (value !== previousValue) {
      currentRank = i + 1;
    }
    player[`${rankField}Rank`] = currentRank;
    previousValue = value;
  }

  // ランク付けに含まれなかったプレイヤーのランクを null に設定
  players.forEach((player) => {
    if (!filteredPlayers.includes(player)) {
      player[`${rankField}Rank`] = null;
    }
  });

  // 年齢別ランク付け
  const ageGroups = {};
  for (const player of players) {
    const group = getAgeGroup(player.age);
    if (!ageGroups[group]) ageGroups[group] = [];
    ageGroups[group].push(player);
  }

  for (const [groupKey, groupPlayers] of Object.entries(ageGroups)) {
    const eligible = groupPlayers.filter(filterFunction);
    eligible.sort(sortFunction);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const player = eligible[i];
      const value = player[rankField];
      if (value !== prevValue) {
        groupRank = count + 1;
      }
      player[`${rankField}Rank_age_${groupKey}`] = groupRank;
      count++;
      prevValue = value;
    }

    // ❗️ランク対象外のプレイヤーにも null を付与
    for (const p of groupPlayers) {
      if (!eligible.includes(p)) {
        p[`${rankField}Rank_age_${groupKey}`] = null;
      }
    }
  }
}

/**
 * 都道府県ごとにピッチャーの年間ランキングを保存します。
 * @param {Object} totalPitchersByPrefecture - 都道府県ごとにグループ化された年間ピッチャーデータ。
 * @param {number} year - 現在の年。
 */
async function saveTop10RanksByPrefecturePitcher(
    totalPitchersByPrefecture, year) {
  const rankCategories = [
    "winRateRank", "totalEarnedRunsRank", "totalPStrikeoutsRank",
    "totalHoldPointsRank", "totalSavesRank", "eraRank",
  ];

  const ageGroups = [
    "0_17", "18_29", "30_39", "40_49", "50_59",
    "60_69", "70_79", "80_89", "90_100",
  ];

  for (
    const [prefecture, pitchers] of Object.entries(totalPitchersByPrefecture)
  ) {
    const topRanks = {};
    rankCategories.forEach((category) => {
      topRanks[category] = pitchers
          .filter((p) => p[category] && p[category] <= 10)
          .map((p) => {
            const entry = {
              id: p.id,
              name: p.name,
              team: p.team,
              teamID: p.teamID,
              rank: p[category],
              value: p[category.replace("Rank", "")],
              totalAppearances: p.totalAppearances || 0,
              age: p.age || null,
            };

            if (category === "eraRank") {
              Object.assign(entry, {
                totalInningsPitched: p.totalInningsPitched,
                totalEarnedRuns: p.totalEarnedRuns,
                totalPStrikeouts: p.totalPStrikeouts,
                totalHitsAllowed: p.totalHitsAllowed,
                totalWalks: p.totalWalks,
                totalHitByPitch: p.totalHitByPitch,
                totalRunsAllowed: p.totalRunsAllowed,
                totalCompleteGames: p.totalCompleteGames,
                totalShutouts: p.totalShutouts,
                totalHolds: p.totalHolds,
                totalSaves: p.totalSaves,
                totalBattersFaced: p.totalBattersFaced,
                totalWins: p.totalWins,
                totalLosses: p.totalLosses,
                winRate: p.winRate,
                age: p.age,
                totalHoldPoints: p.totalHoldPoints,
              });
            }

            return entry;
          });
    });

    const ageTopRanks = {};
    for (const group of ageGroups) {
      for (const category of rankCategories) {
        const ageCategory = `${category}_age_${group}`;
        ageTopRanks[ageCategory] = pitchers
            .filter((p) => p[ageCategory] && p[ageCategory] <= 10)
            .map((p) => {
              const entry = {
                id: p.id,
                name: p.name,
                team: p.team,
                teamID: p.teamID,
                rank: p[ageCategory],
                value: p[category.replace("Rank", "")],
                totalAppearances: p.totalAppearances || 0,
                age: p.age,
              };

              if (category === "eraRank") {
                Object.assign(entry, {
                  totalInningsPitched: p.totalInningsPitched,
                  totalEarnedRuns: p.totalEarnedRuns,
                  totalPStrikeouts: p.totalPStrikeouts,
                  totalHitsAllowed: p.totalHitsAllowed,
                  totalWalks: p.totalWalks,
                  totalHitByPitch: p.totalHitByPitch,
                  totalRunsAllowed: p.totalRunsAllowed,
                  totalCompleteGames: p.totalCompleteGames,
                  totalShutouts: p.totalShutouts,
                  totalHolds: p.totalHolds,
                  totalSaves: p.totalSaves,
                  totalBattersFaced: p.totalBattersFaced,
                  totalWins: p.totalWins,
                  totalLosses: p.totalLosses,
                  winRate: p.winRate,
                  totalHoldPoints: p.totalHoldPoints,
                });
              }

              return entry;
            });
      }
    }

    const collectionPath = `pitcherRanking/${year}_total/${prefecture}`;
    const batch = db.batch();

    for (const [category, data] of Object.entries(topRanks)) {
      if (data.length > 0) {
        const docRef = db.doc(`${collectionPath}/${category}`);
        batch.set(docRef, {PrefectureTop10: data});
      }
    }

    for (const [ageCategory, data] of Object.entries(ageTopRanks)) {
      if (data.length > 0) {
        const group = ageCategory.split("_age_")[1];
        const docRef = db.doc(`${collectionPath}/${ageCategory}`);
        batch.set(docRef, {[`PrefectureTop10_age_${group}`]: data});
      }
    }

    for (const p of pitchers) {
      const uid = p.id;
      if (uid) {
        for (const category of rankCategories) {
          const ref = db.doc(`users/${uid}/rankCtxPitcher/${category}`);
          batch.delete(ref);
        }
        for (const group of ageGroups) {
          for (const category of rankCategories) {
            const ageCategory = `${category}_age_${group}`;
            const ref = db.doc(`users/${uid}/rankCtxPitcher/${ageCategory}`);
            batch.delete(ref);
          }
        }
      }
    }

    for (const category of rankCategories) {
      const sorted = pitchers
          .filter((p) => p[category] != null)
          .sort((a, b) => (a[category] || 9999) - (b[category] || 9999));

      for (const p of sorted) {
        const userId = p.id;
        const rankValue = p[category];
        if (!userId || rankValue == null || rankValue <= 10) continue;

        const idx = sorted.findIndex((x) => x.id === userId);
        if (idx === -1) continue;

        const context = [];
        for (
          let i = Math.max(0, idx - 3); i <=
           Math.min(sorted.length - 1, idx + 3); i++
        ) {
          context.push(sorted[i]);
        }

        const oneBelow = sorted.slice(idx + 1).find(
            (x) => (x[category] != null ? x[category] : 9999) > rankValue,
        );
        if (oneBelow) context.push(oneBelow);

        const ref = db.doc(`users/${userId}/rankCtxPitcher/${category}`);
        batch.set(ref, {context}, {merge: true});
      }
    }

    for (const group of ageGroups) {
      for (const category of rankCategories) {
        const ageCategory = `${category}_age_${group}`;
        const sorted = pitchers
            .filter((p) =>
              p[ageCategory] != null)
            .sort((a, b) =>
              (a[ageCategory] || 9999) - (b[ageCategory] || 9999));

        for (const p of sorted) {
          const userId = p.id;
          const rankValue = p[ageCategory];
          if (!userId || rankValue == null || rankValue <= 10) continue;

          const idx = sorted.findIndex((x) => x.id === userId);
          if (idx === -1) continue;

          const context = [];
          for (
            let i = Math.max(0, idx - 3); i <=
            Math.min(sorted.length - 1, idx + 3); i++
          ) {
            context.push(sorted[i]);
          }

          const oneBelow = sorted.slice(idx + 1).find(
              (x) => (x[ageCategory] != null ?
                x[ageCategory] : 9999) > rankValue,
          );
          if (oneBelow) context.push(oneBelow);

          const ref = db.doc(`users/${userId}/rankCtxPitcher/${ageCategory}`);
          batch.set(ref, {context}, {merge: true});
        }
      }
    }

    await batch.commit();

    // 年齢別人数のカウントと stats への保存（上書きせずマージ）
    const ageGroupCounts = {};
    for (const group of ageGroups) {
      const count = pitchers.filter((p) => {
        const key = `totalPStrikeoutsRank_age_${group}`;
        return p[key] !== undefined && p[key] !== null;
      }).length;
      ageGroupCounts[`totalPlayers_age_${group}`] = count;
    }

    const statsRef = db.doc(`${collectionPath}/stats`);
    await statsRef.set({stats: ageGroupCounts}, {merge: true});
  }
}

/**
      * 全国レベルのピッチャーランキングを保存します。
      * @param {Object} totalPitchersByPrefecture - 都道府県ごとにグループ化された年間ピッチャーデータ。
      * @param {number} year - 現在の年。
      */
async function saveNationwideTopRanksPitcher(totalPitchersByPrefecture, year) {
  const rankCategories = [
    "eraRank", "winRateRank", "totalPStrikeoutsRank",
    "totalHoldPointsRank", "totalSavesRank",
  ];

  const ageGroups = [
    "0_17", "18_29", "30_39", "40_49", "50_59",
    "60_69", "70_79", "80_89", "90_100",
  ];

  const nationwideRanks = {};
  const addedIdsByAgeCategory = {};

  // カテゴリ初期化
  for (const category of rankCategories) {
    nationwideRanks[category] = [];
    for (const ageGroup of ageGroups) {
      const ageKey = `${category}_age_${ageGroup}`;
      nationwideRanks[ageKey] = [];
      addedIdsByAgeCategory[ageKey] = new Set();
    }
  }

  for (
    const [prefecture, pitchers] of Object.entries(totalPitchersByPrefecture)
  ) {
    for (const category of rankCategories) {
      pitchers.forEach((player) => {
        const baseValue = category.replace("Rank", "");
        const value =
         player[baseValue] !== undefined ? player[baseValue] : null;

        const entry = {
          id: player.id,
          name: player.name,
          team: player.team,
          teamID: player.teamID,
          prefecture,
          value,
          totalAppearances: player.totalAppearances || 0,
          age: player.age || null,
        };

        if (category === "eraRank") {
          entry.totalInningsPitched = player.totalInningsPitched || 0;
        }

        // 全体ランキング1位
        if (player[category] === 1) {
          nationwideRanks[category].push(entry);
        }

        // 年齢別ランキング1位
        const ageGroup = getAgeGroup(player.age);
        const ageCategoryKey = `${category}_age_${ageGroup}`;
        if (player[ageCategoryKey] === 1) {
          const uniqueKey = `${player.id}_${category}_${ageGroup}`;
          if (!addedIdsByAgeCategory[ageCategoryKey].has(uniqueKey)) {
            nationwideRanks[ageCategoryKey].push({
              ...entry,
              rank: 1,
              ageGroup: ageGroup,
            });
            addedIdsByAgeCategory[ageCategoryKey].add(uniqueKey);
          }
        }
      });
    }
  }

  // Firestore へ保存
  const collectionPath = `pitcherRanking/${year}_total/全国`;
  const batch = db.batch();

  for (const [category, data] of Object.entries(nationwideRanks)) {
    if (data.length > 0) {
      const docRef = db.doc(`${collectionPath}/${category}`);
      batch.set(docRef, {top: data});
    }
  }

  await batch.commit();

  const ageCounts = {};
  for (const group of ageGroups) {
    ageCounts[`totalPlayers_age_${group}`] = 0;
  }

  for (const prefecture of Object.keys(totalPitchersByPrefecture)) {
    const statsRef =
      db.doc(`pitcherRanking/${year}_total/${prefecture}/stats`);
    const statsSnap = await statsRef.get();
    if (statsSnap.exists) {
      const statsData = statsSnap.data().stats || {};
      for (const group of ageGroups) {
        const key = `totalPlayers_age_${group}`;
        ageCounts[key] += statsData[key] || 0;
      }
    }
  }

  const nationwideStatsRef =
    db.doc(`pitcherRanking/${year}_total/全国/stats`);
  await nationwideStatsRef.set({stats: ageCounts}, {merge: true});
}

/**
      * Firestoreにバッチ書き込みし、順位を付ける関数
      * @param {string} collectionPath - Firestoreのコレクションパス。
      * @param {Array} players - 書き込むプレイヤーのリスト。
      */
async function batchWriteWithRank(collectionPath, players) {
  let batch = db.batch();
  let operationCount = 0;

  for (let i = 0; i < players.length; i++) {
    const player = players[i];

    if (!player.id) {
      console.warn("⚠️ player.id が無効なためスキップ:", player);
      continue;
    }

    const docRef = db.collection(collectionPath).doc(player.id);
    batch.set(docRef, player);
    operationCount++;

    if (operationCount === 500) {
      await batch.commit();
      batch = db.batch();
      operationCount = 0;
    }
  }

  if (operationCount > 0) {
    await batch.commit();
  }
}

// 月一チームランキング
export const createTeamRankingProcessing = onSchedule(
    {
      schedule: "0 1 1 * *", // 毎月1日 1:00 AM
      timeZone: "Asia/Tokyo",
      timeoutSeconds: 3600,
    },
    async () => {
      const date = new Date();
      date.setMonth(date.getMonth() - 1); // ←先月のデータを処理
      const year = date.getFullYear();
      const month = date.getMonth() + 1;

      const skipAnnualUpdate = [12, 1, 2].includes(month);
      console.log(`📅 チームランキング処理開始 - ${year}/${month}`);
      if (skipAnnualUpdate) {
        console.log("🛑 年間ランキングはこの月にはスキップされます");
      }

      const payload = {year, month};

      // 月次処理タスクをキューに追加
      await client.createTask({
        parent: client.queuePath(project, location, "team-month-ranking-queue"),
        task: {
          httpRequest: {
            httpMethod: "POST",
            url: "https://processteammonthlyranking-etndg3x4ra-uc.a.run.app",
            body: Buffer.from(JSON.stringify(payload)).toString("base64"),
            headers: {"Content-Type": "application/json"},
          },
        },
      });

      // 年間処理タスクをキューに追加（スキップ対象外のみ）
      if (!skipAnnualUpdate) {
        await client.createTask({
          parent: client.queuePath(
              project, location, "team-annual-ranking-queue",
          ),
          task: {
            httpRequest: {
              httpMethod: "POST",
              url: "https://processteamannualranking-etndg3x4ra-uc.a.run.app",
              body: Buffer.from(JSON.stringify(payload)).toString("base64"),
              headers: {"Content-Type": "application/json"},
            },
          },
        });
      }

      console.log("📌 チームランキングのCloud Tasksをすべて追加しました。");
    },
);

export const processTeamMonthlyRanking = onRequest(
    {timeoutSeconds: 3600},
    async (req, res) => {
      try {
        const {year, month} = req.body;
        console.log(`📦 月次チームデータ処理開始 - ${year}/${month}`);

        const allTeamsSnapshot = await db.collection("teams").get();
        console.log(`✅ チーム数: ${allTeamsSnapshot.size}`);

        const teamNames = {};
        allTeamsSnapshot.docs.forEach((doc) => {
          const data = doc.data();
          teamNames[doc.id] = data.teamName || "不明"; // teamName がない場合は "不明"
        });

        const monthlyTeamsByPrefecture = {};

        // 各チームのデータを処理
        for (const teamDoc of allTeamsSnapshot.docs) {
          try {
            const teamID = teamDoc.id;
            console.log(`🔁 Monthly: processing team ${teamID}`);
            // --- サブスク判定: プラチナサブスク対象チームのみ処理 ---
            const subscriptionRef =
          await db.doc(`teams/${teamDoc.id}/subscription/iOS`).get();
            const androidRef =
          await db.doc(`teams/${teamDoc.id}/subscription/android`).get();

            const iosData =
          subscriptionRef.exists ? subscriptionRef.data() : null;
            const androidData = androidRef.exists ? androidRef.data() : null;

            const iosStatus = iosData && iosData.status === "active";
            const iosIdMatch =
          iosData &&
          (iosData.productId === "com.sk.bNet.teamPlatina12month" ||
            iosData.productId === "com.sk.bNet.teamPlatina");

            const androidStatus =
            androidData && androidData.status === "active";
            const androidIdMatch =
          androidData &&
          (androidData.productId === "com.sk.bNet.teamPlatina12month" ||
            androidData.productId === "com.sk.bNet.teamPlatina");

            const isPlatinaSub =
           (iosStatus && iosIdMatch) || (androidStatus && androidIdMatch);

            if (!isPlatinaSub) {
              console.log(`🚫 チーム ${teamDoc.id} はプラチナサブスク対象外のためスキップ`);
              continue;
            }

            const teamData = teamDoc.data();

            if (!teamData.prefecture) {
              console.warn(
                  `⚠️ Team ${teamID} has no prefecture set. Skipping...`,
              );
              continue;
            }

            const teamPrefecture = teamData.prefecture;
            const teamName = teamNames[teamID];
            const teamAverageAge =
            (teamData && teamData.averageAge !== undefined) ?
            teamData.averageAge :
            null;

            // 月次データ取得
            const monthlyStatsRef =
            db.doc(`/teams/${teamID}/stats/results_stats_${year}_${month}`);
            const monthlyStatsDoc = await monthlyStatsRef.get();

            if (!monthlyStatsDoc.exists) {
              console.warn(`
                🚨 No monthly stats for team: ${teamID}. Skipping...`,
              );
              continue; // 月ごとのデータがない場合はスキップ
            }

            console.log(`✅ Found monthly stats for team: ${teamID}`);

            const monthlyData = monthlyStatsDoc.data();
            const requiredGames =
          (month === 12 || month === 1 || month === 2) ? 0 : 4;

            const teamDataToSave = {
              id: teamID,
              teamName: teamName,
              battingAverage: monthlyData.battingAverage || 0,
              totalGames: monthlyData.totalGames || 0,
              atBats: monthlyData.atBats || 0,
              sluggingPercentage: monthlyData.sluggingPercentage || 0,
              onBasePercentage: monthlyData.onBasePercentage || 0,
              winRate: monthlyData.winRate || 0,
              totalLosses: monthlyData.totalLosses || 0,
              totalWins: monthlyData.totalWins || 0,
              totalDraws: monthlyData.totalDraws || 0,
              totalScore: monthlyData.totalScore || 0,
              totalRunsAllowed: monthlyData.totalRunsAllowed || 0,
              fieldingPercentage: monthlyData.fieldingPercentage || 0,
              totalPutouts: monthlyData.totalPutouts || 0,
              totalAssists: monthlyData.totalAssists || 0,
              totalErrors: monthlyData.totalErrors || 0,
              averageAge: teamAverageAge,
              era: monthlyData.era || 0,
              isEligible: monthlyData.totalGames >= requiredGames,
            };

            if (!monthlyTeamsByPrefecture[teamPrefecture]) {
              monthlyTeamsByPrefecture[teamPrefecture] = [];
            }
            monthlyTeamsByPrefecture[teamPrefecture].push(teamDataToSave);
          } catch (err) {
            console.error(`❌ Monthly: team ${teamDoc.id} failed`, err);
            continue;
          }
        }

        // 🔄 Firestore に保存
        for (
          const [prefecture, teams] of Object.entries(monthlyTeamsByPrefecture)
        ) {
          const collectionPath = `teamRanking/${year}_${month}/${prefecture}`;
          let batch = db.batch();
          let count = 0;

          for (const team of teams) {
            const docRef = db.doc(`${collectionPath}/${team.id}`);
            console.log(
                `保存対象: ${prefecture}（${teams.length} チーム）➡️ ${collectionPath}`,
            );
            batch.set(docRef, team);
            count++;

            if (count === 500) {
              await batch.commit();
              batch = db.batch();
              count = 0;
            }
          }

          if (count > 0) {
            await batch.commit();
          }

          console.log(`📁 ${prefecture} のチーム月次データを保存しました (${teams.length} 件)`);
        }

        res.status(200).send("✅ 月次チームデータを保存しました");
      } catch (error) {
        console.error("🚨 processTeamMonthlyRanking Error:", error);
        res.status(500).send("❌ 月次チームデータの保存に失敗しました");
      }
    },
);


export const processTeamAnnualRanking = onRequest(
    {
      timeoutSeconds: 3600,
    },
    async (req, res) => {
      try {
        const {year, month} = req.body;
        console.log(`📦 processTeamAnnualRanking 開始: ${year}年 月: ${month}`);

        const skipAnnualUpdate = [12, 1, 2].includes(month);
        if (skipAnnualUpdate) {
          console.log("🛑 年間データの保存はスキップされます（この月では処理されません）");
          return res.status(200).send("Annual update skipped for this month.");
        }

        // ✅ ここで事前削除
        const deleteTarget = db.doc(`teamRanking/${year}_all`);
        console.log(`🧹 teamRanking/${year}_all を recursiveDelete します...`);
        await db.recursiveDelete(deleteTarget);
        console.log("🧹 削除完了");

        const teamsSnapshot = await db.collection("teams").get();
        const teamIdToNameMap = {};
        const yearlyTeamsByPrefecture = {};

        teamsSnapshot.forEach((doc) => {
          const data = doc.data();
          teamIdToNameMap[doc.id] = data.teamName || "不明";
        });

        for (const teamDoc of teamsSnapshot.docs) {
          try {
            const teamID = teamDoc.id;
            console.log(`🔁 Annual: processing team ${teamID}`);
            const teamData = teamDoc.data();

            const subscriptionRef = db.doc(`teams/${teamID}/subscription/iOS`);
            const subscriptionDoc = await subscriptionRef.get();
            const subData =
          subscriptionDoc.exists ? subscriptionDoc.data() : null;

            let isAndroidValid = false;
            const isValidSubscription =
          subData &&
          subData.status === "active" &&
          (subData.productId === "com.sk.bNet.teamPlatina12month" ||
            subData.productId === "com.sk.bNet.teamPlatina");

            if (!isValidSubscription) {
              if (!subData) {
                const androidSubRef =
              db.doc(`teams/${teamID}/subscription/android`);
                const androidSubDoc = await androidSubRef.get();
                const androidData =
              androidSubDoc.exists ? androidSubDoc.data() : null;

                isAndroidValid =
              androidData &&
              androidData.status === "active" &&
              (androidData.productId === "com.sk.bNet.teamPlatina12month" ||
                androidData.productId === "com.sk.bNet.teamPlatina");

                if (!isAndroidValid) {
                  console.log(`⏭ チーム ${teamID} は有効なAndroidサブスクではありません。スキップします`);
                  continue;
                }
              } else {
                console.log(`⏭ チーム ${teamID} は有効なプラチナサブスクではありません。スキップします`);
                continue;
              }
            }

            if (!teamData.prefecture) {
              console.warn(`⚠️ チーム ${teamID} に都道府県が設定されていません。スキップします。`);
              continue;
            }

            const teamPrefecture = teamData.prefecture;
            const teamName = teamIdToNameMap[teamID];
            const teamAverageAge =
            (teamData && teamData.averageAge !== undefined) ?
            teamData.averageAge :
            null;

            const yearlyStatsRef =
          db.doc(`/teams/${teamID}/stats/results_stats_${year}_all`);
            const yearlyStatsDoc = await yearlyStatsRef.get();

            if (!yearlyStatsDoc.exists) {
              console.warn(`🚫 年間データが見つかりません: ${teamID}`);
              continue;
            }

            const yearlyData = yearlyStatsDoc.data();
            const requiredGamesTotal =
          month >= 3 ? Math.min((month - 2) * 4, 36) : 36;

            const yearlyTeamData = {
              id: teamID,
              teamName,
              prefecture: teamPrefecture,
              battingAverage: yearlyData.battingAverage || 0,
              hits: yearlyData.hits || 0,
              totalGames: yearlyData.totalGames || 0,
              atBats: yearlyData.atBats || 0,
              sluggingPercentage: yearlyData.sluggingPercentage || 0,
              onBasePercentage: yearlyData.onBasePercentage || 0,
              winRate: yearlyData.winRate || 0,
              totalLosses: yearlyData.totalLosses || 0,
              totalWins: yearlyData.totalWins || 0,
              totalDraws: yearlyData.totalDraws || 0,
              totalScore: yearlyData.totalScore || 0,
              totalRunsAllowed: yearlyData.totalRunsAllowed || 0,
              fieldingPercentage: yearlyData.fieldingPercentage || 0,
              totalPutouts: yearlyData.totalPutouts || 0,
              totalAssists: yearlyData.totalAssists || 0,
              totalErrors: yearlyData.totalErrors || 0,
              era: yearlyData.era || 0,
              averageAge: teamAverageAge,
              totalInningsPitched: yearlyData.totalInningsPitched || 0,
              isEligibleAll: yearlyData.totalGames >= requiredGamesTotal,
            };

            if (!yearlyTeamsByPrefecture[teamPrefecture]) {
              yearlyTeamsByPrefecture[teamPrefecture] = [];
            }
            yearlyTeamsByPrefecture[teamPrefecture].push(yearlyTeamData);
          } catch (err) {
            console.error(`❌ Annual: team ${teamDoc.id} failed`, err);
            continue;
          }
        }

        // 保存
        for (
          const [prefecture, teams] of Object.entries(yearlyTeamsByPrefecture)
        ) {
          const path = `teamRanking/${year}_all/${prefecture}`;
          const batch = db.batch();
          for (const team of teams) {
            const docRef = db.collection(path).doc(team.id);
            batch.set(docRef, team);
          }
          await batch.commit();
          console.log(`✅ 保存完了: ${prefecture} (${teams.length} チーム)`);
        }

        let totalTeamsCount = 0;
        for (
          const [prefecture, teams] of Object.entries(yearlyTeamsByPrefecture)
        ) {
          const statsRef =
          db.doc(`teamRanking/${year}_all/${prefecture}/stats`);
          await statsRef.set({teamsCount: teams.length}, {merge: true});
          totalTeamsCount += teams.length;
        }

        const nationwideStatsRef = db.doc(`teamRanking/${year}_all/全国/stats`);
        await nationwideStatsRef.set({totalTeamsCount}, {merge: true});

        res.status(200).send("✅ 年間チームデータの保存完了");
      } catch (error) {
        console.error("🚨 processTeamAnnualRanking エラー:", error);
        res.status(500).send("❌ 年間チームランキング処理に失敗しました");
      }
    },
);


// 月一チームーランク付
const teamQueuePath =
client.queuePath(project, location, "team-ranking-queue");
const teamYearlyQueuePath =
client.queuePath(project, location, "team-yearly-ranking-queue");
const nationwideTeamQueuePath =
client.queuePath(project, location, "nationwide-team-queue");

export const TeamRankingProcessing = onSchedule(
    {
      schedule: "40 2 1 * *",
      timeZone: "Asia/Tokyo",
      timeoutSeconds: 3600,
    },
    async () => {
      const now = new Date();
      now.setMonth(now.getMonth() - 1); // ←先月のデータを処理
      const year = now.getFullYear();
      const month = now.getMonth() + 1;

      console.log(`🚀 ランキング処理開始: ${year}年 ${month}月`);

      // 🔁 年間と全国の処理スキップ判定（対象が12月,1月,2月ならスキップ）
      const skipAnnualUpdate = [12, 1, 2].includes(month);
      if (skipAnnualUpdate) {
        console.log("⏭ 年間・全国ランキングの更新はスキップされます");
      }


      // 🔍 Firestore から都道府県リストを取得
      const prefectureRefs = await db
          .doc(`teamRanking/${year}_${month}`)
          .listCollections();

      const prefectures = prefectureRefs.map((col) => col.id);

      console.log(`🏆 都道府県数: ${prefectures.length}`);

      for (const prefecture of prefectures) {
        const payload = {
          year,
          month,
          prefecture,
        };

        // 月
        await client.createTask({
          parent: teamQueuePath,
          task: {
            httpRequest: {
              httpMethod: "POST",
              url: "https://processteamranking-etndg3x4ra-uc.a.run.app",
              body: Buffer.from(JSON.stringify(payload)).toString("base64"),
              headers: {
                "Content-Type": "application/json",
              },
            },
          },
        });
        console.log(`✅ Batterタスク追加: ${prefecture}`);

        if (!skipAnnualUpdate) {
          // 年間
          await client.createTask({
            parent: teamYearlyQueuePath,
            task: {
              httpRequest: {
                httpMethod: "POST",
                url: "https://processteamyearly-etndg3x4ra-uc.a.run.app",
                body: Buffer.from(JSON.stringify(payload)).toString("base64"),
                headers: {"Content-Type": "application/json"},
              },
            },
          });
        }
      }

      // 全国ランキングタスク（最後に追加
      if (!skipAnnualUpdate) {
        await client.createTask({
          parent: nationwideTeamQueuePath,
          task: {
            httpRequest: {
              httpMethod: "POST",
              url: "https://processnationwideteamranking-etndg3x4ra-uc.a.run.app",
              body: Buffer.from(JSON.stringify({year})).toString("base64"),
              headers: {"Content-Type": "application/json"},
            },
          },
        });
      }
      console.log("📌 全タスクのスケジューリング完了");
    });

export const processTeamRanking = onRequest(
    {
      timeoutSeconds: 3600,
    },
    async (req, res) => {
      try {
        const {year, month, prefecture} = req.body;

        console.log(
            `📦 processTeamRanking: ${year}年 ${month}月 - ${prefecture}`,
        );

        // チームデータを取得
        const monthlyTeamsSnapshot = await db
            .collection(`teamRanking/${year}_${month}/${prefecture}`)
            .get();

        const teams = [];
        monthlyTeamsSnapshot.forEach((doc) => {
          teams.push(doc.data());
        });

        if (teams.length === 0) {
          console.log("⚠️ 該当チームなし");
          return res.status(200).send("No teams found for monthly ranking");
        }

        // 月次ランキングを保存
        await saveTeamRankingByPrefecture({[prefecture]: teams}, year, month);

        res.status(200).send("✅ Team ranking processed successfully");
      } catch (error) {
        console.error("🚨 processTeamRanking Error:", error);
        res.status(500).send("❌ Failed to process team ranking");
      }
    });

export const processTeamYearly = onRequest(
    {
      timeoutSeconds: 3600,
    },
    async (req, res) => {
      try {
        const {year, prefecture} = req.body;

        console.log(`📦 processTeamYearly: ${year}年 - ${prefecture}`);

        const teamSnapshot = await db
            .collection(`teamRanking/${year}_all/${prefecture}`)
            .get();

        const teams = [];
        teamSnapshot.forEach((doc) => {
          if (doc.id !== "stats") {
            teams.push({...doc.data(), id: doc.id});
          }
        });

        if (teams.length === 0) {
          console.log(`⚠️ ${prefecture} に年間データがありません`);
          return res.status(200).send("No yearly data found");
        }

        await saveTeamTotalRankingByPrefecture({[prefecture]: teams}, year);
        await saveTeamTop10RanksByPrefecture({[prefecture]: teams}, year);

        res.status(200).send("✅ Team yearly ranking processed successfully");
      } catch (error) {
        console.error("🚨 processTeamYearly Error:", error);
        res.status(500).send("❌ Failed to process team yearly ranking");
      }
    });


export const processNationwideTeamRanking = onRequest(
    {
      timeoutSeconds: 3600,
    },
    async (req, res) => {
      try {
        const {year} = req.body;

        const prefectureRefs = await db
            .doc(`teamRanking/${year}_all`)
            .listCollections();

        const allTeamsByPrefecture = {};

        for (const col of prefectureRefs) {
          const prefecture = col.id;

          if (prefecture === "全国") continue;

          const snapshot = await db
              .collection(`teamRanking/${year}_all/${prefecture}`)
              .get();

          const teams = [];
          snapshot.forEach((doc) => {
            teams.push({...doc.data(), id: doc.id});
          });

          allTeamsByPrefecture[prefecture] = teams;
        }

        // ✅ 通常の全国ランキング保存
        await saveTeamNationwideTopRanks(allTeamsByPrefecture, year);

        res.status(200).send("✅ 全国チームランキングを更新しました");
      } catch (error) {
        console.error("🚨 processNationwideTeamRanking Error:", error);
        res.status(500).send("❌ 全国ランキング処理に失敗しました");
      }
    });

/**
 * 月次ランキングを保存
 *
 * @param {Object} monthlyTeamsByPrefecture - 都道府県ごとにチームデータをまとめたオブジェクト
 * @param {number} year - 対象の年（例: 2025）
 * @param {number} month - 対象の月（1〜12）
 */
async function saveTeamRankingByPrefecture(
    monthlyTeamsByPrefecture, year, month,
) {
  console.log(`📂 Saving Monthly Rankings for ${year}-${month}`);

  for (const [prefecture, teams] of Object.entries(monthlyTeamsByPrefecture)) {
    console.log(
        `🏅 Processing Monthly Ranking for:
        ${prefecture}, Teams Count: ${teams.length}`,
    );

    const monthlyCollectionPath = `teamRanking/${year}_${month}/${prefecture}`;
    await processAndSaveTeamRanks(teams, monthlyCollectionPath, true);

    // 追加: 月次チームTop10（勝率）＋年齢別Top10の保存
    await saveMonthlyTeamTop10RanksByPrefecture(
        {[prefecture]: teams}, year, month,
    );
  }
}


/**
 * 月次チームTop10（勝率）と年齢別Top10を保存
 * @param {Object} teamsByPrefecture -
 * 都道府県ごとにグループ化されたチームデータ { prefecture: Team[] }
 * @param {number} year - 年
 * @param {number|string} month - 月（ゼロ埋め・非ゼロ埋めどちらでも可）
 */
async function saveMonthlyTeamTop10RanksByPrefecture(
    teamsByPrefecture, year, month,
) {
  const ageGroups = [
    "0_17", "18_29", "30_39", "40_49", "50_59",
    "60_69", "70_79", "80_89", "90_100",
  ];

  for (const [prefecture, teams] of Object.entries(teamsByPrefecture)) {
    const monthlyCollectionPath = `teamRanking/${year}_${month}/${prefecture}`;
    const batch = db.batch();

    // ▼ 勝率 Top10（全体）
    const top10 = (teams || [])
        .filter((t) => t && t.winRateRank != null && t.winRateRank <= 10)
        .map((t) => ({
          id: t.id || "",
          teamName: t.teamName || "",
          rank: t.winRateRank != null ? t.winRateRank : null,
          value: (t.winRate !== undefined && t.winRate !== null) ?
          t.winRate : null,
          averageAge: (typeof t.averageAge === "number") ? t.averageAge : null,
          battingAverage: t.battingAverage || 0,
          totalGames: t.totalGames || 0,
          atBats: t.atBats || 0,
          sluggingPercentage: t.sluggingPercentage || 0,
          onBasePercentage: t.onBasePercentage || 0,
          winRate: t.winRate || 0,
          totalLosses: t.totalLosses || 0,
          totalWins: t.totalWins || 0,
          totalDraws: t.totalDraws || 0,
          totalScore: t.totalScore || 0,
          totalRunsAllowed: t.totalRunsAllowed || 0,
          fieldingPercentage: t.fieldingPercentage || 0,
          totalPutouts: t.totalPutouts || 0,
          totalAssists: t.totalAssists || 0,
          totalErrors: t.totalErrors || 0,
          era: t.era || 0,
        }));

    if (top10.length > 0) {
      const docRef = db.doc(`${monthlyCollectionPath}/winRateRank`);
      batch.set(docRef, {PrefectureTop10: top10});
    }

    // ▼ 年齢別 Top10（勝率）
    for (const group of ageGroups) {
      const key = `winRateRank_age_${group}`;
      const top10Age = (teams || [])
          .filter((t) => t && t[key] != null && t[key] <= 10)
          .map((t) => ({
            id: t.id || "",
            teamName: t.teamName || "",
            rank: t[key] != null ? t[key] : null,
            value: (t.winRate !== undefined && t.winRate !== null) ?
             t.winRate : null,
            averageAge: (typeof t.averageAge === "number") ?
             t.averageAge : null,
            battingAverage: t.battingAverage || 0,
            totalGames: t.totalGames || 0,
            atBats: t.atBats || 0,
            sluggingPercentage: t.sluggingPercentage || 0,
            onBasePercentage: t.onBasePercentage || 0,
            winRate: t.winRate || 0,
            totalLosses: t.totalLosses || 0,
            totalWins: t.totalWins || 0,
            totalDraws: t.totalDraws || 0,
            totalScore: t.totalScore || 0,
            totalRunsAllowed: t.totalRunsAllowed || 0,
            fieldingPercentage: t.fieldingPercentage || 0,
            totalPutouts: t.totalPutouts || 0,
            totalAssists: t.totalAssists || 0,
            totalErrors: t.totalErrors || 0,
            era: t.era || 0,
          }));

      if (top10Age.length > 0) {
        const docRef =
        db.doc(`${monthlyCollectionPath}/winRateRank_age_${group}`);
        batch.set(docRef, {[`PrefectureTop10_age_${group}`]: top10Age});
      }
    }

    await batch.commit();
    console.log(`
      ✅ Saved monthly Team Top10 (WinRate)
       for ${prefecture} at ${monthlyCollectionPath}`,
    );
  }
}

/**
 * 年間ランキングを保存
 *
 * @param {Object} yearlyTeamsByPrefecture - 都道府県ごとにグループ化された年間チームデータ
 * @param {number} year - 対象の年（例: 2025）
 */
async function saveTeamTotalRankingByPrefecture(yearlyTeamsByPrefecture, year) {
  console.log(`📂 Saving Yearly Rankings for ${year}`);

  for (const [prefecture, teams] of Object.entries(yearlyTeamsByPrefecture)) {
    console.log(
        `🏅 Processing Yearly Ranking for: 
        ${prefecture}, Teams Count: ${teams.length}`,
    );

    const totalCollectionPath = `teamRanking/${year}_all/${prefecture}`;
    await processAndSaveTeamRanks(teams, totalCollectionPath, false);
  }
}

/**
    * ランク付けを計算して保存
    * @param {Array} teams - ランク付けを行うチームのリスト。
    * @param {string} collectionPath - Firestoreのコレクションパス。
    * @param {boolean} isMonthly - 月次ランキングかどうかを示すフラグ。
    */
async function processAndSaveTeamRanks(teams, collectionPath, isMonthly) {
  if (isMonthly) {
    processWinRateRank(teams, true);
  } else {
    processWinRateRank(teams, false);
    processEraRank(teams);
    processBattingAverageRank(teams);
    processSluggingRank(teams);
    processOnBaseRank(teams);
    processFieldingPercentageRank(teams);
  }

  await batchWriteWithTeamRank(collectionPath, teams);
}


/**
 * 指定したランキングカテゴリの上位10位のチームを保存
 * @param {Object} totalTeamsByPrefecture - 都道府県ごとにグループ化されたチームデータ
 * @param {number} year - 対象の年
 */
async function saveTeamTop10RanksByPrefecture(totalTeamsByPrefecture, year) {
  const categoryToFieldMapping = {
    winRateRank: "winRate",
    battingAverageRank: "battingAverage",
    sluggingRank: "sluggingPercentage",
    onBaseRank: "onBasePercentage",
    eraRank: "era",
    fieldingPercentageRank: "fieldingPercentage",
    averageAgeRank: "averageAge",
  };

  const ageGroups = [
    "0_17", "18_29", "30_39", "40_49", "50_59",
    "60_69", "70_79", "80_89", "90_100",
  ];

  for (const [prefecture, teams] of Object.entries(totalTeamsByPrefecture)) {
    console.log(`🗾 都道府県: ${prefecture}`);
    console.log("🏷 Top10候補:", JSON.stringify(teams, null, 2));

    const totalCollectionPath = `teamRanking/${year}_all/${prefecture}`;
    const batch = db.batch();

    const rankCategories = Object.keys(categoryToFieldMapping);

    for (const category of rankCategories) {
      const field = categoryToFieldMapping[category];

      const top10 = teams
          .filter((team) => team[category] && team[category] <= 10)
          .map((team) => {
            const value = team[field] !== undefined ? team[field] : null;
            const entry = {
              id: team.id || "",
              teamName: team.teamName || "",
              rank: team[category] || null,
              value: value,
              averageAge:
              typeof team.averageAge === "number" ? team.averageAge : null,
            };

            if (category === "winRateRank") {
              entry.totalGames = team.totalGames || 0;
              entry.atBats = team.atBats || 0;
              entry.battingAverage = team.battingAverage || 0,
              entry.sluggingPercentage = team.sluggingPercentage || 0;
              entry.onBasePercentage = team.onBasePercentage || 0,
              entry.winRate = team.winRate || 0;
              entry.totalWins = team.totalWins || 0;
              entry.totalLosses = team.totalLosses || 0;
              entry.totalDraws = team.totalDraws || 0;
              entry.totalScore = team.totalScore || 0;
              entry.totalRunsAllowed = team.totalRunsAllowed || 0;
              entry.fieldingPercentage = team.fieldingPercentage || 0;
              entry.totalPutouts = team.totalPutouts || 0;
              entry.totalAssists = team.totalAssists || 0;
              entry.totalErrors = team.totalErrors || 0;
              entry.era = team.era || 0;
            }

            if (category === "eraRank") {
              entry.totalInningsPitched = team.totalInningsPitched || 0;
            }

            if (category === "fieldingPercentageRank") {
              entry.totalPutouts = team.totalPutouts || 0;
              entry.totalAssists = team.totalAssists || 0;
              entry.totalErrors = team.totalErrors || 0;
            }

            if (category === "battingAverageRank") {
              entry.atBats = team.atBats || 0;
              entry.hits = team.hits || 0;
            }

            if (category === "onBaseRank" || category === "sluggingRank") {
              entry.atBats = team.atBats || 0;
            }

            return entry;
          });

      if (top10.length > 0) {
        const docRef = db.doc(`${totalCollectionPath}/${category}`);
        batch.set(docRef, {PrefectureTop10: top10});
      }

      // 🔵 全体ランキングの rankingContext（±2件）も保存する
      const sortedByRank = teams
          .filter((t) => t[category] !== undefined && t[category] !== null)
          .sort((a, b) => (a[category] || 9999) - (b[category] || 9999));

      for (const team of sortedByRank) {
        const teamId = team.id;
        const rankValue = team[category];
        if (!teamId || !rankValue || rankValue <= 10) continue; // Top10は除外

        const idx = sortedByRank.findIndex((t) => t.id === teamId);
        if (idx === -1) continue;

        const context = [];
        for (let i = Math.max(0, idx - 2); i <=
        Math.min(sortedByRank.length - 1, idx + 2); i++) {
          context.push(sortedByRank[i]);
        }

        const teamDocRef = db.doc(`teams/${teamId}/rankingContext/${category}`);
        batch.set(teamDocRef, {context}, {merge: true});
      }

      // 年齢別
      for (const group of ageGroups) {
        const ageCategory = `${category}_age_${group}`;
        const top10ForAge = teams
            .filter((team) => team[ageCategory] && team[ageCategory] <= 10)
            .map((team) => {
              const value = team[field] !== undefined ? team[field] : null;
              const entry = {
                id: team.id || "",
                teamName: team.teamName || "",
                rank: team[ageCategory] || null,
                value: value,
                averageAge:
                typeof team.averageAge === "number" ? team.averageAge : null,
              };

              if (category === "winRateRank") {
                entry.totalGames = team.totalGames || 0;
                entry.atBats = team.atBats || 0;
                entry.battingAverage = team.battingAverage || 0,
                entry.sluggingPercentage = team.sluggingPercentage || 0;
                entry.onBasePercentage = team.onBasePercentage || 0,
                entry.winRate = team.winRate || 0;
                entry.totalWins = team.totalWins || 0;
                entry.totalLosses = team.totalLosses || 0;
                entry.totalDraws = team.totalDraws || 0;
                entry.totalScore = team.totalScore || 0;
                entry.totalRunsAllowed = team.totalRunsAllowed || 0;
                entry.fieldingPercentage = team.fieldingPercentage || 0;
                entry.totalPutouts = team.totalPutouts || 0;
                entry.totalAssists = team.totalAssists || 0;
                entry.totalErrors = team.totalErrors || 0;
                entry.era = team.era || 0;
              }

              if (category === "eraRank") {
                entry.totalInningsPitched = team.totalInningsPitched || 0;
              }

              if (category === "fieldingPercentageRank") {
                entry.totalPutouts = team.totalPutouts || 0;
                entry.totalAssists = team.totalAssists || 0;
                entry.totalErrors = team.totalErrors || 0;
              }

              if (category === "battingAverageRank") {
                entry.atBats = team.atBats || 0;
                entry.hits = team.hits || 0;
              }

              if (category === "onBaseRank" || category === "sluggingRank") {
                entry.atBats = team.atBats || 0;
              }

              return entry;
            });

        if (top10ForAge.length > 0) {
          const docRef =
          db.doc(`${totalCollectionPath}/${category}_age_${group}`);
          batch.set(docRef, {[`PrefectureTop10_age_${group}`]: top10ForAge});
        }

        // rankingContext (±2) も保存
        const sortedByAgeRank = teams
            .filter((t) =>
              t[ageCategory] !== undefined && t[ageCategory] !== null)
            .sort((a, b) =>
              (a[ageCategory] || 9999) - (b[ageCategory] || 9999));

        for (const team of sortedByAgeRank) {
          const teamId = team.id;
          const rankValue = team[ageCategory];
          if (!teamId || !rankValue || rankValue <= 10) continue;

          const idx = sortedByAgeRank.findIndex((t) => t.id === teamId);
          if (idx === -1) continue;

          const context = [];
          for (let i = Math.max(0, idx - 2); i <=
          Math.min(sortedByAgeRank.length - 1, idx + 2); i++) {
            context.push(sortedByAgeRank[i]);
          }

          const teamDocRef =
          db.doc(`teams/${teamId}/rankingContext/${ageCategory}`);
          batch.set(teamDocRef, {context}, {merge: true});
        }
      }
    }
    await batch.commit();

    // 年齢別人数のカウントと stats への保存（チーム版）
    const ageGroupCounts = {};
    for (const group of ageGroups) {
      const key = `winRateRank_age_${group}`;
      const count = teams.filter((t) => key in t).length;
      ageGroupCounts[`totalTeams_age_${group}`] = count;
    }

    const statsRef = db.doc(`${totalCollectionPath}/stats`);
    await statsRef.set({stats: ageGroupCounts}, {merge: true});
  }
}

/**
* 勝率のランクを計算
* @param {Array} teams - チームのリスト。
* @param {boolean} isMonthly - 月次ランキングかどうかを示すフラグ。
*/
function processWinRateRank(teams, isMonthly) {
  teams.sort((a, b) => b.winRate - a.winRate);
  let currentRank = 0;
  let previousWinRate = null;
  let eligibleCount = 0;

  for (let i = 0; i < teams.length; i++) {
    const team = teams[i];
    const isEligibleField =
    isMonthly ? team.isEligible : team.isEligibleAll;

    // isEligible が false の場合、ランクを null にする
    if (!isEligibleField) {
      team.winRateRank = null;
      continue;
    }

    if (previousWinRate === null || previousWinRate !== team.winRate) {
      currentRank = eligibleCount + 1;
    }

    team.winRateRank = currentRank;
    eligibleCount++;
    previousWinRate = team.winRate;
  }

  // 年齢別ランキング（winRate を使用）
  const groups = {};
  for (const team of teams) {
    const group = getAgeGroup(team.averageAge);
    if (!groups[group]) groups[group] = [];
    groups[group].push(team);
  }

  for (const [group, groupTeams] of Object.entries(groups)) {
    // 月次なら isEligible、年間なら isEligibleAll を使用し、winRate が null でないもの
    const eligible = groupTeams.filter((t) =>
      t.winRate !== null && (isMonthly ? t.isEligible : t.isEligibleAll),
    );

    // 勝率は高いほど上位（降順）
    eligible.sort((a, b) => b.winRate - a.winRate);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const team = eligible[i];
      if (prevValue === null || prevValue !== team.winRate) {
        groupRank = count + 1;
      }
      team[`winRateRank_age_${group}`] = groupRank;
      count++;
      prevValue = team.winRate;
    }

    // 対象外は null を明示的に入れる
    for (const t of groupTeams) {
      if (!eligible.includes(t)) {
        t[`winRateRank_age_${group}`] = null;
      }
    }
  }
}


/**
    * バッティング平均のランクを計算
    * @param {Array} teams - チームのリスト。
    */
function processBattingAverageRank(teams) {
  teams.sort((a, b) => b.battingAverage - a.battingAverage);
  let currentRank = 0;
  let previousBattingAverage = null;
  let eligibleCount = 0;

  for (let i = 0; i < teams.length; i++) {
    const team = teams[i];

    if (team.battingAverage === null || !team.isEligibleAll) {
      team.battingAverageRank = null; // データベースにnullとして保存される
      continue;
    }

    if (
      previousBattingAverage === null ||
      previousBattingAverage !== team.battingAverage
    ) {
      currentRank = eligibleCount + 1;
    }

    team.battingAverageRank = currentRank;
    eligibleCount++;
    previousBattingAverage = team.battingAverage;
  }

  // 年齢別ランキング
  const groups = {};
  for (const team of teams) {
    const group = getAgeGroup(team.averageAge);
    if (!groups[group]) groups[group] = [];
    groups[group].push(team);
  }

  for (const [group, groupTeams] of Object.entries(groups)) {
    // 年間は isEligibleAll を使用し、battingAverage が null でないもの
    const eligible = groupTeams.filter((t) =>
      t.battingAverage !== null && t.isEligibleAll,
    );

    // 打率は高いほど上位（降順）
    eligible.sort((a, b) => b.battingAverage - a.battingAverage);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const team = eligible[i];
      if (prevValue === null || prevValue !== team.battingAverage) {
        groupRank = count + 1;
      }
      team[`battingAverageRank_age_${group}`] = groupRank;
      count++;
      prevValue = team.battingAverage;
    }

    // 対象外は null を明示的に入れる
    for (const t of groupTeams) {
      if (!eligible.includes(t)) {
        t[`battingAverageRank_age_${group}`] = null;
      }
    }
  }
}

/**
    * スラッギングパーセンテージのランクを計算
    * @param {Array} teams - チームのリスト。
    */
function processSluggingRank(teams) {
  teams.sort((a, b) => b.sluggingPercentage - a.sluggingPercentage);
  let currentRank = 0;
  let previousSlugging = null;
  let eligibleCount = 0;

  for (let i = 0; i < teams.length; i++) {
    const team = teams[i];

    if (team.sluggingPercentage === null || !team.isEligibleAll) {
      team.sluggingRank = null; // データベースにnullとして保存される
      continue;
    }

    if (
      previousSlugging === null ||
      previousSlugging !== team.sluggingPercentage
    ) {
      currentRank = eligibleCount + 1;
    }

    team.sluggingRank = currentRank;
    eligibleCount++;
    previousSlugging = team.sluggingPercentage;
  }

  // 年齢別ランキング
  const groups = {};
  for (const team of teams) {
    const group = getAgeGroup(team.averageAge);
    if (!groups[group]) groups[group] = [];
    groups[group].push(team);
  }

  for (const [group, groupTeams] of Object.entries(groups)) {
    // 年間は isEligibleAll を使用し、sluggingPercentage が null でないもの
    const eligible = groupTeams.filter((t) =>
      t.sluggingPercentage !== null && t.isEligibleAll,
    );

    // 長打率は高いほど上位（降順）
    eligible.sort((a, b) => b.sluggingPercentage - a.sluggingPercentage);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const team = eligible[i];
      if (prevValue === null || prevValue !== team.sluggingPercentage) {
        groupRank = count + 1;
      }
      team[`sluggingRank_age_${group}`] = groupRank;
      count++;
      prevValue = team.sluggingPercentage;
    }

    // 対象外は null を明示的に入れる
    for (const t of groupTeams) {
      if (!eligible.includes(t)) {
        t[`sluggingRank_age_${group}`] = null;
      }
    }
  }
}

/**
    * 出塁率のランクを計算
    * @param {Array} teams - チームのリスト。
    */
function processOnBaseRank(teams) {
  teams.sort((a, b) => b.onBasePercentage - a.onBasePercentage);
  let currentRank = 0;
  let previousOnBase = null;
  let eligibleCount = 0;

  for (let i = 0; i < teams.length; i++) {
    const team = teams[i];

    if (team.onBasePercentage === null || !team.isEligibleAll) {
      team.onBaseRank = null; // データベースにnullとして保存される
      continue;
    }

    if (previousOnBase === null || previousOnBase !== team.onBasePercentage) {
      currentRank = eligibleCount + 1;
    }

    team.onBaseRank = currentRank;
    eligibleCount++;
    previousOnBase = team.onBasePercentage;
  }

  // 年齢別ランキング
  const groups = {};
  for (const team of teams) {
    const group = getAgeGroup(team.averageAge);
    if (!groups[group]) groups[group] = [];
    groups[group].push(team);
  }

  for (const [group, groupTeams] of Object.entries(groups)) {
    const eligible = groupTeams.filter((t) =>
      t.onBasePercentage !== null && t.isEligibleAll,
    );

    eligible.sort((a, b) => b.onBasePercentage - a.onBasePercentage);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const team = eligible[i];
      if (prevValue === null || prevValue !== team.onBasePercentage) {
        groupRank = count + 1;
      }
      team[`onBaseRank_age_${group}`] = groupRank;
      count++;
      prevValue = team.onBasePercentage;
    }

    // 対象外は null を明示的に入れる
    for (const t of groupTeams) {
      if (!eligible.includes(t)) {
        t[`onBaseRank_age_${group}`] = null;
      }
    }
  }
}

/**
    * 守備率のランクを計算
    * @param {Array} teams - チームのリスト。
    */
function processFieldingPercentageRank(teams) {
  teams.sort((a, b) => b.fieldingPercentage - a.fieldingPercentage);
  let currentRank = 0;
  let previousFieldingPercentage = null;
  let eligibleCount = 0;

  for (let i = 0; i < teams.length; i++) {
    const team = teams[i];

    if (team.fieldingPercentage === null || !team.isEligibleAll) {
      team.fieldingPercentageRank = null; // データベースにnullとして保存される
      continue;
    }

    if (
      previousFieldingPercentage === null ||
      previousFieldingPercentage !== team.fieldingPercentage
    ) {
      currentRank = eligibleCount + 1;
    }

    team.fieldingPercentageRank = currentRank;
    eligibleCount++;
    previousFieldingPercentage = team.fieldingPercentage;
  }

  // 年齢別ランキング
  const groups = {};
  for (const team of teams) {
    const group = getAgeGroup(team.averageAge);
    if (!groups[group]) groups[group] = [];
    groups[group].push(team);
  }

  for (const [group, groupTeams] of Object.entries(groups)) {
    const eligible = groupTeams.filter((t) =>
      t.fieldingPercentage !== null && t.isEligibleAll,
    );

    eligible.sort((a, b) => b.fieldingPercentage - a.fieldingPercentage);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const team = eligible[i];
      if (prevValue === null || prevValue !== team.fieldingPercentage) {
        groupRank = count + 1;
      }
      team[`fieldingPercentageRank_age_${group}`] = groupRank;
      count++;
      prevValue = team.fieldingPercentage;
    }

    // 対象外は null を明示的に入れる
    for (const t of groupTeams) {
      if (!eligible.includes(t)) {
        t[`fieldingPercentageRank_age_${group}`] = null;
      }
    }
  }
}

/**
 * 防御率のランクを計算
 * @param {Array} teams - チームのリスト。
 */
function processEraRank(teams) {
  teams.sort((a, b) => a.era - b.era);
  let currentRank = 0;
  let previousEra = null;
  let eligibleCount = 0;

  for (let i = 0; i < teams.length; i++) {
    const team = teams[i];

    if (team.era === null || !team.isEligibleAll) {
      team.eraRank = null; // データベースにnullとして保存される
      continue;
    }

    if (previousEra === null || previousEra !== team.era) {
      currentRank = eligibleCount + 1;
    }

    team.eraRank = currentRank;
    eligibleCount++;
    previousEra = team.era;
  }

  // 年齢別ランキング
  const groups = {};
  for (const team of teams) {
    const group = getAgeGroup(team.averageAge);
    if (!groups[group]) groups[group] = [];
    groups[group].push(team);
  }

  for (const [group, groupTeams] of Object.entries(groups)) {
    const eligible = groupTeams.filter((t) =>
      t.era !== null && t.isEligibleAll,
    );

    // ERAは低いほど上位（昇順）
    eligible.sort((a, b) => a.era - b.era);

    let groupRank = 0;
    let prevValue = null;
    let count = 0;

    for (let i = 0; i < eligible.length; i++) {
      const team = eligible[i];
      if (prevValue === null || prevValue !== team.era) {
        groupRank = count + 1;
      }
      team[`eraRank_age_${group}`] = groupRank;
      count++;
      prevValue = team.era;
    }

    // 対象外は null を明示的に入れる
    for (const t of groupTeams) {
      if (!eligible.includes(t)) {
        t[`eraRank_age_${group}`] = null;
      }
    }
  }
}

/**
 * 全国の上位チームのランキングを保存
 *
 * @param {Object} yearlyTeamsByPrefecture - 都道府県ごとにグループ化された年間データのチーム
 * @param {number} year - 対象の年
 * @return {Promise<void>} Firestoreへの保存処理を非同期で実行
 */
async function saveTeamNationwideTopRanks(yearlyTeamsByPrefecture, year) {
  // 各ランキングカテゴリのデータフィールドマッピング
  const nationwideRanks = {
    winRateRank: [],
    battingAverageRank: [],
    sluggingRank: [],
    onBaseRank: [],
    eraRank: [],
    fieldingPercentageRank: [],
  };

  const statKeyMapping = {
    winRateRank: "winRate",
    battingAverageRank: "battingAverage",
    sluggingRank: "sluggingPercentage",
    onBaseRank: "onBasePercentage",
    eraRank: "era",
    fieldingPercentageRank: "fieldingPercentage",
  };

  // 都道府県ごとに処理
  for (const [prefecture, teams] of Object.entries(yearlyTeamsByPrefecture)) {
    for (const category of Object.keys(nationwideRanks)) {
      console.log(`🔍 Checking category: ${category}`);
      // 各都道府県の1位チームを取得
      const topTeams = teams.filter((team) => team[category] === 1);

      topTeams.forEach((team) => {
        const statKey = statKeyMapping[category];
        const value = statKey ? team[statKey] : null;

        const entry = {
          id: team.id,
          teamName: team.teamName,
          prefecture: prefecture,
          value: value,
          averageAge: typeof team.averageAge === "number" ?
          team.averageAge : null,
        };

        if (category === "winRateRank") {
          entry.totalGames = team.totalGames;
          entry.totalLosses = team.totalLosses;
          entry.totalWins = team.totalWins;
          entry.totalScore = team.totalScore;
          entry.totalDraws = team.totalDraws;
          entry.totalRunsAllowed = team.totalRunsAllowed;
        }

        if (category === "onBaseRank" || category === "sluggingRank") {
          entry.atBats = team.atBats;
        }

        if (category === "battingAverageRank") {
          entry.atBats = team.atBats;
          entry.hits = team.hits;
        }

        if (category === "eraRank") {
          entry.totalInningsPitched = team.totalInningsPitched;
        }

        if (category === "fieldingPercentageRank") {
          entry.totalPutouts = team.totalPutouts;
          entry.totalAssists = team.totalAssists;
          entry.totalErrors = team.totalErrors;
        }

        nationwideRanks[category].push(entry);
      });
    }
  }

  // Firestoreの保存先パス
  const nationwideCollectionPath = `teamRanking/${year}_all/全国`;
  const batch = db.batch();

  for (const [category, data] of Object.entries(nationwideRanks)) {
    if (data.length > 0) {
      const docRef =
      db.collection(nationwideCollectionPath).doc(category);
      batch.set(docRef, {top: data});
    }
  }

  // バッチ書き込みを実行
  await batch.commit();
}


/**
 * Firestoreにバッチ書き込みし、順位を付ける関数
 * @param {string} collectionPath - Firestoreのコレクションパス。
 * @param {Array} teams - 書き込むチームのリスト。
 */
async function batchWriteWithTeamRank(collectionPath, teams) {
  console.log(`✍ Writing ${teams.length} teams to ${collectionPath}`);

  let batch = db.batch();
  let operationCount = 0;

  for (let i = 0; i < teams.length; i++) {
    const team = teams[i];
    const docRef = db.collection(collectionPath).doc(team.id);
    batch.set(docRef, team);
    operationCount++;

    if (operationCount === 500) {
      await batch.commit();
      batch = db.batch();
      operationCount = 0;
    }
  }

  if (operationCount > 0) {
    console.log(`✅ Committing final batch of ${operationCount}`);
    await batch.commit();
  }
}


// チーム平均年齢
export const updateTeamAverageAge = onDocumentWritten(
    {
      document: "teams/{teamId}",
      region: "asia-northeast1", // 必要に応じて変更
    },
    async (event) => {
      const teamId = event.params.teamId;
      const snapshot = event.data && event.data.after;

      if (!snapshot || !snapshot.exists) {
        console.log("⚠️ チームドキュメントが削除されました");
        return;
      }

      const members = Array.isArray(snapshot.data().members) ?
  snapshot.data().members :
  [];
      if (members.length === 0) {
        console.log(`⚠️ チーム ${teamId} にメンバーがいません`);
        await db.collection("teams").doc(teamId).update({averageAge: null});
        return;
      }

      const userDocs = await Promise.all(
          members.map((uid) => db.collection("users").doc(uid).get()),
      );

      const today = new Date();

      const birthDates = userDocs
          .map((doc) => {
            const data = doc.data();
            const birthday = data && data.birthday;
            return birthday instanceof Timestamp ? birthday.toDate() : null;
          })
          .filter((date) => date instanceof Date);

      const ages = birthDates.map((birthday) => {
        const age = today.getFullYear() - birthday.getFullYear();
        const hasHadBirthdayThisYear =
        today.getMonth() > birthday.getMonth() ||
        (today.getMonth() === birthday.getMonth() &&
        today.getDate() >= birthday.getDate());
        return hasHadBirthdayThisYear ? age : age - 1;
      });

      const averageAge =
      ages.length > 0 ?
        parseFloat((ages.reduce((a, b) => a + b, 0) / ages.length).toFixed(1)) :
        null;

      await db.collection("teams").doc(teamId).update({
        averageAge: averageAge,
      });

      console.log(
          `✅ チーム ${teamId} の平均年齢を更新: 
    ${(averageAge || averageAge === 0) ? averageAge : "なし"}歳,`,
      );
    },
);

// チャットメッセージ保存後に通知を送る
export const onChatMessageCreated =
onDocumentCreated("chatRooms/{roomId}/messages/{messageId}", async (event) => {
  const roomId = event.params.roomId;

  // メッセージデータを取得
  const snapshot = event.data;
  const messageData = snapshot ? snapshot.data() : null;
  if (!messageData) {
    console.log("⚠️ messageData is empty, skipping notification.");
    return;
  }

  const senderId = messageData.userId;
  const senderName = messageData.userName || "新しいメッセージ";
  const senderProfileImageUrl = messageData.userProfileImageUrl || "";
  const text = messageData.text || "";
  const hasImages =
    Array.isArray(messageData.imageUrls) && messageData.imageUrls.length > 0;
  const hasVideo = !!messageData.videoUrl;

  // 通知本文の内容を決定
  let body = text;
  if (!body) {
    if (hasImages && hasVideo) {
      body = "画像と動画が送信されました";
    } else if (hasImages) {
      body = "画像が送信されました";
    } else if (hasVideo) {
      body = "動画が送信されました";
    } else {
      body = "新しいメッセージが届きました";
    }
  }

  try {
    // 該当チャットルームの参加者を取得
    const chatRoomRef = db.collection("chatRooms").doc(roomId);
    const chatRoomSnap = await chatRoomRef.get();

    if (!chatRoomSnap.exists) {
      console.log(`⚠️ chatRoom ${roomId} not found, skipping notification.`);
      return;
    }

    const chatRoom = chatRoomSnap.data() || {};
    const participants = Array.isArray(chatRoom.participants) ?
      chatRoom.participants :
      [];

    if (!participants.length) {
      console.log(`⚠️ chatRoom ${roomId} has no participants.`);
      return;
    }

    // 送信者以外を通知対象にする
    const targetUserIds = participants.filter((uid) => uid !== senderId);

    if (!targetUserIds.length) {
      console.log(`⚠️ No target users for room ${roomId}.`);
      return;
    }

    const tokens = [];

    // 各ユーザーの FCM トークンを取得
    for (const uid of targetUserIds) {
      const userSnap = await db.collection("users").doc(uid).get();
      if (!userSnap.exists) continue;

      const userData = userSnap.data() || {};
      const fcmTokens = userData.fcmTokens;

      if (Array.isArray(fcmTokens)) {
        // 配列形式の場合
        tokens.push(...fcmTokens.filter((t) => typeof t === "string" && t));
      } else if (fcmTokens && typeof fcmTokens === "object") {
        // {token: true} のようなマップ形式の場合
        tokens.push(
            ...Object.keys(fcmTokens).filter(
                (t) => typeof t === "string" && t,
            ),
        );
      }
    }

    if (!tokens.length) {
      console.log("⚠️ No FCM tokens found for target users.");
      return;
    }

    // 通知ペイロードを構築
    const multicastMessage = {
      tokens,
      notification: {
        title: senderName,
        body,
      },
      data: {
        roomId: roomId,
        // 通知を受け取った側から見た「相手」の情報として sender を渡す
        recipientId: senderId,
        recipientName: senderName,
        recipientProfileImageUrl: senderProfileImageUrl,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: "chat",
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(multicastMessage);
    console.log(
        `📨 Sent chat notifications for room ${roomId}. Success: 
        ${response.successCount}, Failure: ${response.failureCount}`,
    );
  } catch (error) {
    console.error("🚨 Error sending chat notification:", error);
  }
});

/**
 * teams/{teamId}/schedule/{scheduleId} が作成されたときに
 * チームメンバー全員に「スケジュール追加」のプッシュ通知を送る
 */
export const onTeamScheduleCreated = onDocumentCreated(
    "teams/{teamId}/schedule/{scheduleId}",
    async (event) => {
      const snap = event.data;
      const {teamId, scheduleId} = event.params;

      if (!snap) {
        console.log("No schedule snapshot; skip notification");
        return;
      }

      // Firestore ドキュメントの中身を取得
      const data = snap.data() || {};

      // Firestore 上では game_date と title はトップレベルのフィールド
      const gameDateField = data.game_date;
      const title = data.title || "イベント";

      let dateText = "";

      // game_date が Timestamp か文字列かを判定してテキスト化
      if (gameDateField instanceof Timestamp) {
        const d = gameDateField.toDate();
        const month = d.getMonth() + 1;
        const day = d.getDate();
        dateText = `${month}月${day}日`;
      } else if (typeof gameDateField === "string") {
        const m = gameDateField.match(/(\d{1,2})月(\d{1,2})日/);
        if (m) {
          dateText = `${m[1]}月${m[2]}日`;
        } else {
          dateText = gameDateField;
        }
      }

      // チームメンバー一覧を取得
      const teamSnap = await db.collection("teams").doc(teamId).get();
      const teamData = teamSnap.data() || {};
      const memberIds = Array.isArray(teamData.members) ? teamData.members : [];

      if (memberIds.length === 0) {
        console.log("No team members; skip schedule notification");
        return;
      }

      // 各メンバーの FCM トークンを集める
      const tokenSet = new Set();

      for (const memberId of memberIds) {
        const userSnap = await db.collection("users").doc(memberId).get();
        if (!userSnap.exists) continue;

        const userData = userSnap.data() || {};
        const fcmTokens = Array.isArray(userData.fcmTokens) ?
        userData.fcmTokens :
        [];

        for (const t of fcmTokens) {
          if (t && typeof t === "string") {
            tokenSet.add(t);
          }
        }
      }

      const tokens = Array.from(tokenSet);

      if (tokens.length === 0) {
        console.log(
            "No FCM tokens for team members; skip schedule notification",
        );
        return;
      }

      const notificationTitle =
      dateText && title ?
        `${dateText}に${title}が予定されました` :
        `${title}が予定されました`;

      const notificationBody = "リアクションしましょう";

      const message = {
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          type: "schedule",
          teamId: teamId,
          scheduleId: scheduleId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        tokens,
      };

      try {
      // getMessaging() から作った messaging を使う
        const response = await messaging.sendEachForMulticast(message);
        console.log(
            `✅ Sent schedule notification to ${tokens.length} devices`,
            safeStringify(response),
        );
      } catch (err) {
        console.error("🚨 Error sending schedule notification", err);
      }
    },
);

/**
 * teams/{teamId}/schedule/{scheduleId} の comments または stamps が更新されたときに
 * チームメンバー全員に「リアクションがあった」通知を送る
 */
export const onTeamScheduleReactionUpdated = onDocumentWritten(
    "teams/{teamId}/schedule/{scheduleId}",
    async (event) => {
      const beforeSnap = event.data && event.data.before;
      const afterSnap = event.data && event.data.after;
      const {teamId, scheduleId} = event.params;

      // 作成や削除はスキップ（更新時のみ）
      if (
        !beforeSnap || !afterSnap || !beforeSnap.exists || !afterSnap.exists
      ) {
        console.log("Skip reaction notification (create/delete).");
        return;
      }

      const before = beforeSnap.data() || {};
      const after = afterSnap.data() || {};

      const beforeComments = before.comments || {};
      const afterComments = after.comments || {};
      const beforeStamps = before.stamps || {};
      const afterStamps = after.stamps || {};

      const commentsChanged =
        JSON.stringify(beforeComments) !== JSON.stringify(afterComments);
      const stampsChanged =
        JSON.stringify(beforeStamps) !== JSON.stringify(afterStamps);

      if (!commentsChanged && !stampsChanged) {
        console.log(
            "No comments/stamps change; skip schedule reaction notification.",
        );
        return;
      }

      // タイトル・日付は最新の after 側を使う
      const gameDateField = after.game_date;
      const title = after.title || "イベント";

      let dateText = "";

      if (gameDateField instanceof Timestamp) {
        const d = gameDateField.toDate();
        const month = d.getMonth() + 1;
        const day = d.getDate();
        dateText = `${month}月${day}日`;
      } else if (typeof gameDateField === "string") {
        const m = gameDateField.match(/(\d{1,2})月(\d{1,2})日/);
        if (m) {
          dateText = `${m[1]}月${m[2]}日`;
        } else {
          dateText = gameDateField;
        }
      }

      // チームメンバー一覧を取得
      const teamSnap = await db.collection("teams").doc(teamId).get();
      const teamData = teamSnap.data() || {};
      const memberIds = Array.isArray(teamData.members) ? teamData.members : [];

      if (memberIds.length === 0) {
        console.log("No team members; skip schedule reaction notification");
        return;
      }

      const tokenSet = new Set();

      for (const memberId of memberIds) {
        const userSnap = await db.collection("users").doc(memberId).get();
        if (!userSnap.exists) continue;

        const userData = userSnap.data() || {};
        const fcmTokens = Array.isArray(userData.fcmTokens) ?
          userData.fcmTokens :
          [];

        for (const t of fcmTokens) {
          if (t && typeof t === "string") {
            tokenSet.add(t);
          }
        }
      }

      const tokens = Array.from(tokenSet);

      if (tokens.length === 0) {
        console.log(
            "No FCM tokens; skip schedule reaction notification",
        );
        return;
      }

      // コメント / スタンプの差分から、誰が何をしたかを推定して本文を作る
      // Firestore 上の comments / stamps は配列 or マップのどちらでも動くようにする
      const commentsList = Array.isArray(afterComments) ?
        afterComments :
        Object.values(afterComments || {});
      const stampsList = Array.isArray(afterStamps) ?
        afterStamps :
        Object.values(afterStamps || {});

      let latestCommentUser = null;
      let latestCommentText = "";
      if (commentsChanged && commentsList.length > 0) {
        const lastComment = commentsList[commentsList.length - 1] || {};
        latestCommentUser = lastComment.userName || lastComment.name || "誰か";

        // Firestore 側では comment / text / message など、どのキーでも安全に拾う
        const rawCommentText =
          (typeof lastComment.comment === "string" && lastComment.comment) ||
          (typeof lastComment.text === "string" && lastComment.text) ||
          (typeof lastComment.message === "string" && lastComment.message) ||
          "";
        latestCommentText = rawCommentText;
      }

      let latestStampUser = null;
      let latestStampLabel = "";
      if (stampsChanged && stampsList.length > 0) {
        const lastStamp = stampsList[stampsList.length - 1] || {};
        latestStampUser = lastStamp.userName || lastStamp.name || "誰か";
        // スタンプの種類があればラベルに利用
        const stampType = lastStamp.stampType || lastStamp.type || "";
        latestStampLabel = stampType ? `${stampType}` : "スタンプ";
      }

      // 本文を組み立て（「誰々：コメント」「誰々：スタンプ」形式）
      let bodyText = "リアクションがありました";

      if (latestCommentUser && latestStampUser) {
        // コメントとスタンプ両方変わったとき
        const shortComment =
          latestCommentText && typeof latestCommentText === "string" ?
            (latestCommentText.length > 20 ?
              `${latestCommentText.slice(0, 20)}…` :
              latestCommentText) :
            "";
        const commentLine = shortComment ?
          `${latestCommentUser}：${shortComment}` :
          `${latestCommentUser}：コメント`;
        const stampLine = `${latestStampUser}：${latestStampLabel}`;
        bodyText = `${commentLine}\n${stampLine}`;
      } else if (latestCommentUser) {
        const shortComment =
          latestCommentText && typeof latestCommentText === "string" ?
            (latestCommentText.length > 20 ?
              `${latestCommentText.slice(0, 20)}…` :
              latestCommentText) :
            "";
        bodyText = shortComment ?
          `${latestCommentUser}：${shortComment}` :
          `${latestCommentUser}：コメントが追加されました`;
      } else if (latestStampUser) {
        bodyText = `${latestStampUser}：${latestStampLabel}`;
      }

      const notificationTitle =
        dateText && title ?
          `${dateText}の${title}` :
          title || "イベント";

      const message = {
        notification: {
          title: notificationTitle,
          body: bodyText,
        },
        data: {
          type: "schedule",
          teamId: teamId,
          scheduleId: scheduleId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        tokens,
      };

      try {
        const response = await messaging.sendEachForMulticast(message);
        console.log(
            `✅ Sent schedule reaction notification to ${tokens.length} devices`,
            safeStringify(response),
        );
      } catch (err) {
        console.error("🚨 Error sending schedule reaction notification", err);
      }
    },
);

// ================= MVP 共通ヘルパー =================
// MVP Cloud Tasks queue paths and functions base URL
const mvpReminderQueuePath =
  client.queuePath(project, location, "mvp-reminder-queue");
const mvpTallyQueuePath =
  client.queuePath(project, location, "mvp-tally-queue");

// v2 HTTPS Functions のベースURL（Cloud Tasks から叩く用）
const functionsBaseUrl =
  `https://${location}-${project}.cloudfunctions.net`;

/**
 * 指定したユーザーID配列から FCM トークンをまとめて取得
 * @param {string[]} userIds
 * @return {Promise<string[]>}
 */
async function getFcmTokensForUsers(userIds) {
  const tokens = [];

  for (const uid of userIds) {
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) continue;

    const userData = userSnap.data() || {};
    const userTokens = userData.fcmTokens || [];

    if (Array.isArray(userTokens)) {
      for (const t of userTokens) {
        if (typeof t === "string" && t) {
          tokens.push(t);
        }
      }
    }
  }

  return tokens;
}

/**
 * 月間MVPが作成されたときに通知を送る
 * パス: teams/{teamId}/mvp_month/{mvpId}
 */
export const onMvpMonthCreated = onDocumentCreated(
    "teams/{teamId}/mvp_month/{mvpId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        console.log("No snapshot in onMvpMonthCreated");
        return;
      }

      const data = snap.data() || {};
      const teamId = event.params.teamId;
      const mvpId = event.params.mvpId;

      const theme = data.theme || "月間MVP";

      const startRaw = data.voteStartDate;
      const endRaw = data.voteEndDate;
      const deadlineRaw = data.voteDeadline || endRaw;

      const toDate = (v) => (v && v.toDate ? v.toDate() : null);

      const start = toDate(startRaw);
      const end = toDate(endRaw);
      const deadline = toDate(deadlineRaw);

      const fmt = (d) =>
      d ? `${d.getMonth() + 1}月${d.getDate()}日` : "未設定";

      const periodText =
      start && end ? `${fmt(start)}〜${fmt(end)}` : null;

      // 通知タイトル・本文
      const title = `${theme}`;
      const body = periodText ?
      `投票期間：${periodText}` :
      "チームページから投票できます";

      // チームメンバーの FCM トークン取得
      const teamDoc = await db.collection("teams").doc(teamId).get();
      if (!teamDoc.exists) {
        console.log("Team doc not found:", teamId);
        return;
      }

      const teamData = teamDoc.data() || {};
      const memberIds = teamData.members || [];

      const tokenSet = new Set();

      for (const uid of memberIds) {
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) continue;
        const userData = userDoc.data() || {};
        const fcmTokens = userData.fcmTokens || [];
        for (const t of fcmTokens) {
          if (t) tokenSet.add(t);
        }
      }

      const tokens = Array.from(tokenSet);
      if (tokens.length === 0) {
        console.log("No FCM tokens for MVP notice");
        return;
      }

      const message = {
        tokens,
        notification: {title, body},
        data: {
          type: "mvp_vote",
          teamId,
          mvpId,
          theme,
        },
        android: {
          priority: "high",
          notification: {clickAction: "FLUTTER_NOTIFICATION_CLICK"},
        },
        apns: {
          payload: {
            aps: {
              "sound": "default",
              "content-available": 1,
            },
          },
          headers: {
            "apns-priority": "10",
          },
        },
      };

      const res = await messaging.sendEachForMulticast(message);
      console.log("MVP notice sent:", res.successCount, "success");

      // --- Cloud Tasks で「締切前リマインド」と「集計日お知らせ」を予約 ---
      if (deadline) {
        const now = new Date();

        // 「締切直前」= 締切の3時間前（必要に応じてここを調整）
        const reminderTime = new Date(deadline.getTime() - 3 * 60 * 60 * 1000);
        const tallyTime = deadline; // 集計日は締切日時そのもの

        const toScheduleTime = (d) => ({
          seconds: Math.floor(d.getTime() / 1000),
        });

        // 1) 締切前リマインド（未投票者向け）
        if (reminderTime > now) {
          try {
            await client.createTask({
              parent: mvpReminderQueuePath,
              task: {
                scheduleTime: toScheduleTime(reminderTime),
                httpRequest: {
                  httpMethod: "POST",
                  url: `${functionsBaseUrl}/mvpVoteReminderTask`,
                  headers: {
                    "Content-Type": "application/json",
                  },
                  body: Buffer.from(
                      JSON.stringify({teamId, mvpId}),
                  ).toString("base64"),
                },
              },
            });
            console.log("📥 Enqueued MVP vote reminder task", {
              teamId,
              mvpId,
              reminderTime: reminderTime.toISOString(),
            });
          } catch (e) {
            console.error("🚨 Failed to enqueue MVP vote reminder task", e);
          }
        }

        // 2) 集計日お知らせ（作成者向け）
        if (tallyTime > now) {
          try {
            await client.createTask({
              parent: mvpTallyQueuePath,
              task: {
                scheduleTime: toScheduleTime(tallyTime),
                httpRequest: {
                  httpMethod: "POST",
                  url: `${functionsBaseUrl}/mvpTallyNoticeTask`,
                  headers: {
                    "Content-Type": "application/json",
                  },
                  body: Buffer.from(
                      JSON.stringify({teamId, mvpId}),
                  ).toString("base64"),
                },
              },
            });
            console.log("📥 Enqueued MVP tally notice task", {
              teamId,
              mvpId,
              tallyTime: tallyTime.toISOString(),
            });
          } catch (e) {
            console.error("🚨 Failed to enqueue MVP tally notice task", e);
          }
        }
      }
    },
);

// ================= MVP: 結果発表通知 =================
export const onMvpTallied = onDocumentWritten(
    "mvp_month/{mvpMonthId}",
    async (event) => {
      const beforeSnap = event.data.before;
      const afterSnap = event.data.after;

      if (!afterSnap || !afterSnap.exists) {
        return;
      }

      const beforeData = beforeSnap && beforeSnap.exists ?
      beforeSnap.data() : null;
      const afterData = afterSnap.data() || {};

      const wasTallied = beforeData && beforeData.isTallied === true;
      const isTallied = afterData.isTallied === true;

      // false → true のときだけ通知
      if (!isTallied || wasTallied) {
        return;
      }

      const mvpMonthId = event.params.mvpMonthId;
      const teamId = afterData.teamId;

      if (!teamId) {
        console.log(
            `⚠️ teamId 未設定の mvp_month（結果通知スキップ）: ${mvpMonthId}`,
        );
        return;
      }

      const teamSnap = await db.collection("teams").doc(teamId).get();
      if (!teamSnap.exists) {
        console.log(`⚠️ team not found for MVP result: ${teamId}`);
        return;
      }

      const teamData = teamSnap.data() || {};
      const members = teamData.members || [];

      if (!Array.isArray(members) || members.length === 0) {
        console.log(`ℹ️ メンバーなし teamId: ${teamId}`);
        return;
      }

      const tokens = await getFcmTokensForUsers(members);
      if (tokens.length === 0) {
        console.log(
            `⚠️ MVP 結果通知先トークンなし: teamId ${teamId}`,
        );
        return;
      }

      const theme = afterData.theme || "MVP";
      const title = `「${theme}」の結果が発表されました`;
      const body = "アプリから結果をチェックしてみましょう。";

      await messaging.sendEachForMulticast({
        notification: {title, body},
        tokens,
        data: {
          type: "mvpResult",
          teamId: String(teamId),
          mvpMonthId: String(mvpMonthId),
        },
      });

      console.log(
          `🎉 MVP 結果発表通知送信: mvp_month ${mvpMonthId}, ` +
        `teamId=${teamId}, members=${members.length}`,
      );
    },
);

// ================= MVP: 締切前リマインド（未投票者向け） =================
export const mvpVoteReminderTask = onRequest(
    {
      timeoutSeconds: 540,
      region: "asia-northeast1",
    },
    async (req, res) => {
      try {
        const {teamId, mvpId} = req.body || {};
        if (!teamId || !mvpId) {
          res.status(400).send("Missing teamId or mvpId");
          return;
        }

        const teamIdStr = String(teamId);
        const mvpIdStr = String(mvpId);

        // MVP ドキュメントを取得
        const mvpRef = db
            .collection("teams")
            .doc(teamIdStr)
            .collection("mvp_month")
            .doc(mvpIdStr);
        const mvpSnap = await mvpRef.get();

        if (!mvpSnap.exists) {
          console.log("mvpVoteReminderTask: MVP doc not found", {
            teamId: teamIdStr,
            mvpId: mvpIdStr,
          });
          res.status(200).send("MVP doc not found");
          return;
        }

        const mvpData = mvpSnap.data() || {};
        const theme = mvpData.theme || "MVP";

        // チームメンバーと未投票者の抽出
        const teamSnap = await db.collection("teams").doc(teamIdStr).get();
        if (!teamSnap.exists) {
          console.log(
              "mvpVoteReminderTask: team not found", {teamId: teamIdStr},
          );
          res.status(200).send("team not found");
          return;
        }

        const teamData = teamSnap.data() || {};
        const members = Array.isArray(teamData.members) ? teamData.members : [];

        if (!members.length) {
          console.log("mvpVoteReminderTask: no members", {teamId: teamIdStr});
          res.status(200).send("no members");
          return;
        }

        // votes サブコレクションから投票済みユーザーIDを取得
        const votesSnap = await mvpRef.collection("votes").get();
        const votedSet = new Set();
        votesSnap.forEach((doc) => votedSet.add(doc.id));

        const notVoted = members.filter((uid) => !votedSet.has(uid));

        if (!notVoted.length) {
          console.log("mvpVoteReminderTask: all members already voted", {
            teamId: teamIdStr,
            mvpId: mvpIdStr,
          });
          res.status(200).send("all voted");
          return;
        }

        const tokens = await getFcmTokensForUsers(notVoted);
        if (!tokens.length) {
          console.log(
              "mvpVoteReminderTask: no FCM tokens for non-voters",
              {teamId: teamIdStr, mvpId: mvpIdStr},
          );
          res.status(200).send("no tokens");
          return;
        }

        const title = `${theme} の投票締切が近づいています`;
        const body = "まだ投票していない人は、忘れずに投票しましょう。";

        const result = await messaging.sendEachForMulticast({
          tokens,
          notification: {title, body},
          data: {
            type: "mvpVoteReminder",
            teamId: teamIdStr,
            mvpId: mvpIdStr,
          },
        });

        console.log("🎯 MVP vote reminder sent", {
          teamId: teamIdStr,
          mvpId: mvpIdStr,
          success: result.successCount,
          failure: result.failureCount,
          targetUsers: notVoted.length,
        });

        res.status(200).send("ok");
      } catch (err) {
        console.error("🚨 mvpVoteReminderTask error", err);
        res.status(500).send("error");
      }
    },
);

// ================= MVP: 集計日当日のお知らせ（作成者向け） =================
export const mvpTallyNoticeTask = onRequest(
    {
      timeoutSeconds: 540,
      region: "asia-northeast1",
    },
    async (req, res) => {
      try {
        const {teamId, mvpId} = req.body || {};
        if (!teamId || !mvpId) {
          res.status(400).send("Missing teamId or mvpId");
          return;
        }

        const teamIdStr = String(teamId);
        const mvpIdStr = String(mvpId);

        const mvpRef = db
            .collection("teams")
            .doc(teamIdStr)
            .collection("mvp_month")
            .doc(mvpIdStr);
        const mvpSnap = await mvpRef.get();

        if (!mvpSnap.exists) {
          console.log("mvpTallyNoticeTask: MVP doc not found", {
            teamId: teamIdStr,
            mvpId: mvpIdStr,
          });
          res.status(200).send("MVP doc not found");
          return;
        }

        const mvpData = mvpSnap.data() || {};
        const theme = mvpData.theme || "MVP";
        const createdBy = mvpData.createdBy || {};
        const createdUid =
          createdBy.uid || createdBy.userId || createdBy.id || null;

        if (!createdUid) {
          console.log("mvpTallyNoticeTask: createdBy UID not found", {
            teamId: teamIdStr,
            mvpId: mvpIdStr,
          });
          res.status(200).send("no creator uid");
          return;
        }

        const tokens = await getFcmTokensForUsers([createdUid]);
        if (!tokens.length) {
          console.log("mvpTallyNoticeTask: no FCM tokens for creator", {
            teamId: teamIdStr,
            mvpId: mvpIdStr,
            createdUid,
          });
          res.status(200).send("no tokens");
          return;
        }

        const title = `${theme} の集計日になりました`;
        const body = "MVPの集計を行いましょう。";

        const result = await messaging.sendEachForMulticast({
          tokens,
          notification: {title, body},
          data: {
            type: "mvpTallyNotice",
            teamId: teamIdStr,
            mvpId: mvpIdStr,
          },
        });

        console.log("📊 MVP tally notice sent", {
          teamId: teamIdStr,
          mvpId: mvpIdStr,
          createdUid,
          success: result.successCount,
          failure: result.failureCount,
        });

        res.status(200).send("ok");
      } catch (err) {
        console.error("🚨 mvpTallyNoticeTask error", err);
        res.status(500).send("error");
      }
    },
);


// ================= 年間MVP 共通ヘルパー =================
// 年間MVP 用 Cloud Tasks queue paths
const mvpYearReminderQueuePath =
  client.queuePath(project, location, "mvp-year-reminder-queue");
const mvpYearTallyQueuePath =
  client.queuePath(project, location, "mvp-year-tally-queue");

/**
 * 年間MVPが作成されたときに通知を送る
 * パス: teams/{teamId}/mvp_year/{mvpId}
 */
export const onMvpYearCreated = onDocumentCreated(
    "teams/{teamId}/mvp_year/{mvpId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        console.log("No snapshot in onMvpYearCreated");
        return;
      }

      const data = snap.data() || {};
      const teamId = event.params.teamId;
      const mvpId = event.params.mvpId;

      const theme = data.theme || "年間MVP";

      const startRaw = data.voteStartDate;
      const endRaw = data.voteEndDate;
      const deadlineRaw = data.voteDeadline || endRaw;

      const toDate = (v) => (v && v.toDate ? v.toDate() : null);

      const start = toDate(startRaw);
      const end = toDate(endRaw);
      const deadline = toDate(deadlineRaw);

      const fmt = (d) =>
        d ? `${d.getMonth() + 1}月${d.getDate()}日` : "未設定";

      const periodText =
        start && end ? `${fmt(start)}〜${fmt(end)}` : null;

      // 通知タイトル・本文
      const title = `${theme}`;
      const body = periodText ?
        `投票期間：${periodText}` :
        "チームページから投票できます";

      // チームメンバーの FCM トークン取得
      const teamDoc = await db.collection("teams").doc(teamId).get();
      if (!teamDoc.exists) {
        console.log("Team doc not found (Year MVP):", teamId);
        return;
      }

      const teamData = teamDoc.data() || {};
      const memberIds = teamData.members || [];

      const tokenSet = new Set();

      for (const uid of memberIds) {
        const userDoc = await db.collection("users").doc(uid).get();
        if (!userDoc.exists) continue;
        const userData = userDoc.data() || {};
        const fcmTokens = userData.fcmTokens || [];
        for (const t of fcmTokens) {
          if (t) tokenSet.add(t);
        }
      }

      const tokens = Array.from(tokenSet);
      if (tokens.length === 0) {
        console.log("No FCM tokens for Year MVP notice");
        return;
      }

      const message = {
        tokens,
        notification: {title, body},
        data: {
          type: "mvp_year_vote",
          teamId,
          mvpId,
          theme,
        },
        android: {
          priority: "high",
          notification: {clickAction: "FLUTTER_NOTIFICATION_CLICK"},
        },
        apns: {
          payload: {
            aps: {
              "sound": "default",
              "content-available": 1,
            },
          },
          headers: {
            "apns-priority": "10",
          },
        },
      };

      const res = await messaging.sendEachForMulticast(message);
      console.log("Year MVP notice sent:", res.successCount, "success");

      // --- Cloud Tasks で「締切前リマインド」と「集計日お知らせ」を予約 ---
      if (deadline) {
        const now = new Date();

        // 「締切直前」= 締切の3時間前（必要に応じてここを調整）
        const reminderTime =
          new Date(deadline.getTime() - 3 * 60 * 60 * 1000);
        const tallyTime = deadline; // 集計日は締切日時そのもの

        const toScheduleTime = (d) => ({
          seconds: Math.floor(d.getTime() / 1000),
        });

        // 1) 締切前リマインド（未投票者向け）
        if (reminderTime > now) {
          try {
            await client.createTask({
              parent: mvpYearReminderQueuePath,
              task: {
                scheduleTime: toScheduleTime(reminderTime),
                httpRequest: {
                  httpMethod: "POST",
                  url: `${functionsBaseUrl}/mvpYearVoteReminderTask`,
                  headers: {
                    "Content-Type": "application/json",
                  },
                  body: Buffer.from(
                      JSON.stringify({teamId, mvpId}),
                  ).toString("base64"),
                },
              },
            });
            console.log("📥 Enqueued Year MVP vote reminder task", {
              teamId,
              mvpId,
              reminderTime: reminderTime.toISOString(),
            });
          } catch (e) {
            console.error(
                "🚨 Failed to enqueue Year MVP vote reminder task",
                e,
            );
          }
        }

        // 2) 集計日お知らせ（作成者向け）
        if (tallyTime > now) {
          try {
            await client.createTask({
              parent: mvpYearTallyQueuePath,
              task: {
                scheduleTime: toScheduleTime(tallyTime),
                httpRequest: {
                  httpMethod: "POST",
                  url: `${functionsBaseUrl}/mvpYearTallyNoticeTask`,
                  headers: {
                    "Content-Type": "application/json",
                  },
                  body: Buffer.from(
                      JSON.stringify({teamId, mvpId}),
                  ).toString("base64"),
                },
              },
            });
            console.log("📥 Enqueued Year MVP tally notice task", {
              teamId,
              mvpId,
              tallyTime: tallyTime.toISOString(),
            });
          } catch (e) {
            console.error(
                "🚨 Failed to enqueue Year MVP tally notice task",
                e,
            );
          }
        }
      }
    },
);

// ================= 年間MVP: 結果発表通知 =================
export const onMvpYearTallied = onDocumentWritten(
    "mvp_year/{mvpYearId}",
    async (event) => {
      const beforeSnap = event.data.before;
      const afterSnap = event.data.after;

      if (!afterSnap || !afterSnap.exists) {
        return;
      }

      const beforeData =
        beforeSnap && beforeSnap.exists ? beforeSnap.data() : null;
      const afterData = afterSnap.data() || {};

      const wasTallied = beforeData && beforeData.isTallied === true;
      const isTallied = afterData.isTallied === true;

      // false → true のときだけ通知
      if (!isTallied || wasTallied) {
        return;
      }

      const mvpYearId = event.params.mvpYearId;
      const teamId = afterData.teamId;

      if (!teamId) {
        console.log(
            "⚠️ teamId 未設定の mvp_year（結果通知スキップ）:",
            mvpYearId,
        );
        return;
      }

      const teamSnap = await db.collection("teams").doc(teamId).get();
      if (!teamSnap.exists) {
        console.log("⚠️ team not found for Year MVP result:", teamId);
        return;
      }

      const teamData = teamSnap.data() || {};
      const members = teamData.members || [];

      if (!Array.isArray(members) || members.length === 0) {
        console.log("ℹ️ メンバーなし teamId(Year MVP):", teamId);
        return;
      }

      const tokens = await getFcmTokensForUsers(members);
      if (tokens.length === 0) {
        console.log(
            "⚠️ Year MVP 結果通知先トークンなし: teamId",
            teamId,
        );
        return;
      }

      const theme = afterData.theme || "年間MVP";
      const title = `「${theme}」の年間MVP結果が発表されました`;
      const body = "アプリから結果をチェックしてみましょう。";

      await messaging.sendEachForMulticast({
        notification: {title, body},
        tokens,
        data: {
          type: "mvpYearResult",
          teamId: String(teamId),
          mvpYearId: String(mvpYearId),
        },
      });

      console.log(
          "🎉 Year MVP 結果発表通知送信:",
          "mvp_year", mvpYearId,
          "teamId=", teamId,
          "members=", members.length,
      );
    },
);

// ================= 年間MVP: 締切前リマインド（未投票者向け） =================
export const mvpYearVoteReminderTask = onRequest(
    {
      timeoutSeconds: 540,
      region: "asia-northeast1",
    },
    async (req, res) => {
      try {
        const {teamId, mvpId} = req.body || {};
        if (!teamId || !mvpId) {
          res.status(400).send("Missing teamId or mvpId");
          return;
        }

        const teamIdStr = String(teamId);
        const mvpIdStr = String(mvpId);

        // MVP ドキュメントを取得
        const mvpRef = db
            .collection("teams")
            .doc(teamIdStr)
            .collection("mvp_year")
            .doc(mvpIdStr);
        const mvpSnap = await mvpRef.get();

        if (!mvpSnap.exists) {
          console.log("mvpYearVoteReminderTask: MVP doc not found", {
            teamId: teamIdStr,
            mvpId: mvpIdStr,
          });
          res.status(200).send("MVP doc not found");
          return;
        }

        const mvpData = mvpSnap.data() || {};
        const theme = mvpData.theme || "年間MVP";

        // チームメンバーと未投票者の抽出
        const teamSnap = await db.collection("teams").doc(teamIdStr).get();
        if (!teamSnap.exists) {
          console.log(
              "mvpYearVoteReminderTask: team not found",
              {teamId: teamIdStr},
          );
          res.status(200).send("team not found");
          return;
        }

        const teamData = teamSnap.data() || {};
        const members = Array.isArray(teamData.members) ?
          teamData.members :
          [];

        if (!members.length) {
          console.log(
              "mvpYearVoteReminderTask: no members",
              {teamId: teamIdStr},
          );
          res.status(200).send("no members");
          return;
        }

        // votes サブコレクションから投票済みユーザーIDを取得
        const votesSnap = await mvpRef.collection("votes").get();
        const votedSet = new Set();
        votesSnap.forEach((doc) => votedSet.add(doc.id));

        const notVoted = members.filter((uid) => !votedSet.has(uid));

        if (!notVoted.length) {
          console.log(
              "mvpYearVoteReminderTask: all members already voted",
              {teamId: teamIdStr, mvpId: mvpIdStr},
          );
          res.status(200).send("all voted");
          return;
        }

        const tokens = await getFcmTokensForUsers(notVoted);
        if (!tokens.length) {
          console.log(
              "mvpYearVoteReminderTask: no FCM tokens for non-voters",
              {teamId: teamIdStr, mvpId: mvpIdStr},
          );
          res.status(200).send("no tokens");
          return;
        }

        const title = `${theme} の年間MVP投票締切が近づいています`;
        const body = "まだ投票していない人は、忘れずに投票しましょう。";

        const result = await messaging.sendEachForMulticast({
          tokens,
          notification: {title, body},
          data: {
            type: "mvpYearVoteReminder",
            teamId: teamIdStr,
            mvpId: mvpIdStr,
          },
        });

        console.log("🎯 Year MVP vote reminder sent", {
          teamId: teamIdStr,
          mvpId: mvpIdStr,
          success: result.successCount,
          failure: result.failureCount,
          targetUsers: notVoted.length,
        });

        res.status(200).send("ok");
      } catch (err) {
        console.error("🚨 mvpYearVoteReminderTask error", err);
        res.status(500).send("error");
      }
    },
);

// ================= 年間MVP: 集計日当日のお知らせ（作成者向け） =================
export const mvpYearTallyNoticeTask = onRequest(
    {
      timeoutSeconds: 540,
      region: "asia-northeast1",
    },
    async (req, res) => {
      try {
        const {teamId, mvpId} = req.body || {};
        if (!teamId || !mvpId) {
          res.status(400).send("Missing teamId or mvpId");
          return;
        }

        const teamIdStr = String(teamId);
        const mvpIdStr = String(mvpId);

        const mvpRef = db
            .collection("teams")
            .doc(teamIdStr)
            .collection("mvp_year")
            .doc(mvpIdStr);
        const mvpSnap = await mvpRef.get();

        if (!mvpSnap.exists) {
          console.log("mvpYearTallyNoticeTask: MVP doc not found", {
            teamId: teamIdStr,
            mvpId: mvpIdStr,
          });
          res.status(200).send("MVP doc not found");
          return;
        }

        const mvpData = mvpSnap.data() || {};
        const theme = mvpData.theme || "年間MVP";
        const createdBy = mvpData.createdBy || {};
        const createdUid =
          createdBy.uid || createdBy.userId || createdBy.id || null;

        if (!createdUid) {
          console.log("mvpYearTallyNoticeTask: createdBy UID not found", {
            teamId: teamIdStr,
            mvpId: mvpIdStr,
          });
          res.status(200).send("no creator uid");
          return;
        }

        const tokens = await getFcmTokensForUsers([createdUid]);
        if (!tokens.length) {
          console.log(
              "mvpYearTallyNoticeTask: no FCM tokens for creator",
              {teamId: teamIdStr, mvpId: mvpIdStr, createdUid},
          );
          res.status(200).send("no tokens");
          return;
        }

        const title = `${theme} の年間MVP集計日になりました`;
        const body = "年間MVPの集計を行いましょう。";

        const result = await messaging.sendEachForMulticast({
          tokens,
          notification: {title, body},
          data: {
            type: "mvpYearTallyNotice",
            teamId: teamIdStr,
            mvpId: mvpIdStr,
          },
        });

        console.log("📊 Year MVP tally notice sent", {
          teamId: teamIdStr,
          mvpId: mvpIdStr,
          createdUid,
          success: result.successCount,
          failure: result.failureCount,
        });

        res.status(200).send("ok");
      } catch (err) {
        console.error("🚨 mvpYearTallyNoticeTask error", err);
        res.status(500).send("error");
      }
    },
);

// ================= チーム目標作成時の通知 =================
// teams/{teamId}/goals/{goalId} が作成されたら、
// period に応じて「今月 / 年間」のチーム目標決定通知を送る。
export const onTeamGoalCreated = onDocumentCreated(
    "teams/{teamId}/goals/{goalId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        console.log("onTeamGoalCreated: no snapshot, skip.");
        return;
      }

      const goalRef = snap.ref;

      // 🔒 多重実行ガード（at-least-once 対策）
      let alreadyNotified = false;
      await db.runTransaction(async (tx) => {
        const doc = await tx.get(goalRef);
        const d = doc.data() || {};
        if (d._goalCreatedNotified) {
          alreadyNotified = true;
          return;
        }
        // まだ通知していない場合だけフラグを立てる
        tx.set(goalRef, {_goalCreatedNotified: true}, {merge: true});
      });

      if (alreadyNotified) {
        console.log("onTeamGoalCreated: already notified, skip.");
        return;
      }

      const data = snap.data() || {};
      const period = data.period;
      if (period !== "month" && period !== "year") {
      // 月間・年間以外の目標は通知しない
        return;
      }

      const teamId = event.params.teamId;
      console.log(
          "onTeamGoalCreated: teamId=",
          teamId,
          "period=",
          period,
      );

      // チームメンバー取得
      const teamSnap = await db.collection("teams").doc(teamId).get();
      if (!teamSnap.exists) {
        console.log("onTeamGoalCreated: team not found:", teamId);
        return;
      }

      const teamData = teamSnap.data() || {};
      const members = Array.isArray(teamData.members) ?
      teamData.members :
      [];

      if (!members.length) {
        console.log(
            "onTeamGoalCreated: no members for team:",
            teamId,
        );
        return;
      }

      // チームメンバーの FCM トークンを取得
      const tokensRaw = await getFcmTokensForUsers(members);
      // 🔁 念のため重複トークンも排除しておく
      const tokens = Array.from(new Set(tokensRaw || []));
      if (!tokens.length) {
        console.log(
            "onTeamGoalCreated: no FCM tokens for team:",
            teamId,
        );
        return;
      }

      // 通知タイトル・本文
      let title = "";
      const body = "チームページから確認しましょう。";

      if (period === "month") {
        title = "今月のチーム目標が決まりました";
      } else if (period === "year") {
        title = "年間のチーム目標が決まりました";
      }

      // Flutter 側で遷移を判定するための type を付与
      const type =
      period === "month" ? "team_goal_month" : "team_goal_year";

      try {
        const message = {
          notification: {title, body},
          tokens,
          data: {
            type,
            teamId: String(teamId),
            period: String(period),
          },
          android: {
            priority: "high",
            notification: {
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        };

        const res = await messaging.sendEachForMulticast(message);
        console.log(
            "onTeamGoalCreated: notification sent:",
            "success=",
            res.successCount,
            "failure=",
            res.failureCount,
        );
      } catch (err) {
        console.error("onTeamGoalCreated: send error:", err);
      }
    },
);

// ================= チーム加入通知 =================
export const onUserJoinedTeam = onDocumentWritten(
    "users/{userId}",
    async (event) => {
      const before = event.data && event.data.before ?
  event.data.before.data() || {} :
  {};

      const after = event.data && event.data.after ?
  event.data.after.data() || {} :
  {};

      const beforeTeams = before.teams || [];
      const afterTeams = after.teams || [];

      // 新しく追加されたチームIDを検出
      const addedTeams = afterTeams.filter((t) => !beforeTeams.includes(t));
      if (addedTeams.length === 0) {
        return; // 追加なければ終了
      }

      const joinedTeamId = addedTeams[0];

      // チームデータ取得
      const teamSnap = await db.collection("teams").doc(joinedTeamId).get();
      if (!teamSnap.exists) return;

      const teamData = teamSnap.data() || {};
      const teamName = teamData.teamName || "チーム";

      // ユーザー情報取得
      const userId = event.params.userId;
      const userSnap = await db.collection("users").doc(userId).get();
      const userData = userSnap.data() || {};
      const tokens = userData.fcmTokens || [];

      if (!tokens.length) {
        console.log("No FCM tokens for user:", userId);
        return;
      }

      // 通知メッセージ
      const message = {
        notification: {
          title: "チーム参加完了",
          body: `${teamName} に参加しました！`,
        },
        tokens,
        data: {
          type: "joined_team",
          teamId: joinedTeamId,
        },
        android: {
          priority: "high",
          notification: {sound: "default"},
        },
        apns: {
          payload: {aps: {sound: "default"}},
        },
      };

      await messaging.sendEachForMulticast(message);
    },
);
