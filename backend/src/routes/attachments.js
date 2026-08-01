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
 */
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { Router } from 'express';
import multer from 'multer';
import { auditLog } from '../audit.js';
import { UPLOAD_DIR, MAX_UPLOAD_BYTES } from '../config.js';
import { ApiError, badRequest, notFound, listQuery, toIntOrThrow } from '../helpers.js';

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

/** Görüntüleme adını temizler: dizin bileşenleri ve kontrol karakterleri atılır. */
function safeDisplayName(original) {
  const base = path.basename(String(original || 'dosya'));
  const cleaned = base.replace(/[\u0000-\u001f\u007f/\\"]/g, '_').trim();
  return (cleaned || 'dosya').slice(0, 180);
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
      res.json({ ...row, download_url: `/api/v1/attachments/${row.id}/download` });
    } catch (e) { next(e); }
  });

  r.get('/attachments/:id/download', (req, res, next) => {
    try {
      const row = db.prepare('SELECT * FROM attachments WHERE id = ?').get(req.params.id);
      if (!row) throw notFound('Dosya eki bulunamadı');

      // Yol her zaman yeniden kurulur; veritabanındaki `path` doğrudan kullanılmaz.
      const filePath = path.join(UPLOAD_DIR, path.basename(row.stored_name));
      if (path.dirname(path.resolve(filePath)) !== path.resolve(UPLOAD_DIR)) {
        throw new ApiError(400, 'VALIDATION_ERROR', 'Geçersiz dosya yolu');
      }
      if (!fs.existsSync(filePath)) throw notFound('Dosya diskte bulunamadı');

      res.setHeader('Content-Type', row.mime);
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="${row.stored_name}"; filename*=UTF-8''${encodeURIComponent(row.file_name)}`
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
      const kind = b.kind;
      if (!KINDS.includes(kind)) throw badRequest(`'kind' şunlardan biri olmalı: ${KINDS.join(', ')}`);
      const target = resolveEntity(b.entity, b.entity_id);

      const ext = ALLOWED_MIME[req.file.mimetype];
      const storedName = `${randomUUID()}${ext}`;
      const filePath = path.join(UPLOAD_DIR, storedName);
      fs.writeFileSync(filePath, req.file.buffer);

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
      // Yükleyen kendi ekini silebilir; genel merkez her eki silebilir.
      if (req.user.role !== 'genel_merkez' && row.uploaded_by !== req.user.id) {
        throw new ApiError(403, 'FORBIDDEN', 'Yalnız kendi yüklediğiniz eki silebilirsiniz');
      }
      db.prepare('DELETE FROM attachments WHERE id = ?').run(row.id);
      const filePath = path.join(UPLOAD_DIR, path.basename(row.stored_name));
      if (path.dirname(path.resolve(filePath)) === path.resolve(UPLOAD_DIR)) {
        fs.rmSync(filePath, { force: true });
      }
      auditLog(db, { entity: 'attachments', entityId: row.id, action: 'delete', changedBy: req.user.id, changes: row });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  return r;
}
