/**
 * K4 — Teşkilat birimleri ve görevlendirmeler.
 *
 * Bu modülün asıl yönetsel çıktısı `GET /org-units/summary`: hangi il/ilçede teşkilat
 * kurulmamış olduğunu (`teskilat_yok`) gösteren boşluk raporu.
 */
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  badRequest, conflict, notFound, listQuery, requireFields, toIntOrThrow,
} from '../helpers.js';
import {
  STATUSES, validStatus, resolveGeo, optionalInt, optionalText, optionalDate,
  optionalLookup, asArray,
} from '../v2.js';

const TYPES = [
  'koordinasyon_kurulu', 'bolge_temsilciligi', 'komisyon',
  'il_baskanligi', 'ilce_baskanligi', 'temsilcilik',
];

const SELECT = `o.id, o.type, o.name, o.code, o.region_id, o.province_id, o.district_id,
  o.parent_id, o.body_id, o.status, o.notes,
  rg.name AS region_name, pr.name AS province_name, d.name AS district_name,
  parent.name AS parent_name,
  (SELECT COUNT(*) FROM org_assignments oa WHERE oa.org_unit_id = o.id AND oa.status = 'aktif') AS assignment_count,
  o.created_at, o.updated_at`;
const FROM = `org_units o
  LEFT JOIN regions rg ON rg.id = o.region_id
  LEFT JOIN provinces pr ON pr.id = o.province_id
  LEFT JOIN districts d ON d.id = o.district_id
  LEFT JOIN org_units parent ON parent.id = o.parent_id`;
const FIELDS = ['type', 'name', 'code', 'region_id', 'province_id', 'district_id', 'parent_id', 'status', 'notes'];

const A_SELECT = `oa.id, oa.org_unit_id, oa.person_id, oa.role_id, oa.role_title,
  oa.start_date, oa.end_date, oa.status, oa.notes,
  (p.first_name || ' ' || p.last_name) AS person_name,
  p.status AS person_status, ou.name AS org_unit_name, ou.type AS org_unit_type,
  li.name AS role_name, oa.created_at, oa.updated_at`;
const A_FROM = `org_assignments oa
  JOIN persons p ON p.id = oa.person_id
  JOIN org_units ou ON ou.id = oa.org_unit_id
  LEFT JOIN lookup_items li ON li.id = oa.role_id`;
const A_FIELDS = ['org_unit_id', 'person_id', 'role_id', 'role_title', 'start_date', 'end_date', 'status', 'notes'];

