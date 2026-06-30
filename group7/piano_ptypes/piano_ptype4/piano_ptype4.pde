import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;

// 1. ピアノ音色を定義するクラス
class Piano implements Instrument {
  Oscil wave;
  ADSR adsr;
  Waveform pianoWave;
  
  // 高音の減衰をシミュレートするためのフィルター群
  MoogFilter filter;
  Line filterEnv; // フィルターのカットオフ周波数を時間変化させる

  Piano(float frequency, float amplitude) {
    // ---------------------------------------------------------------
    // 特徴3: インハーモニシティ（レイズバック特性）の再現
    // ---------------------------------------------------------------
    float B = 0.003; // インハーモニシティ係数（高音のズレ具合）
    float[] multipliers = new float[6];
    for (int n = 1; n <= 6; n++) {
      // 高次倍音ほど理論値（n）よりわずかに高い周波数にする
      multipliers[n-1] = n * sqrt(1 + B * n * n);
    }

    // 倍音の基本振幅
    float[] amplitudes =  { 1.0f, 0.75f, 0.6f, 0.58f, 0.67f, 0.38f };
    float[] phases =      { 0.0f, 0.52f, 2.62f, 4.19f, 1.05f, 5.24f };

    pianoWave = WavetableGenerator.gen9(4096, multipliers, amplitudes, phases);
    wave = new Oscil(frequency, amplitude, pianoWave);
    
    // 音量のADSR（ピアノらしい減衰。リリースを0.2秒に設定）
    adsr = new ADSR(0.8, 0.01, 0.1, 0.5, 0.2);
    
    // ---------------------------------------------------------------
    // 特徴1 & 2: 動的フィルターによる高音域の先行減衰
    // ---------------------------------------------------------------
    // 基準となるカットオフ周波数（アタック時は高音を多く含ませる）
    float maxCutoff = min(10000, frequency * 5); 
    float minCutoff = frequency * 1.1; // 最終的に基音の少し上まで閉じて余韻にする
    
    // 0.5秒（音の長さ）かけて maxCutoff から minCutoff へ変化するエンベロープ
    filterEnv = new Line(0.5, maxCutoff, minCutoff);
   
    // MoogFilter（ローパスタイプ）の作成
    filter = new MoogFilter(maxCutoff, 0.1f, MoogFilter.Type.LP);

    wave.patch(filter);
    filter.patch(adsr);
    
    // フィルターの周波数にエンベロープを接続
    filterEnv.patch(filter.frequency);
  }

  void noteOn(float duration) {
    adsr.noteOn();
    filterEnv.activate(); // フィルターの変化を開始
    adsr.patch(out);      // 最終段であるadsrを出力に接続
  }

  void noteOff() {
    adsr.noteOff();
    // 音量のリリース（余韻）が完全に終わった後に，自動的にoutから切断する
    adsr.unpatchAfterRelease(out);
  }
}
  
// 2. 主旋律のデータ配列
String[] Melody = {
  "R", "G4", "A4", "B4", "C5", "G4", "E4", "C4", "A4", "R", "A4", "B4", "A4", "G4", "F4", "E4", "D4", "C4",
  "R", "G4", "F#4", "G4","E4", "R", "R", "E4", "D#4", "E4", "D3"
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
