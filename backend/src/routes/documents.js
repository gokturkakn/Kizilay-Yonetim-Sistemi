/**
 * SPEC-V2-M6 — Kılavuz ve Dokümanlar (§4).
 *
 * İki dik eksen:
 *  - TÜR    → `category_id` (K1 tanımları, `dokuman_kategorisi`)
 *  - KAPSAM → `scope` (genel | bolge | il | ilce) + coğrafya alanları
 *
 * Yetki kuralları:
 *  - Yazma (ekleme/güncelleme/yayından kaldırma/silme) yalnız `genel_merkez`.
 *  - `saha` rolü YALNIZ yayındaki (`is_active = 1`) dokümanları görür. Bu kısıt
 *    SUNUCUDA zorlanır; istemcinin filtre göndermesine güvenilmez (saha'nın
 *    `is_active` parametresi bilinçli olarak yok sayılır).
 */
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  badRequest, notFound, listQuery, parseBoolFlag, requireFields, toIntOrThrow,
} from '../helpers.js';
import {
  resolveGeo, requireLookup, optionalText, optionalDate, attachmentCountSql, trLower,
} from '../v2.js';
import { deleteAttachmentsFor } from './attachments.js';

export const SCOPES = ['genel', 'bolge', 'il', 'ilce'];
export const SCOPE_TR = { genel: 'Genel', bolge: 'Bölge', il: 'İl', ilce: 'İlçe' };

// Kapsam rozeti (UX §5.3): "Genel" / "<Bölge adı>" / "<İl adı>" / "<İlçe adı>".
// İlçe kapsamı il ve bölgeyi de doldurduğu için COALESCE en dar kırılımı seçer.
const SCOPE_LABEL = "COALESCE(di.name, pr.name, rg.name, 'Genel') AS scope_label";
// "Süresi doldu" rozeti — son geçerlilik tarihi geçmiş matbu belgeler için.
const EXPIRED = `CASE WHEN d.valid_until IS NOT NULL AND d.valid_until < date('now')
  THEN 1 ELSE 0 END AS is_expired`;
// Kapsam darlığı: 1 = en dar (ilçe) … 4 = en geniş (genel).
// `applicable_to` görünümünde sıralama buna göre yapılır (bkz. aşağıdaki not).
const SCOPE_RANK = `CASE d.scope WHEN 'ilce' THEN 1 WHEN 'il' THEN 2 WHEN 'bolge' THEN 3
  ELSE 4 END AS scope_rank`;

const SELECT = `d.id, d.title, d.description, d.category_id, cat.name AS category_name,
  d.scope, ${SCOPE_LABEL}, ${SCOPE_RANK}, d.region_id, d.province_id, d.district_id,
  rg.name AS region_name, pr.name AS province_name, di.name AS district_name,
  d.version, d.published_at, d.valid_until, ${EXPIRED},
  d.is_active, d.download_count,
  ${attachmentCountSql('documents', 'd')},
  d.created_by, u.name AS created_by_name, d.created_at, d.updated_at`;

const FROM = `documents d
  JOIN lookup_items cat ON cat.id = d.category_id
  LEFT JOIN regions rg ON rg.id = d.region_id
  LEFT JOIN provinces pr ON pr.id = d.province_id
  LEFT JOIN districts di ON di.id = d.district_id
  LEFT JOIN users u ON u.id = d.created_by`;

const FIELDS = ['title', 'description', 'category_id', 'scope', 'region_id', 'province_id',
  'district_id', 'version', 'published_at', 'valid_until', 'is_active'];

const ATTACHMENT_SELECT = `a.id, a.kind, a.file_name, a.mime, a.size,
  a.uploaded_by, u.name AS uploaded_by_name, a.created_at`;

/**
 * Kapsam doğrulaması (SPEC-V2-M6 §2.2).
 *
 *  genel → üç coğrafya alanı da BOŞ olmalı
 *  bolge → region_id zorunlu, il/ilçe boş
 *  il    → province_id zorunlu, ilçe boş
 *  ilce  → district_id zorunlu ve seçilen ile ait olmalı
 *
 * il/ilçe kapsamında bölge (ve ilçe kapsamında il) `provinces.region_id` üzerinden
 * TÜRETİLİR — v2'nin tek doğru kaynak kuralı (bkz. v2.js resolveGeo). Böylece
 * "Marmara bölgesine ait dokümanlar" sorgusu il/ilçe kapsamlı belgeleri de kapsar.
 * Gönderilen bölge türetilenle çelişirse istek reddedilir.
 */
