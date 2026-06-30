// ============================================================
// BearWindow.pde — クマアニメーション用の別ウィンドウ
// BPMでスクロール速度を変え、コイン収集・障害物回避・ランキング表示を行う。
// ============================================================

class BearWindow extends PApplet {

  // UI.pde 側から毎フレーム書き込まれる
  float   bearBpm     = 120.0;
  boolean bearPlaying = false;

  final float BASE_BPM        = 120.0;
  final float BASE_SPEED      = 5.0;
  final float GRAVITY         = 0.9;
  final float JUMP_VELOCITY   = -13.5;
  final int   MAX_JUMPS       = 2;
  final float BEAR_X          = 210.0;
  final float BEAR_GROUND_Y   = 250.0;
  final int   COIN_COUNT       = 7;
  final int   OBSTACLE_COUNT   = 4;
  final int   SCATTER_COUNT    = 36;
  final int   RANKING_SIZE     = 5;

  float legAngle = 0;
  float bearJumpY = 0;
  float bearJumpV = 0;
  int jumpsRemaining = MAX_JUMPS;
  boolean jumpKeyHeld = false;

  int currentRunScore = 0;
  int bestScore = 0;
  int currentRank = -1;
  int collectFlash = 0;
  int hitFlash = 0;
  int finishFlash = 0;
  int collisionCooldown = 0;
  int runSerial = 0;
  boolean runStarted = false;
  boolean runFinished = false;
  boolean lastPlayingState = false;

  float[] treeX = new float[4];
  float[] cloudX = new float[3];

  float[] coinX = new float[COIN_COUNT];
  float[] coinY = new float[COIN_COUNT];
  float[] coinSpin = new float[COIN_COUNT];

  float[] obstacleX = new float[OBSTACLE_COUNT];
  float[] obstacleY = new float[OBSTACLE_COUNT];
  float[] obstacleScale = new float[OBSTACLE_COUNT];

  float[] scatterX = new float[SCATTER_COUNT];
  float[] scatterY = new float[SCATTER_COUNT];
  float[] scatterVX = new float[SCATTER_COUNT];
  float[] scatterVY = new float[SCATTER_COUNT];
  float[] scatterSpin = new float[SCATTER_COUNT];
  int[] scatterLife = new int[SCATTER_COUNT];
  boolean[] scatterActive = new boolean[SCATTER_COUNT];
  int scatterCursor = 0;

  int[] rankingScores = new int[RANKING_SIZE];

  void settings() {
    size(800, 400);
  }

  void setup() {
    textAlign(LEFT, TOP);
    for (int i = 0; i < 4; i++) treeX[i] = i * 250;
    for (int i = 0; i < 3; i++) cloudX[i] = i * 300 + 50;
    resetCoins();
    resetObstacles();
    clearScatter();
  }

  void draw() {
    if (bearPlaying && !lastPlayingState) {
      startRun(bearBpm);
    }

    updateWorld();

    // 背景
    background(135, 206, 235);
    noStroke();
    fill(34, 139, 34);
    rect(0, 280, width, 120);

    // 描画
    noStroke();
    for (int i = 0; i < 3; i++) drawCloud(cloudX[i], 80 + (i % 2) * 40);
    for (int i = 0; i < 4; i++) drawTree(treeX[i], 280);
    for (int i = 0; i < COIN_COUNT; i++) drawCoin(coinX[i], coinY[i], coinSpin[i]);
    for (int i = 0; i < OBSTACLE_COUNT; i++) drawObstacle(i);
    drawScatter();
    drawBear(BEAR_X, BEAR_GROUND_Y + bearJumpY, legAngle);
    drawHud();

    if (runFinished) {
      drawResultPanel();
    } else if (bearPlaying) {
      drawBpmBanner();
    }
  }

  void updateWorld() {
    float speed = getScrollSpeed();
    float obstacleSpeed = speed * 1.08;

    for (int i = 0; i < 3; i++) {
      cloudX[i] -= speed * 0.2;
      if (cloudX[i] < -100) cloudX[i] = width + 100;
    }
    for (int i = 0; i < 4; i++) {
      treeX[i] -= speed;
      if (treeX[i] < -100) treeX[i] = width + random(80, 180);
    }

    updateJump();
    updateCoins(speed);
    updateObstacles(obstacleSpeed);
    updateScatter();

    if (collectFlash > 0) collectFlash--;
    if (hitFlash > 0) hitFlash--;
    if (finishFlash > 0) finishFlash--;
    if (collisionCooldown > 0) collisionCooldown--;

    if (bearPlaying) {
      legAngle += speed * 0.05;
    }

    lastPlayingState = bearPlaying;
  }

