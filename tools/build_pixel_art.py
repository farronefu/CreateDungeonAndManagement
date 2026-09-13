"""Deterministic pixel atlas renderer; edits the project's code-native artwork.

No source-game image data is used. Background surface-v2.png is generated
separately and is never changed by this script.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import random

OUT = Path(__file__).resolve().parents[1] / 'assets'
S = 20
atlas = Image.new('RGBA', (S * 4, S * 5))
for tier in range(5):
    for variant in range(4):
        r = random.Random(tier * 701 + variant * 31)
        im = Image.new('RGBA', (S, S), '#201d1c' if tier else '#242529')
        d = ImageDraw.Draw(im)
        if tier:
            # Recessed seam, raised face, stepped bevel, fractured sandstone.
            d.rectangle((1, 1, 18, 18), fill='#4a3d32')
            d.rectangle((2, 2, 17, 16), fill=['', '#807158', '#82745a', '#85775c', '#746a68'][tier])
            d.line((2, 2, 17, 2), fill='#b7a17a')
            d.line((2, 3, 2, 16), fill='#9c8765')
            d.line((3, 16, 17, 16), fill='#62513f')
            d.line((18, 3, 18, 18), fill='#332b25')
            d.line((2, 18, 18, 18), fill='#171c1e')
            for _ in range(18):
                x, y = r.randrange(3, 17), r.randrange(3, 16)
                d.line((x, y, min(x + r.randrange(1, 3), 16), y), fill=r.choice(['#74684f', '#938264', '#887958']))
            if variant == 1:
                d.line([(14, 3), (12, 7), (13, 10), (10, 14)], fill='#594c3e')
                d.point((13, 7), fill='#ac9670')
            if variant == 3:
                d.line([(3, 9), (6, 11), (9, 10)], fill='#574c3d')
            if tier in (2, 3):
                for _ in range(7 if tier == 2 else 14):
                    x, y = r.randrange(3, 17), r.randrange(3, 15)
                    d.rectangle((x, y, x + 1, y + 1), fill=r.choice(['#485b36', '#647c3b', '#8eab48', '#b1c665']))
                if tier == 3:
                    for x, y in [(5, 5), (13, 9), (8, 13)]:
                        d.point((x, y), fill='#e8dc83')
            if tier == 4:
                for x, y in [(7, 5), (13, 11)]:
                    d.polygon([(x, y-2), (x+2, y), (x, y+4), (x-2, y)], fill='#b4a2cb')
                    d.line((x, y-2, x, y+2), fill='#eee6f2')
        else:
            for _ in range(30):
                x, y = r.randrange(S), r.randrange(S)
                d.point((x, y), fill=r.choice(['#303033', '#393735', '#1c2025', '#41403a']))
            if variant in (0, 2):
                d.line((3, 15, 6, 15), fill='#49463c')
                d.point((5, 14), fill='#605943')
        atlas.paste(im, (variant*S, tier*S))
atlas.save(OUT / 'terrain-v2.png')

sprites = Image.new('RGBA', (7*S, 4*S))
for kind in range(7):
    for frame in range(4):
        im = Image.new('RGBA', (S, S)); d = ImageDraw.Draw(im)
        bob = [0, 1, 0, 0][frame]
        # Each species has a readable silhouette at its actual pixel size.
        if kind == 0:  # Lantern moss: rounded body and glowing seedling crown.
            d.ellipse((3, 17, 17, 19), fill='#07191499')
            d.polygon([(4,16-bob),(5,10-bob),(8,8-bob),(12,8-bob),(16,13-bob),(17,17-bob),(12,18-bob),(6,18-bob)], fill='#20472f')
            d.ellipse((5, 9-bob, 15, 17-bob), fill='#60ad59')
            d.ellipse((6, 10-bob, 13, 15-bob), fill='#83ce6b')
            d.line((7, 11-bob, 10, 10-bob), fill='#c3ec8a')
            d.rectangle((7, 14-bob, 8, 15-bob), fill='#193630')
            d.rectangle((12, 14-bob, 13, 15-bob), fill='#193630')
            d.line((10, 9-bob, 10, 5-bob), fill='#375e30')
            d.polygon([(10,7-bob),(5,5-bob),(5,3-bob),(8,3-bob),(11,6-bob)], fill='#9bce62')
            d.polygon([(10,6-bob),(12,2-bob),(15,2-bob),(14,5-bob)], fill='#d1e784')
            d.point((12,2-bob), fill='#f8edb5')
        elif kind == 1:  # Amber beetle, segmented shell and six moving legs.
            shift = frame % 2
            for y in (8, 12, 16):
                d.line([(5,y),(2,y-1+shift),(1,y+1)], fill='#a7753b')
                d.line([(14,y),(17,y-1-shift),(18,y+1)], fill='#a7753b')
            d.ellipse((4, 5, 15, 17), fill='#36291f')
            d.ellipse((5, 6, 14, 16), fill='#b27c35')
            d.ellipse((6, 6, 12, 13), fill='#e0ad50')
            d.line((10,6,10,16),fill='#805429')
            d.line((6,9,14,9),fill='#a66b2e')
            d.line((6,12,14,12),fill='#a66b2e')
            d.line((7,7,8,7),fill='#ffe19a')
            d.rectangle((6, 2, 13, 5), fill='#6a4b2c')
            d.point((7,3),fill='#fff1c3');d.point((12,3),fill='#fff1c3')
            d.line((6,2,4,0),fill='#c5a565');d.line((13,2,15,0),fill='#c5a565')
        elif kind == 2:  # Stonehorn, stocky quadruped with antler-like stone horns.
            d.ellipse((2,17,18,19),fill='#091a2299')
            d.rectangle((4,13,7,18-frame%2),fill='#4d6468')
            d.rectangle((12,13,15,17+frame%2),fill='#4d6468')
            d.ellipse((3,6+bob,16,16+bob),fill='#324b56')
            d.ellipse((4,6+bob,15,14+bob),fill='#77949a')
            d.polygon([(5,9+bob),(7,6+bob),(12,6+bob),(15,10+bob),(13,13+bob),(7,13+bob)], fill='#a3b8ad')
            d.polygon([(5,8+bob),(2,3+bob),(3,0+bob),(5,5+bob),(8,6+bob)],fill='#d6d5b4')
            d.polygon([(13,6+bob),(16,1+bob),(17,4+bob),(15,9+bob)],fill='#d6d5b4')
            d.rectangle((6,10+bob,7,11+bob),fill='#192e37')
            d.rectangle((12,10+bob,13,11+bob),fill='#192e37')
            d.line((8,14+bob,12,14+bob),fill='#405962')
            d.point((8,7+bob),fill='#e0e3c6')
        elif kind == 3:  # Brown axe warrior, helmet, exposed face, large axe.
            d.ellipse((3,17,18,19),fill='#15131199')
            d.rectangle((5,14,8,18-frame%2),fill='#483329')
            d.rectangle((10,14,13,17+frame%2),fill='#483329')
            d.polygon([(4,9+bob),(12,8+bob),(14,14+bob),(4,15+bob)],fill='#6a4028')
            d.rectangle((5,9+bob,12,13+bob),fill='#a8733b')
            d.line((5,10+bob,11,10+bob),fill='#d39c54')
            d.rectangle((6,4+bob,12,8+bob),fill='#d0a274')
            d.rectangle((6,2+bob,12,4+bob),fill='#665e53')
            d.line((5,4+bob,13,4+bob),fill='#c1b59a')
            d.point((10,6+bob),fill='#302722')
            d.line((16,7,16,17),fill='#9a6e39')
            d.polygon([(15,4),(18,3),(19,4),(19,8),(17,9),(15,7)],fill='#b9c4be')
            d.line((19,4,19,8),fill='#f1eed2')
            d.rectangle((13,10+bob,15,11+bob),fill='#d0a274')
        elif kind == 4:  # Violet mage: pointed hood, long robe, luminous staff.
            d.ellipse((3,17,17,19),fill='#11132499')
            d.polygon([(9,0+bob),(14,7+bob),(4,7+bob)],fill='#746796')
            d.line((9,1+bob,12,5+bob),fill='#b9a6cb')
            d.rectangle((6,7+bob,12,9+bob),fill='#cbb4a1')
            d.point((10,8+bob),fill='#322e43')
            d.polygon([(6,10+bob),(12,10+bob),(15,18),(3,18)],fill='#594d7d')
            d.polygon([(8,10+bob),(10,10+bob),(12,17),(7,17)],fill='#a58bac')
            d.line((9,11+bob,10,16),fill='#e1ccab')
            d.line((17,7,17,18),fill='#997759')
            d.polygon([(17,3),(19,6),(17,9),(15,6)],fill='#83c5c4')
            d.point((17,5),fill='#e7ffff')
        elif kind == 5:  # The garden keeper has a crown and a burgundy cloak.
            d.ellipse((3,17,17,19),fill='#1d132899')
            d.polygon([(5,9+bob),(14,9+bob),(17,18),(3,18)],fill='#562f4f')
            d.polygon([(7,9+bob),(12,9+bob),(14,17),(6,17)],fill='#9d546e')
            d.line((9,11+bob,9,17),fill='#d19c80')
            d.ellipse((5,3+bob,14,11+bob),fill='#b7b39a')
            d.rectangle((7,7+bob,8,8+bob),fill='#312734')
            d.rectangle((11,7+bob,12,8+bob),fill='#312734')
            d.polygon([(5,1),(7,3),(9,0),(11,3),(14,1),(13,5),(6,5)],fill='#d8b86c')
            d.line((7,4,12,4),fill='#ffe1a0')
            d.point((9,2),fill='#b94b61')
        else:
            d.ellipse((5,17,15,19),fill='#1d201c99')
            d.ellipse((6,6,14,17),fill='#705c3f')
            d.ellipse((7,6,13,15),fill='#d3c699')
            d.line((8,8,9,7),fill='#fff0c0')
            d.line([(8,12),(10,11),(11,13)],fill='#a29371')
        sprites.paste(im,(kind*S,frame*S))
sprites.save(OUT / 'actors-v2.png')
print('Rendered native pixel atlases: terrain-v2.png, actors-v2.png')
