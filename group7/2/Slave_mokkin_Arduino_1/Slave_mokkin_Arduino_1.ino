// ============================================================
// Slave Arduino - 木琴（マリンバ）担当
// MasterからI2C受信 → 演奏開始 → Serialで音符送信
// ============================================================

#include <Wire.h>

#define SLAVE_ADDR        0x08   // 全Slave共通アドレス
#define SERIAL_BAUD       9600
#define DATA_SIZE         5
#define MY_INSTRUMENT_ID  2      // 1=ピアノ, 2=木琴

// startCountの定義（演奏順位→待機スロット数）
#define COUNT_1ST   0
#define COUNT_2ND   8

// ベースオクターブ（楽譜データはoctave=4基準で作成）
#define BASE_OCTAVE 4

// ------------------------------------------------------------
// 楽譜データ（もりのくまさん / 木琴主旋律 / BPM120）
// pitch    : MIDIノート番号（0 = 休符）※ octave=4基準
// duration : 音符の長さ（ms）
// startTime: 曲開始からの絶対発音タイミング（ms）
// ------------------------------------------------------------
const int SCORE_LENGTH = 61;

const int pitch[] = {
  0,  67, 69, 71,
  72, 67, 64, 60,
  69,  0, 69, 71, 69,
  67, 68, 69, 71,
  72,  0, 67, 66, 67,
  64,  0,  0, 64, 63, 64,
  60,  0,  0, 64, 62, 60,
  62,  0,  0, 67, 69, 67,
  64,  0,  0, 67, 69, 71,
  72, 67, 64, 60,
  69,  0, 69, 71, 69,
  67, 65, 64, 62,
  60,  0
};

const int duration[] = {
  250, 250, 250, 250,
  500, 500, 500, 500,
  1000, 250, 250, 250, 250,
  500, 500, 500, 500,
  1000, 250, 250, 250, 250,
  500, 500, 250, 250, 250, 250,
  500, 500, 250, 250, 250, 250,
  500, 500, 250, 250, 250, 250,
  500, 500, 250, 250, 250, 250,
  500, 500, 500, 500,
  1000, 250, 250, 250, 250,
  500, 500, 500, 500,
  1500, 500
};

const int startTime[] = {
     0,  250,  500,  750,
  1000, 1500, 2000, 2500,
  3000, 4000, 4250, 4500, 4750,
  5000, 5500, 6000, 6500,
  7000, 8000, 8250, 8500, 8750,
  9000,  9500, 10000, 10250, 10500, 10750,
  11000, 11500, 12000, 12250, 12500, 12750,
  13000, 13500, 14000, 14250, 14500, 14750,
  15000, 15500, 16000, 16250, 16500, 16750,
  17000, 17500, 18000, 18500,
  19000, 20000, 20250, 20500, 20750,
  21000, 21500, 22000, 22500,
  23000, 24500
};

// ------------------------------------------------------------
// グローバル変数
// ------------------------------------------------------------
volatile byte rxData[DATA_SIZE];
volatile bool dataReceived = false;

bool          isPlaying     = false;
int           scoreIndex    = 0;
unsigned long playStartTime = 0;
int           myStartCount  = -1;  // -1=演奏しない
int           flashCount    = 0;
int           currentOctave = BASE_OCTAVE;

// ------------------------------------------------------------
void setup() {
  Wire.begin(SLAVE_ADDR);
  Wire.onReceive(onReceive);
  Serial.begin(SERIAL_BAUD);
  Serial.println("Slave(Mokkin) ready");
}

void loop() {
  if (dataReceived) {
    dataReceived = false;

    byte bpm  = rxData[0];
    byte oct  = rxData[1];
    byte id1  = rxData[2];
    byte id2  = rxData[3];
    // byte id3 = rxData[4]; // 2楽器構成のため未使用

    // オクターブ更新（0を-1として扱う：0→-1, 1→0, ..., 5→4）
    currentOctave = (int)oct - 1;

    // 自分のIDが何番目かでstartCountを設定
    if      (id1 == MY_INSTRUMENT_ID) myStartCount = COUNT_1ST;
    else if (id2 == MY_INSTRUMENT_ID) myStartCount = COUNT_2ND;
    else                               myStartCount = -1;

    // I2C受信カウントアップ（演奏トリガーとして使用）
    flashCount++;

    // startCountに達したら演奏開始
    if (myStartCount >= 0 && !isPlaying && flashCount > myStartCount) {
      isPlaying     = true;
      scoreIndex    = 0;
      playStartTime = millis();
      Serial.println("START");
    }
  }

  // 演奏中：startTimeを過ぎた音符をSerialへ送信
  if (isPlaying && scoreIndex < SCORE_LENGTH) {
    unsigned long elapsed = millis() - playStartTime;

    if (elapsed >= (unsigned long)startTime[scoreIndex]) {
      if (pitch[scoreIndex] != 0) {
        // オクターブシフト：BASE_OCTAVEとの差分×12をMIDIノートに加算
        int shiftedPitch = pitch[scoreIndex] + (currentOctave - BASE_OCTAVE) * 12;
        shiftedPitch = constrain(shiftedPitch, 0, 127);

        Serial.print(shiftedPitch);
        Serial.print(",");
        Serial.println(duration[scoreIndex]);
      }
      scoreIndex++;

      if (scoreIndex >= SCORE_LENGTH) {
        isPlaying  = false;
        flashCount = 0;
        Serial.println("END");
      }
    }
  }
}

void onReceive(int numBytes) {
  if (numBytes == DATA_SIZE) {
    for (int i = 0; i < DATA_SIZE; i++) rxData[i] = Wire.read();
    dataReceived = true;
  } else {
    while (Wire.available()) Wire.read();
  }
}
