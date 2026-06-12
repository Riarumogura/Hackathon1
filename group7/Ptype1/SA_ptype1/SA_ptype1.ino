// ============================================================================
// Slave Arduino - 1台同時再生（主旋律＆対旋律 合致テスト・アドレス0版）
// ============================================================================

#include <Wire.h>

#define SERIAL_BAUD       9600
#define BASE_OCTAVE       4      // 楽譜の基準オクターブ（国際式4）

// ----------------------------------------------------------------------------
// 主旋律（メイン）の楽譜データ
// ----------------------------------------------------------------------------
const int pitch_main[] = {
  0, 67, 69, 71,
  72, 0, 67, 0, 64, 0, 60, 0,
  69, 0, 0, 0, 0, 69, 71, 69,
  67, 0, 65, 0, 64, 0, 62, 0,
  60, 0, 0, 0, 0, 67, 66, 67,
  64, 0, 0, 0, 0, 64, 63, 64,
  60, 0, 0, 0, 0, 64, 62, 60,
  62, 0, 0, 0, 0, 67, 69, 67,
  64, 0, 0, 0, 0, 67, 69, 71,
  72, 0, 67, 0, 64, 0, 60, 0,
  69, 0, 0, 0, 0, 69, 71, 69,
  67, 0, 65, 0, 64, 0, 62, 0,
  60, 0, 0, 0, 0, 0
};

const int duration_main[] = {
  0, 250, 250, 250,
  500, 0, 500, 0, 500, 0, 500, 0, 
  1000, 0, 0, 0, 0, 250, 250, 250,
  500, 0, 500, 0, 500, 0, 500, 0,
  1000, 0, 0, 0, 0, 250, 250, 250,
  500, 0, 0, 0, 0, 250, 250, 250,
  500, 0, 0, 0, 0, 250, 250, 250,
  500, 0, 0, 0, 0, 250, 250, 250,
  500, 0, 0, 0, 0, 250, 250, 250,
  500, 0, 500, 0, 500, 0, 500, 0,
  1000, 0, 0, 0, 0, 250, 250, 250,
  500, 0, 500, 0, 500, 0, 500, 0,
  1000, 0, 0, 0, 0, 0
};

// ----------------------------------------------------------------------------
// 対旋律（サブ）の楽譜データ
// ----------------------------------------------------------------------------
const int pitch_sub[] = {
  48, 0, 0, 0, 
  48, 0, 0, 0, 48, 0, 0, 0, 
  53, 0, 0, 0, 53, 0, 0, 0,
  55, 0, 0, 0, 55, 0, 0, 0,
  48, 0, 0, 0, 48, 0, 0, 0,
  48, 0, 0, 0, 48, 0, 0, 0,
  48, 0, 0, 0, 48, 0, 0, 0, 
  55, 0, 0, 0, 55, 0, 0, 0, 
  48, 0, 0, 0, 48, 0, 0, 0,
  48, 0, 0, 0, 48, 0, 0, 0, 
  53, 0, 0, 0, 53, 0, 0, 0, 
  55, 0, 0, 0, 55, 0, 0, 0,
  48, 0, 0, 0, 0, 0
};

const int duration_sub[] = {
  1000, 0, 0, 0, 
  1000, 0, 0, 0, 1000, 0, 0, 0, 
  1000, 0, 0, 0, 1000, 0, 0, 0,
  1000, 0, 0, 0, 1000, 0, 0, 0,
  1000, 0, 0, 0, 1000, 0, 0, 0,
  1000, 0, 0, 0, 1000, 0, 0, 0,
  1000, 0, 0, 0, 1000, 0, 0, 0, 
  1000, 0, 0, 0, 1000, 0, 0, 0, 
  1000, 0, 0, 0, 1000, 0, 0, 0,
  1000, 0, 0, 0, 1000, 0, 0, 0, 
  1000, 0, 0, 0, 1000, 0, 0, 0, 
  1000, 0, 0, 0, 1000, 0, 0, 0,
  1000, 0, 0, 0, 0, 0
};

