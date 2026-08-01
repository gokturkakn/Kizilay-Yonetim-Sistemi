// K1 — Tanımlar (lookup) yönetimi. Yönetim Paneli bu uçlarla listeleri yönetir;
// yeni görev türü / eğitim konusu / ürün eklemek kod değişikliği gerektirmez.
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  ApiError, badRequest, conflict, notFound, listQuery, parseBoolFlag,
  requireFields, toIntOrThrow,
} from '../helpers.js';

const SELECT = `li.id, li.category_id, lc.code AS category_code, li.parent_id,
  parent.name AS parent_name, li.code, li.name, li.sort_order, li.is_active,
  li.created_at, li.updated_at`;
const FROM = `lookup_items li
  JOIN lookup_categories lc ON lc.id = li.category_id
  LEFT JOIN lookup_items parent ON parent.id = li.parent_id`;

const FIELDS = ['name', 'code', 'parent_id', 'sort_order', 'is_active'];

// Bir tanım kaleminin kullanıldığı yerler — silme koruması için.
const USAGE = [
  ['tasks', 'task_type_id'], ['tasks', 'sub_task_id'],
  ['trainings', 'topic_id'], ['trainings', 'category_id'], ['trainings', 'method_id'],
  ['events', 'event_type_id'],
  ['meetings', 'meeting_type_id'], ['meetings', 'method_id'],
  ['material_requests', 'product_id'], ['shipments', 'shipping_method_id'],
  ['stock_items', 'product_id'], ['stock_movements', 'product_id'],
  ['org_assignments', 'role_id'],
];

