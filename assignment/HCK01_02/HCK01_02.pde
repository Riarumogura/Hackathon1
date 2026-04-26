import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim ;
AudioOutput out;
Waveform currentWaveform;

String [] melody = {
  "G4", "G4", "E4", "E4", "F4", "E4", "D4", "C4", // どんぐりころころ
  "G4", "G4", "E4", "E4", "D4", //　どんぶりこ
  "E4", "E4", "G4", "G4", "A4", "A4", "A4", "A4", //おいけにはまって
  "A4", "A4", "E4", "E4", "G4" //さあたいへん
};

float [] duration = {
  0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f,
  0.4f, 0.4f, 0.4f, 0.4f, 0.4f,
  0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f, 0.4f,
  0.4f, 0.4f, 0.4f, 0.4f, 0.4f,
};

float [] startTime = {
  0.0f, 0.5f, 1.0f, 1.5f, 2.0f, 2.5f, 3.0f, 3.5f,
  4.0f, 4.5f, 5.0f, 5.5f, 6.0f,
  8.0f, 8.5f, 9.0f, 9.5f, 10.0f, 10.5f, 11.0f, 11.5f,
  12.0f, 12.5f, 13.0f, 13.5f, 14.0f,
};

class HackInstrument implements Instrument
{
  Oscil wave ;
  Line ampEnv ;
  float maxAmp ;
  
  HackInstrument ( float frequency , float maxAmp , Waveform wf )
  {
    wave = new Oscil ( frequency , 0, wf );
    this . maxAmp = maxAmp ;
    ampEnv = new Line ( );
    ampEnv . patch ( wave . amplitude );
  }
  
  void noteOn( float duration )
  {
    ampEnv.activate(duration, this.maxAmp, 0);
    wave.patch( out );
  }
  
  void noteOff()
  {
    wave.unpatch( out );
  }
}

void setup ()
{
  size (512 , 200);
  minim = new Minim(this);
  out = minim.getLineOut();
  out.setTempo(120);
  currentWaveform = Waves.SINE;
}

void playSong() {
  out.pauseNotes();
  for (int i = 0; i < melody.length; i++) {
    out.playNote(startTime[i], duration[i], new HackInstrument(Frequency.ofPitch(melody[i]).asHz(), 0.5f, currentWaveform));
  }
  out.resumeNotes();
}

void draw()
{
  background(0);
  stroke(255);
  
  for (int i = 0; i < out.bufferSize() - 1; i++)
  {
    line ( i, 50 - out. left .get(i)*50 , i+1, 50 - out. left .get(i +1)*50 );
    line ( i, 150 - out. right .get(i)*50 , i+1, 150 - out. right .get(i +1)*50 );
  }
}

void keyPressed () {
  switch (key)
  {
  case '1':
    currentWaveform =  Waves.SINE;
    break;
  case '2':
    currentWaveform =  Waves.TRIANGLE;
    break;
  case '3':
    currentWaveform =  Waves.SAW;
    break;
  case '4':
    currentWaveform =  Waves.SQUARE;
    break;
  case '5':
    currentWaveform =  WavetableGenerator.gen10(4096, new float[] {1.0f, 0.45f, 0.20f, 0.10f, 0.05f });
    break;
  case 'p' :
    playSong ();
    break ;
  default:
    break;
  }
}