  float getScrollSpeed() {
    if (runFinished) {
      return 0;
    }
    float bpmScale = max(0.6, bearBpm / BASE_BPM);
    return bearPlaying ? BASE_SPEED * bpmScale : BASE_SPEED * 0.35;
  }

  void updateCoins(float speed) {
    boolean gameplayActive = runStarted && !runFinished;
    for (int i = 0; i < COIN_COUNT; i++) {
      coinX[i] -= speed;
      coinSpin[i] += speed * 0.06;
      if (coinX[i] < -40) {
        respawnCoin(i, width + random(140, 280));
      }
      if (gameplayActive && isCoinCollected(i)) {
        currentRunScore++;
        bestScore = max(bestScore, currentRunScore);
        collectFlash = 18;
        spawnScatter(coinX[i], coinY[i], 6, true);
        respawnCoin(i, width + random(180, 320));
      }
    }
  }

  void updateObstacles(float speed) {
    boolean gameplayActive = runStarted && !runFinished;
    for (int i = 0; i < OBSTACLE_COUNT; i++) {
      obstacleX[i] -= speed;
      if (obstacleX[i] < -120) {
        respawnObstacle(i, nextObstacleSpawnX(i));
      }
    }

    if (!gameplayActive || collisionCooldown > 0) {
      return;
    }

    for (int i = 0; i < OBSTACLE_COUNT; i++) {
      if (isObstacleHit(i)) {
        applyObstaclePenalty(i);
        collisionCooldown = 18;
        break;
      }
    }
  }

  void applyObstaclePenalty(int i) {
    int penalty = 2;
    currentRunScore = max(0, currentRunScore - penalty);
    hitFlash = 24;
    finishFlash = 0;
    float bearBurstX = BEAR_X + 18;
    float bearBurstY = BEAR_GROUND_Y + bearJumpY - 12;
    spawnScatter(bearBurstX, bearBurstY, 16 + penalty * 4, true);
    respawnObstacle(i, width + random(160, 280));
  }

  void drawBear(float x, float y, float angle) {
    fill(139, 69, 19);
    float swing = sin(angle) * 20;
    ellipse(x - 20 - swing, y + 20, 15, 30);
    ellipse(x + 20 + swing, y + 20, 15, 30);
    ellipse(x, y, 90, 60);
    ellipse(x + 40, y - 20, 50, 50);
    ellipse(x + 30, y - 40, 15, 15);
    ellipse(x + 50, y - 40, 15, 15);
    ellipse(x - 20 + swing, y + 20, 15, 30);
    ellipse(x + 20 - swing, y + 20, 15, 30);
    fill(0);
    ellipse(x + 50, y - 25, 5, 5);
    ellipse(x + 60, y - 15, 8, 8);
  }

  void drawCloud(float x, int y) {
    noStroke();
    fill(255, 255, 255, 235);
    ellipse(x, y + 10, 50, 30);
    ellipse(x + 20, y, 42, 26);
    ellipse(x + 42, y + 12, 54, 32);
    ellipse(x + 18, y + 18, 62, 22);
  }

  void drawTree(float x, float groundY) {
    noStroke();
    fill(120, 72, 28);
    rect(x + 18, groundY - 52, 16, 52);
    fill(34, 139, 34);
    ellipse(x + 26, groundY - 70, 62, 48);
    ellipse(x + 10, groundY - 52, 48, 40);
    ellipse(x + 42, groundY - 52, 48, 40);
  }

  void drawCoin(float x, float y, float spin) {
    pushMatrix();
    translate(x, y);
    float squash = 0.55 + 0.45 * abs(sin(spin));
    scale(squash, 1);
    stroke(170, 120, 0);
    strokeWeight(2);
    fill(255, 214, 0);
    ellipse(0, 0, 28, 28);
    noStroke();
    fill(255, 245, 160, 180);
    ellipse(-4, -5, 8, 8);
    popMatrix();
  }

  void drawObstacle(int i) {
    drawRock(obstacleX[i], obstacleY[i], obstacleScale[i]);
  }

  void drawRock(float x, float y, float s) {
    pushMatrix();
    translate(x, y);
    scale(s);
    fill(120);
    stroke(90);
    strokeWeight(2);
    beginShape();
    vertex(6, 34);
    vertex(0, 18);
    vertex(8, 4);
    vertex(26, 0);
    vertex(38, 8);
    vertex(40, 24);
    vertex(28, 36);
    endShape(CLOSE);
    noStroke();
    fill(155);
    ellipse(16, 14, 11, 8);
    popMatrix();
  }

