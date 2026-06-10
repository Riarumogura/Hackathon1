import processing.serial.*;

// ==========================================
// 1. システム制御用の変数定義
// ==========================================
Serial myPort;
boolean isSerialConnected = false;

int bpm = 120;

// 2楽器のみ（ピアノ=0, 木琴=1）
String[] instNames = {"ピアノ", "木琴"};

// 各楽器の演奏順番（0:未設定，1〜2:演奏順）
int[] playOrder = {0, 0};

// オクターブ（国際式：-1〜9）
int octave = 4;

// 演奏順番の入力管理
int[] orderSelection = {-1, -1};
int orderCount = 0;

// 演奏中フラグ
boolean isPlaying = false;

// 楽譜要素数（固定）→ isPlayingの解除カウントに使用
final int SCORE_LENGTH    = 61;   // 木琴の要素数（ピアノと同じ想定）
final int MAX_START_COUNT = 8;    // 2番手のstartCount（2楽器なので8固定）
final int PLAY_LIMIT      = SCORE_LENGTH + MAX_START_COUNT;
int sendCount = 0;

// ==========================================
// 2. UIボタン配置用座標
// ==========================================
int sendX = 610, sendY = 20, sendW = 150, sendH = 32;
int resetX = 610, resetY = 220, resetW = 120, resetH = 40;

int octBtnUpX, octBtnUpY;
int octBtnDownX, octBtnDownY;
int octBtnW = 50, octBtnH = 32;

void setup() {
  size(800, 520);
  String chosenFont = "SansSerif";
  String[] fontList = PFont.list();
  for (String f : fontList) {
    if (f.equals("Meiryo") || f.equals("MS Gothic") ||
        f.equals("Hiragino Kaku Gothic Pro") || f.equals("Yu Gothic")) {
      chosenFont = f;
      break;
    }
  }
  PFont font = createFont(chosenFont, 16, true);
  textFont(font);

  octBtnUpX   = 440;
  octBtnUpY   = 370;
  octBtnDownX = 510;
  octBtnDownY = 370;

  // シリアル通信の初期設定
  // ★ 使用するポート番号を合わせて有効化する
  
  try {
    String portName = Serial.list()[3];
    myPort = new Serial(this, portName, 9600);
    myPort.bufferUntil('\n');
    isSerialConnected = true;
  } catch (Exception e) {
    println("シリアルポートが見つかりません．シミュレーションモードで起動します．");
  }
  

  resetOrder();
}

