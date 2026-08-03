/**
 * K5 — Dosya ekleri.
 *
 * Güvenlik kararları:
 *  - İstemciden gelen dosya adı ASLA dosya sisteminde kullanılmaz. Sunucu `randomUUID()`
 *    ile ad üretir; uzantı MIME beyaz listesinden türetilir (istemci uzantısından değil).
 *  - Orijinal ad yalnız gösterim için, temizlenmiş halde saklanır.
 *  - İndirme yolu her zaman UPLOAD_DIR + basename(stored_name) olarak yeniden kurulur ve
 *    UPLOAD_DIR içinde kaldığı doğrulanır (path traversal koruması).
 *  - 10 MB sınırı ve MIME beyaz listesi multer katmanında zorlanır.
 *  - Yol/ad üretimi tek yerden gelir: `src/storage.js`.
 *
 * v2.3 istisnası — `entity='users'` (profil fotoğrafı): genel sınırlar DEĞİL, `src/avatars.js`
 * içindeki dar kurallar geçerlidir (yalnız JPEG/PNG/WEBP, 2 MB, kullanıcı başına tek dosya,
 * sahiplik kontrolü). Yetki kuralının tam metni o dosyanın başlığındadır.
 */
import fs from 'node:fs';
import { Router } from 'express';
import multer from 'multer';
import { auditLog } from '../audit.js';
import { MAX_UPLOAD_BYTES } from '../config.js';
import { ApiError, badRequest, notFound, listQuery, toIntOrThrow } from '../helpers.js';
import {
  AVATAR_ENTITY, assertAvatarKind, assertMayWriteAvatar, avatarBody,
  clearAvatar, mayReadAvatar, storeAvatar,
} from '../avatars.js';
import {
  UPLOAD_DIR, newStoredName, removeStoredFile, safeDisplayName, storedPath, writeStoredFile,
} from '../storage.js';

const KINDS = ['fotograf', 'dokuman', 'tutanak', 'sunum', 'katilim_listesi'];

// Hangi varlığa ek yüklenebilir → tablo adı doğrulaması (SQL'e serbest metin gitmez).
const ENTITIES = {
  tasks: 'tasks',
  trainings: 'trainings',
  events: 'events',
  meetings: 'meetings',
  persons: 'persons',
  org_units: 'org_units',
  material_requests: 'material_requests',
  shipments: 'shipments',
  field_activities: 'field_activities',
  documents: 'documents', // SPEC-V2-M6: kılavuz/form dosyaları
  // v2.3 — profil fotoğrafı. Diğerlerinden AYRI kurallara tabidir (bkz. src/avatars.js):
  // yalnız görsel türleri, 2 MB sınırı, kullanıcı başına tek dosya ve sahiplik kontrolü.
  [AVATAR_ENTITY]: 'users',
};

// MIME → uzantı. Beyaz liste; buradaki dışında hiçbir tür kabul edilmez.
const ALLOWED_MIME = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'application/pdf': '.pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
};

const SELECT = `a.id, a.entity, a.entity_id, a.kind, a.file_name, a.mime, a.size,
  a.uploaded_by, u.name AS uploaded_by_name, a.created_at`;
const FROM = 'attachments a LEFT JOIN users u ON u.id = a.uploaded_by';

/**
 * Bir varlığın TÜM eklerini siler: hem `attachments` satırlarını hem diskteki dosyaları.
 * Varlık silinirken çağrılır — aksi halde diskte sahipsiz dosyalar birikir.
 * @returns silinen ek satırları (denetim izine yazmak için)
 */
export function deleteAttachmentsFor(db, entity, entityId) {
  const rows = db.prepare('SELECT * FROM attachments WHERE entity = ? AND entity_id = ?')
    .all(entity, entityId);
  if (rows.length === 0) return rows;
  db.prepare('DELETE FROM attachments WHERE entity = ? AND entity_id = ?').run(entity, entityId);
  for (const row of rows) removeStoredFile(row.stored_name);
  return rows;
}

