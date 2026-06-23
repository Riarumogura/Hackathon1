// ============================================================================
// Slave Arduino - 全楽器対応
// ============================================================================

#include <Wire.h>

#define MY_I2C_ADDRESS    0      // この楽器のI2Cアドレス
#define SERIAL_BAUD       9600
#define BASE_OCTAVE       4      // 楽譜の基準オクターブ（国際式4）
#define INST_ID 3                // ピアノ=1, 木琴＝2, フルート=3, ドラム=4

// ドラム用定数（Drumslave_ver2.inoと同じ値）
#define DRUM_HIHAT       2
#define DRUM_SNARE       1
#define DRUM_VEL_HIHAT   80
#define DRUM_VEL_SNARE   110

// ----------------------------------------------------------------------------
// 楽譜データ（もりのくまさん / 主旋律＋対旋律 / 120bpm基準）
// 音階配列は各要素が3音分(和音用に拡張可能、未使用分は0=休符)の二次元配列。
// ----------------------------------------------------------------------------

const int pitch_main[][3] = {
  {0,0,0}, {67,0,0}, {69,0,0}, {71,0,0},
  {72,0,0}, {0,0,0}, {67,0,0}, {0,0,0}, {64,0,0}, {0,0,0}, {60,0,0}, {0,0,0},
  {69,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {69,0,0}, {71,0,0}, {69,0,0},
  {67,0,0}, {0,0,0}, {65,0,0}, {0,0,0}, {64,0,0}, {0,0,0}, {62,0,0}, {0,0,0},
  {60,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {67,0,0}, {66,0,0}, {67,0,0},
  {64,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {64,0,0}, {63,0,0}, {64,0,0},
  {60,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {64,0,0}, {62,0,0}, {60,0,0},
  {62,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {67,0,0}, {69,0,0}, {67,0,0},
  {64,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {67,0,0}, {69,0,0}, {71,0,0},
  {72,0,0}, {0,0,0}, {67,0,0}, {0,0,0}, {64,0,0}, {0,0,0}, {60,0,0}, {0,0,0},
  {69,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {69,0,0}, {71,0,0}, {69,0,0},
  {67,0,0}, {0,0,0}, {65,0,0}, {0,0,0}, {64,0,0}, {0,0,0}, {62,0,0}, {0,0,0},
  {60,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
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

const int pitch_sub[][3] = {
  {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {53,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {53,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {55,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {55,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {55,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {55,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {53,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {53,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {55,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {55,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
  {48,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0},
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
const int SCORE_LENGTH = sizeof(pitch_main) / sizeof(pitch_main[0]);

// ----------------------------------------------------------------------------
// グローバル変数
// ----------------------------------------------------------------------------
volatile bool dataReceived = false;
volatile char rxBuffer[16];      // 割り込み内で受信データを保持するバッファ
volatile int  rxLength    = 0;

int receivedOctave  = 5;      // 受信したオクターブ値
int myPlayOrder     = 1;      // 自分の演奏順（初期設定データ受信で上書きされる）
int currentBPM      = 120;    // 現在のBPM
int startTick       = 0;      // 演奏を開始するTickの閾値
int indexOffset      = -1;    // (i2cReceiveCount - startTick) からindexへの補正値
int i2cReceiveCount = 0;      // I2Cでデータを受信した回数
bool isPlaying      = false;
bool drumNextIsHihat = true;  // ドラム(INST_ID==4)用：次に鳴らす音がハイハットかどうか

void setup() {
  Serial.begin(SERIAL_BAUD);
  Wire.begin(MY_I2C_ADDRESS);
  Wire.onReceive(receiveEvent);
  if(INST_ID == 1) {
    Serial.println("Slave(Piano) Ready.");
  } else if (INST_ID == 2) {
    Serial.println("Slave(Mokkin) Ready.");
  } else if (INST_ID == 3) {
    Serial.println("Slave(Flute) Ready.");
  } else if(INST_ID == 4){
    Serial.println("Slave(Drum) Ready.");
  }else{
    Serial.println("Warning! Invalid instrument!");
  }
}

void loop() {
  if (dataReceived) {
    // 割り込みバッファの内容を、通常の String 変数にコピーして退避
    String input = "";
    for (int i = 0; i < rxLength; i++) {
      input += (char)rxBuffer[i];
    }
    dataReceived = false;
    input.trim();

    // 【デバッグ出力】I2Cで受信した生の文字列と文字数をシリアルモニタに表示
    Serial.print("I2C: ");
    Serial.println(input);

    // ドラム(INST_ID==4)は通常楽器と処理が完全に異なるため、専用関数に分岐する
    if (INST_ID == 4) {
      handleDrum(input);
      return;
    }

    // ========================================================================
    // 【判定1】初期設定データ（8桁）の受信
    // ========================================================================
    if (input.length() == 8) {
      receivedOctave = input.substring(0, 2).toInt();
      myPlayOrder = input.substring(INST_ID + 1, INST_ID +2).toInt();
      currentBPM = input.substring(5, 8).toInt();

      if (myPlayOrder == 1) {
        startTick = 0;
        indexOffset = -1;
      } else if (myPlayOrder == 2 || myPlayOrder == 3) {
        startTick = 37;
        indexOffset = 32;  // TickCount==38(tickCount=1)で33要素目から始まる
      } else {
        startTick = -1;
        indexOffset = 0;
      }

      i2cReceiveCount = 0;
      isPlaying = (startTick != -1);

      // 【デバッグ出力】解析した設定内容を表示
      Serial.print("  -> Config parsed. Octave:");
      Serial.print(receivedOctave);
      Serial.print(", Order:");
      Serial.print(myPlayOrder);
      Serial.print(", BPM:");
      Serial.print(currentBPM);
      Serial.print(", StartTickLimit:");
      Serial.println(startTick);
    }

    // ========================================================================
    // 【判定2】演奏中のBPMデータ（3桁）の受信 ＝ Tickカウント
    // ========================================================================
    else if (input.length() == 3) {
      currentBPM = input.toInt();

      if (isPlaying) {
        i2cReceiveCount++;

        if (i2cReceiveCount > startTick) {
          int index = (i2cReceiveCount - startTick) + indexOffset;

          // myPlayOrderが2,3のときはTickCount=66（myPlayOrder==1が65要素目を演奏する
          // タイミング）から、myPlayOrder==1と同じ進行に合流する
          if ((myPlayOrder == 2 || myPlayOrder == 3) && i2cReceiveCount >= 66) {
            index = i2cReceiveCount - 1;
          }

          if (index < SCORE_LENGTH) {
            // ① pitchのオクターブ変更処理（主旋律・対旋律それぞれ、3音分）
            int targetOctave = receivedOctave - 1;

            int shiftedMain[3];
            int shiftedSub[3];
            for (int v = 0; v < 3; v++) {
              shiftedMain[v] = 0;
              if (pitch_main[index][v] > 0) {
                shiftedMain[v] = constrain(pitch_main[index][v] + (targetOctave - BASE_OCTAVE) * 12, 0, 127);
              }
              shiftedSub[v] = 0;
              if (pitch_sub[index][v] > 0) {
                shiftedSub[v] = constrain(pitch_sub[index][v] + (targetOctave - BASE_OCTAVE) * 12, 0, 127);
              }
            }

            // ② durationのBPM補正処理
            long targetDurationMain = (long)duration_main[index] * 120 / currentBPM;
            long targetDurationSub  = (long)duration_sub[index]  * 120 / currentBPM;

            // ③ カンマ区切りでシリアルへ送信（主旋律・対旋律を別の行で送信）
            Serial.print(shiftedMain[0]);
            Serial.print(",");
            Serial.print(shiftedMain[1]);
            Serial.print(",");
            Serial.print(shiftedMain[2]);
            Serial.print(",");
            Serial.println(targetDurationMain);

            Serial.print(shiftedSub[0]);
            Serial.print(",");
            Serial.print(shiftedSub[1]);
            Serial.print(",");
            Serial.print(shiftedSub[2]);
            Serial.print(",");
            Serial.println(targetDurationSub);

            if (index == SCORE_LENGTH - 1) {
              isPlaying = false;
              // 【デバッグ出力】楽譜の最後まで演奏したことを通知
              Serial.println("  -> Score Finished.");
            }
          }
        }
      }
    }
  }
}

// ----------------------------------------------------------------------------
// ドラム専用処理（INST_ID==4 のときだけ呼び出される）
// 出力フォーマットはDrumslave_ver2.inoと同じ "drumType,velocity,BPM"
// ----------------------------------------------------------------------------
void handleDrum(String input) {
  // 【判定1】初期設定データ（8桁）の受信 → 演奏開始
  if (input.length() == 8) {
    i2cReceiveCount = 0;
    isPlaying = true;
    drumNextIsHihat = true;
  }

  // 【判定2】演奏中のBPMデータ（3桁）の受信 ＝ Tickカウント
  else if (input.length() == 3) {
    if (isPlaying) {
      i2cReceiveCount++;
      int tickCount = i2cReceiveCount - 1; // TickCountは0始まり

      // TickCountが偶数のときだけ、ハイハットとスネアを交互に発音する
      if (tickCount % 2 == 0) {
        int drumType = drumNextIsHihat ? DRUM_HIHAT : DRUM_SNARE;
        int velocity = drumNextIsHihat ? DRUM_VEL_HIHAT : DRUM_VEL_SNARE;

        Serial.print(drumType);
        Serial.print(",");
        Serial.print(velocity);
        Serial.print(",");
        Serial.println(input);

        drumNextIsHihat = !drumNextIsHihat;
      }

      // TickCountが97（i2cReceiveCountが98）になったら終了
      if (tickCount == 97) {
        isPlaying = false;
      }
    }
  }
}

// ----------------------------------------------------------------------------
// I2C受信割り込みイベント
// ----------------------------------------------------------------------------
void receiveEvent(int numBytes) {
  rxLength = 0;
  while (Wire.available() && rxLength < (int)sizeof(rxBuffer) - 1) {
    rxBuffer[rxLength] = Wire.read();
    rxLength++;
  }
  dataReceived = true;
}
