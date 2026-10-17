// Foreground-browser GPS estimate, not a certified taximeter.
export const MAX_GAP_MS=30000;
export function metersBetween(a,b){const rad=x=>x*Math.PI/180,R=6371000,dLat=rad(b.lat-a.lat),dLon=rad(b.lng-a.lng),h=Math.sin(dLat/2)**2+Math.cos(rad(a.lat))*Math.cos(rad(b.lat))*Math.sin(dLon/2)**2;return R*2*Math.atan2(Math.sqrt(h),Math.sqrt(Math.max(0,1-h)))}
export function validFix(f,now){return f&&[f.lat,f.lng,f.accuracy,f.timestamp].every(Number.isFinite)&&Math.abs(f.lat)<=90&&Math.abs(f.lng)<=180&&f.accuracy>=0&&f.accuracy<=50&&Math.abs(now-f.timestamp)<=15000&&(f.speed==null||Number.isFinite(f.speed)&&f.speed>=0&&f.speed<=60)}
export function startMeter(tariff,now){return {state:'waiting',meters:0,waitingSeconds:0,updated:now,started:now,tariff,lastFix:null,lastGood:now,stopSince:null,pendingMeters:0,pendingSeconds:0,note:'Waiting timer started'}}
export function advanceMeter(input,event,now){const m=structuredClone(input);if(m.state==='finished')return m;const dt=Math.max(0,(now-m.updated)/1000);if(m.state==='waiting')m.waitingSeconds+=Math.max(0,Math.min(now,m.updated+MAX_GAP_MS,m.lastGood+MAX_GAP_MS)-m.updated)/1000;const gap=now-m.updated>MAX_GAP_MS;
if(gap){m.state='paused';m.lastFix=null;m.pendingMeters=0;m.pendingSeconds=0;m.note='Connection/GPS gap: meter paused; missing distance was not estimated'}
m.updated=now;
if(event.type==='pause'){m.state='paused';m.lastFix=null;m.pendingMeters=0;m.pendingSeconds=0;m.note='Meter paused';return m}
if(event.type==='resume'){m.state='waiting';m.lastFix=null;m.lastGood=now;m.pendingMeters=0;m.pendingSeconds=0;m.stopSince=null;m.note='Resumed waiting; acquiring a fresh GPS fix';return m}
if(event.type==='finish'){m.state='finished';m.note='Trip finished';return m}
if(m.state==='paused')return m;
const f=event.fix;
if(!validFix(f,now)){if(now-m.lastGood>MAX_GAP_MS){m.state='paused';m.lastFix=null;m.note='GPS unavailable or inaccurate: meter paused'}else m.note='Waiting for an accurate GPS fix (≤50 m)';return m}
// Duplicate positions must not refresh lastGood: GPS needs genuinely new samples.
if(m.lastFix&&f.timestamp<=m.lastFix.timestamp)return m;
m.lastGood=now;
if(!m.lastFix){m.lastFix=f;m.note='GPS ready';return m}
const old=m.lastFix,seconds=(f.timestamp-old.timestamp)/1000;if(seconds<=0)return m;
if(seconds>30){m.state='paused';m.lastFix=null;m.note='GPS sample gap: meter paused';return m}
const distance=metersBetween(old,f),derived=distance/seconds;
if(derived>55.56){m.lastFix=null;m.note='Unrealistic GPS jump ignored';return m}
const measuredSpeed=f.speed==null?derived:f.speed,threshold=Math.max(8,(old.accuracy+f.accuracy)*0.6),moving=measuredSpeed>=1.4&&distance>=threshold;
if(moving){m.stopSince=null;if(m.state==='waiting'){m.pendingMeters+=distance;m.pendingSeconds+=Math.min(seconds,dt);if(m.pendingSeconds>=5){m.meters+=m.pendingMeters;m.waitingSeconds=Math.max(0,m.waitingSeconds-m.pendingSeconds);m.state='driving';m.pendingMeters=0;m.pendingSeconds=0}}else m.meters+=distance;m.lastFix=f;m.note=m.state==='driving'?'Driving: distance fare active':'Movement detected; confirming GPS'}else{m.pendingMeters=0;m.pendingSeconds=0;if(m.state==='driving'&&measuredSpeed<0.56){if(m.stopSince==null)m.stopSince=now;if(now-m.stopSince>=10000){m.state='waiting';m.waitingSeconds+=(now-m.stopSince)/1000;m.lastFix=f;m.stopSince=null;m.note='Stopped: waiting fare active'}}else if(m.state==='waiting'){m.lastFix=f;m.note='Waiting: seconds are being charged'}else if(distance>=threshold){m.lastFix=f;m.note='Slow movement below driving threshold'}}
return m}
export function meterFare(m){const t=m.tariff,distanceFare=m.meters/1000*t.rate,waitingFare=m.waitingSeconds/60*t.waitRate,raw=t.base+distanceFare+waitingFare;return {km:m.meters/1000,waitingSeconds:m.waitingSeconds,distanceFare,waitingFare,base:t.base,total:Math.ceil(raw/t.round)*t.round}}