export default function lookupRoutes(db) {
  const r = Router();
  const admin = requireRole('genel_merkez');

  const getItem = (id) => db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE li.id = ?`).get(id);
  const catByCode = (code) => db.prepare('SELECT * FROM lookup_categories WHERE code = ?').get(code);

  // ---------------------------------------------------------- kategoriler
  r.get('/lookup-categories', (req, res, next) => {
    try {
      res.json(listQuery(db, {
        select: `lc.id, lc.code, lc.name, lc.is_system,
          (SELECT COUNT(*) FROM lookup_items li WHERE li.category_id = lc.id) AS item_count`,
        from: 'lookup_categories lc',
        orderBy: 'lc.id',
        query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.post('/lookup-categories', admin, (req, res, next) => {
    try {
      requireFields(req.body || {}, ['code', 'name']);
      const code = String(req.body.code).trim().toLowerCase();
      if (!/^[a-z0-9_]+$/.test(code)) {
        throw badRequest("'code' yalnız küçük harf, rakam ve alt çizgi içerebilir");
      }
      if (catByCode(code)) throw conflict('Bu kod ile bir kategori zaten var');
      const { lastInsertRowid } = db
        .prepare('INSERT INTO lookup_categories (code, name, is_system) VALUES (?, ?, 0)')
        .run(code, String(req.body.name).trim());
      const row = db.prepare(`SELECT id, code, name, is_system, 0 AS item_count
        FROM lookup_categories WHERE id = ?`).get(lastInsertRowid);
      auditLog(db, { entity: 'lookup_categories', entityId: row.id, action: 'create', changedBy: req.user.id, changes: row });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  // -------------------------------------------------------------- kalemler
  function listItems(req, res, categoryCode) {
    const where = [];
    const params = [];
    if (categoryCode) {
      const cat = catByCode(categoryCode);
      if (!cat) throw notFound(`Tanım kategorisi bulunamadı: ${categoryCode}`);
      where.push('li.category_id = ?'); params.push(cat.id);
    } else if (req.query.category_id) {
      where.push('li.category_id = ?'); params.push(toIntOrThrow(req.query.category_id, 'category_id'));
    }
    if (req.query.parent_id !== undefined && req.query.parent_id !== '') {
      if (req.query.parent_id === 'null') where.push('li.parent_id IS NULL');
      else { where.push('li.parent_id = ?'); params.push(toIntOrThrow(req.query.parent_id, 'parent_id')); }
    }
    const active = parseBoolFlag(req.query.is_active);
    if (active !== undefined) { where.push('li.is_active = ?'); params.push(active); }
    if (req.query.q) { where.push('li.name LIKE ?'); params.push(`%${req.query.q}%`); }

    res.json(listQuery(db, {
      select: SELECT, from: FROM, where, params,
      orderBy: 'lc.code, li.sort_order, li.name', query: req.query,
    }));
  }

  // Kısayol: GET /lookups/gorev_turu
  r.get('/lookups/:code', (req, res, next) => {
    try { listItems(req, res, req.params.code); } catch (e) { next(e); }
  });

  r.get('/lookup-items', (req, res, next) => {
    try { listItems(req, res, req.query.category_code); } catch (e) { next(e); }
  });

  r.get('/lookup-items/:id', (req, res, next) => {
    try {
      const row = getItem(req.params.id);
      if (!row) throw notFound('Tanım kalemi bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  function resolveParent(db_, categoryId, parentId) {
    if (parentId === undefined || parentId === null || parentId === '') return null;
    const id = toIntOrThrow(parentId, 'parent_id');
    const parent = db_.prepare('SELECT id, category_id FROM lookup_items WHERE id = ?').get(id);
    if (!parent) throw badRequest('parent_id geçersiz');
    if (parent.category_id === categoryId) {
      throw badRequest('Bir kalem kendi kategorisindeki bir kaleme bağlanamaz');
    }
    return parent.id;
  }

  r.post('/lookup-items', admin, (req, res, next) => {
    try {
      const b = req.body || {};
      requireFields(b, ['name']);
      let cat = null;
      if (b.category_code) cat = catByCode(String(b.category_code));
      else if (b.category_id) cat = db.prepare('SELECT * FROM lookup_categories WHERE id = ?').get(toIntOrThrow(b.category_id, 'category_id'));
      if (!cat) throw badRequest("'category_code' veya 'category_id' geçerli olmalı");

      const parentId = resolveParent(db, cat.id, b.parent_id);
      const name = String(b.name).trim();
      const dupe = db.prepare(
        'SELECT id FROM lookup_items WHERE category_id = ? AND COALESCE(parent_id,0) = ? AND name = ?'
      ).get(cat.id, parentId || 0, name);
      if (dupe) throw conflict('Bu kategoride aynı isimde bir kalem zaten var');

      const sortOrder = b.sort_order !== undefined && b.sort_order !== ''
        ? toIntOrThrow(b.sort_order, 'sort_order')
        : (db.prepare('SELECT COALESCE(MAX(sort_order),0)+1 AS n FROM lookup_items WHERE category_id = ?').get(cat.id).n);

      const { lastInsertRowid } = db.prepare(`
        INSERT INTO lookup_items (category_id, parent_id, code, name, sort_order, is_active)
        VALUES (?, ?, ?, ?, ?, ?)`).run(
        cat.id, parentId, b.code ? String(b.code).trim() : null, name, sortOrder,
        parseBoolFlag(b.is_active) ?? 1
      );
      const row = getItem(lastInsertRowid);
      auditLog(db, { entity: 'lookup_items', entityId: row.id, action: 'create', changedBy: req.user.id, changes: row });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/lookup-items/:id', admin, (req, res, next) => {
    try {
      const before = getItem(req.params.id);
      if (!before) throw notFound('Tanım kalemi bulunamadı');
      const b = req.body || {};
      const name = b.name !== undefined ? String(b.name).trim() : before.name;
      if (!name) throw badRequest("'name' boş olamaz");
      const parentId = b.parent_id !== undefined
        ? resolveParent(db, before.category_id, b.parent_id)
        : before.parent_id;

      const dupe = db.prepare(
        'SELECT id FROM lookup_items WHERE category_id = ? AND COALESCE(parent_id,0) = ? AND name = ? AND id <> ?'
      ).get(before.category_id, parentId || 0, name, before.id);
      if (dupe) throw conflict('Bu kategoride aynı isimde bir kalem zaten var');

      db.prepare(`
        UPDATE lookup_items SET name = ?, code = ?, parent_id = ?, sort_order = ?, is_active = ?,
          updated_at = datetime('now') WHERE id = ?`).run(
        name,
        b.code !== undefined ? (b.code ? String(b.code).trim() : null) : before.code,
        parentId,
        b.sort_order !== undefined && b.sort_order !== '' ? toIntOrThrow(b.sort_order, 'sort_order') : before.sort_order,
        parseBoolFlag(b.is_active) ?? before.is_active,
        before.id
      );
      const after = getItem(before.id);
      auditLog(db, {
        entity: 'lookup_items', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.patch('/lookup-items/:id/active', admin, (req, res, next) => {
    try {
      const before = getItem(req.params.id);
      if (!before) throw notFound('Tanım kalemi bulunamadı');
      const flag = parseBoolFlag((req.body || {}).is_active);
      if (flag === undefined) throw badRequest("'is_active' alanı zorunludur");
      db.prepare("UPDATE lookup_items SET is_active = ?, updated_at = datetime('now') WHERE id = ?")
        .run(flag, before.id);
      const after = getItem(before.id);
      auditLog(db, {
        entity: 'lookup_items', entityId: before.id, action: 'active_toggle', changedBy: req.user.id,
        changes: { is_active: { old: before.is_active, new: flag } },
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.delete('/lookup-items/:id', admin, (req, res, next) => {
    try {
      const before = getItem(req.params.id);
      if (!before) throw notFound('Tanım kalemi bulunamadı');

      // Geçmiş kayıtları bozmamak için kullanımda olan kalem SİLİNMEZ.
      for (const [table, column] of USAGE) {
        const used = db.prepare(`SELECT 1 FROM ${table} WHERE ${column} = ? LIMIT 1`).get(before.id);
        if (used) {
          throw new ApiError(409, 'IN_USE',
            `Bu tanım '${table}' kayıtlarında kullanılıyor; silmek yerine pasifleştirin`);
        }
      }
      const child = db.prepare('SELECT 1 FROM lookup_items WHERE parent_id = ? LIMIT 1').get(before.id);
      if (child) throw new ApiError(409, 'IN_USE', 'Bu kaleme bağlı alt kalemler var; önce onları silin');

      db.prepare('DELETE FROM lookup_items WHERE id = ?').run(before.id);
      auditLog(db, { entity: 'lookup_items', entityId: before.id, action: 'delete', changedBy: req.user.id, changes: before });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  return r;
}