void draw() {
  background(245);

  // ----------------------------------------
  // A. タイトル ＆ 送信ボタン
  // ----------------------------------------
  fill(40);
  textSize(22);
  text("ハッカソン1 グループ7 演奏制御システム", 40, 46);

  boolean isSendHovered = isHover(sendX, sendY, sendW, sendH);
  fill(isSendHovered ? color(0, 153, 76) : color(0, 204, 102));
  stroke(isSendHovered ? color(0, 102, 51) : color(0, 153, 76));
  strokeWeight(isSendHovered ? 2 : 1);
  rect(sendX, sendY, sendW, sendH, 6);
  noStroke();
  fill(255); textSize(14);
  text("設定確定・送信", sendX + 26, sendY + 21);

  // ----------------------------------------
  // B. BPM設定エリア（演奏中も変更可能）
  // ----------------------------------------
  stroke(200); fill(255);
  rect(40, 75, 720, 80, 8);
  noStroke();

  fill(40); textSize(20);
  text("現在の設定BPM: " + bpm, 60, 110);
  fill(120); textSize(13);
  text("【操作方法】[↑] キーで +10 / [↓] キーで -10（範囲：30〜180）※演奏中も可変", 60, 140);

  // ----------------------------------------
  // C. 演奏順番設定エリア（演奏中はロック）
  // ----------------------------------------
  stroke(200);
  fill(isPlaying ? color(240) : color(255));
  rect(40, 170, 720, 150, 8);
  noStroke();

  fill(isPlaying ? color(140) : color(40)); textSize(16);
  text("【演奏順番の設定】" + (isPlaying ? "（演奏中：変更不可）" : ""), 60, 200);
  fill(80); textSize(14);
  text("楽器番号 ―――  1: ピアノ  |  2: 木琴", 60, 225);

  if (isPlaying) {
    fill(200, 100, 100);
    text("★ 現在演奏中．演奏が終了するまで順番変更はできません．", 60, 248);
  } else {
    fill(0, 102, 204);
    text("★ キーボードの [1] [2] キーを演奏したい順番に押してください．", 60, 248);
  }

  fill(50); textSize(14);
  text("現在の演奏ルート：", 60, 290);
  for (int i = 0; i < 2; i++) {
    int idx = orderSelection[i];
    String name = (idx == -1) ? "未選択" : instNames[idx];
    fill(idx == -1 ? color(160) : (isPlaying ? color(100, 140, 180) : color(0, 102, 204)));
    text("[" + (i + 1) + "番手: " + name + "]", 200 + i * 180, 290);
    if (i < 1) { fill(180); text("→", 340, 290); }
  }

  // リセットボタン
  if (isPlaying) {
    fill(230); stroke(200);
    rect(resetX, resetY, resetW, resetH, 6); noStroke();
    fill(160); textSize(14);
    text("ロック中", resetX + 32, resetY + 25);
  } else {
    boolean isResetHovered = isHover(resetX, resetY, resetW, resetH);
    fill(isResetHovered ? color(255, 210, 210) : color(255, 235, 235));
    stroke(isResetHovered ? color(204, 0, 0) : color(255, 150, 150));
    rect(resetX, resetY, resetW, resetH, 6); noStroke();
    fill(204, 0, 0); textSize(14);
    text("順番リセット", resetX + 18, resetY + 25);
  }

  // ----------------------------------------
  // D. 共通オクターブ設定エリア（演奏中はロック）
  // ----------------------------------------
  stroke(180);
  fill(isPlaying ? color(240) : color(255));
  rect(40, 340, 720, 80, 8);
  noStroke();

  fill(isPlaying ? color(140) : color(40)); textSize(16);
  text("【共通オクターブ設定】" + (isPlaying ? "（演奏中：変更不可）" : ""), 60, 368);

  fill(50); textSize(14);
  String octLabel = (octave == -1) ? "-1（最低域）" : String.valueOf(octave);
  text("現在のオクターブ: " + octLabel + " （国際式 -1〜9）", 60, 395);

  // ▲ボタン
  if (isPlaying) {
    fill(235); stroke(220); rect(octBtnUpX, octBtnUpY, octBtnW, octBtnH, 4); noStroke();
    fill(170); textSize(14); text("▲ +1", octBtnUpX + 7, octBtnUpY + 22);
  } else {
    boolean isUpHover = isHover(octBtnUpX, octBtnUpY, octBtnW, octBtnH);
    fill(isUpHover ? color(215, 235, 255) : color(245));
    stroke(isUpHover ? color(0, 102, 204) : color(210));
    rect(octBtnUpX, octBtnUpY, octBtnW, octBtnH, 4); noStroke();
    fill(40); textSize(14); text("▲ +1", octBtnUpX + 7, octBtnUpY + 22);
  }

  // ▼ボタン
  if (isPlaying) {
    fill(235); stroke(220); rect(octBtnDownX, octBtnDownY, octBtnW, octBtnH, 4); noStroke();
    fill(170); textSize(14); text("▼ -1", octBtnDownX + 7, octBtnDownY + 22);
  } else {
    boolean isDownHover = isHover(octBtnDownX, octBtnDownY, octBtnW, octBtnH);
    fill(isDownHover ? color(215, 235, 255) : color(245));
    stroke(isDownHover ? color(0, 102, 204) : color(210));
    rect(octBtnDownX, octBtnDownY, octBtnW, octBtnH, 4); noStroke();
    fill(40); textSize(14); text("▼ -1", octBtnDownX + 7, octBtnDownY + 22);
  }

  // ----------------------------------------
  // E. 各楽器ステータスボックス（2台分）
  // ----------------------------------------
  for (int i = 0; i < 2; i++) {
    int boxX = 40 + i * 200;
    int boxY = 440;
    int boxW = 180;
    int boxH = 65;

    stroke(200); fill(255);
    rect(boxX, boxY, boxW, boxH, 8);
    noStroke();

    fill(40); textSize(15);
    text(instNames[i] + " (" + (i + 1) + ")", boxX + 15, boxY + 26);

    textSize(13);
    if (playOrder[i] == 0) {
      fill(150);
      text("順番: 未設定", boxX + 15, boxY + 47);
    } else {
      fill(isPlaying ? color(100, 130, 160) : color(0, 102, 204));
      text("順番: " + playOrder[i] + " 番手", boxX + 15, boxY + 47);
    }

    int midiC = (octave + 1) * 12;
    fill(100); textSize(11);
    text("C" + octave + " = MIDI " + midiC, boxX + 15, boxY + 62);
  }

  // ----------------------------------------
  // F. 送信パケットプレビュー ＆ ステータス
  // ----------------------------------------
  fill(60); textSize(13);
  text("送信パケット（8バイト）: " + buildPacket(), 40, 512);

  textAlign(RIGHT);
  if (isPlaying) {
    fill(204, 0, 0);
    text("【ステータス: 演奏中・設定ロック中】", 760, 512);
  } else {
    fill(0, 153, 76);
    text("【ステータス: 待機中・編集可能】", 760, 512);
  }
  textAlign(LEFT);

  // 演奏中：sendCountがPLAY_LIMITに達したらisPlayingをfalseに
  if (isPlaying && sendCount >= PLAY_LIMIT) {
    isPlaying  = false;
    sendCount  = 0;
    println("演奏終了．UIロックを解除します．");
  }
}

