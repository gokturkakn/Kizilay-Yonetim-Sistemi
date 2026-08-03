/**
 * Yönetim Paneli — Kullanıcı Yönetimi.
 *
 * Denetim raporu Y-2'nin doğrudan karşılığı: v1'de ülke genelinde tek paylaşımlı `saha`
 * hesabı vardı ve ikinci bir hesap açmanın yolu yoktu; bu, `created_by` alanını ve
 * dolayısıyla tüm denetim izini anlamsızlaştırıyordu.
 *
 * `password_hash` hiçbir yanıtta dönmez.
 */
import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  ApiError, badRequest, conflict, notFound, listQuery, parseBoolFlag,
  requireFields, EMAIL_RE, toIntOrThrow,
} from '../helpers.js';
import { optionalInt, optionalText } from '../v2.js';
import {
  avatarBody, avatarUpload, clearAvatar, currentAvatar, storeAvatar,
} from '../avatars.js';

const ROLES = ['genel_merkez', 'saha'];
const MIN_PASSWORD = 8;
// `av` JOIN'i: yönetici listesinde profil fotoğrafı satır başına EK SORGU olmadan gelir
// (müşteri: "profil resimlerini kullanıcı yönetimi kısmında görebilmeliyim").
const SELECT = `u.id, u.name, u.email, u.phone, u.title, u.role,
  u.region_id, u.province_id, u.district_id,
  u.is_active, u.must_change_password,
  rg.name AS region_name, pr.name AS province_name, di.name AS district_name,
  u.avatar_attachment_id, av.mime AS avatar_mime, av.size AS avatar_size,
  av.file_name AS avatar_file_name,
  u.created_at, u.updated_at`;
const FROM = `users u
  LEFT JOIN regions rg ON rg.id = u.region_id
  LEFT JOIN provinces pr ON pr.id = u.province_id
  LEFT JOIN districts di ON di.id = u.district_id
  LEFT JOIN attachments av ON av.id = u.avatar_attachment_id`;
const FIELDS = ['name', 'email', 'phone', 'title', 'role', 'region_id', 'province_id',
  'district_id', 'is_active'];
// Kullanıcının KENDİSİ hakkında değiştirebildiği alanlar (v2.3).
const SELF_FIELDS = ['name', 'email', 'phone', 'title', 'region_id', 'province_id', 'district_id'];

/**
 * `PATCH /auth/me` ile ASLA değiştirilemeyecek alanlar.
 *
 * Sessizce yok saymak YETMEZ: yok sayılan bir `role: "genel_merkez"` isteği istemciye
 * 200 döner, kullanıcı kendini yükselttiğini sanır, kayıtlarda hiçbir iz kalmaz ve
 * denetim sırasında yetki yükseltme denemesi görünmez. Bu yüzden istek 400 ile
 * REDDEDİLİR ve deneme denetim iznine yazılır (`self_update_rejected`).
 *
 * Şifre de buradadır: tek yolu `POST /auth/change-password`'dır ve o uç MEVCUT şifreyi
 * ister. Profil güncellemesi üzerinden şifre yazılabilseydi, çalınmış bir token'la
 * şifre değiştirilebilir ve o kontrol delinmiş olurdu.
 */
const SELF_FORBIDDEN = [
  'id', 'role', 'is_active', 'must_change_password',
  'password', 'new_password', 'password_hash', 'avatar_attachment_id',
  'created_at', 'updated_at',
];
const SECRET_KEYS = new Set(['password', 'new_password', 'password_hash']);

/**
 * Yanıt gövdesi: yardımcı `avatar_*` sütunları tek bir `avatar` nesnesine katlanır.
 * Biçim dokümanlardaki `files` alanıyla aynı mantıktadır (kimlik + url + mime + boyut).
 * Fotoğrafı olmayan kullanıcıda `avatar: null` döner — istemci baş harf rozetine düşer.
 */
function withAvatar(row) {
  if (!row) return row;
  const { avatar_mime: mime, avatar_size: size, avatar_file_name: fileName, ...rest } = row;
  return {
    ...rest,
    avatar: row.avatar_attachment_id
      ? avatarBody({ id: row.avatar_attachment_id, mime, size, file_name: fileName })
      : null,
  };
}