  void drawScatter() {
    for (int i = 0; i < SCATTER_COUNT; i++) {
      if (!scatterActive[i]) continue;
      float alpha = map(scatterLife[i], 0, 26, 0, 220);
      pushMatrix();
      translate(scatterX[i], scatterY[i]);
      rotate(scatterSpin[i]);
      stroke(170, 120, 0, alpha);
      strokeWeight(1.5);
      fill(255, 214, 0, alpha);
      ellipse(0, 0, 12, 12);
      noStroke();
      fill(255, 245, 160, alpha);
      ellipse(-2, -2, 3, 3);
      popMatrix();
    }
  }

  void drawHud() {
    fill(0, 0, 0, 115);
    rect(14, 12, 190, 66, 10);
    fill(255);
    textSize(15);
    text("COINS  " + currentRunScore, 28, 22);
    text("BPM    " + nf(bearBpm, 0, 0), 28, 42);
    text("BEST   " + bestScore, 28, 60);

    if (collectFlash > 0) {
      fill(255, 240, 120, 220);
      textSize(18);
      text("GET!", 690, 18);
    }

    if (hitFlash > 0) {
      fill(255, 216, 96, 230);
      textSize(16);
      text("COINS!", 690, 42);
    }
  }

  void drawBpmBanner() {
    fill(0, 0, 0, 105);
    rect(560, 12, 216, 30, 8);
    fill(255);
    textSize(14);
    text("BPM " + nf(bearBpm, 0, 0) + "  /  speed x" + nf(getScrollSpeed() / BASE_SPEED, 0, 2), 575, 18);
  }

  void drawResultPanel() {
    fill(0, 0, 0, 165);
    rect(420, 44, 350, 190, 14);
    fill(255);
    textSize(18);
    text("FINISH", 442, 58);
    textSize(14);
    text("RUN SCORE  " + currentRunScore, 442, 88);
    text("BEST SCORE " + bestScore, 442, 108);
    text("RANKING", 442, 136);

    String[] lines = getRankingLines();
    textSize(13);
    for (int i = 0; i < lines.length; i++) {
      fill(i == currentRank ? color(255, 240, 120) : color(255));
      text(lines[i], 458, 156 + i * 16);
    }
  }

  void updateJump() {
    if (bearJumpY < 0 || bearJumpV != 0) {
      bearJumpV += GRAVITY;
      bearJumpY += bearJumpV;
      if (bearJumpY >= 0) {
        bearJumpY = 0;
        bearJumpV = 0;
        jumpsRemaining = MAX_JUMPS;
      }
    }
  }

  boolean isCoinCollected(int i) {
    float bearCenterX = BEAR_X + 18;
    float bearCenterY = BEAR_GROUND_Y + bearJumpY - 8;
    return dist(coinX[i], coinY[i], bearCenterX, bearCenterY) < 34;
  }

  boolean isObstacleHit(int i) {
    float bearLeft = BEAR_X - 34;
    float bearTop = BEAR_GROUND_Y + bearJumpY - 32;
    float bearW = 68;
    float bearH = 46;
    return rectsOverlap(bearLeft, bearTop, bearW, bearH, obstacleX[i], obstacleY[i], obstacleWidth(i), obstacleHeight(i));
  }

  boolean rectsOverlap(float ax, float ay, float aw, float ah, float bx, float by, float bw, float bh) {
    return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
  }

  float obstacleWidth(int i) {
    return 34 * obstacleScale[i];
  }

  float obstacleHeight(int i) {
    return 28 * obstacleScale[i];
  }

  float groundTop() {
    return 280;
  }

  float nextObstacleSpawnX(int i) {
    float bpmScale = constrain((bearBpm - 60.0) / 120.0, 0.0, 1.0);
    float minGap = lerp(270, 150, bpmScale);
    float maxGap = lerp(400, 220, bpmScale);
    return width + random(minGap, maxGap) + i * random(20, 50);
  }

  void respawnCoin(int i, float x) {
    coinX[i] = x;
    coinY[i] = random(150, 230);
    coinSpin[i] = random(TWO_PI);
  }

  void resetCoins() {
    float x = width + 60;
    for (int i = 0; i < COIN_COUNT; i++) {
      coinX[i] = x + i * 130 + random(30, 110);
      coinY[i] = random(150, 230);
      coinSpin[i] = random(TWO_PI);
    }
  }