function resolveScope(db, scope, raw) {
  if (!SCOPES.includes(scope)) {
    throw badRequest(`'scope' şunlardan biri olmalı: ${SCOPES.join(', ')}`);
  }
  const has = (k) => raw[k] !== undefined && raw[k] !== null && raw[k] !== '';
  const empty = { region_id: null, province_id: null, district_id: null };

  if (scope === 'genel') {
    if (has('region_id') || has('province_id') || has('district_id')) {
      throw badRequest("Kapsam 'Genel' seçildiğinde bölge, il ve ilçe boş bırakılmalıdır");
    }
    return { scope, ...empty };
  }

  if (scope === 'bolge') {
    if (!has('region_id')) throw badRequest("Kapsam 'Bölge' seçildiğinde 'region_id' zorunludur");
    if (has('province_id') || has('district_id')) {
      throw badRequest("Kapsam 'Bölge' seçildiğinde il ve ilçe boş bırakılmalıdır");
    }
    const regionId = toIntOrThrow(raw.region_id, 'region_id');
    if (!db.prepare('SELECT id FROM regions WHERE id = ?').get(regionId)) {
      throw badRequest('region_id geçersiz');
    }
    return { scope, ...empty, region_id: regionId };
  }

  if (scope === 'il') {
    if (!has('province_id')) throw badRequest("Kapsam 'İl' seçildiğinde 'province_id' zorunludur");
    if (has('district_id')) throw badRequest("Kapsam 'İl' seçildiğinde ilçe boş bırakılmalıdır");
  } else if (!has('district_id')) {
    throw badRequest("Kapsam 'İlçe' seçildiğinde 'district_id' zorunludur");
  }

  const geo = resolveGeo(db, {
    region_id: has('region_id') ? raw.region_id : null,
    province_id: has('province_id') ? raw.province_id : null,
    district_id: has('district_id') ? raw.district_id : null,
  }, { requireProvince: scope === 'il' });

  const derivedRegion = db.prepare('SELECT region_id FROM provinces WHERE id = ?')
    .get(geo.province_id)?.region_id ?? null;
  if (has('region_id') && geo.region_id !== derivedRegion) {
    throw badRequest('Seçilen il, gönderilen bölgeye ait değil');
  }
  return {
    scope,
    region_id: derivedRegion,
    province_id: geo.province_id,
    district_id: scope === 'ilce' ? geo.district_id : null,
  };
}

const APPLICABLE_RE = /^(region|province|district):(\d+)$/;
const APPLICABLE_FORMAT = "'applicable_to' 'region:<id>', 'province:<id>' veya "
  + "'district:<id>' biçiminde olmalı";

/**
 * "Bana uygulanan dokümanlar" görünümü.
 *
 * Çankaya'daki bir gönüllü kütüphaneyi açtığında kendisini ilgilendiren HER ŞEYİ görmeli:
 * ülke geneli kılavuz + İç Anadolu genelgesi + Ankara formu + Çankaya belgesi. Bunu
 * birebir eşleşen filtrelerle (`?province_id=`) kurmak istemciye dört ayrı sorgu yaptırır
 * ve bir kırılımı unutan istemci belgeyi kaçırır — bu yüzden birleştirme SUNUCUDA yapılır.
 *
 * Birebir eşleşen `region_id`/`province_id`/`district_id` filtreleri OLDUĞU GİBİ kalır;
 * onlar yönetim ekranlarının ve "Yalnız bana ait olanlar" anahtarının kullandığı moddur
 * (o anahtar `genel` kapsamı HARİÇ tutar, dolayısıyla birebir eşleşme doğrudur).
 */
