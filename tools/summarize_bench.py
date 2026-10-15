"""Summarize real-device timing; do not infer flight performance."""
import json
import re
import sys
from pathlib import Path

path=Path(sys.argv[1]);data=path.read_bytes()
groups={}
for kind in ['SFTIMING','SFTASK','SFPROFILE','SFFRONT','SFBOTTOM','SFRC']:
    rows=[]
    for match in re.findall(kind.encode()+rb'[^\r\n]*',data):
        row={k.decode():int(v) for k,v in re.findall(rb'(\w+)=(-?\d+)',match)}
        if kind=='SFTIMING':
            duty=re.search(rb'applied=(\d+),(\d+),(\d+),(\d+)',match)
            if duty:row['applied_max']=max(map(int,duty.groups()))
        rows.append(row)
    groups[kind]=rows
summary={'file':str(path),'bytes':len(data),'NACKs':data.count(b'NACK')}
for kind,rows in groups.items():
    summary[kind]={'windows':len(rows),'minimum':{},'maximum':{}}
    keys=set().union(*(r.keys() for r in rows))
    for key in keys:
        values=[r[key] for r in rows if key in r]
        summary[kind]['minimum'][key]=min(values)
        summary[kind]['maximum'][key]=max(values)
summary['SFTOF']=[x.decode(errors='replace') for x in re.findall(rb'SFTOF[^\r\n]*',data)]
path.with_suffix('.summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps(summary,indent=2))
