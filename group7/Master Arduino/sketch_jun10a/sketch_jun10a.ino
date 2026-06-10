#include <Wire.h>

// 【グローバル変数】現在のBPMを保持する
int currentBPM = 0;

void setup() {
  // パソコン（Processing）からのシリアル通信用
  Serial.begin(9600);
  
  // I2C通信のMasterとして初期化
  Wire.begin(); 
  
  Serial.println("Master Arduino Ready. Waiting for Processing...");
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

      // 2. I2Cを使って、全Slaveへ8桁の文字列をそのまま一斉送信
      Wire.beginTransmission(0); 
      Wire.print(input);       
      Wire.endTransmission();

      // デバッグログ
      Serial.print("[Config] Forwarded. (Stored BPM: "); 
      Serial.print(currentBPM);
      Serial.println(")");
    }
    
    // パターンB：演奏中のBPM同期データ（3桁）が届いた場合
    else if (input.length() == 3) {
      
      // 1. 届いた3桁を整数に変換して、グローバル変数 currentBPM を更新
      currentBPM = input.toInt();

      // 2. 送信用の3桁文字列（例: 95 -> "095"）を再整形
      char sendBpmStr[4];
      sprintf(sendBpmStr, "%03d", currentBPM);

      // 3. I2Cを使って、全Slaveへ新しく格納されたBPM（3桁）を一斉送信
      Wire.beginTransmission(0); 
      Wire.print(sendBpmStr);        
      Wire.endTransmission();

      // デバッグログ
      Serial.print("[BPM Sync] Forwarded Stored BPM: "); 
      Serial.println(sendBpmStr);
    }
    
    // エラー対策：それ以外の桁数は無視
    else {
      Serial.print("[Warning] Invalid data length: ");
      Serial.println(input);
    }
  }
}