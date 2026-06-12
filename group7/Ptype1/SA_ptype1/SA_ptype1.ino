// ============================================================================
// Slave Arduino - ピアノ担当
// ============================================================================

#include <Wire.h>

#define MY_I2C_ADDRESS    0      // この楽器のI2Cアドレス
#define SERIAL_BAUD       9600
#define BASE_OCTAVE       4      // 楽譜の基準オクターブ（国際式4）

// ----------------------------------------------------------------------------
// 楽譜データ（もりのくまさん / 120bpm基準）
// ----------------------------------------------------------------------------

// メイン楽譜（1番手、および3番手が使用）
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
  60, 0, 0, 0, 0, 0,
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
  1000, 0, 0, 0, 0, 0,
};

// サブ楽譜（2番手が使用）※中身は検証用に仮のものを置いています
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
  48, 0, 0, 0, 0, 0,
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
  1000, 0, 0, 0, 0, 0,
};

// 要素数の自動計算
const int SCORE_LENGTH_MAIN = sizeof(pitch_main) / sizeof(pitch_main[0]);
const int SCORE_LENGTH_SUB  = sizeof(pitch_sub) / sizeof(pitch_sub[0]);

// ----------------------------------------------------------------------------
// グローバル変数（Uno R4対応）
// ----------------------------------------------------------------------------
volatile bool dataReceived = false;
volatile char rxBuffer[16];           
volatile int rxLength = 0;

int receivedOctave  = 5;      // 受信したオクターブ値
int myPlayOrder     = 1;      // 自分の演奏順
int currentBPM      = 120;    // 現在のBPM
int i2cReceiveCount = 0;      // I2Cでデータ（Tick）を受信した通算回数
bool isPlaying      = false;

void setup() {
  Serial.begin(SERIAL_BAUD);
  Wire.begin(MY_I2C_ADDRESS);
  Wire.onReceive(receiveEvent);
  Serial.println("Slave(Piano) Ready.");
}

void loop() {
  if (dataReceived) {
    // 割り込みバッファから通常のStringへ安全にコピー
    String input = "";
    noInterrupts();
    for(int i = 0; i < rxLength; i++) {
      input += (char)rxBuffer[i];
    }
    dataReceived = false;
    interrupts();

    input.trim();

    // 【デバッグ出力】受信ログ
    Serial.print("I2C Rx: [");
    Serial.print(input);             
    Serial.print("] (Len: ");
    Serial.print(input.length());    
    Serial.println(")");

    // ========================================================================
    // 【判定1】初期設定データ（8桁）の受信
    // ========================================================================
    if (input.length() == 8) {
      receivedOctave = input.substring(0, 2).toInt();
      myPlayOrder    = input.substring(2, 3).toInt(); // 演奏順
      currentBPM     = input.substring(5, 8).toInt();

      i2cReceiveCount = 0;
      // 演奏順が 1, 2, 3 のいずれかであれば演奏に参加する
      isPlaying = (myPlayOrder >= 1 && myPlayOrder <= 3);
      
      Serial.print("  -> Config parsed. Order:");
      Serial.println(myPlayOrder);
    }
    
    // ========================================================================
    // 【判定2】演奏中のBPMデータ（3桁）の受信 ＝ Tickカウント
    // ========================================================================
    else if (input.length() == 3) {
      currentBPM = input.toInt();
      
      if (isPlaying) {
        i2cReceiveCount++; // Masterからの通算受信回数（＝現在の全体のTickCount）
        
        int targetPitch = 0;
        int targetDuration = 0;
        bool hasNoteToPlay = false;

        // --------------------------------------------------------------------
        // パターン①：演奏順が 1 のとき（最初からメイン楽譜）
        // --------------------------------------------------------------------
        if (myPlayOrder == 1) {
          int index = i2cReceiveCount - 1; // tickCount=1 のとき index=0
          if (index < SCORE_LENGTH_MAIN) {
            targetPitch = pitch_main[index];
            targetDuration = duration_main[index];
            hasNoteToPlay = true;
          } else {
            isPlaying = false; // 楽譜終了
          }
        }

        // --------------------------------------------------------------------
        // パターン②：演奏順が 2 のとき（最初からサブ楽譜）
        // --------------------------------------------------------------------
        else if (myPlayOrder == 2) {
          int index = i2cReceiveCount - 1; // tickCount=1 のとき index=0
          if (index < SCORE_LENGTH_SUB) {
            targetPitch = pitch_sub[index];
            targetDuration = duration_sub[index];
            hasNoteToPlay = true;
          } else {
            isPlaying = false; // 楽譜終了
          }
        }

        // --------------------------------------------------------------------
        // パターン③：演奏順が 3 のとき（変則ジャンプ演奏）
        // --------------------------------------------------------------------
        else if (myPlayOrder == 3) {
          
          // 条件①＆②：TickCount=37〜65 のとき
          if (i2cReceiveCount >= 37 && i2cReceiveCount < 66) {
            // TickCount=37 のときに 要素番号33 を参照させるための計算
            int index = 33 + (i2cReceiveCount - 37); 
            
            if (index < SCORE_LENGTH_MAIN) {
              targetPitch = pitch_main[index];
              targetDuration = duration_main[index];
              hasNoteToPlay = true;
            }
          }
          
          // 条件③：TickCount=66〜98 のとき
          else if (i2cReceiveCount >= 66 && i2cReceiveCount <= 98) {
            // TickCount=66 のときに 要素番号65 を参照させるための計算
            int index = 65 + (i2cReceiveCount - 66);
            
            if (index < SCORE_LENGTH_MAIN) {
              targetPitch = pitch_main[index];
              targetDuration = duration_main[index];
              hasNoteToPlay = true;
            }
            
            if (i2cReceiveCount == 98) {
              isPlaying = false; // 指定のTick98に達したので終了
            }
          }
        }

        // --------------------------------------------------------------------
        // データ送信処理（音符が存在し、休符でなければProcessingへ送信）
        // --------------------------------------------------------------------
        if (hasNoteToPlay) {
          int shiftedPitch = 0;
          long calculatedDuration = 0;

          if (targetPitch > 0) {
            // オクターブ補正
            int targetOctave = receivedOctave - 1;
            shiftedPitch = targetPitch + (targetOctave - BASE_OCTAVE) * 12;
            shiftedPitch = constrain(shiftedPitch, 0, 127);
            
            // BPM補正
            calculatedDuration = (long)targetDuration * 120 / currentBPM;

            // Processingへカンマ区切りで送信
            Serial.print(shiftedPitch);
            Serial.print(",");
            Serial.println(calculatedDuration);
          }
        }
      }
    }
  }
}

// ----------------------------------------------------------------------------
// I2C受信割り込みイベント
// ----------------------------------------------------------------------------
void receiveEvent(int numBytes) {
  rxLength = 0;
  while (Wire.available() && rxLength < 15) {
    char c = Wire.read();
    rxBuffer[rxLength] = c;
    rxLength++;
  }
  dataReceived = true;
}