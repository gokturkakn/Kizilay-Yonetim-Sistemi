/**
 * Güvenlik paketi — v2.1.
 *
 * Duman testi (`smoke.mjs`) TEK bir sunucu örneğiyle sözleşmeyi doğrular. Buradaki
 * kontroller ise farklı ORTAMLARDA farklı sunucu örnekleri gerektirir:
 *
 *   [1] Üretim benzeri ortamda JWT anahtarı yoksa/zayıfsa sunucu AÇILMAMALI (BLOKE-5).
 *   [2] Üretim benzeri ortamda bilinen şifreli tohum hesabı AÇILMAMALI (canlı bulgu).
 *   [3] KK_SEED_ADMIN_* ile açılan hesap ilk girişte şifre değiştirmeden çalışamamalı.
 *   [4] Kaba kuvvet: hesap ve IP kilidi gerçekten devreye girmeli VE kendiliğinden
 *       çözülmeli (Y-3 — denetimde 25 deneme 1,84 saniyede engelsiz geçmişti).
 *
 * Çalıştırma: `npm test` (paketin son adımı) veya `node test/security.mjs`.
 */
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKEND_DIR = path.resolve(__dirname, '..');
const tmpDir = mkdtempSync(path.join(tmpdir(), 'kk-security-'));

let passed = 0;
let failed = 0;
const failures = [];
function check(name, cond, extra = '') {
  if (cond) { passed += 1; console.log(`  ✓ ${name}`); } else {
    failed += 1; failures.push(name);
    console.error(`  ✗ ${name}${extra ? ` — ${extra}` : ''}`);
  }
}

// Süreç ortamı MİRAS ALINMAZ: geliştiricinin kabuğundaki KK_JWT_SECRET ya da
// NODE_ENV bu testin sonucunu değiştirmemelidir.
const baseEnv = (extra) => ({
  PATH: process.env.PATH,
  HOME: process.env.HOME,
  ...extra,
});

const GOOD_SECRET = 'x'.repeat(24) + '-uretim-icin-uretilmis-anahtar';

/** Sunucuyu başlatır ve ÇIKMASINI bekler (fail-fast senaryoları). */
function runUntilExit(env, timeoutMs = 20000) {
  return new Promise((resolve) => {
    const p = spawn(process.execPath, ['src/server.js'], {
      cwd: BACKEND_DIR, env, stdio: ['ignore', 'pipe', 'pipe'],
    });
    let out = '';
    p.stdout.on('data', (d) => { out += d; });
    p.stderr.on('data', (d) => { out += d; });
    const timer = setTimeout(() => { p.kill('SIGKILL'); resolve({ code: null, out, timedOut: true }); }, timeoutMs);
    p.on('exit', (code) => { clearTimeout(timer); resolve({ code, out, timedOut: false }); });
  });
}

/** Sunucuyu başlatır ve AYAKTA KALMASINI bekler. */
async function startServer(env, port, timeoutMs = 30000) {
  const p = spawn(process.execPath, ['src/server.js'], {
    cwd: BACKEND_DIR, env, stdio: ['ignore', 'pipe', 'pipe'],
  });
  let out = '';
  p.stdout.on('data', (d) => { out += d; });
  p.stderr.on('data', (d) => { out += d; });
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (p.exitCode !== null) throw new Error(`Sunucu beklenmedik şekilde çıktı:\n${out}`);
    try {
      const res = await fetch(`http://localhost:${port}/health`);
      if (res.ok) return { proc: p, log: () => out, port };
    } catch { /* henüz hazır değil */ }
    await new Promise((r) => setTimeout(r, 200));
  }
  p.kill('SIGKILL');
  throw new Error(`Sunucu ${timeoutMs}ms içinde ayağa kalkmadı:\n${out}`);
}

