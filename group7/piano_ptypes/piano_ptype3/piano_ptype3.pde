import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;

// 1. ピアノ音色を定義するクラス
class Piano implements Instrument {
  Oscil wave;
  ADSR adsr;
  Waveform pianoWave;

  Piano(float frequency, float amplitude) {
    // gen9 を使用して，倍音ごとに振幅と位相（波のズレ）を設定
    // multipliers: 基音(1)から第6倍音まで
    // amplitudes:  各倍音の強さ
    // phases:      各倍音の位相（0.0〜1.0で指定）。わずかにずらすことで深みを出します
    float[] multipliers = { 1, 2, 3, 4, 5, 6 };
    float[] amplitudes =  { 1.0f, 0.75f, 0.6f, 0.58f, 0.67f, 0.38f };
    float[] phases =      { 0.0f, 0.52f, 2.62f, 4.19f, 1.05f, 5.24f };

    pianoWave = WavetableGenerator.gen9(4096, multipliers, amplitudes, phases);
    
    wave = new Oscil(frequency, amplitude, pianoWave);
    
    // ADSR設定（ピアノらしい音量変化）
    adsr = new ADSR(0.8, 0.01, 0.1, 0.5, 0.2);
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
  
// 2. 主旋律のデータ配列（最新の楽譜）
String[] Melody = {
  "R", "G4", "A4", "B4", "C5", "G4", "E4", "C4", "A4", "R", "A4", "B4", "A4", "G4", "F4", "E4", "D4", "C4",
  "R", "G4", "F#4", "G4","E4", "R", "R", "E4", "D#4", "E4", "C3"
};

float[] Duration = {
  0.5, 0.5, 0.5, 0.5, 1.0, 1.0, 1.0, 1.0, 2.0, 0.5, 0.5, 0.5, 0.5, 1.0, 1.0, 1.0, 1.0, 2.0,
  0.5, 0.5, 0.5, 0.5, 1.0, 1.0, 0.5, 0.5, 0.5, 0.5, 1.0, 1.0, 0.5
};

float[] StartTime = {
  0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 8.5, 9.0, 9.5, 10.0, 11.0, 12.0, 13.0, 14.0, 
  16.0, 16.5, 17.0, 17.5, 18.0, 19.0, 20.0, 20.5, 21.0, 21.5, 22.0, 23.0,
};

void setup() {
  size(512, 200);
  minim = new Minim(this);
  out = minim.getLineOut();
  out.setTempo(120); // テンポ 120BPM 固定
}

void draw() {
  background(0);
  stroke(255);
  // オシロスコープ表示（左右の音の波形）
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 50 - out.left.get(i)*50, i+1, 50 - out.left.get(i+1)*50);
    line(i, 150 - out.right.get(i)*50, i+1, 150 - out.right.get(i+1)*50);
  }
  fill(255);
  textSize(16);
  text("Press 'k' to play the song", 20, 35);
}

// 3. 再生関数（休符 "R" をスキップ）
void playSong() {
  out.pauseNotes();
  for (int i = 0; i < Melody.length; i++) {
    if (!Melody[i].equals("R")) {
      float freq = Frequency.ofPitch(Melody[i]).asHz();
      out.playNote(StartTime[i], Duration[i], new Piano(freq, 0.6));
    }
  }
  out.resumeNotes();
}

void keyPressed() {
  // 'k' キーで曲を再生
  if (key == 'k') {
    playSong();
  }
  
  // 1-8 キーでピアノを自由演奏
  int noteIdx = key - '1';
  if (noteIdx >= 0 && noteIdx < 8) {
    String[] scale = {"C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"};
    float freq = Frequency.ofPitch(scale[noteIdx]).asHz();
    out.playNote(0.0, 0.65, new Piano(freq, 0.8));
  }
}
