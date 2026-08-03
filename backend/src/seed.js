import fs from 'node:fs';
import path from 'node:path';
import bcrypt from 'bcryptjs';
import { DATA_DIR, isProductionLike } from './config.js';
import { completeTcNo } from './tc.js';
import { seedV2 } from './seed-v2.js';
import { seedV2Demo } from './seed-v2-demo.js';
import { EMAIL_RE } from './helpers.js';

const COMMISSIONS = [
  'Eğitim Komisyonu',
  'Proje Komisyonu',
  'Gönüllü Kazanım ve İşbirlikleri Komisyonu',
  'Sosyal Medya ve İletişim Komisyonu',
  'Sağlıklı Yaşam Komisyonu',
  'Evde Bakım Rehberliği Komisyonu',
];

const KOORDINASYON_KURULU = 'Koordinasyon Kurulu';

const TASK_AREAS = [
  'Afet Müdahale Desteği',
  'Kan Bağışı Organizasyonu',
  'Sosyal Yardım Dağıtımı',
  'Eğitim Faaliyeti',
  'Sağlık Taraması',
  'Toplum Merkezi Etkinliği',
  'Gönüllü Kazanım Etkinliği',
];

/**
 * ---------------------------------------------------------------------------
 * GİRİŞ HESAPLARI — üç mod
 * ---------------------------------------------------------------------------
 *
 * Denetim BLOKE-5 / canlı bulgu: bu iki hesap sabit, herkese açık README'de
 * yayımlanmış şifrelerle oluşturuluyordu ve aynı şifreler canlı sistemde çalışıyordu.
 *
 * Artık:
 *
 *  1. `env`  — `KK_SEED_ADMIN_EMAIL` + `KK_SEED_ADMIN_PASSWORD` verilmişse YALNIZ o
 *              genel merkez hesabı açılır. `must_change_password = 1` ile gelir:
 *              operatörün bildiği ilk şifre kalıcı olamaz.
 *  2. `none` — Üretim benzeri ortamda bu değişkenler YOKSA hiçbir hesap açılmaz.
 *              Sunucu çalışır (sağlık ucu, göçler, referans veri) ama giriş yapılamaz;
 *              konsola nasıl ilk yönetici açılacağını anlatan Türkçe uyarı basılır.
 *              "Sessizce bilinen şifreli hesap açmak"tan iyisi budur.
 *  3. `dev`  — Yerel geliştirme (üretim benzeri DEĞİL, değişken de yok): eski
 *              davranış aynen sürer, `npm test` ve yerel çalıştırma etkilenmez.
 *              Bu hesaplarda `must_change_password = 0`'dır; yoksa her testin ilk
 *              işi şifre değiştirmek olurdu.
 */
const DEV_SEED_USERS = [
  { name: 'Genel Merkez Admin', email: 'admin@kizilay.org.tr', password: 'Admin!2026', role: 'genel_merkez', must_change_password: 0 },
  { name: 'Saha Kullanıcısı', email: 'saha@kizilay.org.tr', password: 'Saha!2026', role: 'saha', must_change_password: 0 },
];

const MIN_SEED_PASSWORD = 8;

/** Tohumlanacak hesapları ve modu ortam değişkenlerinden çözer. */
export function resolveSeedUsers(env = process.env) {
  const email = String(env.KK_SEED_ADMIN_EMAIL || '').trim().toLowerCase();
  const password = String(env.KK_SEED_ADMIN_PASSWORD || '');

  if (email || password) {
    // Yarım yapılandırma sessizce yok sayılmaz — operatör bir şey yapmaya çalışıyor.
    if (!email || !password) {
      throw new Error(
        'Tohum yöneticisi yapılandırması eksik: KK_SEED_ADMIN_EMAIL ve '
        + 'KK_SEED_ADMIN_PASSWORD birlikte verilmelidir.'
      );
    }
    if (!EMAIL_RE.test(email)) {
      throw new Error(`KK_SEED_ADMIN_EMAIL geçerli bir e-posta değil: ${email}`);
    }
    if (password.length < MIN_SEED_PASSWORD) {
      throw new Error(
        `KK_SEED_ADMIN_PASSWORD en az ${MIN_SEED_PASSWORD} karakter olmalı `
        + `(verilen: ${password.length} karakter).`
      );
    }
    return {
      mode: 'env',
      users: [{
        name: String(env.KK_SEED_ADMIN_NAME || 'Genel Merkez Yöneticisi').trim(),
        email,
        password,
        role: 'genel_merkez',
        must_change_password: 1,
      }],
    };
  }

  if (isProductionLike(env)) return { mode: 'none', users: [] };
  return { mode: 'dev', users: DEV_SEED_USERS };
}