function applicableFilter(db, raw) {
  const m = APPLICABLE_RE.exec(String(raw).trim());
  if (!m) throw badRequest(APPLICABLE_FORMAT);
  const [, level, rawId] = m;
  const id = Number(rawId);

  if (level === 'region') {
    if (!db.prepare('SELECT id FROM regions WHERE id = ?').get(id)) {
      throw badRequest(`applicable_to: bölge bulunamadı (${id})`);
    }
    // Bölge/il/ilçe kapsamlarının hepsinde region_id doludur (il üzerinden türetilir),
    // bu yüzden tek koşul bölgenin altındaki tüm il ve ilçeleri de kapsar.
    return { sql: "(d.scope = 'genel' OR d.region_id = ?)", params: [id] };
  }

  if (level === 'province') {
    const p = db.prepare('SELECT id, region_id FROM provinces WHERE id = ?').get(id);
    if (!p) throw badRequest(`applicable_to: il bulunamadı (${id})`);
    // İl düzeyindeki kullanıcı kendi ilçelerine ait belgeleri de görür.
    return {
      sql: `(d.scope = 'genel'
             OR (d.scope = 'bolge' AND d.region_id = ?)
             OR (d.scope IN ('il', 'ilce') AND d.province_id = ?))`,
      params: [p.region_id, p.id],
    };
  }

  const dis = db.prepare(`
    SELECT di.id, di.province_id, pr.region_id
    FROM districts di JOIN provinces pr ON pr.id = di.province_id
    WHERE di.id = ?`).get(id);
  if (!dis) throw badRequest(`applicable_to: ilçe bulunamadı (${id})`);
  return {
    sql: `(d.scope = 'genel'
           OR (d.scope = 'bolge' AND d.region_id = ?)
           OR (d.scope = 'il' AND d.province_id = ?)
           OR (d.scope = 'ilce' AND d.district_id = ?))`,
    params: [dis.region_id, dis.province_id, dis.id],
  };
}

