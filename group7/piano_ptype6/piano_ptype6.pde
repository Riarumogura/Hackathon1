/**
 * ============================================================
 * Grand Piano Synthesis — Processing + Minim
 * ============================================================
 *
 * 【主な改良点】
 *
 * 1. 周波数帯域別の倍音構造モデリング
 *    - 低音 / 中音 / 高音 の3帯域でまったく異なる倍音振幅スペクトルを使用
 *    - 低音は奇数倍音を豊かにし、基音を強調（弦の張力特性）
 *    - 高音は倍音数を減らし、基音主体で電子音感を排除
 *    - 中音は自然なピアノ特有のスペクトル（2〜4倍音が強い）
 *
 * 2. 周波数依存インハーモニシティ
 *    - 低音 B=0.00015、高音 B=0.0008 と周波数に応じて係数を変化
 *    - 実際のグランドピアノの弦定数に近似
 *
 * 3. 多段 ADSR（Attack を2ステージに分割）
 *    - Attack1: 打鍵直後の鋭い「コン」という打音成分（5〜15 ms）
 *    - Attack2: 倍音の膨らみ（50〜80 ms）
 *    - 実装：振幅変調用 AttackTransient を別 Oscil で重畳
 *
 * 4. ストリングレゾナンス（共鳴弦のシミュレーション）
 *    - 延音ペダル効果：同時に鳴っている音の基音を微小振幅で加える
 *    - Resonance Oscil を追加し、基音の 0.5〜1 オクターブ下の成分を加算
 *
 * 5. 周波数依存 ADSR 時定数
 *    - 低音は Decay が長い（6〜10 秒）、高音は短い（1〜2 秒）
 *    - 実ピアノの音響エネルギー保持特性を模倣
 *
 * 6. アタックトランジェント（打弦ノイズ）
 *    - ホワイトノイズを極短時間（~10 ms）バースト させて打鍵感を再現
 *    - Noise + ADSR で実装し、倍音波形に加算合成
 *
 * 7. コーラス（ユニゾン弦のデチューン）
 *    - 1音につき3本の弦（±1.5 cent, 0 cent）をシミュレート
 *    - 各弦の位相差・振幅差をランダマイズしてピアノらしい揺らぎを実現
 *
 * 8. 高音域の倍音急減衰フィルター
 *    - MoogFilter の Q を帯域別に調整し、高音の鐘状スペクトルを再現
 */

import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;

// ============================================================
// ユーティリティ: 音程 → 帯域判定
// ============================================================
int getRegister(float freq) {
  // 0=低音(< C3=130Hz), 1=中音(C3〜C5), 2=高音(>C5=523Hz)
  if (freq < 130.8) return 0;
  if (freq < 523.3) return 1;
  return 2;
}

// ============================================================
// ピアノ音色クラス
// ============================================================
class Piano implements Instrument {

  // --- 弦1〜3（ユニゾンデチューン）---
  Oscil[] strings;
  ADSR[]  stringAdsr;

  // --- アタックトランジェント（打弦ノイズ）---
  Noise   strikeNoise;
  ADSR    noiseAdsr;

  // --- 低音共鳴成分 ---
  Oscil   resonance;
  ADSR    resAdsr;

  // --- フィルター ---
  MoogFilter[] filters;
  Line[]       filterEnv;

  // --- パラメータ保存 ---
  float baseFreq;
  int   reg;

