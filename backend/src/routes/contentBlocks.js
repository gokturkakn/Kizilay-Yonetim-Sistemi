// İçerik Yönetimi — modül giriş ekranlarındaki bilgilendirme metinleri.
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import { badRequest, notFound, listQuery, requireFields } from '../helpers.js';

const SELECT = `cb.id, cb.key, cb.title, cb.body, cb.updated_by,
  u.name AS updated_by_name, cb.created_at, cb.updated_at`;
const FROM = 'content_blocks cb LEFT JOIN users u ON u.id = cb.updated_by';

export default function contentBlockRoutes(db) {
  const r = Router();

  const getByKey = (key) => db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE cb.key = ?`).get(key);

  r.get('/content-blocks', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      if (req.query.prefix) { where.push('cb.key LIKE ?'); params.push(`${req.query.prefix}%`); }
      res.json(listQuery(db, {
        select: SELECT, from: FROM, where, params, orderBy: 'cb.key', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/content-blocks/:key', (req, res, next) => {
    try {
      const row = getByKey(req.params.key);
      if (!row) throw notFound(`İçerik bloğu bulunamadı: ${req.params.key}`);
      res.json(row);
    } catch (e) { next(e); }
  });

  // Yoksa oluşturur, varsa günceller (upsert) — Yönetim Paneli tek uçla çalışsın diye.
  r.put('/content-blocks/:key', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const key = String(req.params.key);
      if (!/^[a-z0-9_.-]+$/i.test(key)) throw badRequest('Geçersiz içerik anahtarı');
      requireFields(req.body || {}, ['title']);
      const title = String(req.body.title).trim();
      const body = req.body.body === undefined || req.body.body === null ? '' : String(req.body.body);

      const before = getByKey(key);
      if (before) {
        db.prepare("UPDATE content_blocks SET title = ?, body = ?, updated_by = ?, updated_at = datetime('now') WHERE key = ?")
          .run(title, body, req.user.id, key);
        const after = getByKey(key);
        auditLog(db, {
          entity: 'content_blocks', entityId: after.id, action: 'update', changedBy: req.user.id,
          changes: diffChanges(before, after, ['title', 'body']),
        });
        return res.json(after);
      }
      const { lastInsertRowid } = db.prepare(
        'INSERT INTO content_blocks (key, title, body, updated_by) VALUES (?, ?, ?, ?)'
      ).run(key, title, body, req.user.id);
      const created = getByKey(key);
      auditLog(db, {
        entity: 'content_blocks', entityId: Number(lastInsertRowid), action: 'create',
        changedBy: req.user.id, changes: { key, title, body },
      });
      return res.status(201).json(created);
    } catch (e) { next(e); }
  });

  return r;
}