async function api(port, method, url, { token, body, raw } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const res = await fetch(`http://localhost:${port}/api/v1${url}`, {
    method, headers, body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  if (raw) return res;
  let json = null;
  try { json = await res.json(); } catch { /* 204 */ }
  return { status: res.status, json, headers: res.headers };
}

const running = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

try {
  // ======================================================================
  console.log('\n[1] Üretim benzeri ortamda JWT anahtarı — fail-fast (BLOKE-5)');
  // ======================================================================
  const jwtCases = [
    ['NODE_ENV=production + anahtar YOK', { NODE_ENV: 'production' }, /tanımlı değil/],
    ['RENDER=true + anahtar YOK', { RENDER: 'true' }, /tanımlı değil/],
    ['KK_ENV=production + anahtar YOK', { KK_ENV: 'production' }, /tanımlı değil/],
    ['anahtar ÇOK KISA (32 karakterden az)',
      { NODE_ENV: 'production', KK_JWT_SECRET: 'kisacik-anahtar' }, /çok kısa/],
    ['anahtar geliştirme VARSAYILANINA eşit (depoda yayımlanmış)',
      { NODE_ENV: 'production', KK_JWT_SECRET: 'kizilay-kadin-mvp-dev-secret' }, /varsayılan/],
    ['anahtar yalnız boşluktan ibaret',
      { NODE_ENV: 'production', KK_JWT_SECRET: '            ' }, /tanımlı değil/],
  ];
  for (const [i, [label, env, re]] of jwtCases.entries()) {
    const r = await runUntilExit(baseEnv({
      ...env, KK_DB_PATH: path.join(tmpDir, `jwt-${i}.db`), PORT: '4211',
    }));
    check(`${label} → sunucu AÇILMIYOR (çıkış kodu 1)`, r.code === 1, `kod: ${r.code}`);
    check(`${label} → sebebi Türkçe açıklanıyor`, re.test(r.out), r.out.slice(0, 200));
    check(`${label} → çözüm yolu (KK_JWT_SECRET üretimi) gösteriliyor`,
      /KK_JWT_SECRET=/.test(r.out) && /randomBytes/.test(r.out));
  }

  const devNoSecret = await runUntilExit(baseEnv({
    KK_ENV: 'development', KK_DB_PATH: path.join(tmpDir, 'dev-nosecret.db'), PORT: '4212',
  }), 6000);
  check('yerel geliştirmede anahtar zorunlu DEĞİL (sunucu ayakta kalır, süreç kesilmez)',
    devNoSecret.timedOut === true, `kod: ${devNoSecret.code}, çıktı: ${devNoSecret.out.slice(0, 200)}`);
  check('yerel geliştirmede sunucu gerçekten dinlemeye başlamış',
    /Teşkilat Yönetim Sistemi API/.test(devNoSecret.out), devNoSecret.out.slice(0, 200));

  // ======================================================================
  console.log('\n[2] Üretim benzeri ortam + geçerli anahtar, tohum hesabı YOK');
  // ======================================================================
  const prodEnv = baseEnv({
    NODE_ENV: 'production',
    KK_JWT_SECRET: GOOD_SECRET,
    KK_DB_PATH: path.join(tmpDir, 'prod-noadmin.db'),
    KK_UPLOAD_DIR: path.join(tmpDir, 'uploads-prod'),
    PORT: '4213',
  });
  const prodServer = await startServer(prodEnv, 4213);
  running.push(prodServer);
  check('geçerli anahtarla sunucu AÇILIYOR',
    (await fetch('http://localhost:4213/health')).ok);
  check('referans veri yüklenmiş (sistem çalışır durumda, yalnız girişi yok)',
    (await (await fetch('http://localhost:4213/health')).json()).seeded.provinces === 81);

  const knownAdmin = await api(4213, 'POST', '/auth/login', {
    body: { email: 'admin@kizilay.org.tr', password: 'Admin!2026' },
  });
  check('README\'de yayımlanmış tohum şifresi ÜRETİMDE ÇALIŞMIYOR (401)',
    knownAdmin.status === 401 && knownAdmin.json.error.code === 'INVALID_CREDENTIALS',
    JSON.stringify(knownAdmin.json));
  const knownSaha = await api(4213, 'POST', '/auth/login', {
    body: { email: 'saha@kizilay.org.tr', password: 'Saha!2026' },
  });
  check('ikinci tohum hesabı da yok (401)', knownSaha.status === 401);
  check('operatöre nasıl ilk yönetici açacağı Türkçe anlatılıyor',
    /HİÇBİR GİRİŞ HESABI OLUŞTURULMADI/.test(prodServer.log())
    && /KK_SEED_ADMIN_EMAIL/.test(prodServer.log()),
    prodServer.log().slice(-400));
  check('açılış günlüğü ortamı ve hesap modunu bildiriyor',
    /Ortam: üretim benzeri/.test(prodServer.log()) && /giriş hesabı modu: none/.test(prodServer.log()),
    prodServer.log().slice(-200));

  // Geçersiz tohum yapılandırması da açılışı durdurur.
  const badSeed = await runUntilExit(baseEnv({
    NODE_ENV: 'production', KK_JWT_SECRET: GOOD_SECRET,
    KK_SEED_ADMIN_EMAIL: 'yonetici@kizilay.org.tr', KK_SEED_ADMIN_PASSWORD: 'kisa',
    KK_DB_PATH: path.join(tmpDir, 'prod-badseed.db'), PORT: '4214',
  }));
  check('zayıf KK_SEED_ADMIN_PASSWORD ile sunucu AÇILMIYOR',
    badSeed.code === 1 && /en az 8 karakter/.test(badSeed.out), badSeed.out.slice(0, 200));

  // ======================================================================
  console.log('\n[3] Üretim benzeri ortam + KK_SEED_ADMIN_* → hesap doğrudan kullanılabilir');
  // ======================================================================
  // Not: zorunlu şifre değişikliği KAPISI (403 PASSWORD_CHANGE_REQUIRED) burada değil,
  // smoke.mjs [21c]'de yönetici tarafından açılan hesap üzerinden test edilir — o
  // mekanizma hâlâ mevcut ve varsayılan olarak çalışıyor. Bu blok yalnızca seed ile
  // açılan İLK (ve tek) hesabın kendi kendini kilitlemediğini doğrular.
  const seededEnv = baseEnv({
    NODE_ENV: 'production',
    KK_JWT_SECRET: GOOD_SECRET,
    KK_SEED_ADMIN_EMAIL: 'ilk.yonetici@kizilay.org.tr',
    KK_SEED_ADMIN_PASSWORD: 'IlkSifre!2026',
    KK_SEED_ADMIN_NAME: 'İlk Yönetici',
    KK_DB_PATH: path.join(tmpDir, 'prod-admin.db'),
    KK_UPLOAD_DIR: path.join(tmpDir, 'uploads-admin'),
    PORT: '4215',
  });
  const seededServer = await startServer(seededEnv, 4215);
  running.push(seededServer);
  check('açılış günlüğü hesap modunu "env" olarak bildiriyor',
    /giriş hesabı modu: env/.test(seededServer.log()), seededServer.log().slice(-200));

  const firstLogin = await api(4215, 'POST', '/auth/login', {
    body: { email: 'ilk.yonetici@kizilay.org.tr', password: 'IlkSifre!2026' },
  });
  check('operatörün verdiği şifreyle giriş yapılıyor',
    firstLogin.status === 200 && !!firstLogin.json.token, JSON.stringify(firstLogin.json));
  check('hesap must_change_password = 0 ile gelir (seed hesabı kilitlenmez)',
    firstLogin.json.user.must_change_password === 0);
  const opToken = firstLogin.json.token;

  check('hesap İLK GİRİŞTEN İTİBAREN doğrudan kullanılabiliyor (kapı yok)',
    (await api(4215, 'GET', '/persons', { token: opToken })).status === 200);
  check('yönetici uçları da açık (GET /users 200)',
    (await api(4215, 'GET', '/users', { token: opToken })).status === 200);

  // Operatör isterse şifreyi yine de kendi değiştirebilir — bu yol her zaman açık kalır.
  const changed = await api(4215, 'POST', '/auth/change-password', {
    token: opToken, body: { current_password: 'IlkSifre!2026', new_password: 'KalıcıYeni!2026' },
  });
  check('şifre isteğe bağlı olarak değiştirilebiliyor (200)', changed.status === 200 && changed.json.ok === true);
  check('operatörün bildiği ilk şifre artık geçersiz (401)',
    (await api(4215, 'POST', '/auth/login', {
      body: { email: 'ilk.yonetici@kizilay.org.tr', password: 'IlkSifre!2026' },
    })).status === 401);
  // Tohumlama her açılışta çalışır. Değiştirilmiş şifreyi EZMEMELİ.
  seededServer.proc.kill('SIGKILL');
  running.splice(running.indexOf(seededServer), 1);
  await sleep(500);
  const restarted = await startServer(seededEnv, 4215);
  running.push(restarted);
  const afterRestart = await api(4215, 'POST', '/auth/login', {
    body: { email: 'ilk.yonetici@kizilay.org.tr', password: 'KalıcıYeni!2026' },
  });
  check('yeniden başlatmadan sonra YENİ şifre hâlâ geçerli (tohumlama ezmiyor)',
    afterRestart.status === 200, JSON.stringify(afterRestart.json));
  check('yeniden başlatmadan sonra da must_change_password = 0',
    afterRestart.json.user.must_change_password === 0, JSON.stringify(afterRestart.json.user));
  check('yeniden başlatmadan sonra ilk (operatör) şifresi hâlâ geçersiz',
    (await api(4215, 'POST', '/auth/login', {
      body: { email: 'ilk.yonetici@kizilay.org.tr', password: 'IlkSifre!2026' },
    })).status === 401);
  check('yeniden başlatmada mükerrer hesap açılmıyor',
    (await api(4215, 'GET', '/users', { token: afterRestart.json.token })).json.total === 1,
    JSON.stringify((await api(4215, 'GET', '/users', { token: afterRestart.json.token })).json.total));

  // ======================================================================
  console.log('\n[4] Kaba kuvvet koruması (denetim Y-3)');
  // ======================================================================
  // Kısa pencereler: kilit gerçekten devreye giriyor mu VE kendiliğinden çözülüyor mu?
  const rlEnv = baseEnv({
    KK_ENV: 'development',
    KK_DB_PATH: path.join(tmpDir, 'ratelimit.db'),
    KK_UPLOAD_DIR: path.join(tmpDir, 'uploads-rl'),
    PORT: '4216',
    KK_LOGIN_MAX_ATTEMPTS: '3',      // hesap başına 3 hatalı deneme
    KK_LOGIN_IP_MAX_ATTEMPTS: '9',   // IP başına 9 hatalı deneme
    KK_LOGIN_WINDOW_MS: '60000',
    KK_LOGIN_LOCK_MS: '1500',        // testte kısa: kilidin ÇÖZÜLDÜĞÜ de doğrulanır
  });
  const rlServer = await startServer(rlEnv, 4216);
  running.push(rlServer);

  const login = (email, password) => api(4216, 'POST', '/auth/login', { body: { email, password } });
  const ADMIN = 'admin@kizilay.org.tr';

  check('kilitlenmeden önce doğru şifreyle giriş çalışıyor',
    (await login(ADMIN, 'Admin!2026')).status === 200);

  const attempt1 = await login(ADMIN, 'yanlis1');
  const attempt2 = await login(ADMIN, 'yanlis2');
  check('ilk hatalı denemeler 401 döndürüyor (kilit erken kapanmıyor)',
    attempt1.status === 401 && attempt2.status === 401);
  const attempt3 = await login(ADMIN, 'yanlis3');
  check('sınıra ulaşan deneme de 401 (kilit bir SONRAKİ istekte hisseder)',
    attempt3.status === 401);

  const locked = await login(ADMIN, 'yanlis4');
  check('sınır aşılınca 429 TOO_MANY_ATTEMPTS',
    locked.status === 429 && locked.json.error.code === 'TOO_MANY_ATTEMPTS',
    JSON.stringify(locked.json));
  check('hata mesajı Türkçe ve ne kadar bekleneceğini söylüyor',
    /kilitlendi/.test(locked.json.error.message) && /saniye sonra/.test(locked.json.error.message),
    locked.json.error.message);
  check('Retry-After başlığı gönderiliyor',
    Number(locked.headers.get('retry-after')) > 0, locked.headers.get('retry-after'));

  const lockedCorrect = await login(ADMIN, 'Admin!2026');
  check('KİLİTLİYKEN DOĞRU ŞİFRE DE reddediliyor (kilit atlatılamaz)',
    lockedCorrect.status === 429, JSON.stringify(lockedCorrect.json));

  const otherAccount = await login('saha@kizilay.org.tr', 'Saha!2026');
  check('hesap kilidi BAŞKA hesabı etkilemiyor (IP sınırı henüz aşılmadı)',
    otherAccount.status === 200, JSON.stringify(otherAccount.json));

  await sleep(1800);
  const recovered = await login(ADMIN, 'Admin!2026');
  check('kilit süresi dolunca hesap KENDİLİĞİNDEN açılıyor (200)',
    recovered.status === 200, JSON.stringify(recovered.json));
  check('başarılı giriş sayacı sıfırlıyor (ceza taşınmıyor)',
    (await login(ADMIN, 'Admin!2026')).status === 200);

  // --- IP düzeyi: her denemede farklı e-posta kullanan saldırgan --------
  let ipLocked = null;
  for (let i = 0; i < 12; i += 1) {
    const r = await login(`saldirgan${i}@ornek.org`, 'DenemeSifre1');
    if (r.status === 429) { ipLocked = r; break; }
  }
  check('her denemede farklı hesap deneyen saldırgan IP düzeyinde kilitleniyor (429)',
    ipLocked !== null && ipLocked.json.error.code === 'TOO_MANY_ATTEMPTS',
    JSON.stringify(ipLocked?.json));
  check('IP kilidinin mesajı hesap kilidinden AYRI (ağ adresi vurgusu)',
    /ağ adresinden/.test(ipLocked.json.error.message), ipLocked.json.error.message);
  check('IP kilitliyken geçerli bir hesap da giriş yapamıyor',
    (await login(ADMIN, 'Admin!2026')).status === 429);

  await sleep(1800);
  check('IP kilidi de süresi dolunca çözülüyor',
    (await login(ADMIN, 'Admin!2026')).status === 200);

  // Pasif hesap bir KİMLİK hatası değildir; sayaç artırmamalı.
  const adminTok = (await login(ADMIN, 'Admin!2026')).json.token;
  const tempUser = await api(4216, 'POST', '/users', {
    token: adminTok,
    body: { name: 'Pasif Hesap', email: 'pasif.hesap@kizilay.org.tr', password: 'Pasif!2026', role: 'saha' },
  });
  await api(4216, 'PATCH', `/users/${tempUser.json.id}/active`, { token: adminTok, body: { is_active: false } });
  let disabledStatuses = [];
  for (let i = 0; i < 6; i += 1) {
    disabledStatuses.push((await login('pasif.hesap@kizilay.org.tr', 'Pasif!2026')).status);
  }
  check('pasif hesap denemeleri kilit sayacını ŞİŞİRMİYOR (hepsi 401 ACCOUNT_DISABLED)',
    disabledStatuses.every((s) => s === 401), JSON.stringify(disabledStatuses));
  check('bu denemelerden sonra geçerli hesap hâlâ giriş yapabiliyor',
    (await login(ADMIN, 'Admin!2026')).status === 200);
} catch (err) {
  failed += 1;
  failures.push(`beklenmeyen hata: ${err.message}`);
  console.error('\nBeklenmeyen hata:', err);
} finally {
  for (const s of running) s.proc.kill('SIGKILL');
  rmSync(tmpDir, { recursive: true, force: true });
}

console.log(`\n=== Güvenlik testi: ${passed} başarılı, ${failed} başarısız ===`);
if (failed > 0) {
  console.error('Başarısız kontroller:', failures.join(' | '));
  process.exit(1);
}
