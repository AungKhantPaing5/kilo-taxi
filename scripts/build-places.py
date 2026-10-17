"""Build a local OSM place-name index; no public geocoding API calls."""
import json,sys,os,unicodedata
import osmium
source,target=sys.argv[1:3]
class Places(osmium.SimpleHandler):
    def __init__(self,out):
        super().__init__();self.out=out;self.count=0
    def emit(self,kind,ident,tags,lat,lng):
        names=list(dict.fromkeys(str(tags.get(k,'')) for k in ['name','name:my','name:en','alt_name','official_name','short_name'] if tags.get(k)))
        if not names:return
        name=names[0]
        city=tags.get('addr:city','')
        if city:name+=' — '+city
        self.out.write(json.dumps({'id':'osm-'+kind+str(ident),'name':name[:250],'search':unicodedata.normalize('NFKC',' | '.join(names)).lower(),'lat':lat,'lng':lng},ensure_ascii=False)+'\n');self.count+=1
    def node(self,n):
        if n.location.valid():self.emit('n',n.id,n.tags,n.location.lat,n.location.lon)
    def way(self,w):
        if not any(w.tags.get(k) for k in ['name','name:my','name:en']):return
        points=[(n.lat,n.lon) for n in w.nodes if n.location.valid()]
        if points:self.emit('w',w.id,w.tags,sum(p[0] for p in points)/len(points),sum(p[1] for p in points)/len(points))
with open(target+'.tmp','w',encoding='utf8') as out:
    handler=Places(out);handler.apply_file(source,locations=True,idx='flex_mem')
os.replace(target+'.tmp',target)
print('Indexed',handler.count,'named OSM objects')
