# Kilo Taxi — Docker

Google Maps နဲ့ လမ်းအကွာအဝေးယူပြီး taxi ခတွက်ပေးသော မြန်မာဘာသာ website ဖြစ်ပါတယ်။ Username/password login, Admin panel, User/Role/Permission, ခရီးမှတ်တမ်း၊ နေ့စွဲ/ယာဉ်မောင်းအလိုက် ရှာဖွေခြင်းနဲ့ ပြေစာထုတ်ခြင်း ပါဝင်ပါတယ်။ ChatGPT account မလိုပါ။

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

## 3. Google Maps ကို user အားလုံးအတွက် ချိတ်ရန်

1. Google Cloud project တွင် billing ချိတ်ပါ။
2. **Maps JavaScript API** နှင့် **Routes API** ကို enable လုပ်ပါ။
3. Browser API key ဖန်တီးပါ။ Application restriction ကို **Websites / HTTP referrers** သတ်မှတ်ပါ။
4. ကိုယ့် URL ကို ခွင့်ပြုပါ: `https://taxi.your-domain.example/*`။ Local testing အတွက် `http://localhost:8080/*` ကိုသာ ထပ်ထည့်ပါ။
5. API restriction တွင် အထက်ပါ API နှစ်ခုကိုသာ ခွင့်ပြုပါ။
6. Login → **Admin → Google Maps** တွင် key ကို သိမ်းပါ။ Calculator ကို reload လုပ်ပါ။
7. စတင်မည့်နေရာနှင့် သွားမည့်နေရာထည့်ပြီး **ခရီးခတွက်မယ်** ကိုနှိပ်ပါ။ Google road distance နှင့် route ကိုပြပေးပါမယ်။

Alternative: `.env` ထဲ `GOOGLE_MAPS_API_KEY=...` ထည့်ပြီး container recreate လုပ်နိုင်ပါတယ်။ Admin တွင်သိမ်းထားသော key က env key ထက် ဦးစားပေးပါတယ်။

Google Maps browser key ကို browser က ဖတ်နိုင်ပါတယ်။ Referrer/API restrictions မဖြစ်မနေ သတ်မှတ်ပါ။ Key ကို GitHub ပေါ်မတင်ပါနှင့်။ Google API အသုံးပြုခနှင့် quotas သည် VPS fee နဲ့ သီးခြားဖြစ်ပါတယ်။ Key မရှိသေးပါက manual ကီလိုထည့်တွက်နိုင်ပါတယ်။

Official guide: https://developers.google.com/maps/documentation/javascript/routes/start

## 4. Admin / User

- Admin က username/password ဖြင့် user ဖန်တီးနိုင်ပါတယ်။ Password အနည်းဆုံး 12 လုံးလိုပါတယ်။
- Roles: Driver, Manager, Admin. Role သည် preset ဖြစ်ပြီး အောက်ပါ permission ကို တစ်ခုချင်းပြင်နိုင်ပါတယ်။
- `calculate`, `save_trips`, `view_own`, `view_all`, `manage_users`, `edit_rates`, `manage_maps`
- Driver က ကိုယ့် server မှတ်တမ်းကိုသာ ကြည့်နိုင်ပါတယ်။
- Admin က ယာဉ်မောင်းအမည်/username၊ မြန်မာရက်စွဲအလိုက် အားလုံး၏ခရီးကို ရှာနိုင်ပါတယ်။
- User account ကို ပိတ်/ပြန်ဖွင့်နိုင်ပြီး password reset လုပ်နိုင်ပါတယ်။ ပိတ်ခြင်း သို့မဟုတ် reset လုပ်ခြင်းက sessions များကို ဖျက်ပါတယ်။
- Owner account ကို အခြား account များက ပြင်/ပိတ်မရပါ။ မိမိ password ကို `/account` တွင်ပြောင်းနိုင်ပါတယ်။
- Server မှတ်တမ်းသိမ်းရန် **ခရီးသိမ်းရန်** ကို နှိပ်ရပါမယ်။ အလိုအလျောက် မသိမ်းပါ။

## 5. Fare and storage

ခရီးခ = စတင်ခ + (km × တစ်ကီလိုခ) + (စောင့်မိနစ် × တစ်မိနစ်ခ) + အပိုခ၊ ထို့နောက် ရွေးထားသောယူနစ်အလိုက် အပေါ်သို့အပြည့်ယူပါတယ်။

Default နမူနာ: စတင်ခ 1500 ကျပ်၊ 1 km 1000 ကျပ်၊ စောင့်ခ 1 မိနစ် 100 ကျပ်၊ အပြည့်ယူခ 100 ကျပ်။ `edit_rates` မရှိသော user ပေးပို့သည့် rate ကို server က လက်မခံဘဲ default ဖြင့်တွက်ပါတယ်။ အပိုခကို driver က ထည့်နိုင်ပါတယ်။

ခရီးအကွာအဝေးသည် manual သို့မဟုတ် Google Maps browser result ဖြစ်ပါတယ်။ Server က ခရီးခပြန်တွက်သော်လည်း browser မှပေးသော km ကို GPS meter reading အဖြစ် အတည်ပြုမထားပါ။

SQLite WAL database ကို Docker named volume `taxi_data` တွင် သိမ်းပါတယ်။ Restart/update လုပ်လည်း data မပျောက်ပါ။ `docker compose down -v` လုပ်ပါက database volume ပျောက်ပါမယ်။

```bash
bash scripts/backup.sh
```

`backups/` သို့ consistent SQLite snapshot သိမ်းပါတယ်။ Backup ထဲမှာ account/password hashes၊ Maps key၊ ခရီးမှတ်တမ်း ပါဝင်လို့ private အဖြစ် သိမ်းပါ။

## 6. Update / logs

```bash
git pull --ff-only
docker compose up -d --build
docker compose logs --tail=100 taxi
```

HTTPS compose အသုံးပြုသူ:

```bash
git pull --ff-only
docker compose -f compose.yaml -f compose.https.yaml up -d --build
```

## 7. Resources and verification

VPS စတင်အသုံးပြုရန် **2 vCPU / 2 GB RAM / 20 GB SSD** ကို ခန့်မှန်းထားပါတယ်။ Container ကို 768 MB RAM / 1.5 CPU limit သတ်မှတ်ထားပြီး HTTPS proxy ကို 256 MB သတ်မှတ်ထားပါတယ်။ လိုအပ်လျှင် limits ပြင်နိုင်ပါတယ်။ ဒါတွေဟာ measured 400-user capacity guarantee မဟုတ်ပါ။

- Zero npm production dependencies, Node.js 24 built-in HTTP/SQLite/crypto.
- Indexed records, 50 trips per page, browser-side Google Maps rendering.
- Hashed passwords, HttpOnly session cookies, CSRF origin check, login throttling, role permissions enforced server-side.
- Local API integration tests cover login, user creation, permission denial, own/all history, server fare, duplicate saves, invalid input, Maps settings, deactivation, password change, login rate limiting.
- Test also issues 400 concurrent authenticated `/me` requests using one session. This does not simulate 400 independent drivers using Maps and does not prove production capacity.
- GitHub Actions runs API tests, Docker build, container startup and restart/persistence checks.

Run tests with Node.js 24:

```bash
npm test
```

This repository is the standalone Docker version. It uses its own database and credentials; it does not synchronize data from the earlier ChatGPT-hosted preview.