const NO_SEED_USER_WARNING = [
  '',
  '───────────────────────────────────────────────────────────────────────',
  '  UYARI — HİÇBİR GİRİŞ HESABI OLUŞTURULMADI',
  '───────────────────────────────────────────────────────────────────────',
  '  Üretim benzeri bir ortam algılandı (NODE_ENV=production, RENDER veya',
  '  KK_ENV=production) ve KK_SEED_ADMIN_EMAIL / KK_SEED_ADMIN_PASSWORD',
  '  tanımlı değil.',
  '',
  '  Bilinen şifreli varsayılan hesap üretime AÇILMAZ; bu yüzden hesap',
  '  oluşturulmadı. Sunucu çalışıyor ancak giriş yapılamaz.',
  '',
  '  İlk yöneticiyi oluşturmak için sunucuyu bir kez şu değişkenlerle başlatın:',
  '',
  '    KK_SEED_ADMIN_EMAIL=yonetici@kizilay.org.tr \\',
  '    KK_SEED_ADMIN_PASSWORD=<en az 8 karakter, harf + rakam> \\',
  '    npm start',
  '',
  '  Hesap "şifre değişikliği zorunlu" bayrağıyla açılır: ilk girişten sonra',
  '  POST /auth/change-password çağrılmadan başka hiçbir uç kullanılamaz.',
  '  Hesap oluştuktan sonra değişkenleri ortamdan KALDIRIN.',
  '───────────────────────────────────────────────────────────────────────',
  '',
].join('\n');

const DEMO_SKIPPED_WARNING = (personCount) => [
  '',
  '───────────────────────────────────────────────────────────────────────',
  '  BİLGİ — DEMO VERİSİ YÜKLENMEDİ',
  '───────────────────────────────────────────────────────────────────────',
  `  Demo verisi istendi (KK_SEED_DEMO=1 / --demo) ancak veritabanında zaten`,
  `  ${personCount} kişi kaydı var. Demo verisi YALNIZCA boş bir veritabanına`,
  '  yüklenir; mevcut kayıtların üzerine sahte kayıt eklenmez.',
  '',
  '  Gerçekten demo verisiyle başlamak istiyorsanız işlem kayıtlarını temizleyin:',
  '',
  '    npm run db:reset          (onay ister; betikte: npm run db:reset -- --yes)',
  '    npm run start:demo',
  '',
  '  `db:reset` referans veriye (81 il, 973 ilçe, komisyonlar, tanımlar,',
  '  teşkilat birimleri, takvim) DOKUNMAZ; yalnız işlem kayıtlarını siler.',
  '───────────────────────────────────────────────────────────────────────',
  '',
].join('\n');

// Bariz sahte ama sağlama (checksum) geçen TC numaraları: 999xxxxxx tabanından üretilir.
function fakeTc(i) {
  return completeTcNo(String(999000001 + i * 111));
}

const DEMO_PERSONS = [
  { first_name: 'Ayşe', last_name: 'Yılmaz', birth_date: '1985-03-12', phone: '05300000001', email: 'ayse.yilmaz@example.org', profession: 'Öğretmen', unit_type: 'il_teskilati', province: 'Ankara', district: null },
  { first_name: 'Fatma', last_name: 'Demir', birth_date: '1990-07-25', phone: '05300000002', email: 'fatma.demir@example.org', profession: 'Hemşire', unit_type: 'ilce_teskilati', province: 'Ankara', district: 'Çankaya' },
  { first_name: 'Zeynep', last_name: 'Kaya', birth_date: '1988-11-02', phone: '05300000003', email: 'zeynep.kaya@example.org', profession: 'Avukat', unit_type: 'il_teskilati', province: 'İstanbul', district: null },
  { first_name: 'Elif', last_name: 'Çelik', birth_date: '1995-01-17', phone: '05300000004', email: 'elif.celik@example.org', profession: 'Sosyal Hizmet Uzmanı', unit_type: 'ilce_teskilati', province: 'İstanbul', district: 'Üsküdar' },
  { first_name: 'Merve', last_name: 'Şahin', birth_date: '1992-05-30', phone: '05300000005', email: 'merve.sahin@example.org', profession: 'Doktor', unit_type: 'ilce_teskilati', province: 'İzmir', district: 'Karşıyaka' },
  { first_name: 'Hatice', last_name: 'Arslan', birth_date: '1979-09-08', phone: '05300000006', email: 'hatice.arslan@example.org', profession: 'Ev Hanımı', unit_type: 'temsilcilik', province: 'Gaziantep', district: null },
  { first_name: 'Emine', last_name: 'Doğan', birth_date: '1983-12-21', phone: '05300000007', email: 'emine.dogan@example.org', profession: 'Eczacı', unit_type: 'il_teskilati', province: 'Bursa', district: null },
  { first_name: 'Selin', last_name: 'Aydın', birth_date: '1997-04-14', phone: '05300000008', email: 'selin.aydin@example.org', profession: 'Psikolog', unit_type: 'ilce_teskilati', province: 'Antalya', district: 'Muratpaşa' },
  { first_name: 'Büşra', last_name: 'Öztürk', birth_date: '1993-08-03', phone: '05300000009', email: 'busra.ozturk@example.org', profession: 'Mühendis', unit_type: 'temsilcilik', province: 'Trabzon', district: null, is_active: 0 },
];

