"""Extract official YAML independently of the TSV runtime generator."""
import pathlib, re, json, collections, copy, sys
root=pathlib.Path(__file__).resolve().parents[1]
if len(sys.argv)!=2: raise SystemExit('Usage: python scripts/generate-conformance-corpus.py OFFICIAL_RELEASE/extracted-files/tags')
src=pathlib.Path(sys.argv[1])
base='https://gedcom.io/terms/v7/'
terms={}
def scalar(s):
    return s.strip().strip('"\'')
for p in src.iterdir():
    if not p.is_file():continue
    text=p.read_text(encoding='utf-8')
    fields={m[1]:scalar(m[2]) for m in re.finditer(r'^([a-z][a-z -]*): (.+)$',text,re.M)}
    uri=fields.get('uri','')
    if not uri.startswith(base):continue
    item={k:fields[k] for k in ('type','standard tag','payload','enumeration set') if k in fields}
    if item.get('type')=='structure':
        sub=text.split('\nsubstructures:',1)[1].split('\nsuperstructures:',1)[0]
        item['children']={u.removeprefix(base):c for u,c in re.findall(r'^  "([^"]+)": "([^"]+)"',sub,re.M)}
    if item.get('type')=='enumeration set':
        item['values']=re.findall(r'^  - "([^"]+)"',text.split('enumeration values:',1)[1],re.M)
    terms[uri.removeprefix(base)]=item
structures={k:v for k,v in terms.items() if v['type']=='structure'}
structures.pop('CONT',None)  # folded pseudo-structure, covered by parser tests
# HEAD/TRLR are pseudo-structures, whose normative organization is in 搂3.2.1.
roots=['HEAD','record-FAM','record-INDI','record-OBJE','record-REPO','record-SNOTE','record-SOUR','record-SUBM','TRLR']
for k in ['HEAD','TRLR']:
    if k not in structures:raise RuntimeError(k)
def pl(t):
    v=structures[t].get('payload','null');return '' if v=='null' else v
def enumvals(t):
    eset=structures[t].get('enumeration set','').removeprefix(base)
    return [terms[v.removeprefix(base)]['standard tag'] for v in terms[eset]['values']] if eset else []
def default(t,parent=''):
    k=pl(t)
    if t=='GEDC-VERS':return '7.0'
    if k.startswith('@<'):return '@VOID@'
    if k=='':return ''
    if k=='Y|<NULL>':return 'Y'
    if t=='NO':return 'ANUL' if parent=='record-FAM' else 'BIRT'
    if k.endswith('type-Enum') or k.endswith('type-List#Enum'):return enumvals(t)[0]
    if k.endswith('nonNegativeInteger'):return '0'
    if 'type-Date#period' in k:return 'FROM 1900 TO 2000'
    if 'type-Date#exact' in k:return '1 JAN 2000'
    if k.endswith('type-Date'):return '1900'
    if k.endswith('type-Time'):return '12:30:00Z'
    if k.endswith('type-Age'):return '25y'
    if k.endswith('type-Name'):return 'A /Synthetic/'
    if k.endswith('#Language'):return 'en'
    if k.endswith('#mediaType'):return 'image/png' if t=='FORM' else 'text/plain'
    if k.endswith('type-FilePath'):return 'media/example.png'
    if k.endswith('type-Latitude'):return 'N0'
    if k.endswith('type-Longitude'):return 'E0'
    if k.endswith('type-TagDef'):return '_EXAMPLE urn:moonged:example'
    if k.endswith('#anyURI'):return 'urn:moonged:example'
    return 'Synthetic'
