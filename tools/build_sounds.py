"""Rebuild the four original sound effects using only Python stdlib."""
from pathlib import Path
import math, wave, struct
p=Path(__file__).resolve().parents[1]/"assets"
for name,freq,duration in [('dig',180,.08),('confirm',550,.13),('alert',270,.3),('win',740,.4)]:
 with wave.open(str(p/(name+'.wav')),'wb') as w:
  w.setparams((1,2,22050,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',int(3500*(1-i/(duration*22050))**2*(math.sin(2*math.pi*(freq+freq*.4*i/(duration*22050))*i/22050)))) for i in range(int(duration*22050))))