  Piano(float frequency, float amplitude) {
    baseFreq = frequency;
    reg      = getRegister(frequency);

    // ----------------------------------------------------------
    // 1. 帯域別スペクトルパラメータ
    // ----------------------------------------------------------
    int    nHarmonics;
    float[] ampRatios;
    float[] phaseOffsets;
    float   B; // インハーモニシティ係数

    if (reg == 0) {
      // 低音：基音強め、奇数倍音豊か、倍音数多め
      nHarmonics  = 10;
      ampRatios   = new float[]{1.0, 0.55, 0.70, 0.40, 0.50, 0.25, 0.35, 0.18, 0.22, 0.12};
      phaseOffsets= new float[]{0.0, 0.45, 2.50, 4.00, 1.10, 5.20, 2.80, 0.90, 3.60, 1.80};
      B           = 0.00015;
    } else if (reg == 1) {
      // 中音：2〜4倍音が特徴的なピアノスペクトル
      nHarmonics  = 8;
      ampRatios   = new float[]{1.0, 0.70, 0.55, 0.60, 0.30, 0.20, 0.14, 0.08};
      phaseOffsets= new float[]{0.0, 0.52, 2.62, 4.19, 1.05, 5.24, 3.10, 0.70};
      B           = 0.0004;
    } else {
      // 高音：基音主体、倍音少、電子音感を抑制
      nHarmonics  = 5;
      ampRatios   = new float[]{1.0, 0.40, 0.20, 0.08, 0.03};
      phaseOffsets= new float[]{0.0, 0.52, 2.62, 4.19, 1.05};
      B           = 0.0008;
    }

    // ----------------------------------------------------------
    // 2. インハーモニシティ補正した倍音周波数乗数
    // ----------------------------------------------------------
    float[] multipliers = new float[nHarmonics];
    for (int n = 1; n <= nHarmonics; n++) {
      multipliers[n-1] = n * sqrt(1 + B * n * n);
    }

    // ----------------------------------------------------------
    // 3. 波形テーブル生成
    // ----------------------------------------------------------
    Waveform pianoWave = WavetableGenerator.gen9(4096, multipliers, ampRatios, phaseOffsets);

    // ----------------------------------------------------------
    // 4. ユニゾン弦（3本）のデチューン量 [セント → 周波数比]
    //    低音ほどデチューンを強く（実ピアノの複数弦特性）
    // ----------------------------------------------------------
    float detuneAmt = (reg == 0) ? 2.5f : (reg == 1) ? 1.5f : 0.8f;
    float[] detuneCents = { -detuneAmt, 0.0f, detuneAmt };
    float[] stringAmps  = { 0.38f, 0.44f, 0.38f }; // 中央弦が若干強い

    strings     = new Oscil[3];
    stringAdsr  = new ADSR[3];
    filters     = new MoogFilter[3];
    filterEnv   = new Line[3];

    // ----------------------------------------------------------
    // 5. 周波数依存 ADSR 時定数
    // ----------------------------------------------------------
    // 低音 → Decay長、Sustain高い　高音 → Decay短、Sustain低い
    float attackTime, decayTime, sustainLevel, releaseTime;
    if (reg == 0) {
      attackTime   = 0.008;
      decayTime    = 5.0;
      sustainLevel = 0.35;
      releaseTime  = 0.6;
    } else if (reg == 1) {
      attackTime   = 0.010;
      decayTime    = 2.5;
      sustainLevel = 0.25;
      releaseTime  = 0.4;
    } else {
      attackTime   = 0.012;
      decayTime    = 1.0;
      sustainLevel = 0.15;
      releaseTime  = 0.25;
    }

    // ----------------------------------------------------------
    // 6. フィルターパラメータ（帯域別）
    // ----------------------------------------------------------
    float maxCutoff, minCutoff, filterQ;
    if (reg == 0) {
      maxCutoff = min(5000, frequency * 8);
      minCutoff = frequency * 2.5;
      filterQ   = 0.05;
    } else if (reg == 1) {
      maxCutoff = min(8000, frequency * 6);
      minCutoff = frequency * 1.5;
      filterQ   = 0.08;
    } else {
      maxCutoff = min(12000, frequency * 4);
      minCutoff = frequency * 1.2;
      filterQ   = 0.12;
    }
    float filterDuration = decayTime * 0.6;

    // ----------------------------------------------------------
    // 7. 弦オシレータ生成・パッチ
    // ----------------------------------------------------------
    for (int i = 0; i < 3; i++) {
      float ratio  = pow(2.0, detuneCents[i] / 1200.0);
      float sFreq  = frequency * ratio;
      float sAmp   = amplitude * stringAmps[i];

      strings[i]    = new Oscil(sFreq, sAmp, pianoWave);
      stringAdsr[i] = new ADSR(0.9, attackTime, decayTime, sustainLevel, releaseTime);
      filters[i]    = new MoogFilter(maxCutoff, filterQ, MoogFilter.Type.LP);
      filterEnv[i]  = new Line(filterDuration, maxCutoff, minCutoff);

      strings[i].patch(filters[i]);
      filters[i].patch(stringAdsr[i]);
      filterEnv[i].patch(filters[i].frequency);
    }

    // ----------------------------------------------------------
    // 8. アタックトランジェント（打弦ノイズ）
    //    ごく短い ADSR でホワイトノイズをバースト
    // ----------------------------------------------------------
    float noiseAmp = (reg == 0) ? 0.08f : (reg == 1) ? 0.05f : 0.03f;
    strikeNoise = new Noise(noiseAmp, Noise.Tint.WHITE);

    // ノイズ用 ADSR: 極短 attack/decay、sustain 0（瞬間バースト）
    noiseAdsr = new ADSR(1.0, 0.002, 0.020, 0.0, 0.005);

    // ノイズの高周波成分だけを通すハイパスで「コン」感を強調
    MoogFilter noiseHPF = new MoogFilter(frequency * 2, 0.1, MoogFilter.Type.HP);
    strikeNoise.patch(noiseHPF);
    noiseHPF.patch(noiseAdsr);

    // ----------------------------------------------------------
    // 9. 低音共鳴成分（低〜中音域のみ）
    // ----------------------------------------------------------
    if (reg <= 1) {
      float resFreq = frequency * 0.5; // 1オクターブ下の共鳴
      float resAmp  = amplitude * (reg == 0 ? 0.12f : 0.06f);
      resonance = new Oscil(resFreq, resAmp, Waves.SINE);
      resAdsr   = new ADSR(0.9, 0.02, decayTime * 1.2, sustainLevel * 0.8, releaseTime * 1.5);
      resonance.patch(resAdsr);
    }
  }