  void resetObstacles() {
    float x = width + 120;
    for (int i = 0; i < OBSTACLE_COUNT; i++) {
      respawnObstacle(i, x + i * 220 + random(80, 140));
    }
  }

  void respawnObstacle(int i, float x) {
    obstacleScale[i] = random(0.95, 1.25);
    obstacleX[i] = x;
    obstacleY[i] = groundTop() - obstacleHeight(i);
  }

  void clearScatter() {
    for (int i = 0; i < SCATTER_COUNT; i++) {
      scatterActive[i] = false;
      scatterLife[i] = 0;
    }
    scatterCursor = 0;
  }

  void updateScatter() {
    for (int i = 0; i < SCATTER_COUNT; i++) {
      if (!scatterActive[i]) continue;
      scatterX[i] += scatterVX[i];
      scatterY[i] += scatterVY[i];
      scatterVX[i] *= 0.985;
      scatterVY[i] += 0.22;
      scatterSpin[i] += 0.18 + abs(scatterVX[i]) * 0.02;
      scatterLife[i]--;
      if (scatterLife[i] <= 0 || scatterY[i] > height + 40 || scatterX[i] < -40 || scatterX[i] > width + 40) {
        scatterActive[i] = false;
      }
    }
  }

  void spawnScatter(float x, float y, int amount, boolean fromCoin) {
    for (int n = 0; n < amount; n++) {
      int i = scatterCursor;
      scatterCursor = (scatterCursor + 1) % SCATTER_COUNT;
      scatterActive[i] = true;
      scatterX[i] = x + random(-8, 8);
      scatterY[i] = y + random(-8, 8);
      float spread = fromCoin ? random(2.0, 4.8) : random(2.8, 6.4);
      float angle = fromCoin ? random(TWO_PI) : random(-PI, PI);
      scatterVX[i] = cos(angle) * spread;
      scatterVY[i] = sin(angle) * spread - random(1.5, 5.0);
      scatterSpin[i] = random(TWO_PI);
      scatterLife[i] = fromCoin ? 18 : 26;
    }
  }

  void startRun(float bpm) {
    bearBpm = bpm;
    runStarted = true;
    runFinished = false;
    currentRunScore = 0;
    currentRank = -1;
    collectFlash = 0;
    hitFlash = 0;
    finishFlash = 0;
    collisionCooldown = 0;
    legAngle = 0;
    bearJumpY = 0;
    bearJumpV = 0;
    jumpsRemaining = MAX_JUMPS;
    jumpKeyHeld = false;
    resetCoins();
    resetObstacles();
    clearScatter();
    runSerial++;
  }

  void completeRun() {
    if (!runStarted) {
      startRun(bearBpm);
    }
    if (runFinished) {
      return;
    }
    runFinished = true;
    bearPlaying = false;
    finishFlash = 60;
    currentRank = insertRanking(currentRunScore);
  }

  int insertRanking(int score) {
    int rank = -1;
    for (int i = 0; i < RANKING_SIZE; i++) {
      if (score >= rankingScores[i]) {
        rank = i;
        break;
      }
    }

    if (rank == -1) {
      bestScore = max(bestScore, score);
      return -1;
    }

    for (int i = RANKING_SIZE - 1; i > rank; i--) {
      rankingScores[i] = rankingScores[i - 1];
    }
    rankingScores[rank] = score;
    bestScore = max(bestScore, rankingScores[0]);
    return rank;
  }

  String[] getRankingLines() {
    String[] lines = new String[RANKING_SIZE];
    for (int i = 0; i < RANKING_SIZE; i++) {
      if (rankingScores[i] == 0 && i > 0 && rankingScores[i - 1] == 0) {
        lines[i] = (i + 1) + ". --";
      } else {
        lines[i] = (i + 1) + ". " + rankingScores[i];
      }
    }
    return lines;
  }

  boolean hasResult() {
    return runFinished;
  }

  int getCurrentRunScore() {
    return currentRunScore;
  }

  void triggerJump() {
    if (runFinished || jumpsRemaining <= 0) {
      return;
    }
    bearJumpV = JUMP_VELOCITY;
    jumpsRemaining--;
  }

  void keyPressed() {
    if (key == ' ' && !jumpKeyHeld) {
      jumpKeyHeld = true;
      triggerJump();
    }
  }

  void keyReleased() {
    if (key == ' ') {
      jumpKeyHeld = false;
    }
  }
}
