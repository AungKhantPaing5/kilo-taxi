# Kilo Taxi — Docker

OpenStreetMap + ကိုယ်ပိုင် OSRM ကနေ ကားလမ်းအကွာအဝေးယူပြီး taxi ခတွက်ပေးသော မြန်မာဘာသာ website ဖြစ်ပါတယ်။ Username/password login, Admin panel, User/Role/Permission, ခရီးမှတ်တမ်း၊ နေ့စွဲ/ယာဉ်မောင်းအလိုက် ရှာဖွေခြင်းနဲ့ ပြေစာထုတ်ခြင်း ပါဝင်ပါတယ်။ ChatGPT account မလိုပါ။

## 1. Docker ဖြင့် စတင်ရန်

Ubuntu server တွင် [Docker Engine + Compose plugin](https://docs.docker.com/engine/install/ubuntu/) ရှိပြီးသားဖြစ်ရပါမယ်။ Repository သည် private ဖြစ်သောကြောင့် GitHub authentication သို့မဟုတ် SSH deploy key လိုပါတယ်။ GitHub token/password ကို command ထဲ မထည့်ပါနှင့်။

```bash
git clone https://github.com/AungKhantPaing5/kilo-taxi.git
cd kilo-taxi
bash install.sh
```

Installer က `.env` ဖန်တီးပြီး random Admin password တစ်ခု ထုတ်ပေးကာ Docker ကို build/run လုပ်ပေးပါတယ်။

- URL: `http://localhost:8080`
- Username: `admin`
- Password: `.env` ဖိုင်၏ `ADMIN_PASSWORD` ကို ကြည့်ပါ။
- Default သည် server loopback ပေါ်မှာသာ ဖွင့်ထားပါတယ်။
- First run ပြီးနောက် `.env` ထဲ password ပြင်ရုံဖြင့် database password မပြောင်းပါ။ Website > Password မှပြောင်းပါ။

Local PC/WSL မှ server ကို tunnel ဖွင့်ပြီး စမ်းနိုင်ပါတယ်:

```bash
ssh -L 8080:127.0.0.1:8080 root@YOUR_SERVER_IP
```

ထို့နောက် ကိုယ့် browser မှ `http://localhost:8080` ကိုဖွင့်ပါ။

## 2. VPS + Domain + Automatic HTTPS

Domain A record ကို VPS IP သို့ညွှန်ပါ။ Ports 80/443 ကို ဖွင့်ထားပြီး အခြား app မသုံးနေစေရပါ။ `.env` တွင် ထည့်ပါ:

```dotenv
DOMAIN=taxi.your-domain.example
PUBLIC_URL=https://taxi.your-domain.example
```

```bash
docker compose -f compose.yaml -f compose.https.yaml up -d --build
```

Caddy က certificate ယူပြီး HTTPS ဖွင့်ပေးပါတယ်။ `https://taxi.your-domain.example` ကို ကိုယ့် domain ဖြင့် အစားထိုးဖွင့်ပါ။ DNS အဆင်သင့်ဖြစ်ပြီး inbound 80/443 ရရပါမယ်။ Ports အသုံးပြုပြီးသားဆို existing HTTPS reverse proxy မှ `http://127.0.0.1:8080` သို့ proxy လုပ်ပြီး `.env` ရဲ့ `PUBLIC_URL` ကို အပြင်မှသုံးမည့် HTTPS origin အတိအကျ သတ်မှတ်ပါ။

`PUBLIC_URL` နှင့် browser URL (scheme/domain/port) မတူပါက write requests မအောင်မြင်ပါ။ ပြင်ပြီးနောက်:

```bash
docker compose up -d
```

HTTPS stack သုံးထားပါက compose files နှစ်ခုလုံးနဲ့ပဲ update လုပ်ပါ။

Public HTTP ကို production login အတွက် မသုံးပါနှင့်။ Phone GPS သည် HTTPS (သို့မဟုတ် localhost) လိုအပ်ပါတယ်။ LAN-only test အတွက်သာ `.env` တွင် `BIND_ADDRESS=0.0.0.0`, `PUBLIC_URL=http://SERVER_IP:8080` သတ်မှတ်ပြီး firewall ကို စမ်းသပ်မည့် network အတွက်သာ ဖွင့်ပါ။

## တိုက်ရိုက် GPS ကားမီတာ (Waiting ON → Driving km)

ဒီ mode မှာ destination ရွေးထားစရာ၊ Google Billing/API key သို့မဟုတ် OSRM data မလိုပါ။ ဖုန်း GPS ကနေ ရွေ့လျားမှုကို ခန့်မှန်းပြီး မီတာတွက်ပါတယ်။

ရှိပြီးသား install update:

```bash
git pull --ff-only
docker compose up -d --build
```

HTTPS stack သုံးထားပါက သုံးနေသော compose flags များကို ဆက်သုံးပါ။ Account/မှတ်တမ်း volume မဖျက်ပါ။

1. Admin → ခရီးခသတ်မှတ်ရန်မှာ **1 km ဈေး** နဲ့ **စောင့်ခ / မိနစ်** သတ်မှတ်ပါ။ Waiting ပထမ 600 စက္ကန့် (10 မိနစ်) သည် ခရီးတစ်ခုလျှင် အခမဲ့ဖြစ်ပြီး ကျော်သောစက္ကန့်အတွက်သာ တွက်ပါတယ်။ ဥပမာ 1 မိနစ် 120 ကျပ်ဆို 601 စက္ကန့်တွင် စောင့်ခ 2 ကျပ်၊ 660 စက္ကန့်တွင် 120 ကျပ်။
2. Website > **တိုက်ရိုက်ကားမီတာ** (`/meter`) ကိုဖွင့်ပါ။
3. **Waiting ON** ကိုနှိပ်မှ waiting timer စပါတယ်။ UI မှာ စောင့်ပြီး **စက္ကန့်အရေအတွက်ပဲ** ပြပါတယ်။ 0–600 စက္ကန့်အတွက် စောင့်ခ 0 ဖြစ်ပြီး 601 စက္ကန့်မှ စကောက်ပါတယ်။ Location ကို Allow လုပ်ပါ။
4. ကားရွေ့လျားမှုကို GPS က အတည်ပြုရင် distance fare စုပါတယ်။ ထိုရွေ့လျားမှု interval အတွက် waiting နဲ့ distance နှစ်ခါမကောက်ပါ။
5. ကားရပ်နားလျှင် **Waiting ON** ကို ကိုယ်တိုင်နှိပ်ပါ။ **Waiting OFF** မှာ စက္ကန့်ရပ်ပြီး ON ပြန်နှိပ်ရင် မူလစောင့်ချိန်အပေါ် ဆက်ပေါင်းပါတယ်။ Free 600 စက္ကန့်ကို ပြန်မရပါ။ **ခေတ္တရပ်ရန်** နှိပ်ထားပါက နှစ်မျိုးစလုံး မတိုးပါ။
6. **ခရီးဆုံး · သိမ်းမယ်** နှိပ်ပါ။ Admin history မှာ source `တိုက်ရိုက် GPS မီတာ`၊ km၊ waiting seconds နဲ့ ခရီးခ တွေ့ရပါမယ်။

**တွက်ပုံ**: စတင်ခ + GPS km × 1 km ဈေး + max(0, floor(waiting seconds) − 600) / 60 × တစ်မိနစ်စောင့်ခ။ နောက်ဆုံးမှာ Admin ရွေးထားသောယူနစ်အလိုက် အပေါ်သို့အပြည့်ယူပါတယ်။ Ride စချိန်က tariff ကို snapshot သိမ်းပြီး ခရီးပြီးသည်အထိ သုံးပါတယ်။ Admin ဈေးပြောင်းလျှင် နောက်ခရီးမှ စသုံးပါတယ်။

**ကန့်သတ်ချက်များ**: Foreground-browser GPS ခန့်မှန်းစနစ်သာ ဖြစ်ပါတယ်။ HTTPS (သို့မဟုတ် localhost) နှင့် Location permission လိုပါတယ်။ Screen ဖွင့်ထားပြီး စာမျက်နှာကို အပေါ်မှာထားရပါမယ်။ Background/screen-off မှာ GPS ဆက်ရမည်ဟု အာမမခံပါ။ App က visible အချိန် screen wake lock ကြိုးစားယူပေမယ့် device က ငြင်းနိုင်ပါတယ်။ နောက်ခံရောက်ရင် pause ပို့ဖို့ ကြိုးစားပြီး connection/GPS 30 စက္ကန့်ကျော် gap ကို pause လုပ်ပါတယ်။ Missing distance မဖြည့်ပါ။

GPS accuracy 50 m ထက်ဆိုးသော fix၊ 200 km/h ထက်မြန်သော jump ကို distance မပေါင်းပါ။ Driving ~5 km/h၊ stopped ~2 km/h thresholds နှင့် drift filter သုံးထားသောကြောင့် low-speed traffic၊ အဆောက်အဦးကြား၊ tunnel၊ ကွေ့လမ်းတွေမှာ distance လွဲ/လျော့နိုင်ပါတယ်။ GPS spoofing ကို မကာကွယ်နိုင်ပါ။ Certified commercial taximeter မဟုတ်ပါ။ အမှန်တကယ်မောင်းနှင်ပြီး distance/wait transition စစ်ဆေးရန် ကျန်ရှိပါတယ်။ Screen-off အလုပ်လုပ်ရန်လိုလျှင် native Android/iOS foreground/background location implementation လိုပါတယ်။

Server DB မှာ meter state/time/distance/tariff/နောက်ဆုံး GPS fix ကို သိမ်းပါတယ်။ Full GPS route trace ကို မသိမ်းပါ။ 5 စက္ကန့် heartbeat သည် user 400 အတွက် ~80 requests/sec ဖြစ်သဖြင့် အမှန်တကယ် host ပေါ် load test လုပ်ရပါမယ်။ အရင် 400 `/me` request test သည် ဒီ workload ကို အတည်မပြုပါ။

## 3. Google Billing မလိုဘဲ ကားလမ်း km အလိုအလျောက်တွက်ရန်

ဒီ version က OpenStreetMap မြေပုံနဲ့ ကိုယ်ပိုင် OSRM routing container ကို သုံးပါတယ်။ Google API key / Google Billing မလိုပါ။ Routing server ရဲ့ CPU/RAM/disk နဲ့ မြေပုံ tiles အတွက် အင်တာနက်တော့ လိုပါတယ်။

ရှိပြီးသား install ကို update လုပ်ရန် (account နှင့် ခရီးမှတ်တမ်း မဖျက်ပါ):

```bash
git pull --ff-only
bash scripts/setup-routing.sh
```

HTTPS stack သုံးထားလျှင်:

```bash
git pull --ff-only
bash scripts/setup-routing.sh --https
```

ပထမအကြိမ်တွင် Myanmar OpenStreetMap data ကို Geofabrik မှ download လုပ်ပြီး OSRM `extract → partition → customize` လုပ်ပေးပါတယ်။ အချိန်အတော်ကြာနိုင်ပြီး RAM GB အများအပြား လိုနိုင်ပါတယ်။ Engine image digest ကို `routing-data/.image` တွင် မှတ်ထားပြီး data နဲ့ version တူသော engine ကိုပဲ run ပေးပါတယ်။ နောက် run မှာ `.ready` ရှိလျှင် preprocessing ကို ပြန်မလုပ်ပါ။

မြေပုံ data source: https://download.geofabrik.de/asia/myanmar.html
OSRM documentation: https://github.com/Project-OSRM/osrm-backend

### Admin က 1 km ဈေးသတ်မှတ်ရန်

1. Login → **Admin → ခရီးခသတ်မှတ်ရန်** ကိုဝင်ပါ။
2. **1 km ဈေး** ထည့်ပါ။ ဥပမာ `1200` ကျပ်။
3. km × ဈေးနှုန်းသာတွက်လိုလျှင် စတင်ခ `0`၊ စောင့်ခ `0`၊ အပြည့်ယူ `1` ထားပါ။
4. **ဈေးနှုန်းသိမ်းရန်** ကိုနှိပ်ပါ။ User က ကိုယ်တိုင် km ဈေးပြင်မရပါ။

ဥပမာ: လမ်းအကွာအဝေး **12.5 km × 1200 = 15000 ကျပ်**။

### User အသုံးပြုရန်

1. Website ကို `Ctrl + Shift + R` ဖြင့် reload လုပ်ပါ။
2. **မြေပုံမှ စမှတ်ရွေး** နှိပ်ပြီး စမည့်နေရာကို မြေပုံပေါ်နှိပ်ပါ။ လက်ရှိတည်နေရာကိုလည်း သုံးနိုင်ပါတယ်။
3. **မြေပုံမှ ဆုံးမှတ်ရွေး** နှိပ်ပြီး သွားမည့်နေရာကိုနှိပ်ပါ။
4. နှစ်နေရာစလုံးရွေးပြီးနောက် ကားလမ်းအကွာအဝေး၊ ခရီးချိန်နဲ့ Admin ဈေးအလိုက် ခရီးခ အလိုအလျောက်ပြပါတယ်။
5. **ခရီးသိမ်းရန်** နှိပ်လျှင် server တွင်မှတ်တမ်းသိမ်းပါတယ်။

နေရာအမည်ရှာဖွေခြင်း မပါသေးပါ။ မြေပုံမှရွေးခြင်း သို့မဟုတ် `latitude, longitude` ထည့်ခြင်းကို သုံးပါ။ Public geocoding/demo routing server ကို User 400 အတွက် မသုံးထားပါ။ Google version မှ ခရီးမှတ်တမ်းအဟောင်းများ ဆက်ရှိပါတယ်။

### Map tiles နှင့် User 400

Default tile layer `tile.openstreetmap.org` သည် သေးငယ်သော စမ်းသပ်မှုအတွက်သာ စတင်ထားခြင်းဖြစ်ပြီး unlimited production hosting မဟုတ်ပါ။ User 400 အတွက် production tile provider သို့မဟုတ် ကိုယ်ပိုင် tile server ကို သတ်မှတ်ရပါမယ်။ Provider ကို `.env` မှပြောင်းနိုင်ပါတယ်:

```dotenv
TILE_URL=https://YOUR_TILE_HOST/{z}/{x}/{y}.png
TILE_ATTRIBUTION=YOUR_PROVIDER_ATTRIBUTION
```

Provider attribution လည်း ဆက်ပြထားပါတယ်။ Tile downloading/prefetching/offline bulk caching မလုပ်ထားပါ။ OSM policy: https://operations.osmfoundation.org/policies/tiles/

Routing သည် ကိုယ်ပိုင် container မှ တွက်ခြင်းဖြစ်ပြီး OSRM public demo server ကို fallback မလုပ်ပါ။ Myanmar data အပြင်ဘက် သို့မဟုတ် OSM တွင် ကားလမ်းမဆက်သည့်နေရာများအတွက် route မရနိုင်ပါ။ Road distance သည် မြေပုံဒေတာအပေါ်မူတည်ပြီး လက်ရှိပိတ်ထားသောလမ်း/real-time traffic ကို အာမမခံပါ။

## 4. Admin / User

- Admin က username/password ဖြင့် user ဖန်တီးနိုင်ပါတယ်။ Password အနည်းဆုံး 12 လုံးလိုပါတယ်။
- Roles: Driver, Manager, Admin. Role သည် preset ဖြစ်ပြီး အောက်ပါ permission ကို တစ်ခုချင်းပြင်နိုင်ပါတယ်။
- `calculate`, `save_trips`, `view_own`, `view_all`, `manage_users`, `manage_rates` (`edit_rates`/`manage_maps` သည် version အဟောင်း compatibility အတွက်သာ ကျန်ရှိပါတယ်)
- Driver က ကိုယ့် server မှတ်တမ်းကိုသာ ကြည့်နိုင်ပါတယ်။
- Admin က ယာဉ်မောင်းအမည်/username၊ မြန်မာရက်စွဲအလိုက် အားလုံး၏ခရီးကို ရှာနိုင်ပါတယ်။
- User account ကို ပိတ်/ပြန်ဖွင့်နိုင်ပြီး password reset လုပ်နိုင်ပါတယ်။ ပိတ်ခြင်း သို့မဟုတ် reset လုပ်ခြင်းက sessions များကို ဖျက်ပါတယ်။
- Owner account ကို အခြား account များက ပြင်/ပိတ်မရပါ။ မိမိ password ကို `/account` တွင်ပြောင်းနိုင်ပါတယ်။
- Server မှတ်တမ်းသိမ်းရန် **ခရီးသိမ်းရန်** ကို နှိပ်ရပါမယ်။ အလိုအလျောက် မသိမ်းပါ။

## 5. Fare and storage

ခရီးခ = စတင်ခ + (km × တစ်ကီလိုခ) + (စောင့်မိနစ် × တစ်မိနစ်ခ) + အပိုခ၊ ထို့နောက် ရွေးထားသောယူနစ်အလိုက် အပေါ်သို့အပြည့်ယူပါတယ်။

Default နမူနာ: စတင်ခ 1500 ကျပ်၊ 1 km 1000 ကျပ်၊ စောင့်ခ 1 မိနစ် 100 ကျပ်၊ အပြည့်ယူခ 100 ကျပ်။ User ပေးပို့သည့် rate ကို server က လက်မခံဘဲ Admin သိမ်းထားသော ဈေးနှုန်းဖြင့် ပြန်တွက်ပါတယ်။ အပိုခကို driver က ထည့်နိုင်ပါတယ်။

Automatic mode မှာ OSRM ကပေးသော km ကို server quote ထဲမှာ သိမ်းပြီး save လုပ်ချိန် browser ပေးသော km ကို လက်မခံပါ။ Quote သက်တမ်း 15 မိနစ်ဖြစ်ပြီး Admin က ဈေးပြောင်းထားလျှင် ပြန်တွက်ရပါမယ်။ Manual mode မှာတော့ ကိုယ်တိုင်ထည့်သော km ဖြစ်ပါတယ်။ မည်သည့် mode မှ GPS တိုက်ရိုက် taxi meter မဟုတ်ပါ။

SQLite WAL database ကို Docker named volume `taxi_data` တွင် သိမ်းပါတယ်။ Restart/update လုပ်လည်း data မပျောက်ပါ။ `docker compose down -v` လုပ်ပါက database volume ပျောက်ပါမယ်။

```bash
bash scripts/backup.sh
```

`backups/` သို့ consistent SQLite snapshot သိမ်းပါတယ်။ Backup ထဲမှာ account/password hashes၊ Maps key၊ ခရီးမှတ်တမ်း ပါဝင်လို့ private အဖြစ် သိမ်းပါ။

## 6. Update / logs

```bash
git pull --ff-only
bash scripts/setup-routing.sh
docker compose logs --tail=100 taxi
```

HTTPS compose အသုံးပြုသူ:

```bash
git pull --ff-only
bash scripts/setup-routing.sh --https
```

## 7. Resources and verification

Web app သီးသန့် အရင် 2 vCPU / 2 GB ခန့်မှန်းချက်ထက် ကိုယ်ပိုင် routing အတွက် RAM ပိုလိုပါတယ်။ **4 vCPU / 8 GB RAM / 30 GB SSD** ကို Myanmar preprocessing + app + routing အတွက် စတင်ခန့်မှန်းထားပါတယ်။ Preprocessing/runtime resources ကို အမှန်တကယ် map size နှင့် load ဖြင့် ထပ်တိုင်းတာရပါမယ်။ 400 users capacity ကို အာမမခံပါ။ Web container 768 MB / 1.5 CPU၊ OSRM container 3 GB / 2 CPU သတ်မှတ်ထားပါတယ်။ Preprocessing သည် runtime RAM limit ကိုမသုံးဘဲ Docker host resources ကိုသုံးပါတယ်။
- Zero npm production dependencies, Node.js 24 built-in HTTP/SQLite/crypto.
- Indexed records, 50 trips per page, browser-side Leaflet map rendering.
- Hashed passwords, HttpOnly session cookies, CSRF origin check, login throttling, role permissions enforced server-side.
- Local API integration tests cover login, user creation, permission denial, own/all history, server fare, duplicate saves, invalid input, Maps settings, deactivation, password change, login rate limiting.
- Test also issues 400 concurrent authenticated `/me` requests using one session. This does not simulate 400 independent drivers using Maps and does not prove production capacity.
- GitHub Actions runs API tests, Compose validation, Docker build, startup/restart/persistence tests, and a real OSRM test using a tiny synthetic road network. Full Myanmar dataset preprocessing is not run in CI.

Run tests with Node.js 24:

```bash
npm test
```

This repository is the standalone Docker version. It uses its own database and credentials; it does not synchronize data from the earlier ChatGPT-hosted preview.