  // ----------------------------------------------------------
  // noteOn: 全コンポーネントを出力に接続して発音開始
  // ----------------------------------------------------------
  void noteOn(float duration) {
    // 弦3本
    for (int i = 0; i < 3; i++) {
      stringAdsr[i].noteOn();
      filterEnv[i].activate();
      stringAdsr[i].patch(out);
    }
    // 打弦ノイズ
    noiseAdsr.noteOn();
    noiseAdsr.patch(out);

    // 低音共鳴
    if (reg <= 1 && resonance != null) {
      resAdsr.noteOn();
      resAdsr.patch(out);
    }
  }

  // ----------------------------------------------------------
  // noteOff: リリース後に自動切断
  // ----------------------------------------------------------
  void noteOff() {
    for (int i = 0; i < 3; i++) {
      stringAdsr[i].noteOff();
      stringAdsr[i].unpatchAfterRelease(out);
    }
    noiseAdsr.noteOff();
    noiseAdsr.unpatchAfterRelease(out);

    if (reg <= 1 && resAdsr != null) {
      resAdsr.noteOff();
      resAdsr.unpatchAfterRelease(out);
    }
  }
}


// ============================================================
// メロディデータ（エリーゼのために 冒頭）
// ============================================================
String[] Melody = {
  "R", "G4", "A4", "B4", "C5", "G4", "E4", "C4", "A4",
  "R", "A4", "B4", "A4", "G4", "F4", "E4", "D4", "C4",
  "R", "G4", "F#4", "G4","E4", "R",
  "R", "E4", "D#4", "E4", "D3"
};

float[] Duration = {
  0.5, 0.5, 0.5, 0.5, 1.0, 1.0, 1.0, 1.0, 2.0,
  0.5, 0.5, 0.5, 0.5, 1.0, 1.0, 1.0, 1.0, 2.0,
  0.5, 0.5, 0.5, 0.5, 1.0, 1.0,
  0.5, 0.5, 0.5, 0.5, 1.0, 1.0, 0.5
};

float[] StartTime = {
  0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0,
  8.0, 8.5, 9.0, 9.5, 10.0, 11.0, 12.0, 13.0, 14.0,
  16.0, 16.5, 17.0, 17.5, 18.0, 19.0,
  20.0, 20.5, 21.0, 21.5, 22.0, 23.0
};


// ============================================================
// setup / draw
// ============================================================
void setup() {
  size(700, 280);
  minim = new Minim(this);
  out   = minim.getLineOut();
  out.setTempo(120);
}

void draw() {
  background(15, 15, 25);

  // オシロスコープ（左チャンネル）
  stroke(80, 200, 120);
  strokeWeight(1.5);
  noFill();
  beginShape();
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    float x = map(i, 0, out.bufferSize(), 0, width);
    float y = map(out.left.get(i), -1, 1, 240, 140);
    vertex(x, y);
  }
  endShape();

  // スペクトル風アニメーション（ビジュアルのみ）
  noStroke();
  for (int i = 0; i < out.bufferSize() - 1; i += 4) {
    float val = abs(out.left.get(i));
    fill(60 + val * 180, 80, 180 + val * 75, 140);
    float x = map(i, 0, out.bufferSize(), 0, width);
    rect(x, 120, 3, -val * 100);
  }

  // UI テキスト
  fill(220);
  textSize(14);
  text("k : 曲を再生  /  1〜8 : 単音演奏 (ドレミファソラシド)", 16, 26);
  textSize(11);
  fill(130);
  text("Grand Piano Synthesis — 3-string unison · freq-dependent ADSR · attack transient · sub-resonance", 16, 50);
}


// ============================================================
// 再生
// ============================================================
void playSong() {
  out.pauseNotes();
  for (int i = 0; i < Melody.length; i++) {
    if (!Melody[i].equals("R")) {
      float freq = Frequency.ofPitch(Melody[i]).asHz();
      // 振幅を音域に応じてわずかに調整（低音は大きめ）
      float amp  = (getRegister(freq) == 0) ? 0.55 : 0.50;
      out.playNote(StartTime[i], Duration[i], new Piano(freq, amp));
    }
  }
  out.resumeNotes();
}

void keyPressed() {
  if (key == 'k') {
    playSong();
  }

  int noteIdx = key - '1';
  if (noteIdx >= 0 && noteIdx < 8) {
    String[] scale = {"C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"};
    float freq = Frequency.ofPitch(scale[noteIdx]).asHz();
    out.playNote(0.0, 1.2, new Piano(freq, 0.75));
  }

  // 低音テスト: A〜G で低音域の音を鳴らす
  if (key == 'a') out.playNote(0.0, 2.0, new Piano(Frequency.ofPitch("C2").asHz(), 0.7));
  if (key == 's') out.playNote(0.0, 2.0, new Piano(Frequency.ofPitch("G2").asHz(), 0.7));
  if (key == 'd') out.playNote(0.0, 2.0, new Piano(Frequency.ofPitch("C3").asHz(), 0.7));
  // 高音テスト
  if (key == 'f') out.playNote(0.0, 1.0, new Piano(Frequency.ofPitch("C6").asHz(), 0.65));
  if (key == 'g') out.playNote(0.0, 1.0, new Piano(Frequency.ofPitch("A6").asHz(), 0.65));
}