def node(t,parent=''):
    n={'t':t,'v':default(t,parent),'children':[]}
    for child,c in structures[t]['children'].items():
        if c.startswith('{1:'):n['children'].append(node(child,t))
    if t=='NOTE-TRAN':n['children'].append(node('LANG',t));n['children'][-1]['v']='fr'
    if t=='FILE-TRAN':
        for c in n['children']:
            if c['t']=='FORM':c['v']='image/jpeg'
    if t in ('NAME-TRAN','PLAC-TRAN'):
        for c in n['children']:
            if c['t']=='LANG':c['v']='fr'
    if not n['v'] and not n['children'] and t not in ('TRLR',):
        # Optional empty record has to be nonempty (搂1.2).
        child=next((k for k in structures[t]['children'] if k in ['NOTE','NAME','INDI-NAME']),next(iter(structures[t]['children']),None))
        if child is None:raise RuntimeError('Cannot make nonempty '+t)
        n['children'].append(node(child,t))
    return n
paths={r:[r] for r in roots}
queue=collections.deque(roots)
while queue:
    p=queue.popleft()
    for t in structures[p]['children']:
        if t not in paths:paths[t]=paths[p]+[t];queue.append(t)
def document(path):
    top=node(path[0]);cur=top
    for t in path[1:]:
        found=next((c for c in cur['children'] if c['t']==t),None)
        if found is None:found=node(t,cur['t']);cur['children'].append(found)
        cur=found
    return top,cur
def render(top):
    lines=[]
    def walk(n,level):
        lines.append(str(level)+' '+structures[n['t']]['standard tag']+(' '+n['v'] if n['v'] else ''))
        for c in n['children']:walk(c,level+1)
    if top['t']!='HEAD':walk(node('HEAD'),0)
    walk(top,0)
    if top['t']!='TRLR':walk(node('TRLR'),0)
    return '\n'.join(lines)+'\n'
cases=[]
for parent,definition in structures.items():
    for child,card in definition['children'].items():
        top,cur=document(paths[parent]+[child])
        cases.append({'id':'edge:'+parent+'/'+child,'valid':True,'text':render(top)})
        if card.endswith(':1}'):
            top2,par=document(paths[parent]);item=next((c for c in par['children'] if c['t']==child),None)
            if item is None:item=node(child,parent);par['children'].append(item)
            par['children'].append(copy.deepcopy(item))
            cases.append({'id':'singleton:'+parent+'/'+child,'valid':False,'code':'structure-cardinality','text':render(top2)})
        if card.startswith('{1:'):
            top2,par=document(paths[parent]);par['children']=[c for c in par['children'] if c['t']!=child]
            cases.append({'id':'required:'+parent+'/'+child,'valid':False,'code':'required-structure','text':render(top2)})
for t in structures:
    top,cur=document(paths[t]);cur['v']='@VOID@' if not pl(t).startswith('@<') else 'Not a pointer'
    cases.append({'id':'payload:'+t,'valid':False,'code':'payload-type','text':render(top)})
    if enumvals(t):
        for value in enumvals(t):
            if t=='NO':continue # event set is additionally constrained by parent
            top,cur=document(paths[t]);cur['v']=value
            cases.append({'id':'enum:'+t+'/'+value,'valid':True,'text':render(top)})
out=root/'spec/gedcom-7.0.18'
enum_tags={base+k:{terms[v.removeprefix(base)]['standard tag']:v for v in definition['values']} for k,definition in terms.items() if definition['type']=='enumeration set'}
(out/'enum-tags.json').write_text(json.dumps(enum_tags,indent=2)+'\n',encoding='utf-8',newline='\n')
(out/'official-yaml-schema.json').write_text(json.dumps({'source':'FamilySearch/GEDCOM v7.0.18 extracted-files/tags','types':structures,'enums':{t:enumvals(t) for t in structures if enumvals(t)}},indent=2)+'\n',encoding='utf-8',newline='\n')
(root/'tests/semantic-corpus.json').write_text(json.dumps(cases,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8',newline='\n')
print('Official YAML structures:',len(structures),'edges:',sum(len(v['children']) for v in structures.values()),'cases:',len(cases),'positive:',sum(c['valid'] for c in cases))