export default function documentRoutes(db) {
  const r = Router();
  const admin = requireRole('genel_merkez');
  const isHq = (req) => req.user.role === 'genel_merkez';

  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE d.id = ?`).get(id);

  /** Saha rolü yayından kaldırılmış dokümanı hiç göremez — 404 (varlığını sızdırmayız). */
  function getVisible(req, id) {
    const row = getOne(id);
    if (!row) throw notFound('Doküman bulunamadı');
    if (!isHq(req) && row.is_active !== 1) throw notFound('Doküman bulunamadı');
    return row;
  }

  /**
   * Liste satırlarına kompakt dosya özeti ekler.
   *
   * Önceden liste yalnız `attachment_count` döndürüyordu; istemci dosya türünü ve
   * boyutunu göstermek için ayrıca `GET /attachments?entity=documents` çağırmak
   * zorundaydı — mobil şebekede sayfa başına ikinci bir gidiş-dönüş. Tek bir
   * `IN (...)` sorgusuyla toplanır (satır başına sorgu YOK, N+1 üretmez).
   *
   * `attachment_count` KALDIRILMADI: mevcut istemciler onu okuyor (geriye dönük uyum).
   */
  function withFiles(rows) {
    if (rows.length === 0) return rows;
    const ids = rows.map((row) => row.id);
    const files = db.prepare(`
      SELECT a.entity_id, a.id, a.mime, a.size, a.file_name
      FROM attachments a
      WHERE a.entity = 'documents' AND a.entity_id IN (${ids.map(() => '?').join(',')})
      ORDER BY a.id`).all(...ids);
    const byDocument = new Map();
    for (const f of files) {
      const list = byDocument.get(f.entity_id) || [];
      list.push({ id: f.id, mime: f.mime, size: f.size, file_name: f.file_name });
      byDocument.set(f.entity_id, list);
    }
    return rows.map((row) => ({ ...row, files: byDocument.get(row.id) || [] }));
  }

  const listAttachments = (documentId) => db.prepare(`
    SELECT ${ATTACHMENT_SELECT} FROM attachments a
    LEFT JOIN users u ON u.id = a.uploaded_by
    WHERE a.entity = 'documents' AND a.entity_id = ?
    ORDER BY a.id`).all(documentId)
    .map((a) => ({ ...a, download_url: `/api/v1/attachments/${a.id}/download` }));

  function validate(body, existing = null) {
    const pick = (k) => (body[k] !== undefined ? body[k] : existing?.[k]);

    const title = optionalText(pick('title'));
    if (!title) throw badRequest("'title' alanı zorunludur");
    const category = requireLookup(db, pick('category_id'), 'dokuman_kategorisi', 'category_id');

    // Kapsam değiştiyse eski coğrafya alanları TAŞINMAZ: 'il' iken 'genel'e çekilen bir
    // doküman province_id'sini üstünde taşıyamaz (aksi halde doğrulama kuralı delinir).
    const scope = body.scope !== undefined ? String(body.scope) : (existing?.scope ?? 'genel');
    const scopeChanged = existing !== null && scope !== existing.scope;
    const geoRaw = {};
    for (const k of ['region_id', 'province_id', 'district_id']) {
      if (body[k] !== undefined) geoRaw[k] = body[k];
      else if (!scopeChanged && existing) geoRaw[k] = existing[k];
    }

    const validUntil = optionalDate(pick('valid_until'), 'valid_until');
    const publishedAt = optionalDate(pick('published_at'), 'published_at');
    if (publishedAt && validUntil && validUntil < publishedAt) {
      throw badRequest("'valid_until' yayın tarihinden önce olamaz");
    }

    return {
      title,
      description: optionalText(pick('description')),
      category_id: category.id,
      ...resolveScope(db, scope, geoRaw),
      version: optionalText(pick('version')),
      published_at: publishedAt,
      valid_until: validUntil,
      is_active: parseBoolFlag(body.is_active) ?? existing?.is_active ?? 1,
    };
  }

  // ------------------------------------------------------------------ liste
  r.get('/documents', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      // İki mod birbirini dışlar: ya birebir eşleşme ya "bana uygulananlar".
      // Sessizce birini yok saymak yerine açıkça reddedilir.
      const exactGeo = ['region_id', 'province_id', 'district_id'].filter((k) => req.query[k]);
      if (req.query.applicable_to && exactGeo.length > 0) {
        throw badRequest(
          `'applicable_to' ile ${exactGeo.join('/')} filtresi birlikte kullanılamaz; `
          + 'ya kapsam eşleşmesi ya da "bana uygulananlar" modunu seçin'
        );
      }
      let applicable = null;
      if (req.query.applicable_to) {
        applicable = applicableFilter(db, req.query.applicable_to);
        where.push(applicable.sql); params.push(...applicable.params);
      }
      for (const [q, col] of [['category_id', 'd.category_id'], ['region_id', 'd.region_id'],
        ['province_id', 'd.province_id'], ['district_id', 'd.district_id']]) {
        if (req.query[q]) { where.push(`${col} = ?`); params.push(toIntOrThrow(req.query[q], q)); }
      }
      if (req.query.scope) {
        if (!SCOPES.includes(req.query.scope)) {
          throw badRequest(`'scope' filtresi şunlardan biri olmalı: ${SCOPES.join(', ')}`);
        }
        where.push('d.scope = ?'); params.push(req.query.scope);
      }
      if (req.query.q) {
        where.push("(tr_lower(d.title) LIKE ? OR tr_lower(COALESCE(d.description, '')) LIKE ?)");
        const like = `%${trLower(req.query.q)}%`;
        params.push(like, like);
      }
      const active = parseBoolFlag(req.query.is_active);
      if (active !== undefined) { where.push('d.is_active = ?'); params.push(active); }
      // Görünürlük kısıtı SUNUCUDA eklenir; istemcinin filtre göndermesine güvenilmez.
      // Saha `is_active=0` gönderirse iki koşul çelişir ve boş liste döner — doğrusu budur:
      // "yayından kaldırılmış belgeleriniz yok", sessizce yayındakileri göstermek değil.
      if (!isHq(req)) where.push('d.is_active = 1');

      // "Bana uygulananlar" görünümünde EN DARDAN EN GENİŞE sıralanır (ilçe → il → bölge →
      // genel): kullanıcının konumuna en özel belge en üstte çıkar. Birebir eşleşen listede
      // tek kapsam olduğu için sıralama yayın tarihine göre kalır (envanter görünümü).
      const orderBy = applicable
        ? `scope_rank, COALESCE(d.published_at, '0000-00-00') DESC, d.id DESC`
        : "COALESCE(d.published_at, '0000-00-00') DESC, d.id DESC";
      const result = listQuery(db, {
        select: SELECT, from: FROM, where, params, orderBy, query: req.query,
      });
      res.json({ ...result, data: withFiles(result.data) });
    } catch (e) { next(e); }
  });

  r.get('/documents/:id', (req, res, next) => {
    try {
      const row = getVisible(req, req.params.id);
      // Tek kayıtta `attachments` (tam model) ve `files` (kompakt özet) birlikte döner;
      // liste ve detay ekranı aynı alanı okuyabilsin diye.
      res.json({ ...withFiles([row])[0], attachments: listAttachments(row.id) });
    } catch (e) { next(e); }
  });

  // ------------------------------------------------------------------ yazma
  r.post('/documents', admin, (req, res, next) => {
    try {
      requireFields(req.body || {}, ['title', 'category_id']);
      const p = validate(req.body);
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO documents (title, description, category_id, scope, region_id, province_id,
          district_id, version, published_at, valid_until, is_active, created_by)
        VALUES (@title, @description, @category_id, @scope, @region_id, @province_id,
          @district_id, @version, @published_at, @valid_until, @is_active, @created_by)`)
        .run({ ...p, created_by: req.user.id });
      const row = getOne(lastInsertRowid);
      auditLog(db, { entity: 'documents', entityId: row.id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json({ ...row, attachments: [] });
    } catch (e) { next(e); }
  });

  r.put('/documents/:id', admin, (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Doküman bulunamadı');
      const p = validate(req.body || {}, before);
      db.prepare(`
        UPDATE documents SET title=@title, description=@description, category_id=@category_id,
          scope=@scope, region_id=@region_id, province_id=@province_id, district_id=@district_id,
          version=@version, published_at=@published_at, valid_until=@valid_until,
          is_active=@is_active, updated_at=datetime('now')
        WHERE id=@id`).run({ ...p, id: before.id });
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'documents', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json({ ...after, attachments: listAttachments(after.id) });
    } catch (e) { next(e); }
  });

  // Yayından kaldırma — SİLME DEĞİLDİR, kayıt ve geçmiş korunur (§3).
  r.patch('/documents/:id/active', admin, (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Doküman bulunamadı');
      const flag = parseBoolFlag((req.body || {}).is_active);
      if (flag === undefined) throw badRequest("'is_active' alanı zorunludur");
      db.prepare("UPDATE documents SET is_active = ?, updated_at = datetime('now') WHERE id = ?")
        .run(flag, before.id);
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'documents', entityId: before.id, action: 'active_toggle', changedBy: req.user.id,
        changes: { is_active: { old: before.is_active, new: flag } },
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.delete('/documents/:id', admin, (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Doküman bulunamadı');
      // Ek satırları VE diskteki dosyalar birlikte gider — sahipsiz dosya kalmaz.
      const removed = deleteAttachmentsFor(db, 'documents', before.id);
      db.prepare('DELETE FROM documents WHERE id = ?').run(before.id);
      auditLog(db, {
        entity: 'documents', entityId: before.id, action: 'delete', changedBy: req.user.id,
        changes: { ...before, deleted_attachments: removed.map((a) => a.id) },
      });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  // İndirme sayacı — istemci dosyayı çekmeden ÖNCE çağırır (§4).
  // Hangi belgenin gerçekten kullanıldığını görmek için; saha da çağırabilir.
  r.post('/documents/:id/download', (req, res, next) => {
    try {
      const before = getVisible(req, req.params.id);
      db.prepare('UPDATE documents SET download_count = download_count + 1 WHERE id = ?').run(before.id);
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'documents', entityId: before.id, action: 'download', changedBy: req.user.id,
        changes: { download_count: { old: before.download_count, new: after.download_count } },
      });
      res.json({ id: after.id, download_count: after.download_count, attachments: listAttachments(after.id) });
    } catch (e) { next(e); }
  });

  return r;
}