/**
 * Şifre gücü (asgari eşik).
 *
 * Uzunluk tek başına yetmez: "12345678" sekiz karakterdir. Harf + rakam şartı, sözlük
 * saldırısına karşı sihirli bir çözüm değildir ama tohum/varsayılan tipi şifrelerin
 * (`00000000`, `password`) kabul edilmesini engeller. Kaba kuvvet tarafı ayrıca
 * `loginRateLimit.js` ile kapatılmıştır.
 */
export function checkPassword(value) {
  const pwd = String(value ?? '');
  if (pwd.length < MIN_PASSWORD) {
    throw new ApiError(400, 'WEAK_PASSWORD', `Şifre en az ${MIN_PASSWORD} karakter olmalı`);
  }
  if (!/[A-Za-zÇĞİıÖŞÜçğöşü]/.test(pwd) || !/\d/.test(pwd)) {
    throw new ApiError(400, 'WEAK_PASSWORD',
      'Şifre en az bir harf ve en az bir rakam içermeli');
  }
  return pwd;
}

/**
 * Telefon — biçimi ZORLANMAZ, yalnız akla yatkınlığı denetlenir.
 *
 * Teşkilatta numaralar `0532 111 22 33`, `+90 532 …`, `(0212) …` gibi çok farklı
 * yazılıyor; katı bir maske kullanıcıyı kendi numarasını giremez hale getirirdi.
 * Bu yüzden yalnız izinli karakterler ve uzunluk sınırı kontrol edilir.
 * Boş string ya da `null` gönderilerek alan TEMİZLENEBİLİR.
 */
const PHONE_RE = /^[0-9+()\-\s]{7,20}$/;

export function optionalPhone(value) {
  const text = optionalText(value);
  if (text === null) return null;
  if (!PHONE_RE.test(text)) {
    throw badRequest('Telefon 7–20 karakter olmalı; yalnız rakam, boşluk ve + - ( ) kabul edilir');
  }
  return text;
}

/** Unvan (ör. "İl Başkanı") — serbest metin, yalnız uzunluk sınırlı. */
export function optionalTitle(value) {
  const text = optionalText(value);
  if (text === null) return null;
  if (text.length > 120) throw badRequest('Unvan en fazla 120 karakter olabilir');
  return text;
}

