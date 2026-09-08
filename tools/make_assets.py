from PIL import Image, ImageDraw
from pathlib import Path
import random, math, wave, struct, urllib.request
p=Path(__file__).resolve().parents[1]/'assets'; p.mkdir(parents=True,exist_ok=True)
# Original hand-pixelled silhouettes. No source-game art is used.
patterns={
'sprout':[
'........g.......','.......gg..g....','.....gggg.gg....','......GGggg.....','.......GG.......','....ggGGggg.....','...gGGGGGGGg....','..gGGHHGGGGGg...','..gGHGGGGGGGg...','..gGGGkGGkGGg...','...gGGGGGGGg....','....ggGGGgg.....','.....g...g......','................','................','................'],
'beetle':[
'................','...o......o.....','....o....o......','....oooooo......','...oYYooYYo.....','..ooYYooYYoo....','.o.oYYooYYo.o...','...oYYooYYo.....','.o.oYYooYYo.o...','...ooooooo......','....okooko......','....oooooo......','...o......o.....','................','................','................'],
'warden':[
'....t......t....','....tt....tt....','....tTTTTTTt....','...tTTTTTTTTt...','...tTHHTTHHTt...','...tTkTTTTkTt...','....tTTTTTTt....','.....tTTTTt.....','...ttTTTTTTtt...','..tTTTTTTTTTTt..','..tTTTtTTtTTTt..','...tttTTTTttt...','.....tTttTt.....','....ttt..ttt....','................','................'],
'knight':[
'......ssss......','.....sSSSSs.....','.....sHHSSs.....','.....sSSSSs.....','.....skkkks.....','......ssss......','...ssssSSsss....','..sSSsSSSSsSs...','..sSSsSSSSsSs...','..sSSsSSSSs.s...','...ss.ssss..s...','......sSSs..H...','.....ss..ss.....','.....ss..ss.....','................','................'],
'healer':[
'.......p........','......pPp.......','.....pPPPp......','....pPPHPPp.....','...pPPPHPPPp....','.....skkss......','.....sSSSs......','....pPPPPPp..Y..','...pPPPHPPPp.Y..','...pPPPHPPPp.o..','....pPPHPPp..o..','....pPPHPPp..o..','...pPPPHPPPp.o..','.....ss.ss......','................','................'],
'heart':[
'....Y..Y..Y.....','....YYYYYYY.....','.....YYYYY......','....pPPPPPp.....','...pPHHHHPPp....','...pPHPPPPPp....','...pPkPPkPPp....','....pPPPPPp.....','...ppPPPPPpp....','..pPPPPHPPPPp...','..pPPPHHHPPPp...','..pPPPPHPPPPp...','...ppPPPPPpp....','....ppppppp.....','................','................'],
'egg':[
'................','................','................','.......oo.......','......oYYo......','.....oYHHYo.....','....oYYHYYYo....','....oYYYYYYo....','....oYYYYYYo....','.....oooooo.....','................','................','................','................','................','................'],
}
palette={'g':'#254e49','G':'#69ba81','H':'#e2efb1','k':'#10252b','o':'#65402b','Y':'#eebf63','t':'#294d62','T':'#74a5ac','s':'#3c5062','S':'#c9d7d4','p':'#59486f','P':'#b297c8'}
sheet=Image.new('RGBA',(24*len(patterns),48))
for idx,(name,pat) in enumerate(patterns.items()):
 for frame in range(2):
  im=Image.new('RGBA',(24,24)); d=ImageDraw.Draw(im)
  d.ellipse((5,18,19,21),fill='#07151d99')
  for y,row in enumerate(pat):
   for x,c in enumerate(row):
    if c in palette: d.point((x+4,y+3+(frame if name not in ['egg'] else 0)),fill=palette[c])
  sheet.paste(im,(idx*24,frame*24))
sheet.save(p/'actors.png')
tiles=Image.new('RGBA',(24*5,24)); r=random.Random(212)
for level in range(5):
 im=Image.new('RGBA',(24,24),['#101f28','#34433e','#3a4940','#455140','#394659'][level]); d=ImageDraw.Draw(im)
 if level:
  d.line((0,0,23,0),fill='#596050'); d.line((0,1,0,23),fill='#455247'); d.line((0,23,23,23),fill='#202c2d')
  for j in range(17):
   x,y=r.randrange(2,22),r.randrange(2,22); d.rectangle((x,y,x+1,y+1),fill=r.choice(['#4a5549','#2a3835','#555b48']))
  for j in range([0,1,4,7,5][level]):
   x,y=r.randrange(3,20),r.randrange(3,20); col=['','#6e8760','#92ac6a','#e0be70','#aa9bc4'][level];d.rectangle((x,y,x+1,y+1),fill=col)
 else:
  for j in range(6):
   x,y=r.randrange(24),r.randrange(24); d.point((x,y),fill='#1b3036')
 tiles.paste(im,(level*24,0))
tiles.save(p/'tiles.png')
icon=sheet.crop((5*24,0,6*24,24)).resize((192,192),Image.Resampling.NEAREST);icon.save(p/'icon.png')
for name,freq,duration in [('dig',180,.08),('confirm',550,.13),('alert',270,.3),('win',740,.4)]:
 with wave.open(str(p/(name+'.wav')),'wb') as w:
  w.setparams((1,2,22050,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',int(3500*(1-i/(duration*22050))**2*(math.sin(2*math.pi*(freq+freq*.4*i/(duration*22050))*i/22050)))) for i in range(int(duration*22050))))
url='https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf'
if not (p/'NotoSansJP.otf').exists(): urllib.request.urlretrieve(url,p/'NotoSansJP.otf')
urllib.request.urlretrieve('https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/LICENSE',p/'FONT-LICENSE.txt')
urllib.request.urlretrieve('https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/LICENSE.txt',p/'GODOT-LICENSE.txt')
print('Original pixel assets, synthesized SFX, licensed font created')