export default function orgUnitRoutes(db) {
  const r = Router();
  const admin = requireRole('genel_merkez');

  const getUnit = (id) => db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE o.id = ?`).get(id);
  const getAssignment = (id) => db.prepare(`SELECT ${A_SELECT} FROM ${A_FROM} WHERE oa.id = ?`).get(id);

  // ------------------------------------------------------------- listeleme
  r.get('/org-units', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      if (req.query.type) {
        const types = asArray(req.query.type);
        for (const t of types) if (!TYPES.includes(t)) throw badRequest(`type filtresi geçersiz: ${t}`);
        where.push(`o.type IN (${types.map(() => '?').join(',')})`); params.push(...types);
      }
      const statuses = asArray(req.query.status);
      if (statuses.length) {
        for (const s of statuses) validStatus(s, 'status');
        where.push(`o.status IN (${statuses.map(() => '?').join(',')})`); params.push(...statuses);
      }
      for (const [q, col] of [['region_id', 'o.region_id'], ['province_id', 'o.province_id'],
        ['district_id', 'o.district_id'], ['parent_id', 'o.parent_id']]) {
        if (req.query[q]) { where.push(`${col} = ?`); params.push(toIntOrThrow(req.query[q], q)); }
      }
      if (req.query.q) { where.push('o.name LIKE ?'); params.push(`%${req.query.q}%`); }

      res.json(listQuery(db, {
        select: SELECT, from: FROM, where, params,
        orderBy: "CASE o.type WHEN 'koordinasyon_kurulu' THEN 0 WHEN 'bolge_temsilciligi' THEN 1"
          + " WHEN 'komisyon' THEN 2 WHEN 'il_baskanligi' THEN 3 WHEN 'ilce_baskanligi' THEN 4 ELSE 5 END,"
          + ' pr.code, o.name',
        query: req.query,
      }));
    } catch (e) { next(e); }
  });

  // --------------------------------------- teşkilatlanma boşluğu raporu
  // (:id rotalarından ÖNCE tanımlanmalı, aksi halde 'summary' id sanılır.)
  r.get('/org-units/summary', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      if (req.query.type) { where.push('type = ?'); params.push(req.query.type); }
      if (req.query.region_id) { where.push('region_id = ?'); params.push(toIntOrThrow(req.query.region_id, 'region_id')); }
      const whereSql = where.length ? ` WHERE ${where.join(' AND ')}` : '';

      const blank = () => ({ aktif: 0, pasif: 0, teskilat_yok: 0, total: 0 });
      const byStatus = blank();
      const byTypeMap = new Map();
      for (const row of db.prepare(
        `SELECT type, status, COUNT(*) AS c FROM org_units${whereSql} GROUP BY type, status`
      ).all(...params)) {
        byStatus[row.status] += row.c;
        byStatus.total += row.c;
        if (!byTypeMap.has(row.type)) byTypeMap.set(row.type, { type: row.type, ...blank() });
        const t = byTypeMap.get(row.type);
        t[row.status] += row.c;
        t.total += row.c;
      }

      const byRegionMap = new Map();
      for (const rg of db.prepare('SELECT id, name FROM regions ORDER BY sort_order').all()) {
        byRegionMap.set(rg.id, { region_id: rg.id, region_name: rg.name, ...blank() });
      }
      byRegionMap.set(null, { region_id: null, region_name: 'Bölgesiz (genel merkez)', ...blank() });
      for (const row of db.prepare(
        `SELECT region_id, status, COUNT(*) AS c FROM org_units${whereSql} GROUP BY region_id, status`
      ).all(...params)) {
        const bucket = byRegionMap.get(row.region_id);
        if (!bucket) continue;
        bucket[row.status] += row.c;
        bucket.total += row.c;
      }

      res.json({
        total: byStatus.total,
        by_status: { aktif: byStatus.aktif, pasif: byStatus.pasif, teskilat_yok: byStatus.teskilat_yok },
        by_type: [...byTypeMap.values()].sort((a, b) => TYPES.indexOf(a.type) - TYPES.indexOf(b.type)),
        by_region: [...byRegionMap.values()].filter((x) => x.total > 0),
      });
    } catch (e) { next(e); }
  });

  r.get('/org-units/:id', (req, res, next) => {
    try {
      const row = getUnit(req.params.id);
      if (!row) throw notFound('Teşkilat birimi bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  r.get('/org-units/:id/assignments', (req, res, next) => {
    try {
      const unit = getUnit(req.params.id);
      if (!unit) throw notFound('Teşkilat birimi bulunamadı');
      const where = ['oa.org_unit_id = ?'];
      const params = [unit.id];
      if (req.query.status) { where.push('oa.status = ?'); params.push(validStatus(req.query.status)); }
      res.json(listQuery(db, {
        select: A_SELECT, from: A_FROM, where, params,
        orderBy: 'oa.status, oa.start_date DESC, oa.id', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  function validateUnit(body, existing = null) {
    const type = body.type ?? existing?.type;
    if (!TYPES.includes(type)) throw badRequest(`type şunlardan biri olmalı: ${TYPES.join(', ')}`);
    const geo = resolveGeo(db, {
      region_id: body.region_id ?? existing?.region_id,
      province_id: body.province_id ?? existing?.province_id,
      district_id: body.district_id ?? existing?.district_id,
    });
    let parentId = body.parent_id !== undefined ? optionalInt(body.parent_id, 'parent_id') : (existing?.parent_id ?? null);
    if (parentId !== null) {
      if (existing && parentId === existing.id) throw badRequest('Bir birim kendisinin üstü olamaz');
      if (!db.prepare('SELECT id FROM org_units WHERE id = ?').get(parentId)) throw badRequest('parent_id geçersiz');
    }
    return {
      type,
      name: body.name !== undefined ? String(body.name).trim() : existing.name,
      code: body.code !== undefined ? optionalText(body.code) : (existing?.code ?? null),
      ...geo,
      parent_id: parentId,
      status: body.status !== undefined && body.status !== ''
        ? validStatus(body.status)
        : (existing?.status ?? 'teskilat_yok'),
      notes: body.notes !== undefined ? optionalText(body.notes) : (existing?.notes ?? null),
    };
  }

  r.post('/org-units', admin, (req, res, next) => {
    try {
      const b = req.body || {};
      requireFields(b, ['type', 'name']);
      const p = validateUnit(b);
      const dupe = db.prepare(`
        SELECT id FROM org_units
        WHERE type = ? AND COALESCE(province_id,0) = ? AND COALESCE(district_id,0) = ? AND name = ?`)
        .get(p.type, p.province_id || 0, p.district_id || 0, p.name);
      if (dupe) throw conflict('Aynı kapsamda bu isimde bir teşkilat birimi zaten var');

      const { lastInsertRowid } = db.prepare(`
        INSERT INTO org_units (type, name, code, region_id, province_id, district_id, parent_id, status, notes)
        VALUES (@type, @name, @code, @region_id, @province_id, @district_id, @parent_id, @status, @notes)`)
        .run(p);
      const row = getUnit(lastInsertRowid);
      auditLog(db, { entity: 'org_units', entityId: row.id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/org-units/:id', admin, (req, res, next) => {
    try {
      const before = getUnit(req.params.id);
      if (!before) throw notFound('Teşkilat birimi bulunamadı');
      const p = validateUnit(req.body || {}, before);
      db.prepare(`
        UPDATE org_units SET type=@type, name=@name, code=@code, region_id=@region_id,
          province_id=@province_id, district_id=@district_id, parent_id=@parent_id,
          status=@status, notes=@notes, updated_at=datetime('now')
        WHERE id=@id`).run({ ...p, id: before.id });
      const after = getUnit(before.id);
      auditLog(db, {
        entity: 'org_units', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.patch('/org-units/:id/status', admin, (req, res, next) => {
    try {
      const before = getUnit(req.params.id);
      if (!before) throw notFound('Teşkilat birimi bulunamadı');
      const status = validStatus((req.body || {}).status);
      db.prepare("UPDATE org_units SET status = ?, updated_at = datetime('now') WHERE id = ?")
        .run(status, before.id);
      const after = getUnit(before.id);
      auditLog(db, {
        entity: 'org_units', entityId: before.id, action: 'status_change', changedBy: req.user.id,
        changes: { status: { old: before.status, new: status } },
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  // ------------------------------------------------------- görevlendirmeler
  r.get('/org-assignments', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      for (const [q, col] of [['org_unit_id', 'oa.org_unit_id'], ['person_id', 'oa.person_id'],
        ['role_id', 'oa.role_id']]) {
        if (req.query[q]) { where.push(`${col} = ?`); params.push(toIntOrThrow(req.query[q], q)); }
      }
      if (req.query.status) { where.push('oa.status = ?'); params.push(validStatus(req.query.status)); }
      if (req.query.active_on) {
        const d = optionalDate(req.query.active_on, 'active_on');
        where.push('(oa.start_date IS NULL OR oa.start_date <= ?) AND (oa.end_date IS NULL OR oa.end_date >= ?)');
        params.push(d, d);
      }
      res.json(listQuery(db, {
        select: A_SELECT, from: A_FROM, where, params,
        orderBy: 'oa.start_date DESC, oa.id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/org-assignments/:id', (req, res, next) => {
    try {
      const row = getAssignment(req.params.id);
      if (!row) throw notFound('Görevlendirme bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  function validateAssignment(body, existing = null) {
    const orgUnitId = body.org_unit_id !== undefined
      ? toIntOrThrow(body.org_unit_id, 'org_unit_id') : existing.org_unit_id;
    if (!db.prepare('SELECT id FROM org_units WHERE id = ?').get(orgUnitId)) {
      throw badRequest('org_unit_id geçersiz');
    }
    const personId = body.person_id !== undefined
      ? toIntOrThrow(body.person_id, 'person_id') : existing.person_id;
    if (!db.prepare('SELECT id FROM persons WHERE id = ?').get(personId)) {
      throw badRequest('person_id geçersiz');
    }
    const startDate = body.start_date !== undefined
      ? optionalDate(body.start_date, 'start_date') : (existing?.start_date ?? null);
    const endDate = body.end_date !== undefined
      ? optionalDate(body.end_date, 'end_date') : (existing?.end_date ?? null);
    if (startDate && endDate && endDate < startDate) {
      throw badRequest('Görev bitiş tarihi başlama tarihinden önce olamaz');
    }
    return {
      org_unit_id: orgUnitId,
      person_id: personId,
      role_id: body.role_id !== undefined
        ? optionalLookup(db, body.role_id, 'gorev_unvani', 'role_id') : (existing?.role_id ?? null),
      role_title: body.role_title !== undefined
        ? optionalText(body.role_title) : (existing?.role_title ?? null),
      start_date: startDate,
      end_date: endDate,
      status: body.status !== undefined && body.status !== ''
        ? validStatus(body.status) : (existing?.status ?? 'aktif'),
      notes: body.notes !== undefined ? optionalText(body.notes) : (existing?.notes ?? null),
    };
  }

  // Birimin durumunu görevlendirmelere göre günceller:
  // en az bir aktif görevlendirme varsa 'aktif'; hiç yoksa ve birim 'aktif' idiyse 'teskilat_yok'.
  function syncUnitStatus(unitId, changedBy) {
    const unit = db.prepare('SELECT id, status FROM org_units WHERE id = ?').get(unitId);
    if (!unit) return;
    const active = db.prepare(
      "SELECT COUNT(*) AS c FROM org_assignments WHERE org_unit_id = ? AND status = 'aktif'"
    ).get(unitId).c;
    const next = active > 0 ? 'aktif' : (unit.status === 'aktif' ? 'teskilat_yok' : unit.status);
    if (next === unit.status) return;
    db.prepare("UPDATE org_units SET status = ?, updated_at = datetime('now') WHERE id = ?").run(next, unitId);
    auditLog(db, {
      entity: 'org_units', entityId: unitId, action: 'status_change', changedBy,
      changes: { status: { old: unit.status, new: next }, reason: 'gorevlendirme_degisikligi' },
    });
  }

  r.post('/org-assignments', admin, (req, res, next) => {
    try {
      requireFields(req.body || {}, ['org_unit_id', 'person_id']);
      const p = validateAssignment(req.body);
      const id = db.transaction(() => {
        const { lastInsertRowid } = db.prepare(`
          INSERT INTO org_assignments (org_unit_id, person_id, role_id, role_title,
            start_date, end_date, status, notes)
          VALUES (@org_unit_id, @person_id, @role_id, @role_title, @start_date, @end_date, @status, @notes)`)
          .run(p);
        syncUnitStatus(p.org_unit_id, req.user.id);
        return Number(lastInsertRowid);
      })();
      const row = getAssignment(id);
      auditLog(db, { entity: 'org_assignments', entityId: id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/org-assignments/:id', admin, (req, res, next) => {
    try {
      const before = getAssignment(req.params.id);
      if (!before) throw notFound('Görevlendirme bulunamadı');
      const p = validateAssignment(req.body || {}, before);
      db.transaction(() => {
        db.prepare(`
          UPDATE org_assignments SET org_unit_id=@org_unit_id, person_id=@person_id, role_id=@role_id,
            role_title=@role_title, start_date=@start_date, end_date=@end_date, status=@status,
            notes=@notes, updated_at=datetime('now')
          WHERE id=@id`).run({ ...p, id: before.id });
        syncUnitStatus(before.org_unit_id, req.user.id);
        if (p.org_unit_id !== before.org_unit_id) syncUnitStatus(p.org_unit_id, req.user.id);
      })();
      const after = getAssignment(before.id);
      auditLog(db, {
        entity: 'org_assignments', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, A_FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.patch('/org-assignments/:id/status', admin, (req, res, next) => {
    try {
      const before = getAssignment(req.params.id);
      if (!before) throw notFound('Görevlendirme bulunamadı');
      const status = validStatus((req.body || {}).status);
      db.transaction(() => {
        db.prepare("UPDATE org_assignments SET status = ?, updated_at = datetime('now') WHERE id = ?")
          .run(status, before.id);
        syncUnitStatus(before.org_unit_id, req.user.id);
      })();
      auditLog(db, {
        entity: 'org_assignments', entityId: before.id, action: 'status_change', changedBy: req.user.id,
        changes: { status: { old: before.status, new: status } },
      });
      res.json(getAssignment(before.id));
    } catch (e) { next(e); }
  });

  r.delete('/org-assignments/:id', admin, (req, res, next) => {
    try {
      const before = getAssignment(req.params.id);
      if (!before) throw notFound('Görevlendirme bulunamadı');
      db.transaction(() => {
        db.prepare('DELETE FROM org_assignments WHERE id = ?').run(before.id);
        syncUnitStatus(before.org_unit_id, req.user.id);
      })();
      auditLog(db, { entity: 'org_assignments', entityId: before.id, action: 'delete', changedBy: req.user.id, changes: before });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  return r;
}