export default function userRoutes(db) {
  const r = Router();
  const admin = requireRole('genel_merkez');

  const getOne = (id) => withAvatar(db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE u.id = ?`).get(id));

  /**
   * Kapsam doğrulaması: bölge → il → ilçe.
   *
   * `district_id`, dokümanların `?applicable_to=district:<id>` görünümünü gerçek bir
   * oturumdan ulaşılabilir kılar (önceden il en dar kırılımdı). İlçenin kullanıcının
   * iline ait olması ZORUNLUDUR; aksi halde "Ankara sorumlusu"na Üsküdar kapsamı
   * verilebilir ve kapsam alanı anlamını yitirirdi.
   */
  function validateScope(body, existing = null) {
    const regionId = body.region_id !== undefined ? optionalInt(body.region_id, 'region_id') : (existing?.region_id ?? null);
    if (regionId !== null && !db.prepare('SELECT id FROM regions WHERE id = ?').get(regionId)) {
      throw badRequest('region_id geçersiz');
    }
    const provinceId = body.province_id !== undefined ? optionalInt(body.province_id, 'province_id') : (existing?.province_id ?? null);
    if (provinceId !== null && !db.prepare('SELECT id FROM provinces WHERE id = ?').get(provinceId)) {
      throw badRequest('province_id geçersiz');
    }
    const districtId = body.district_id !== undefined
      ? optionalInt(body.district_id, 'district_id')
      : (existing?.district_id ?? null);
    if (districtId !== null) {
      const dist = db.prepare('SELECT id, province_id FROM districts WHERE id = ?').get(districtId);
      if (!dist) throw badRequest('district_id geçersiz');
      if (provinceId === null) {
        throw badRequest("İlçe kapsamı verebilmek için 'province_id' de gönderilmelidir");
      }
      if (dist.province_id !== provinceId) {
        throw badRequest('İlçe, seçilen ile ait değil');
      }
    }
    return { region_id: regionId, province_id: provinceId, district_id: districtId };
  }

  function activeAdminCount(excludeId = null) {
    return db.prepare(
      "SELECT COUNT(*) AS c FROM users WHERE role = 'genel_merkez' AND is_active = 1 AND id <> ?"
    ).get(excludeId ?? -1).c;
  }

  r.get('/users', admin, (req, res, next) => {
    try {
      const where = [];
      const params = [];
      if (req.query.role) {
        if (!ROLES.includes(req.query.role)) throw badRequest('role filtresi geçersiz');
        where.push('u.role = ?'); params.push(req.query.role);
      }
      const active = parseBoolFlag(req.query.is_active);
      if (active !== undefined) { where.push('u.is_active = ?'); params.push(active); }
      if (req.query.q) { where.push('(u.name LIKE ? OR u.email LIKE ?)'); params.push(`%${req.query.q}%`, `%${req.query.q}%`); }
      const result = listQuery(db, {
        select: SELECT, from: FROM, where, params, orderBy: 'u.name', query: req.query,
      });
      res.json({ ...result, data: result.data.map(withAvatar) });
    } catch (e) { next(e); }
  });

  r.get('/users/:id', admin, (req, res, next) => {
    try {
      const row = getOne(req.params.id);
      if (!row) throw notFound('Kullanıcı bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  r.post('/users', admin, (req, res, next) => {
    try {
      const b = req.body || {};
      requireFields(b, ['name', 'email', 'password', 'role']);
      const email = String(b.email).trim().toLowerCase();
      if (!EMAIL_RE.test(email)) throw badRequest('E-posta biçimi geçersiz');
      if (!ROLES.includes(b.role)) throw badRequest(`role şunlardan biri olmalı: ${ROLES.join(', ')}`);
      if (db.prepare('SELECT id FROM users WHERE email = ?').get(email)) {
        throw conflict('Bu e-posta ile kayıtlı bir kullanıcı zaten var');
      }
      const password = checkPassword(b.password);
      const scope = validateScope(b);
      // Yönetici tarafından açılan hesap, yöneticinin bildiği bir şifreyle başlar.
      // Bu yüzden varsayılan olarak ilk girişte şifre değişikliği ZORUNLUDUR.
      // Açıkça `must_change_password: false` gönderilerek devre dışı bırakılabilir
      // (ör. istemcisi bu akışı desteklemeyen servis hesapları için).
      const mustChange = parseBoolFlag(b.must_change_password) ?? 1;

      const { lastInsertRowid } = db.prepare(`
        INSERT INTO users (name, email, phone, title, password_hash, role,
                           region_id, province_id, district_id,
                           is_active, must_change_password, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))`).run(
        String(b.name).trim(), email, optionalPhone(b.phone), optionalTitle(b.title),
        bcrypt.hashSync(password, 10), b.role,
        scope.region_id, scope.province_id, scope.district_id,
        parseBoolFlag(b.is_active) ?? 1, mustChange
      );
      const row = getOne(lastInsertRowid);
      auditLog(db, {
        entity: 'users', entityId: row.id, action: 'create', changedBy: req.user.id,
        changes: {
          name: row.name, email: row.email, phone: row.phone, title: row.title,
          role: row.role, region_id: row.region_id,
          province_id: row.province_id, district_id: row.district_id,
          must_change_password: row.must_change_password,
        },
      });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/users/:id', admin, (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Kullanıcı bulunamadı');
      const b = req.body || {};
      const email = b.email !== undefined ? String(b.email).trim().toLowerCase() : before.email;
      if (!EMAIL_RE.test(email)) throw badRequest('E-posta biçimi geçersiz');
      const dupe = db.prepare('SELECT id FROM users WHERE email = ? AND id <> ?').get(email, before.id);
      if (dupe) throw conflict('Bu e-posta ile kayıtlı bir kullanıcı zaten var');
      const role = b.role !== undefined ? b.role : before.role;
      if (!ROLES.includes(role)) throw badRequest(`role şunlardan biri olmalı: ${ROLES.join(', ')}`);
      // Son aktif genel merkez hesabının rolü düşürülemez.
      if (before.role === 'genel_merkez' && role !== 'genel_merkez'
        && before.is_active === 1 && activeAdminCount(before.id) === 0) {
        throw new ApiError(409, 'LAST_ADMIN', 'Sistemdeki son genel merkez hesabının rolü değiştirilemez');
      }
      const scope = validateScope(b, before);

      db.prepare(`
        UPDATE users SET name = ?, email = ?, phone = ?, title = ?, role = ?,
          region_id = ?, province_id = ?, district_id = ?,
          updated_at = datetime('now') WHERE id = ?`).run(
        b.name !== undefined ? String(b.name).trim() : before.name,
        email,
        b.phone !== undefined ? optionalPhone(b.phone) : before.phone,
        b.title !== undefined ? optionalTitle(b.title) : before.title,
        role, scope.region_id, scope.province_id, scope.district_id, before.id
      );
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'users', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.patch('/users/:id/active', admin, (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Kullanıcı bulunamadı');
      const flag = parseBoolFlag((req.body || {}).is_active);
      if (flag === undefined) throw badRequest("'is_active' alanı zorunludur");
      if (flag === 0 && before.role === 'genel_merkez' && activeAdminCount(before.id) === 0) {
        throw new ApiError(409, 'LAST_ADMIN', 'Sistemdeki son aktif genel merkez hesabı pasifleştirilemez');
      }
      db.prepare("UPDATE users SET is_active = ?, updated_at = datetime('now') WHERE id = ?")
        .run(flag, before.id);
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'users', entityId: before.id, action: 'active_toggle', changedBy: req.user.id,
        changes: { is_active: { old: before.is_active, new: flag } },
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.put('/users/:id/password', admin, (req, res, next) => {
    try {
      const user = getOne(req.params.id);
      if (!user) throw notFound('Kullanıcı bulunamadı');
      const password = checkPassword((req.body || {}).password);
      // Yönetici sıfırlaması: yeni şifreyi yönetici biliyor → kullanıcı ilk girişinde
      // yeniden değiştirmek ZORUNDA. Bayrak burada tekrar kurulur.
      const mustChange = parseBoolFlag((req.body || {}).must_change_password) ?? 1;
      db.prepare(`UPDATE users SET password_hash = ?, must_change_password = ?,
          updated_at = datetime('now') WHERE id = ?`)
        .run(bcrypt.hashSync(password, 10), mustChange, user.id);
      // Şifrenin kendisi ASLA günlüğe yazılmaz.
      auditLog(db, {
        entity: 'users', entityId: user.id, action: 'password_reset', changedBy: req.user.id,
        changes: { password: 'değiştirildi', must_change_password: mustChange },
      });
      res.json({ ok: true });
    } catch (e) { next(e); }
  });

  return r;
}

/**
 * Kendi profilinden teşkilat (bölge/il/ilçe) güncellemesi.
 *
 * Yönetici ucundaki `validateScope`'tan FARKLIDIR: burada bölge her zaman
 * `provinces.region_id` üzerinden TÜRETİLİR (bkz. `v2.js resolveGeo` /
 * `routes/documents.js resolveScope`'taki aynı kural) — kullanıcı "Ankara / Marmara"
 * gibi imkânsız bir teşkilat tanımlayamaz. Gönderilmeyen alan DEĞİŞMEZ (diğer
 * kendi-profil alanlarıyla aynı kısmi güncelleme davranışı); il yoksa (bölge-only ya
 * da teşkilatsız kapsam) bölge olduğu gibi korunur.
 */
function resolveSelfScope(db, body, existing) {
  const has = (k) => Object.prototype.hasOwnProperty.call(body, k);

  const provinceId = has('province_id')
    ? optionalInt(body.province_id, 'province_id')
    : (existing.province_id ?? null);
  if (provinceId !== null && !db.prepare('SELECT id FROM provinces WHERE id = ?').get(provinceId)) {
    throw badRequest('province_id geçersiz');
  }

  const districtId = has('district_id')
    ? optionalInt(body.district_id, 'district_id')
    : (existing.district_id ?? null);
  if (districtId !== null) {
    const dist = db.prepare('SELECT id, province_id FROM districts WHERE id = ?').get(districtId);
    if (!dist) throw badRequest('district_id geçersiz');
    if (provinceId === null) {
      throw badRequest("İlçe kapsamı verebilmek için 'province_id' de gönderilmelidir");
    }
    if (dist.province_id !== provinceId) {
      throw badRequest('İlçe, seçilen ile ait değil');
    }
  }

  const derivedRegion = provinceId !== null
    ? (db.prepare('SELECT region_id FROM provinces WHERE id = ?').get(provinceId)?.region_id ?? null)
    : null;

  let regionId;
  if (has('region_id')) {
    regionId = optionalInt(body.region_id, 'region_id');
    if (regionId !== null && !db.prepare('SELECT id FROM regions WHERE id = ?').get(regionId)) {
      throw badRequest('region_id geçersiz');
    }
    if (provinceId !== null && regionId !== derivedRegion) {
      throw badRequest('Seçilen il, gönderilen bölgeye ait değil');
    }
  } else {
    regionId = provinceId !== null ? derivedRegion : (existing.region_id ?? null);
  }

  return { region_id: regionId, province_id: provinceId, district_id: districtId };
}

/**
 * Kullanıcının kendisiyle ilgili uçları (rol farketmez).
 *
 * `GET /auth/me` ve `POST /auth/change-password` `must_change_password` kapısının
 * DIŞINDA tutulur (bkz. `src/auth.js`): biri kilidin sebebini gösterir, diğeri kilidi
 * açar. v2.3'te eklenen profil uçları (`PATCH /auth/me`, `/auth/me/avatar`) kapının
 * İÇİNDEDİR — bayrak açıkken önce şifre değiştirilir, profil sonra düzenlenir.
 */
export function selfRoutes(db) {
  const r = Router();
  const readSelf = (id) => withAvatar(db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE u.id = ?`).get(id));

  // Oturumdaki kullanıcı. `must_change_password` açıkken de erişilebilir olmalı;
  // istemci "şifrenizi değiştirin" ekranını buna bakarak açar.
  r.get('/auth/me', (req, res, next) => {
    try {
      const row = readSelf(req.user.id);
      if (!row) throw notFound('Kullanıcı bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  /**
   * Kendi profilini düzenleme (v2.3 — müşterinin birebir isteği).
   *
   * *"her kullanıcı kendi profilini düzenleyebilmeli … şifresinin yanı sıra ismini,
   * teşkilatını vesaire. Bu konularda esneklik ve özgürlük önemli."*
   *
   * Bu yüzden alan listesi CÖMERTTİR: ad, e-posta, telefon, unvan ve teşkilat
   * (bölge/il/ilçe) kullanıcının kendi tasarrufundadır. Sınır tek bir yerdedir ve
   * serttir: KİMLİĞİNİ ve YETKİSİNİ kendisi yazamaz (`SELF_FORBIDDEN`).
   *
   * Coğrafya doğrulaması dokümanlardaki kuralla aynıdır: ilçe verilirse ili türetilir,
   * il verilirse bölgesi `provinces.region_id` üzerinden TÜRETİLİR. Gönderilen bölge
   * türetilenle çelişirse istek reddedilir — kullanıcı "Ankara / Marmara" gibi
   * imkânsız bir teşkilat tanımlayamaz.
   */
  r.patch('/auth/me', (req, res, next) => {
    try {
      const b = req.body || {};
      const before = readSelf(req.user.id);
      if (!before) throw notFound('Kullanıcı bulunamadı');

      // --- YETKİ SINIRI: sessizce yok saymak yerine AÇIKÇA REDDET -------------
      const offending = SELF_FORBIDDEN.filter((k) => Object.prototype.hasOwnProperty.call(b, k));
      if (offending.length > 0) {
        // Deneme denetim izine yazılır: bir `saha` hesabının kendini `genel_merkez`
        // yapmaya çalışması sessiz bir 400 olarak kaybolmamalı, GÖRÜNMELİDİR.
        auditLog(db, {
          entity: 'users', entityId: before.id, action: 'self_update_rejected',
          changedBy: req.user.id,
          changes: {
            rejected_fields: offending,
            attempted: Object.fromEntries(offending.map(
              (k) => [k, SECRET_KEYS.has(k) ? '(gizlendi)' : b[k]]
            )),
            current_role: before.role,
          },
        });
        throw new ApiError(400, 'FORBIDDEN_FIELD',
          `Bu alanlar kendi profilinizden değiştirilemez: ${offending.join(', ')}. `
          + 'Rol, hesap durumu ve şifre değişikliği bayrağı yalnız genel merkez '
          + 'tarafından; şifre ise POST /auth/change-password ile değiştirilir.');
      }

      // --- Alanlar (hepsi opsiyonel; gönderilmeyen alan DEĞİŞMEZ) -------------
      let name = before.name;
      if (b.name !== undefined) {
        name = optionalText(b.name);
        if (!name) throw badRequest("'name' alanı boş bırakılamaz");
      }

      let email = before.email;
      if (b.email !== undefined) {
        email = String(b.email).trim().toLowerCase();
        if (!EMAIL_RE.test(email)) throw badRequest('E-posta biçimi geçersiz');
        // E-posta giriş kimliğidir: benzersizliği burada da zorlanmalı, aksi halde
        // kullanıcı kendi hesabını başka bir hesabın kimliğiyle çakıştırabilirdi.
        if (db.prepare('SELECT id FROM users WHERE email = ? AND id <> ?').get(email, before.id)) {
          throw conflict('Bu e-posta ile kayıtlı bir kullanıcı zaten var');
        }
      }

      const phone = b.phone !== undefined ? optionalPhone(b.phone) : before.phone;
      const title = b.title !== undefined ? optionalTitle(b.title) : before.title;
      const scope = resolveSelfScope(db, b, before);

      db.prepare(`
        UPDATE users SET name = ?, email = ?, phone = ?, title = ?,
          region_id = ?, province_id = ?, district_id = ?, updated_at = datetime('now')
        WHERE id = ?`).run(
        name, email, phone, title,
        scope.region_id, scope.province_id, scope.district_id, before.id
      );
      const after = readSelf(before.id);
      // Her kendi-güncellemesi denetim izine yazılır (müşteri değişikliği kim yaptı
      // sorusunu kullanıcı yönetiminden de sorabilmeli).
      auditLog(db, {
        entity: 'users', entityId: before.id, action: 'self_update', changedBy: req.user.id,
        changes: diffChanges(before, after, SELF_FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  // ---------------------------------------------------------------- avatar
  // Yetki kuralının tam metni `src/avatars.js` başlığındadır. Buradaki iki uç
  // "kendi" halinin kısayoludur: hedef her zaman oturumdaki kullanıcıdır, dolayısıyla
  // başkasının fotoğrafına DOKUNULAMAZ (`entity_id` istemciden gelmez).
  r.post('/auth/me/avatar', avatarUpload(), (req, res, next) => {
    try {
      const { attachment } = storeAvatar(db, {
        targetUserId: req.user.id, file: req.file, actorId: req.user.id,
      });
      res.status(201).json({ ...readSelf(req.user.id), avatar: avatarBody(attachment) });
    } catch (e) { next(e); }
  });

  r.delete('/auth/me/avatar', (req, res, next) => {
    try {
      if (!currentAvatar(db, req.user.id)) throw notFound('Profil fotoğrafı bulunamadı');
      clearAvatar(db, { targetUserId: req.user.id, actorId: req.user.id });
      res.json(readSelf(req.user.id));
    } catch (e) { next(e); }
  });

  r.post('/auth/change-password', (req, res, next) => {
    try {
      const b = req.body || {};
      requireFields(b, ['current_password', 'new_password']);
      const row = db.prepare('SELECT id, password_hash FROM users WHERE id = ?').get(req.user.id);
      if (!row) throw notFound('Kullanıcı bulunamadı');
      // Mevcut şifre ZORUNLU: çalınmış bir token'la şifre ele geçirilemesin.
      if (!bcrypt.compareSync(String(b.current_password), row.password_hash)) {
        throw new ApiError(401, 'UNAUTHORIZED', 'Mevcut şifre hatalı');
      }
      const password = checkPassword(b.new_password);
      // "Değiştirdim" deyip aynı şifreyi yazmak zorunlu değişikliği anlamsız kılardı.
      if (bcrypt.compareSync(password, row.password_hash)) {
        throw new ApiError(400, 'WEAK_PASSWORD', 'Yeni şifre mevcut şifreden farklı olmalı');
      }
      db.prepare(`UPDATE users SET password_hash = ?, must_change_password = 0,
          updated_at = datetime('now') WHERE id = ?`)
        .run(bcrypt.hashSync(password, 10), row.id);
      auditLog(db, {
        entity: 'users', entityId: row.id, action: 'password_change', changedBy: req.user.id,
        changes: { password: 'değiştirildi', must_change_password: { old: 1, new: 0 } },
      });
      res.json({ ok: true });
    } catch (e) { next(e); }
  });
  return r;
}

// v2.1 öncesi ad — `app.js` dışında kullanan kalmadı, uyum için korunur.
export const selfPasswordRoute = selfRoutes;

export { toIntOrThrow };
