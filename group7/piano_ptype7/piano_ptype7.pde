import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;

// 空間の響き（リバーブ/ディレイ）を管理するグローバルバス
Summer masterBus;
Delay bodyResonance;

// ピアノ用の波形データを保持するグローバル変数（都度生成を防ぎ軽量化）
Waveform pianoWave;
Waveform hammerWave;

// -------------------------------------------------------------
// 1. 全楽器共通のベースクラス
// 今後新しい楽器を追加する際は、このクラスを継承（extends）して作成します
// -------------------------------------------------------------
abstract class BaseInstrument implements Instrument {
  // Minimの仕様に合わせ、発音開始と終了のメソッドを強制します
  abstract public void noteOn(float duration);
  abstract public void noteOff();
}

// -------------------------------------------------------------
// 2. ピアノ音色のクラス（BaseInstrumentを継承）
// -------------------------------------------------------------
class Piano extends BaseInstrument {
  
  // --- 弦の響き（トーン）成分 ---
  Oscil wave;
  ADSR adsr;
  MoogFilter filter;
  Line filterEnv;

  // --- ハンマーの打弦（アタック）成分 ---
  Oscil hammerStrike;
  ADSR hammerAdsr;

  // --- 音の合成用ミキサー ---
  Summer voiceMixer;

  Piano(float frequency, float amplitude) {
    voiceMixer = new Summer();

    // ==========================================
    // A. 弦の持続音の生成と制御
    // ==========================================
    wave = new Oscil(frequency, 1.0f, pianoWave); 
    
    // アタック振幅を amplitude * 0.6f に調整（音量飽和の防止）
    adsr = new ADSR(amplitude * 0.6f, 0.006, 0.8, 0.2, 0.35);

    // 高音域の動的コントロール（打鍵時に高域を開放し、徐々に閉じる）
    float velocityFactor = map(amplitude, 0.0f, 1.0f, 3.0f, 7.0f);
    float maxCutoff = min(14000, frequency * velocityFactor);
    float minCutoff = frequency * 1.5;
    
    // 0.4秒かけて高音のきらめきをなだらかに減衰させる
    filterEnv = new Line(0.4, maxCutoff, minCutoff);
    filter = new MoogFilter(maxCutoff, 0.02f, MoogFilter.Type.LP); 
    
    // 弦成分のルーティング
    wave.patch(filter);
    filter.patch(voiceMixer); 
    filterEnv.patch(filter.frequency);

    // ==========================================
    // B. ハンマー打撃音の生成と制御
    // ==========================================
    float hammerFreq = frequency * 2.2;
    hammerStrike = new Oscil(hammerFreq, 1.0f, hammerWave);
    
    // アタック振幅を amplitude * 0.4f に調整（15msで消滅する急峻なエンベロープ）
    hammerAdsr = new ADSR(amplitude * 0.4f, 0.001, 0.015, 0.0, 0.01);
    
    // ハンマー成分のルーティング
    hammerStrike.patch(hammerAdsr);
    hammerAdsr.patch(voiceMixer);

    // ==========================================
    // C. 最終出力への接続
    // ==========================================
    voiceMixer.patch(adsr);
  }

  // 発音時の処理
  public void noteOn(float duration) {
    adsr.noteOn();
    hammerAdsr.noteOn();
    filterEnv.activate();
    adsr.patch(masterBus); // マスターバス（空間エフェクト）へ送る
  }

  // 発音終了時の処理
  public void noteOff() {
    adsr.noteOff();
    hammerAdsr.noteOff();
    adsr.unpatchAfterRelease(masterBus); // 余韻が終わったら安全に切断
  }
}
  
// -------------------------------------------------------------
// 3. 楽曲データ
// -------------------------------------------------------------
int[] Melody = {
  0, 67, 69, 71, 72, 67, 64, 60, 69, 0, 69, 71, 69, 67, 65, 64, 62, 60,
  0, 67, 66, 67, 64, 0, 0, 64, 63, 64, 50
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
  out.setTempo(120);

  // 波形テーブルの初期化（純粋な整数倍音を使用）
  initWavetables();

  // マスターバスと空間共鳴（ディレイ）の設定
  masterBus = new Summer();
  bodyResonance = new Delay(0.035f, 0.18f, true, true);
  
  masterBus.patch(out);                    
  masterBus.patch(bodyResonance).patch(out); 
}

// 楽器用の波形を生成するヘルパー関数
void initWavetables() {
  // 弦の持続音用波形（整数倍音列）
  float[] multipliers = { 1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f };
  float[] amplitudes =  { 1.0f, 0.85f, 0.70f, 0.50f, 0.60f, 0.35f, 0.15f, 0.08f };
  float[] phases =      { 0.0f, 0.30f, 1.50f, 3.00f, 0.80f, 4.00f, 0.00f, 0.00f };
  pianoWave = WavetableGenerator.gen9(4096, multipliers, amplitudes, phases);
  
  // ハンマー打撃音用波形
  float[] hammerMultipliers = { 1.0f, 2.0f, 4.0f };
  float[] hammerAmps =        { 1.0f, 0.6f, 0.3f };
  float[] hammerPhases =      { 0.0f, 0.0f, 0.0f };
  hammerWave = WavetableGenerator.gen9(4096, hammerMultipliers, hammerAmps, hammerPhases);
}

void draw() {
  background(0);
  stroke(255);
  // オシロスコープの描画
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i, 50 - out.left.get(i)*50, i+1, 50 - out.left.get(i+1)*50);
    line(i, 150 - out.right.get(i)*50, i+1, 150 - out.right.get(i+1)*50);
  }
  fill(255);
  textSize(16);
  text("Press 'k' to play the song", 20, 35);
}

// 楽曲再生処理
void playSong() {
  out.pauseNotes();
  for (int i = 0; i < Melody.length; i++) {
    // 0（休符）でない場合のみ周波数を計算して発音
    if (Melody[i] != 0) {
      // MIDIノート番号からHz（周波数）へ一発変換
      float freq = Frequency.ofMidiNote(Melody[i]).asHz();
      out.playNote(StartTime[i], Duration[i], new Piano(freq, 0.55)); 
    }
  }
  out.resumeNotes();
}

void keyPressed() {
  if (key == 'k') {
    playSong();
  }
  
  // 1-8キーによるマニュアル演奏
  int noteIdx = key - '1';
  if (noteIdx >= 0 && noteIdx < 8) {
    int[] scale = {60, 62, 64, 65, 67, 69, 71, 72};
    float freq = Frequency.ofMidiNote(scale[noteIdx]).asHz();
    out.playNote(0.0, 0.85, new Piano(freq, 0.65));
  }
}
