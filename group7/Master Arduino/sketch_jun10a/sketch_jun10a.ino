#include <Wire.h>

void setup() {
  // パソコン（Processing）からのシリアル通信を受信するために初期化
  // ※PC側のProcessingプログラムの通信速度（Baud rate）と合わせてください
  Serial.begin(9600);
  
  // I2C通信のMasterとして初期化
  Wire.begin(); 
  
  // デバッグ用表示
  Serial.println("Master Arduino Ready. Waiting for Processing...");
}

void loop() {
  // Processingからシリアルデータが届いているか確認
  if (Serial.available() > 0) {
    
    // 改行コード（\n）が来るまで一気に読み込む
    String input = Serial.readStringUntil('\n');
    input.trim(); // 末尾の不要な改行コードや空白を削除

    // 【桁数判定ロジック】届いたデータの長さで「初期設定」か「BPM」かを判別する

    // パターンA：初期設定データ（8桁）が届いた場合
    if (input.length() == 8) {
      
      // 1. デバッグ用にPC（シリアルモニタ等）へ中継ログを表示
      Serial.print("[Serial -> I2C] Forwarding Config: "); 
      Serial.println(input);

      // 2. I2Cを使って、全Slave（アドレス0）へ8桁の文字列をそのまま一斉送信
      Wire.beginTransmission(0); 
      Wire.print(input);       
      Wire.endTransmission();
    }
    
    // パターンB：演奏中のBPM同期データ（3桁）が届いた場合
    else if (input.length() == 3) {
      
      // 1. デバッグ用にログを表示
      Serial.print("[Serial -> I2C] Forwarding BPM: "); 
      Serial.println(input);

      // 2. I2Cを使って、全Slave（アドレス0）へ3桁のBPM文字列を一斉送信
      Wire.beginTransmission(0); 
      Wire.print(input);        
      Wire.endTransmission();
    }
    
    // エラー対策：それ以外の想定外の桁数が届いた場合はノイズとして無視
    else {
      Serial.print("[Warning] Invalid data length received: ");
      Serial.print(input.length());
      Serial.print(" bytes -> ");
      Serial.println(input);
    }
  }
}