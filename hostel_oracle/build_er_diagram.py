"""Create a plain, monochrome ER diagram with no external rendering service."""
from pathlib import Path
import re
import math
import html
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
detail = ROOT / 'er_diagram_detailed.mmd'
if not detail.exists():
    detail.write_text((ROOT / 'er_diagram.mmd').read_text(encoding='utf-8'), encoding='utf-8')
source = detail.read_text(encoding='utf-8')
entities = {}
for name, body in re.findall(r'^    (\w+) \{\n(.*?)^    \}', source, re.M | re.S):
    entities[name] = [line.strip().split() for line in body.strip().splitlines()]
relationships = [line for line in source.splitlines() if '||--o{' in line]
keys = {name: [row for row in fields if len(row) == 3 and row[2] in ('PK', 'FK')]
        for name, fields in entities.items()}

theme = '%%{init: {"theme":"neutral","themeVariables":{"fontFamily":"Arial","primaryColor":"#ffffff","primaryTextColor":"#000000","primaryBorderColor":"#000000","lineColor":"#000000"}}}%%\n'
mmd = theme + 'erDiagram\n' + '\n'.join(relationships) + '\n'
for name, fields in keys.items():
    mmd += '    ' + name + ' {\n'
    mmd += ''.join('        ' + ' '.join(row) + '\n' for row in fields)
    mmd += '    }\n'
(ROOT / 'er_diagram.mmd').write_text(mmd, encoding='utf-8')

W, H, SCALE = 1230, 985, 2
im = Image.new('RGB', (W*SCALE, H*SCALE), 'white')
draw = ImageDraw.Draw(im)
font_path = 'C:/Windows/Fonts/arial.ttf'
fonts = {size: ImageFont.truetype(font_path, size*SCALE) for size in (14, 15, 20)}
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
       '<title>Hostel accommodation ER diagram</title>', '<rect width="100%" height="100%" fill="white"/>']

def line(points, width=1):
    draw.line([(round(x*SCALE), round(y*SCALE)) for x,y in points], fill='black', width=width*SCALE)
    coords = ' '.join(f'{x},{y}' for x,y in points)
    svg.append(f'<polyline points="{coords}" fill="none" stroke="black" stroke-width="{width}"/>')

def text(x,y,words,size=14,center=False):
    font = fonts[size]
    if center:
        length = draw.textlength(words, font=font)/SCALE
        px = x-length/2
    else:
        px = x
    draw.text((round(px*SCALE),round(y*SCALE)), words, fill='black', font=font)
    svg.append(f'<text x="{px}" y="{y+size}" font-family="Arial, sans-serif" font-size="{size}" fill="black">{html.escape(words)}</text>')

def circle(x,y,r):
    draw.ellipse(((x-r)*SCALE,(y-r)*SCALE,(x+r)*SCALE,(y+r)*SCALE),fill='white',outline='black',width=SCALE)
    svg.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="white" stroke="black"/>')

def connection(points):
    line(points)
    x,y=points[0]; nx,ny=points[1]
    length=math.hypot(nx-x,ny-y); ux,uy=(nx-x)/length,(ny-y)/length
    # Parent endpoint: exactly one (two parallel bars).
    for distance in (9,15):
        cx,cy=x+distance*ux,y+distance*uy
        line([(cx-6*uy,cy+6*ux),(cx+6*uy,cy-6*ux)])
    x,y=points[-1]; px,py=points[-2]
    length=math.hypot(x-px,y-py); ux,uy=(x-px)/length,(y-py)/length
    # Child endpoint: optional-many (circle and crow's foot).
    circle(x-25*ux,y-25*uy,4)
    junction=(x-14*ux,y-14*uy)
    line([junction,(x-7*uy,y+7*ux)])
    line([junction,(x+7*uy,y-7*ux)])

positions = {
    'HOSTEL':(40,80), 'ROOM':(350,80), 'BED':(660,80),
    'COMPLAINT':(40,340), 'STUDENT':(350,340), 'ALLOCATION':(660,340), 'FEE_CHARGE':(970,340),
    'MAINTENANCE_EXPENSE':(40,600), 'ATTENDANCE':(350,600), 'VISITOR_VISIT':(660,600), 'PAYMENT':(970,600),
    'DISCIPLINARY_INCIDENT':(660,800),
}
edges = [
    [(260,140),(350,140)], # Hostel -> room
    [(570,140),(660,140)], # Room -> bed
    [(770,200),(770,340)], # Bed -> allocation
    [(570,400),(660,400)], # Student -> allocation
    [(350,400),(260,400)], # Student -> complaint
    [(460,200),(460,265),(150,265),(150,340)], # Room -> complaint
    [(150,460),(150,600)], # Complaint -> expense
    [(880,400),(970,400)], # Allocation -> fee
    [(1080,460),(1080,600)], # Fee -> payment
    [(690,460),(690,530),(460,530),(460,600)], # Allocation -> attendance
    [(800,460),(800,600)], # Allocation -> visit
    [(880,425),(925,425),(925,860),(880,860)], # Allocation -> discipline
]
text(W/2,22,'Hostel Accommodation - ER Diagram',20,True)
for edge in edges:
    connection(edge)
for name,(x,y) in positions.items():
    draw.rectangle((x*SCALE,y*SCALE,(x+220)*SCALE,(y+120)*SCALE),fill='white',outline='black',width=SCALE)
    svg.append(f'<rect x="{x}" y="{y}" width="220" height="120" fill="white" stroke="black"/>')
    line([(x,y+35),(x+220,y+35)])
    text(x+110,y+9,name,15,True)
    for i,row in enumerate(keys[name]):
        text(x+12,y+45+i*23,f'{row[2]}  {row[1]}')
text(40,948,'PK = primary key    FK = foreign key    || = exactly one    circle + crow\'s foot = zero or many',14)
svg.append('</svg>')
(ROOT / 'er_diagram.svg').write_text('\n'.join(svg),encoding='utf-8')
im.save(ROOT / 'er_diagram.png')

md = '# Hostel accommodation ER diagram\n\n'
md += 'Plain black-and-white layout. Boxes show primary and foreign keys; all attributes are listed below.\n\n'
md += '![Hostel accommodation ER diagram](er_diagram.png)\n\n'
md += 'Each relationship is one-to-zero-or-many. Student and bed allocations can repeat over time, but overlapping allocations are prohibited.\n\n'
md += '## Attributes\n\n| Entity | Attributes |\n|---|---|\n'
for name, rows in entities.items():
    labels = [row[1] + (f' ({row[2]})' if len(row)>2 else '') for row in rows]
    md += f'| {name} | '+', '.join(labels)+' |\n'
md += '\nPK = primary key; FK = foreign key; UK = unique key.\n\n'
md += 'Compound unique keys: Room(hostel_id, room_no), Bed(room_id, bed_no), FeeCharge(allocation_id, billing_period), Attendance(allocation_id, attendance_date).\n\n'
md += 'Editable sources: `er_diagram.mmd` (simple) and `er_diagram_detailed.mmd` (all attributes). `er_diagram.svg` is the vector export. Reporting configuration and transaction-lock tables are implementation helpers and are omitted.\n'
(ROOT / 'ER_DIAGRAM.md').write_text(md,encoding='utf-8')
print('Updated simple Mermaid, SVG, PNG, and ER_DIAGRAM.md in', ROOT)
