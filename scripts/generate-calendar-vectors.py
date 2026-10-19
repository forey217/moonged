import sys, pathlib, json, hashlib
root=pathlib.Path(__file__).resolve().parents[1]
if len(sys.argv)==2: sys.path.insert(0,str(pathlib.Path(sys.argv[1]).resolve()))
from pyluach import dates
months={7:'TSH',8:'CSH',9:'KSL',10:'TVT',11:'SHV',1:'NSN',2:'IYR',3:'SVN',4:'TMZ',5:'AAV',6:'ELL'}
vectors=[]
for year in [1,2,3,4,5,6,7,8,19,20,99,100,1000,3761,5700,5783,5784,5785,6000,100000,9999999]:
    leap=(7*year+1)%19<7
    names={**months,12:'ADR' if leap else 'ADS'}
    if leap:names[13]='ADS'
    for month,name in sorted(names.items()):
        for day in [1,29,30,31]:
            text=f'HEBREW {day} {name} {year}'
            try:
                h=dates.HebrewDate(year,month,day); jd=int(h.jd+0.5)
            except ValueError:jd=None
            vectors.append((text,jd))
lines=['// Oracle: pyluach 2.3.0 (MIT), https://github.com/simlist/pyluach',
       '// Generated via scripts/generate-calendar-vectors.py; no runtime dependency.',
       '///|','test "Hebrew calendar matches independent pyluach month boundaries across 21 years" {','  let vectors : Array[(String, Int64?)] = [']
for text,jd in vectors:lines.append('    ('+json.dumps(text)+', '+('None' if jd is None else f'Some({jd}L)')+'),')
lines+=['  ]','  for (text, expected) in vectors {','    let actual = try { Some(parse_date(text).window().earliest.unwrap()) } catch { _ => None }','    assert_eq(actual, expected, msg=text)','  }','}','']
(root/'calendar_vectors_wbtest.mbt').write_text('\n'.join(lines),encoding='utf-8',newline='\n')
(root/'spec/gedcom-7.0.18/calendar-oracle.json').write_text(json.dumps({'oracle':'pyluach 2.3.0','license':'MIT','source':'https://github.com/simlist/pyluach','cases':len(vectors),'valid':sum(j is not None for _,j in vectors)},indent=2)+'\n',encoding='utf-8',newline='\n')
print('calendar vectors',len(vectors))
