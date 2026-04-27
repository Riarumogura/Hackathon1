import processing.serial.*;

Serial myPort;

int bSize = 800;
float[] buffer = new float[bSize];

float MIN_AMP = -1.65;
float MAX_AMP = 1.65;

float marginRatio = 0.1;
float displayMin;
float displayMax;

float xzoom = 8.0;
int plt;

void setup() {
  size(800, 400);

  myPort = new Serial(this, "/dev/cu.usbmodem34B7DA6378002", 921600);
  myPort.bufferUntil('\n');

  float RANGE_AMP = MAX_AMP - MIN_AMP;
  displayMin = MIN_AMP - RANGE_AMP * marginRatio;
  displayMax = MAX_AMP + RANGE_AMP * marginRatio;

  for (int i = 0; i < bSize; i++) {
    buffer[i] = 0;
  }
}

void draw() {
  background(0);

  // 横軸拡大
  plt = int(bSize / xzoom);
  plt = max(20, plt);

  // 基準線
  stroke(255, 0, 0);
  strokeWeight(1);

  float yMax = map(MAX_AMP, displayMin, displayMax, height, 0);
  float yMin = map(MIN_AMP, displayMin, displayMax, height, 0);

  line(0, yMax, width, yMax);
  line(0, yMin, width, yMin);

  // 波形
  stroke(0, 255, 0);
  strokeWeight(2);
  noFill();

  beginShape();

  int start = bSize - plt;

  for (int i = 0; i < plt; i++) {
    float x = map(i, 0, plt - 1, 0, width);
    float y = map(buffer[start + i], displayMin, displayMax, height, 0);
    vertex(x, y);
  }

  endShape();
}

void serialEvent(Serial p) {
  String data = p.readStringUntil('\n');

  if (data != null) {
    data = trim(data);

    try {
      float val = float(data); // 文字列を数字に変換
      
      // [0] <--古い---最新--> [max-1]
      for (int i = 0; i < bSize - 1; i++) {
        buffer[i] = buffer[i + 1]; // 1つずつ左にずらす
      }

      buffer[bSize - 1] = val;

    } catch (Exception e) {
    }
  }
}
