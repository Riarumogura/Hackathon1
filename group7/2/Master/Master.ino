// ============================================================
// Master Arduino
// PC5（Controller.pde）からSerial受信
// → パース → I2CでSlave全員へブロードキャスト
//
// 受信フォーマット（桁指定形式・9byte）：
//   通常パケット : "XYYYYBBB\n"
//     X   : オクターブ（'0'=-1, '1'=0, ..., '5'=4, ..., 'A'=9）
//     YYYY: 演奏順（楽器1〜4の演奏順番，0=未使用）
//     BBB : BPM（030〜180，3桁ゼロ埋め）
//   BPMのみ変更（演奏中）: "BBBB\n"（先頭'B' + 3桁BPM）
//
// I2C送信フォーマット（5byte）：
//   [0] BPM（byte）
//   [1] オクターブ（byte，0=-1, 1=0, ..., 5=4, ...）
//   [2] 1番目の楽器ID（1=ピアノ, 2=木琴, 0=未使用）
//   [3] 2番目の楽器ID
//   [4] 3番目の楽器ID（2楽器構成では0固定）
// ============================================================

#include <Wire.h>

#define SLAVE_ADDR  0x08
#define SERIAL_BAUD 9600
#define DATA_SIZE   5

// I2C送信バッファ
byte sendData[DATA_SIZE] = {120, 5, 1, 2, 0};
// デフォルト: BPM=120, OCT=4('5'), ピアノ1番手, 木琴2番手

// ============================================================
void setup() {
  Wire.begin();
  Serial.begin(SERIAL_BAUD);
  Serial.println("Master ready");
}

void loop() {
  if (Serial.available() > 0) {
    String line = Serial.readStringUntil('\n');
    line.trim();
    if (line.length() == 0) return;

    // BPMのみ変更パケット："BBBB" (先頭'B' + 3桁BPM)
    if (line.charAt(0) == 'B' && line.length() == 4) {
      int newBpm = line.substring(1).toInt();
      if (newBpm >= 30 && newBpm <= 180) {
        sendData[0] = (byte)newBpm;
        broadcastI2C();
        Serial.println("ACK_BPM");
      } else {
        Serial.println("ERR_BPM");
      }
      return;
    }

    // 通常パケット："XYYYYBBB" (8文字)
    if (line.length() == 8) {
      // オクターブ解析（'0'=-1, '1'=0, ..., '9'=8, 'A'=9）
      char octChar = line.charAt(0);
      int octByte;
      if (octChar >= '0' && octChar <= '9') {
        octByte = octChar - '0';
      } else if (octChar == 'A') {
        octByte = 10;
      } else {
        Serial.println("ERR_OCT");
        return;
      }

      // 演奏順解析（4桁：楽器ごとの演奏順番，0=未使用）
      // YYYY の各桁 = 楽器1〜4の演奏順番
      // 例："1200" → ピアノ=1番手, 木琴=2番手, 以降=未使用
      int orders[4];
      for (int i = 0; i < 4; i++) {
        orders[i] = line.charAt(1 + i) - '0';
      }

      // BPM解析（3桁）
      int bpm = line.substring(5, 8).toInt();
      if (bpm < 30 || bpm > 180) {
        Serial.println("ERR_BPM");
        return;
      }

      // I2C送信データ組み立て
      // [0] BPM
      sendData[0] = (byte)bpm;
      // [1] オクターブ（byte値そのまま）
      sendData[1] = (byte)octByte;
      // [2][3][4] 演奏順→楽器IDに変換
      // ordersは楽器インデックス（0=ピアノ,1=木琴）の演奏順番
      // → 1番手の楽器ID, 2番手の楽器ID, 3番手=0（2楽器なので未使用）
      byte ids[3] = {0, 0, 0};
      for (int inst = 0; inst < 4; inst++) {
        int order = orders[inst];  // 0=未設定, 1〜4=演奏順
        if (order >= 1 && order <= 3) {
          ids[order - 1] = (byte)(inst + 1);  // 楽器ID = インデックス+1
        }
      }
      sendData[2] = ids[0];
      sendData[3] = ids[1];
      sendData[4] = ids[2];

      broadcastI2C();
      Serial.println("ACK");

      // デバッグ出力
      Serial.print("OCT:");   Serial.print(octByte - 1);
      Serial.print(" BPM:");  Serial.print(bpm);
      Serial.print(" ID1:");  Serial.print(ids[0]);
      Serial.print(" ID2:");  Serial.print(ids[1]);
      Serial.print(" ID3:");  Serial.println(ids[2]);

    } else {
      Serial.println("ERR_LEN");
    }
  }
}

// I2Cブロードキャスト送信
void broadcastI2C() {
  Wire.beginTransmission(SLAVE_ADDR);
  for (int i = 0; i < DATA_SIZE; i++) Wire.write(sendData[i]);
  byte result = Wire.endTransmission();
  if (result != 0) {
    Serial.print("I2C_ERR:");
    Serial.println(result);
  }
}
