import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;

// ピアノの倍音波形（キー'5'のロジックを応用）
Waveform pianoWave;

// 1. ピアノ音色を定義するクラス
class PianoInstrument implements Instrument {
  Oscil wave;
  ADSR adsr;

  PianoInstrument(float frequency, float amplitude) { // 解像度, 倍音のバランス
    // {基音, 第2, 第3, 第4, 第5, 第6}
    pianoWave = WavetableGenerator.gen10(4096, new float[] {1.0f, 0.4f, 0.25f, 0.1f, 0.05f, 0.03f});
    
    wave = new Oscil(frequency, amplitude, pianoWave);
    
    // ADSR設定: Attack(s), Decay(s), SustainLevel, Release(s)
    adsr = new ADSR(0.8, 0.01, 0.175, 0.2, 0.4);
    
    wave.patch(adsr);
  }

  void noteOn(float duration) {
    adsr.noteOn();
    adsr.patch(out);
  }

  void noteOff() {
    adsr.noteOff();
    // 音が完全に消えてからアンパッチ（自動で行われるため記述不要な場合が多いが念のため）
    adsr.unpatchAfterRelease(out);
  }
}

// 2. メロディデータ
String[] scaleNotes = {"C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"};
float[] volumes = {1.0, 0.7, 0.8, 0.7, 0.9, 0.7, 0.8, 1.0};

void setup() {
  size(512, 200);
  minim = new Minim(this);
  out = minim.getLineOut();
  out.setTempo(120);
}

void draw() {
  background(0);
  stroke(255);
  // 波形表示
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 50 - out.left.get(i)*50, i+1, 50 - out.left.get(i+1)*50);
    line(i, 150 - out.right.get(i)*50, i+1, 150 - out.right.get(i+1)*50);
  }
}

// 3. キーボード操作
void keyPressed() {
  // 数字キー 1〜8 でドレミファソラシドを演奏
  int noteIdx = key - '1';
  if (noteIdx >= 0 && noteIdx < scaleNotes.length) {
    float freq = Frequency.ofPitch(scaleNotes[noteIdx]).asHz();
    // 即座に音を鳴らす（持続時間は0.5秒に設定）
    out.playNote(0.0, 0.65, new PianoInstrument(freq, volumes[noteIdx]));
   
  }
}
