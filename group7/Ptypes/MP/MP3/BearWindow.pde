// ============================================================
// BearWindow.pde — クマアニメーション用の別ウィンドウ
// UI.pde の setup() で起動し、draw() で bearBpm / bearPlaying を更新する。
// ============================================================

class BearWindow extends PApplet {

  // UI.pde 側から毎フレーム書き込まれる
  float   bearBpm     = 120.0;
  boolean bearPlaying = false;

  final float BASE_BPM   = 120.0;
  final float BASE_SPEED = 5.0;

  float   legAngle = 0;
  float[] treeX    = new float[4];
  float[] cloudX   = new float[3];

  void settings() {
    size(800, 400);
  }

  void setup() {
    for (int i = 0; i < 4; i++) treeX[i] = i * 250;
    for (int i = 0; i < 3; i++) cloudX[i] = i * 300 + 50;
  }

  void draw() {
    // 背景
    background(135, 206, 235);
    noStroke();
    fill(34, 139, 34);
    rect(0, 280, width, 120);

    // 位置更新（演奏中のみ）
    if (bearPlaying) {
      float spd = BASE_SPEED * (bearBpm / BASE_BPM);
      for (int i = 0; i < 3; i++) {
        cloudX[i] -= spd * 0.2;
        if (cloudX[i] < -100) cloudX[i] = width + 100;
      }
      for (int i = 0; i < 4; i++) {
        treeX[i] -= spd;
        if (treeX[i] < -100) treeX[i] = width + 100;
      }
      legAngle += spd * 0.05;
    }

    // 描画
    noStroke();
    for (int i = 0; i < 3; i++) drawCloud(cloudX[i], 80 + (i % 2) * 40);
    for (int i = 0; i < 4; i++) drawTree(treeX[i], 280);
    drawBear(width / 2, 250, legAngle);
  }

  void drawBear(float x, float y, float angle) {
    fill(139, 69, 19);
    float swing = sin(angle) * 20;
    ellipse(x-20-swing, y+20, 15, 30);
    ellipse(x+20+swing, y+20, 15, 30);
    ellipse(x, y, 90, 60);
    ellipse(x+40, y-20, 50, 50);
    ellipse(x+30, y-40, 15, 15);
    ellipse(x+50, y-40, 15, 15);
    ellipse(x-20+swing, y+20, 15, 30);
    ellipse(x+20-swing, y+20, 15, 30);
    fill(0);
    ellipse(x+50, y-25, 5, 5);
    ellipse(x+60, y-15, 8, 8);
  }

  void drawTree(float x, float y) {
    fill(139, 69, 19);
    rect(x-10, y-60, 20, 60);
    fill(0, 100, 0);
    ellipse(x, y-80, 80, 80);
  }

  void drawCloud(float x, float y) {
    fill(255);
    ellipse(x,      y,      60, 60);
    ellipse(x + 30, y + 10, 50, 50);
    ellipse(x - 30, y + 10, 50, 50);
  }
}
