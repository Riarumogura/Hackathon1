#define BAUD 921600
#define PIN A0
#define RESOLUTION 10

const float rate = 8; //　サンプリングレート(kHz)
const long INTERVAL_MICROS = 1000000 / (rate * 1000);
unsigned long nextT = 0;

const float Voltage = 3.3; //　電圧: 3.3 V
const float MAX_AMP = Voltage / 2.0; //　最大振幅
const float MIN_AMP = -MAX_AMP; //　最小振幅

void setup() {
  pinMode(PIN, INPUT);
  Serial.begin(BAUD);
  analogReadResolution(RESOLUTION);
  nextT = micros() + INTERVAL_MICROS;
}

void loop() {
  if (micros() >= nextT) {
    int d = analogRead(PIN);
    float AMP = (float) d * 5 / 1023 - MAX_AMP;

    Serial.println(AMP, 3);

    nextT += INTERVAL_MICROS;
  }
}