// それぞれの楽譜の長さを自動計算
const int LENGTH_MAIN = sizeof(pitch_main) / sizeof(pitch_main[0]);
const int LENGTH_SUB  = sizeof(pitch_sub) / sizeof(pitch_sub[0]);

// ----------------------------------------------------------------------------
// グローバル変数
// ----------------------------------------------------------------------------
volatile bool dataReceived = false;
volatile char rxBuffer[16];           
volatile int rxLength = 0;

int receivedOctave  = 5;      
int currentBPM      = 120;    
int i2cReceiveCount = 0;      
bool isPlaying      = false;

void setup() {
  Serial.begin(SERIAL_BAUD);
  
  // ★【アドレス0】ブロードキャスト（ジェネラルコール）のアドレス0で初期化
  Wire.begin(0);
  Wire.onReceive(receiveEvent);
  
  Serial.println("Slave (Dual Play Test Mode Address:0) Ready.");
}

void loop() {
  if (dataReceived) {
    String input = "";
    noInterrupts();
    for(int i = 0; i < rxLength; i++) {
      input += (char)rxBuffer[i];
    }
    dataReceived = false;
    interrupts();

    input.trim();

    // 1. 初期設定データ（8桁）を受け取ったら演奏フラグをON
    if (input.length() == 8) {
      receivedOctave = input.substring(0, 2).toInt();
      currentBPM     = input.substring(5, 8).toInt();
      i2cReceiveCount = 0;
      isPlaying = true;
      Serial.println("--- Dual Test Play Started ---");
    }
    
    // 2. 演奏中のBPMデータ（3桁のTick信号）を受信したときの処理
    else if (input.length() == 3) {
      currentBPM = input.toInt();
      
      if (isPlaying) {
        i2cReceiveCount++; // 1から始まる現在の通算Tick数
        int index = i2cReceiveCount - 1; // 配列にアクセスするためのインデックス

        bool mainFinished = (index >= LENGTH_MAIN);
        bool subFinished  = (index >= LENGTH_SUB);

        // 両方の楽譜を最後まで流し終えたら演奏終了
        if (mainFinished && subFinished) {
          isPlaying = false;
          Serial.println("--- Dual Test Play Finished ---");
          return;
        }

        // 共通のオクターブ計算用
        int targetOctave = receivedOctave - 1;

        // --------------------------------------------------------------------
        // ① 主旋律（メイン）の音符送信処理
        // --------------------------------------------------------------------
        if (!mainFinished && pitch_main[index] > 0) {
          int shiftedPitch = pitch_main[index] + (targetOctave - BASE_OCTAVE) * 12;
          shiftedPitch = constrain(shiftedPitch, 0, 127);
          long calcDuration = (long)duration_main[index] * 120 / currentBPM;

          // Processingへカンマ区切りで送信
          Serial.print(shiftedPitch);
          Serial.print(",");
          Serial.println(calcDuration);
        }

        // --------------------------------------------------------------------
        // ② 対旋律（サブ）の音符送信処理（主旋律のすぐ直後に連続送信して和音化）
        // --------------------------------------------------------------------
        if (!subFinished && pitch_sub[index] > 0) {
          int shiftedPitch = pitch_sub[index] + (targetOctave - BASE_OCTAVE) * 12;
          shiftedPitch = constrain(shiftedPitch, 0, 127);
          long calcDuration = (long)duration_sub[index] * 120 / currentBPM;

          // Processingへカンマ区切りで送信
          Serial.print(shiftedPitch);
          Serial.print(",");
          Serial.println(calcDuration);
        }
      }
    }
  }
}

void receiveEvent(int numBytes) {
  rxLength = 0;
  while (Wire.available() && rxLength < 15) {
    char c = Wire.read();
    rxBuffer[rxLength] = c;
    rxLength++;
  }
  dataReceived = true;
}