// ==========================================
// 3. キーボード入力
// ==========================================
void keyPressed() {
  if (key == CODED) {
    if (keyCode == UP)   bpm = min(180, bpm + 10);
    if (keyCode == DOWN) bpm = max(30,  bpm - 10);
  }

  if (isPlaying) return;

  // 1〜2キーで演奏順を設定
  if (key >= '1' && key <= '2') {
    int instIndex = key - '1';
    if (playOrder[instIndex] == 0 && orderCount < 2) {
      orderSelection[orderCount] = instIndex;
      playOrder[instIndex] = orderCount + 1;
      orderCount++;
    }
  }
}

// ==========================================
// 4. マウスクリック
// ==========================================
void mousePressed() {
  if (isHover(sendX, sendY, sendW, sendH)) {
    sendParametersToMaster();
    if (!isSerialConnected) {
      isPlaying  = true;
      sendCount  = 0;
      println("（シミュレーション）演奏を開始しました．");
    }
  }

  if (!isSerialConnected && key == 's') {
    isPlaying = false;
    sendCount = 0;
    println("（シミュレーション）演奏を停止しました．");
  }

  if (isPlaying) return;

  if (isHover(resetX, resetY, resetW, resetH)) resetOrder();

  if (isHover(octBtnUpX, octBtnUpY, octBtnW, octBtnH)) {
    if (octave < 9) octave++;
  }
  if (isHover(octBtnDownX, octBtnDownY, octBtnW, octBtnH)) {
    if (octave > -1) octave--;
  }
}

// ==========================================
// 5. Masterからの信号受信
// ==========================================
void serialEvent(Serial p) {
  String inString = p.readStringUntil('\n');
  if (inString == null) return;
  inString = trim(inString);

  if (inString.equals("ACK")) {
    // 送信確認：演奏開始フラグを立てる
    isPlaying  = true;
    sendCount  = 0;
    println("【通信確認】Masterが受信しました．演奏を開始します．");
  }
  // 拍ごとのACKでsendCountをインクリメント
  else if (inString.equals("BEAT")) {
    sendCount++;
  }
}

// ==========================================
// 6. ユーティリティ関数
// ==========================================
boolean isHover(int x, int y, int w, int h) {
  return (mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h);
}

void resetOrder() {
  for (int i = 0; i < 2; i++) {
    playOrder[i] = 0;
    orderSelection[i] = -1;
  }
  orderCount = 0;
}

// ==========================================
// 7. 送信パケット生成（桁指定形式：8byte+改行）
// オクターブ1桁 + 演奏順4桁（2楽器は前2桁使用、後2桁=0）+ BPM3桁
// ==========================================
String buildPacket() {
  // オクターブ：-1→'0', 0→'1', ..., 9→'A'
  char octChar = (octave == 9) ? 'A' : (char)('0' + (octave + 1));

  // 演奏順（4桁：ピアノ・木琴・未使用・未使用）
  String order = "";
  for (int i = 0; i < 2; i++) {
    order += str(playOrder[i]);
  }
  order += "00";  // 後2桁は2楽器構成のため0固定

  String bpmStr = nf(bpm, 3);
  return "" + octChar + order + bpmStr;
}

// ==========================================
// 8. Master Arduino送信関数
// ==========================================
void sendParametersToMaster() {
  String packet = buildPacket() + "\n";

  println("【送信パケット】: " + packet.trim());
  println("  ├ オクターブ  : " + octave + " → '" + packet.charAt(0) + "'");
  println("  ├ 演奏順      : " + packet.substring(1, 5));
  println("  └ BPM         : " + bpm + " → '" + packet.substring(5, 8) + "'");

  if (isSerialConnected) {
    myPort.write(packet);
  } else {
    println("（シミュレーションモード）");
  }
}
