import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;

// 1. ピアノ音色を定義するクラス
class PianoInstrument implements Instrument {
  Oscil wave;
  ADSR adsr;
  Waveform pianoWave;

  PianoInstrument(float frequency, float amplitude) {
    // ピアノらしい倍音構成を作成
    pianoWave = WavetableGenerator.gen10(4096, new float[] {1.0f, 0.4f, 0.25f, 0.1f, 0.05f, 0.03f});
    wave = new Oscil(frequency, amplitude, pianoWave);
    
    // ピアノのエンベロープ（音量変化）設定
    adsr = new ADSR(0.8, 0.01, 0.175, 0.2, 0.4);
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

// 2. 「もりのくまさん」のデータ配列（楽譜・長さ・タイミング）
String[] bearMelody = {
  "G4", "C4", "C4", "C4", "C4", "A4", "G4", "E4", "G4", // あるひ
  "G4", "C4", "C4", "C4", "C4", "A4", "G4"              // もりのなか
};

float[] bearDuration = {
  0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.6,
  0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.6
};

float[] bearStartTime = {
  0.0, 0.4, 0.8, 1.2, 1.6, 2.0, 2.4, 2.8, 3.2,
  4.0, 4.4, 4.8, 5.2, 5.6, 6.0, 6.4
};

// 鍵盤演奏用のデータ
String[] scaleNotes = {"C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"};

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

// 曲を再生する関数
void playBearSong() {
  out.pauseNotes(); // 全ての音を登録し終えるまで一時停止
  for (int i = 0; i < bearMelody.length; i++) {
    float freq = Frequency.ofPitch(bearMelody[i]).asHz();
    // ピアノ音色で再生予約
    out.playNote(bearStartTime[i], bearDuration[i], new PianoInstrument(freq, 0.6));
  }
  out.resumeNotes(); // 一斉に再生を開始
}

void keyPressed() {
  // 1-8キーでドレミファソラシドを演奏
  int noteIdx = key - '1';
  if (noteIdx >= 0 && noteIdx < scaleNotes.length) {
    float freq = Frequency.ofPitch(scaleNotes[noteIdx]).asHz();
    out.playNote(0.0, 0.65, new PianoInstrument(freq, 0.8));
  }
  
  // 'k' キーで「もりのくまさん」を自動再生
  if (key == 'k') {
    playBearSong();
  }
}
