// ============================================================
// SlaveProcessing_mokkin.pde - 木琴用（PC2）
// Slave ArduinoからSerial受信 → 木琴音色で再生（Minim使用）
// ============================================================

import ddf.minim.*;
import ddf.minim.ugens.*;
import processing.serial.*;

Minim minim;
AudioOutput out;
Serial slavePort;

// ------------------------------------------------------------
// 木琴（マリンバ）音色クラス
// 正弦波ベース + ADSR 2段制御（短いDecay・低いSustain）
// ------------------------------------------------------------
class Marimba implements Instrument {
  Oscil    wave;
  ADSR     adsr;
  Line     attackEnv;
  Line     decayEnv;

  Marimba(float frequency, float amplitude) {
    // 正弦波ベース（木琴らしい純音に近い音色）
    wave = new Oscil(frequency, amplitude, Waves.SINE);

    // ADSR: 極短いAttack・短いDecay・低いSustain → 打楽器らしい立ち上がり
    // maxAmp, attack(s), decay(s), sustain, release(s)
    adsr = new ADSR(amplitude, 0.005, 0.15, 0.05, 0.1);

    wave.patch(adsr);
  }

  void noteOn(float duration) {
    adsr.noteOn();
    adsr.patch(out);
  }

  void noteOff() {
    adsr.noteOff();
    adsr.unpatchAfterRelease(out);
  }
}

// ------------------------------------------------------------
void setup() {
  size(400, 200);
  minim = new Minim(this);
  out   = minim.getLineOut();

  printArray(Serial.list());
  // ★ ポート番号を環境に合わせて変更
  slavePort = new Serial(this, Serial.list()[0], 9600);
  slavePort.bufferUntil('\n');

  println("SlaveProcessing（木琴）起動");
}

void draw() {
  background(0);
  stroke(255);
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 50  - out.left.get(i)  * 50, i+1, 50  - out.left.get(i+1)  * 50);
    line(i, 150 - out.right.get(i) * 50, i+1, 150 - out.right.get(i+1) * 50);
  }
  fill(255);
  textSize(14);
  text("木琴受信待機中...", 20, 185);
}

// ------------------------------------------------------------
// Slave ArduinoからSerial受信
// フォーマット："pitch,duration\n"（pitchはMIDIノート番号）
// ※ オクターブシフトはSlave.ino側で適用済み
// ------------------------------------------------------------
void serialEvent(Serial p) {
  String line = trim(p.readStringUntil('\n'));
  if (line == null) return;

  if (line.equals("START") || line.equals("END") ||
      line.equals("Slave(Mokkin) ready")) {
    println("[Slave] " + line);
    return;
  }

  String[] parts = split(line, ',');
  if (parts.length < 2) return;

  int   midiNote = int(parts[0]);
  float durSec   = int(parts[1]) / 1000.0;

  // MIDIノート番号 → 周波数
  float freq = 440.0 * pow(2.0, (midiNote - 69) / 12.0);

  // 木琴音色で再生（非同期）
  out.playNote(0.0, durSec, new Marimba(freq, 0.7));

  println("再生 midi:" + midiNote + " freq:" + nf(freq, 0, 1) + "Hz dur:" + durSec + "s");
}

void stop() {
  minim.stop();
  super.stop();
}