/**
 * Veritabanını tohumlar.
 *
 * İki tür veri vardır ve bunlar KARIŞTIRILMAMALIDIR:
 *
 *  1. REFERANS VERİ (her zaman yüklenir, üründe de gereklidir):
 *     81 il + 973 ilçe, koordinasyon kurulu + 6 komisyon, görev alanları, giriş kullanıcıları.
 *     Bunlar müşterinin "tanımlı ve veri girişi yapılmış olacak" dediği teşkilat omurgasıdır.
 *
 *  2. DEMO VERİ (yalnızca `withDemo: true` ile yüklenir):
 *     Sahte kişiler, üyelikler, faaliyetler, toplantılar, atamalar. Yalnızca geliştirme ve
 *     tanıtım içindir; gerçek üye listesi Excel'den içe aktarılacaktır. Üretimde ASLA yüklenmez.
 *
 * @param {object} db
 * @param {{withDemo?: boolean, env?: object, log?: (msg: string) => void}} [options]
 */
export function seedAll(db, { withDemo = false, env = process.env, log = console.warn } = {}) {
  const result = {};

  // --- Kullanıcılar (e-posta üzerinden idempotent) ---
  const seedUsers = resolveSeedUsers(env);
  result.seed_user_mode = seedUsers.mode;

  const userInsert = db.prepare(`
    INSERT INTO users (name, email, password_hash, role, must_change_password, updated_at)
    VALUES (?, ?, ?, ?, ?, datetime('now'))`);
  const userByEmail = db.prepare('SELECT id FROM users WHERE email = ?');
  for (const u of seedUsers.users) {
    if (!userByEmail.get(u.email)) {
      userInsert.run(u.name, u.email, bcrypt.hashSync(u.password, 10), u.role, u.must_change_password);
    }
  }
  if (seedUsers.mode === 'none' && db.prepare('SELECT COUNT(*) AS c FROM users').get().c === 0) {
    log(NO_SEED_USER_WARNING);
  }

  // Demo verisi ve `created_by` alanları için gerçek kullanıcı kimlikleri.
  // 'none' modunda hiç kullanıcı olmayabilir; o zaman null kalırlar.
  const firstByRole = (role) =>
    db.prepare('SELECT id FROM users WHERE role = ? ORDER BY id LIMIT 1').get(role)?.id ?? null;
  const adminId = firstByRole('genel_merkez');
  const sahaId = firstByRole('saha') ?? adminId;

  // --- İl / ilçe (boşsa yükle) ---
  const provinceCount = db.prepare('SELECT COUNT(*) AS c FROM provinces').get().c;
  if (provinceCount === 0) {
    const raw = JSON.parse(
      fs.readFileSync(path.join(DATA_DIR, 'turkey-provinces-districts.json'), 'utf8')
    );
    const insProvince = db.prepare('INSERT INTO provinces (code, name) VALUES (?, ?)');
    const insDistrict = db.prepare('INSERT INTO districts (province_id, name) VALUES (?, ?)');
    db.transaction(() => {
      for (const p of raw) {
        const { lastInsertRowid } = insProvince.run(p.code, p.name);
        for (const d of p.districts) insDistrict.run(lastInsertRowid, d);
      }
    })();
  }

  // --- Kurul + komisyonlar (isim üzerinden idempotent) ---
  const bodyByName = db.prepare('SELECT id FROM bodies WHERE name = ?');
  const insBody = db.prepare('INSERT INTO bodies (type, name) VALUES (?, ?)');
  if (!bodyByName.get(KOORDINASYON_KURULU)) insBody.run('koordinasyon_kurulu', KOORDINASYON_KURULU);
  for (const name of COMMISSIONS) {
    if (!bodyByName.get(name)) insBody.run('komisyon', name);
  }

  // --- Görev alanları ---
  const taskByName = db.prepare('SELECT id FROM task_areas WHERE name = ?');
  const insTask = db.prepare('INSERT INTO task_areas (name) VALUES (?)');
  for (const name of TASK_AREAS) {
    if (!taskByName.get(name)) insTask.run(name);
  }

  // --- v2 referans verisi: bölgeler, tanımlar, teşkilat birimleri, takvim, içerik ---
  // (il/ilçe ve kurul/komisyon tohumlandıktan SONRA çalışmalıdır — onlardan türetir.)
  const v2Counts = seedV2(db);

  // --- Tohum `saha` hesabına coğrafya ver (Ankara / Çankaya) ---
  //
  // Neden: kapsamsız bir hesapla giriş yapıldığında dokümanlardaki kapsam anahtarı
  // arayüzde hiç görünmüyordu ve istemci `applicable_to` göndermiyordu — yani
  // "bana uygulananlar" görünümü temiz kurulumda hiç denenemiyordu. Artık `saha`
  // hesabı ilçe kırılımına kadar bir kapsam taşır ve özellik ilk günden denenebilir.
  //
  // `seedV2`'den SONRA çalışır: `provinces.region_id` eşlemesi orada yapılır.
  // YALNIZ boş alanlar doldurulur — yöneticinin sonradan yaptığı değişiklik ezilmez.
  const sahaUser = sahaId !== null && sahaId !== adminId
    ? db.prepare('SELECT id, region_id, province_id, district_id FROM users WHERE id = ?').get(sahaId)
    : null;
  if (sahaUser && sahaUser.province_id === null && sahaUser.district_id === null) {
    const ankara = db.prepare("SELECT id, region_id FROM provinces WHERE name = 'Ankara'").get();
    const cankaya = ankara
      ? db.prepare("SELECT id FROM districts WHERE province_id = ? AND name = 'Çankaya'").get(ankara.id)
      : null;
    if (ankara && cankaya) {
      db.prepare(`UPDATE users SET region_id = COALESCE(region_id, ?), province_id = ?,
          district_id = ?, updated_at = datetime('now') WHERE id = ?`)
        .run(ankara.region_id ?? null, ankara.id, cankaya.id, sahaUser.id);
    }
  }

  // --- Demo verisi: yalnızca açıkça istendiğinde ve persons tablosu boşsa ---
  const personCount = db.prepare('SELECT COUNT(*) AS c FROM persons').get().c;
  // Sessiz no-op yerine açık bilgi: "KK_SEED_DEMO=1 verdim ama hiçbir şey olmadı"
  // sorusunun cevabı konsolda durur (denetim: sessiz davranış = en kötü davranış).
  if (withDemo && personCount > 0) log(DEMO_SKIPPED_WARNING(personCount));
  if (withDemo && personCount === 0 && adminId === null) {
    log('\n[UYARI] Demo verisi yüklenemedi: veritabanında hiç kullanıcı yok '
      + '(kayıtların `created_by` alanı doldurulamaz). Önce bir yönetici hesabı oluşturun.\n');
  }
  if (withDemo && personCount === 0 && adminId !== null) {
    const provByName = db.prepare('SELECT id FROM provinces WHERE name = ?');
    const distByName = db.prepare('SELECT id FROM districts WHERE province_id = ? AND name = ?');
    const insPerson = db.prepare(`
      INSERT INTO persons (first_name, last_name, tc_no, birth_date, phone, email, profession,
                           unit_type, province_id, district_id, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);

    const personIds = [];
    db.transaction(() => {
      DEMO_PERSONS.forEach((p, i) => {
        const prov = provByName.get(p.province);
        const dist = p.district ? distByName.get(prov.id, p.district) : null;
        const { lastInsertRowid } = insPerson.run(
          p.first_name, p.last_name, fakeTc(i), p.birth_date, p.phone, p.email,
          p.profession, p.unit_type, prov.id, dist ? dist.id : null,
          p.is_active === 0 ? 'pasif' : 'aktif'
        );
        personIds.push(Number(lastInsertRowid));
      });

      // Üyelikler
      const kurulId = bodyByName.get(KOORDINASYON_KURULU).id;
      const egitimId = bodyByName.get('Eğitim Komisyonu').id;
      const sosyalMedyaId = bodyByName.get('Sosyal Medya ve İletişim Komisyonu').id;
      const insMember = db.prepare(
        'INSERT INTO memberships (body_id, person_id, role_title) VALUES (?, ?, ?)'
      );
      insMember.run(kurulId, personIds[0], 'Başkan');
      insMember.run(kurulId, personIds[2], 'Üye');
      insMember.run(kurulId, personIds[6], 'Üye');
      insMember.run(egitimId, personIds[1], 'Komisyon Başkanı');
      insMember.run(egitimId, personIds[3], 'Üye');
      insMember.run(sosyalMedyaId, personIds[7], 'Üye');

      // Saha faaliyetleri
      const taskId = (name) => taskByName.get(name).id;
      const insAct = db.prepare(`
        INSERT INTO field_activities (task_area_id, activity_date, volunteer_count,
          beneficiary_count, province_id, district_id, notes, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)`);
      const ankara = provByName.get('Ankara').id;
      const istanbul = provByName.get('İstanbul').id;
      const izmir = provByName.get('İzmir').id;
      const cankaya = distByName.get(ankara, 'Çankaya').id;
      insAct.run(taskId('Kan Bağışı Organizasyonu'), '2026-07-05', 12, 240, ankara, cankaya, 'Kızılay Meydanı kan bağışı standı', sahaId);
      insAct.run(taskId('Sosyal Yardım Dağıtımı'), '2026-07-12', 8, 65, istanbul, null, 'Gıda kolisi dağıtımı', sahaId);
      insAct.run(taskId('Eğitim Faaliyeti'), '2026-07-18', 5, 40, izmir, null, 'İlk yardım farkındalık eğitimi', sahaId);
      insAct.run(taskId('Gönüllü Kazanım Etkinliği'), '2026-07-26', 15, 90, ankara, null, 'Üniversite gönüllü tanıtım günü', adminId);

      // Toplantılar
      const insMeet = db.prepare(`
        INSERT INTO meetings (body_id, meeting_date, decision, outcome, created_by)
        VALUES (?, ?, ?, ?, ?)`);
      insMeet.run(kurulId, '2026-07-01', '2026 sonbahar kampanya takviminin onaylanması', 'Takvim oy birliği ile onaylandı', adminId);
      insMeet.run(egitimId, '2026-07-10', 'İlk yardım eğitici eğitimi planlaması', 'Eylül ayında 2 grup eğitim yapılacak', adminId);
      insMeet.run(sosyalMedyaId, '2026-07-20', 'Kan bağışı haftası iletişim planı', 'İçerik takvimi hazırlandı', sahaId);

      // Görev atamaları
      const insAssign = db.prepare(`
        INSERT INTO assignments (person_id, title, description, assigned_date, status, created_by)
        VALUES (?, ?, ?, ?, ?, ?)`);
      insAssign.run(personIds[0], 'Ankara il koordinasyon toplantısı organizasyonu', 'Eylül ayı il koordinasyon toplantısının hazırlığı', '2026-07-15', 'devam', adminId);
      insAssign.run(personIds[1], 'Çankaya kan bağışı standı sorumluluğu', null, '2026-07-03', 'tamamlandi', adminId);
      insAssign.run(personIds[4], 'İzmir sağlık taraması saha ekibi kurulumu', 'Gönüllü sağlık personeli listesinin çıkarılması', '2026-07-22', 'atandi', adminId);
    })();

    // v2 modüllerinin demo kayıtları (görev, eğitim, etkinlik, lojistik, görevlendirme)
    seedV2Demo(db, { adminId, sahaId, personIds });
  }

  Object.assign(result, v2Counts);
  result.users = db.prepare('SELECT COUNT(*) AS c FROM users').get().c;
  result.provinces = db.prepare('SELECT COUNT(*) AS c FROM provinces').get().c;
  result.districts = db.prepare('SELECT COUNT(*) AS c FROM districts').get().c;
  result.commissions = db.prepare("SELECT COUNT(*) AS c FROM bodies WHERE type = 'komisyon'").get().c;
  result.bodies = db.prepare('SELECT COUNT(*) AS c FROM bodies').get().c;
  result.task_areas = db.prepare('SELECT COUNT(*) AS c FROM task_areas').get().c;
  result.persons = db.prepare('SELECT COUNT(*) AS c FROM persons').get().c;
  return result;
}