export default function attachmentRoutes(db) {
  const r = Router();
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });

  const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: MAX_UPLOAD_BYTES, files: 1 },
    fileFilter: (_req, file, cb) => {
      if (!ALLOWED_MIME[file.mimetype]) {
        return cb(new ApiError(400, 'UNSUPPORTED_FILE_TYPE',
          `Bu dosya türü kabul edilmiyor: ${file.mimetype}. İzinli türler: `
          + 'JPEG, PNG, WEBP, GIF, PDF, DOCX, XLSX'));
      }
      return cb(null, true);
    },
  });

  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE a.id = ?`).get(id);

  /**
   * Avatar okuma kısıtı (v2.3 — bkz. src/avatars.js başlığı).
   *
   * `genel_merkez` kullanıcı yönetiminde herkesin fotoğrafını görebilmelidir; diğer
   * roller YALNIZ kendi avatarını görür. Bulunamadı (404) döndürülür, yasak (403)
   * DEĞİL: 403 "bu kimlikte bir ek var" bilgisini sızdırır ve `saha` bir kullanıcının
   * fotoğrafı olup olmadığını kimlik tarayarak öğrenebilirdi.
   *
   * Diğer varlıkların ek davranışı DEĞİŞMEDİ (geriye dönük uyum).
   */
  function assertReadable(req, row) {
    if (row.entity !== AVATAR_ENTITY) return row;
    if (!mayReadAvatar(req.user, row.entity_id)) throw notFound('Dosya eki bulunamadı');
    return row;
  }

  function resolveEntity(entity, entityId) {
    const table = ENTITIES[entity];
    if (!table) {
      throw badRequest(`'entity' şunlardan biri olmalı: ${Object.keys(ENTITIES).join(', ')}`);
    }
    const id = toIntOrThrow(entityId, 'entity_id');
    if (!db.prepare(`SELECT id FROM ${table} WHERE id = ?`).get(id)) {
      throw badRequest(`${entity} kaydı bulunamadı: ${id}`);
    }
    return { entity, entity_id: id };
  }

  r.get('/attachments', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      if (req.query.entity) {
        if (!ENTITIES[req.query.entity]) throw badRequest('entity filtresi geçersiz');
        where.push('a.entity = ?'); params.push(req.query.entity);
      }
      if (req.query.entity_id) { where.push('a.entity_id = ?'); params.push(toIntOrThrow(req.query.entity_id, 'entity_id')); }
      if (req.query.kind) {
        if (!KINDS.includes(req.query.kind)) throw badRequest('kind filtresi geçersiz');
        where.push('a.kind = ?'); params.push(req.query.kind);
      }
      // Avatar görünürlüğü SUNUCUDA kısıtlanır: `saha` filtre göndermese bile listede
      // başkasının profil fotoğrafını sayamaz. Diğer varlıklar etkilenmez.
      if (req.user.role !== 'genel_merkez') {
        where.push('(a.entity <> ? OR a.entity_id = ?)');
        params.push(AVATAR_ENTITY, req.user.id);
      }
      const result = listQuery(db, {
        select: SELECT, from: FROM, where, params, orderBy: 'a.id DESC', query: req.query,
      });
      result.data = result.data.map((row) => ({ ...row, download_url: `/api/v1/attachments/${row.id}/download` }));
      res.json(result);
    } catch (e) { next(e); }
  });

  r.get('/attachments/:id', (req, res, next) => {
    try {
      const row = getOne(req.params.id);
      if (!row) throw notFound('Dosya eki bulunamadı');
      assertReadable(req, row);
      res.json({ ...row, download_url: `/api/v1/attachments/${row.id}/download` });
    } catch (e) { next(e); }
  });

  r.get('/attachments/:id/download', (req, res, next) => {
    try {
      const row = db.prepare('SELECT * FROM attachments WHERE id = ?').get(req.params.id);
      if (!row) throw notFound('Dosya eki bulunamadı');
      assertReadable(req, row);

      // Yol her zaman yeniden kurulur; veritabanındaki `path` doğrudan kullanılmaz.
      const filePath = storedPath(row.stored_name);
      if (!fs.existsSync(filePath)) throw notFound('Dosya diskte bulunamadı');

      res.setHeader('Content-Type', row.mime);
      res.setHeader('X-Content-Type-Options', 'nosniff');
      // Profil fotoğrafı GÖSTERİLMEK içindir, indirilmek için değil: `inline` olmadan
      // tarayıcı her avatarı dosya olarak kaydetmeye çalışır. `nosniff` ile birlikte
      // yalnız beyaz listedeki görsel türleri bu yolu kullanabildiği için güvenlidir.
      const disposition = row.entity === AVATAR_ENTITY ? 'inline' : 'attachment';
      res.setHeader(
        'Content-Disposition',
        `${disposition}; filename="${row.stored_name}"; filename*=UTF-8''${encodeURIComponent(row.file_name)}`
      );
      fs.createReadStream(filePath).pipe(res);
    } catch (e) { next(e); }
  });

  r.post('/attachments', upload.single('file'), (req, res, next) => {
    try {
      if (!req.file || !req.file.buffer) {
        throw badRequest("Dosya gerekli: multipart 'file' alanında yükleyin");
      }
      const b = req.body || {};
      // Avatar (entity='users') GENEL ek kurallarına DEĞİL, kendi dar kurallarına tabidir:
      // sahiplik kontrolü, yalnız görsel türleri, 2 MB ve kullanıcı başına tek dosya.
      // Bu yüzden ortak doğrulamadan ÖNCE ayrılır (bkz. src/avatars.js).
      if (b.entity === AVATAR_ENTITY) {
        const target = resolveEntity(b.entity, b.entity_id);
        assertMayWriteAvatar(req.user, target.entity_id);
        assertAvatarKind(b.kind);
        const { attachment } = storeAvatar(db, {
          targetUserId: target.entity_id, file: req.file, actorId: req.user.id,
        });
        const created = getOne(attachment.id);
        return res.status(201).json({
          ...created,
          download_url: `/api/v1/attachments/${created.id}/download`,
          avatar: avatarBody(attachment),
        });
      }

      const kind = b.kind;
      if (!KINDS.includes(kind)) throw badRequest(`'kind' şunlardan biri olmalı: ${KINDS.join(', ')}`);
      const target = resolveEntity(b.entity, b.entity_id);

      const storedName = newStoredName(ALLOWED_MIME[req.file.mimetype]);
      writeStoredFile(storedName, req.file.buffer);

      const { lastInsertRowid } = db.prepare(`
        INSERT INTO attachments (entity, entity_id, kind, file_name, stored_name, mime, size, path, uploaded_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
        target.entity, target.entity_id, kind,
        safeDisplayName(req.file.originalname), storedName,
        req.file.mimetype, req.file.size, storedName, req.user.id
      );
      const row = getOne(lastInsertRowid);
      auditLog(db, { entity: 'attachments', entityId: row.id, action: 'create', changedBy: req.user.id, changes: row });
      res.status(201).json({ ...row, download_url: `/api/v1/attachments/${row.id}/download` });
    } catch (e) { next(e); }
  });

  r.delete('/attachments/:id', (req, res, next) => {
    try {
      const row = db.prepare('SELECT * FROM attachments WHERE id = ?').get(req.params.id);
      if (!row) throw notFound('Dosya eki bulunamadı');
      // Avatarda ölçüt YÜKLEYEN değil SAHİPTİR: fotoğrafı yönetici yüklemiş olsa bile
      // kullanıcı kendi fotoğrafını kaldırabilmelidir (müşteri: "esneklik ve özgürlük").
      if (row.entity === AVATAR_ENTITY) {
        assertMayWriteAvatar(req.user, row.entity_id);
        clearAvatar(db, { targetUserId: row.entity_id, actorId: req.user.id });
        return res.status(204).end();
      }
      // Yükleyen kendi ekini silebilir; genel merkez her eki silebilir.
      if (req.user.role !== 'genel_merkez' && row.uploaded_by !== req.user.id) {
        throw new ApiError(403, 'FORBIDDEN', 'Yalnız kendi yüklediğiniz eki silebilirsiniz');
      }
      db.prepare('DELETE FROM attachments WHERE id = ?').run(row.id);
      removeStoredFile(row.stored_name);
      auditLog(db,{ entity: 'attachments', entityId: row.id, action: 'delete', changedBy: req.user.id, changes: row });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  return r;
}
