#include <Wire.h>

#define SERIAL_BAUND 9600

int currentBPM = 0;
int tickCount = 0;
bool playing = false;

unsigned long waitStart = 0;
unsigned long waitMs = 0;
bool waiting = false;
bool finishWaiting = false;

void setup() {
  Serial.begin(SERIAL_BAUND);
  Wire.begin();
  Serial.println("Master Arduino Ready");
}

void loop() {

  // Processingからシリアルデータが届いているか確認
  if (Serial.available() > 0) {

    // 改行コード（\n）が来るまで読み込んで、前後の余白を削除
    String input = Serial.readStringUntil('\n');
    input.trim();

    // 【桁数判定】

    // パターンA：初期設定データ（8桁）が届いた場合
    if (input.length() == 8) {

      // 1. 後ろの3文字（5〜7番目）を切り出して、グローバル変数 currentBPM を更新
      String bpmStr = input.substring(5, 8);
      currentBPM = bpmStr.toInt();

      if (currentBPM >= 30 && currentBPM <= 180) {
        // 2. I2Cを使って、全Slaveへ8桁の文字列をそのまま一斉送信
        Wire.beginTransmission(0);
        Wire.print(input);
        Wire.endTransmission();

        // start制御
        Serial.print("START");

        // デバッグログ
        Serial.println("Config Fowarded");

        // 演奏開始：tickCountを1とし、待機タイマーをセット
        tickCount = 1;
        playing = true;
        waiting = true;
        finishWaiting = false;
        waitMs = (unsigned long)currentBPM * 25UL / 12UL;
        waitStart = millis();
      }
    }

    // パターンB：演奏中のBPM同期データ（3桁）が届いた場合
    else if (input.length() == 3) {

      // 1. 届いた3桁を整数に変換して、グローバル変数 currentBPM を更新
      int newBPM = input.toInt();
      if (newBPM >= 30 && newBPM <= 180) {
        currentBPM = newBPM;
        // デバッグログ
        Serial.print("[BPM Sync] Updated currentBPM: ");
        Serial.println(currentBPM);
        // ※次回の送信・待機時間から新しいcurrentBPMが反映される
      }
    }

    // エラー対策：それ以外の桁数は無視
    else {
      Serial.print("[Warning] Invalid data length: ");
      Serial.println(input);
    }
  }

  // 通常待機タイマー（BPM x 25 / 12 ms）
  if (playing && waiting && !finishWaiting) {
    if (millis() - waitStart >= waitMs) {
      waiting = false;

      if (tickCount >= 98) {
        // 98回目の送信完了 → 最終待機へ移行
        finishWaiting = true;
        waitMs = (unsigned long)currentBPM * 50UL / 12UL + 500UL;
        waitStart = millis();
        Serial.print("[Finish Wait] ");
        Serial.print(waitMs);
        Serial.println(" ms");

      } else {
        // BPMを再送信し、tickCountを加算して次の待機へ
        tickCount++;
        char sendBpmStr[4];
        sprintf(sendBpmStr, "%03d", currentBPM);
        Wire.beginTransmission(0);
        Wire.print(sendBpmStr);
        Wire.endTransmission();
        Serial.print("[BPM Tick] Sent: ");
        Serial.print(sendBpmStr);
        Serial.print("  tick: ");
        Serial.println(tickCount);

        // 次の待機タイマーをセット（currentBPMを参照）
        waiting = true;
        waitMs = (unsigned long)currentBPM * 25UL / 12UL;
        waitStart = millis();
      }
    }
  }

  // 最終待機タイマー（BPM x 50 / 12 + 500 ms）
  if (playing && finishWaiting) {
    if (millis() - waitStart >= waitMs) {
      Serial.println("FINISH");
      playing = false;
      finishWaiting = false;
    }
  }
}
