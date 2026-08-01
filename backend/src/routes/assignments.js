import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  badRequest, notFound, listQuery, requireFields, validDate, toIntOrThrow,
} from '../helpers.js';

const STATUSES = ['atandi', 'devam', 'tamamlandi'];
const FIELDS = ['person_id', 'title', 'description', 'assigned_date', 'status'];
const SELECT = 'id, person_id, title, description, assigned_date, status, created_by, created_at';

function validatePayload(db, body) {
  requireFields(body, ['person_id', 'title', 'assigned_date']);
  const personId = toIntOrThrow(body.person_id, 'person_id');
  if (!db.prepare('SELECT id FROM persons WHERE id = ?').get(personId)) {
    throw badRequest('person_id geçersiz');
  }
  validDate(body.assigned_date, 'assigned_date');
  const status = body.status ?? 'atandi';
  if (!STATUSES.includes(status)) {
    throw badRequest(`status şunlardan biri olmalı: ${STATUSES.join(', ')}`);
  }
  return {
    person_id: personId,
    title: String(body.title).trim(),
    description: body.description ? String(body.description).trim() : null,
    assigned_date: body.assigned_date,
    status,
  };
}

export default function assignmentRoutes(db) {
  const r = Router();
  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM assignments WHERE id = ?`).get(id);

  // Tüm oturum açmış roller okuyabilir.
  r.get('/assignments', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      const { person_id, status } = req.query;
      if (person_id) { where.push('person_id = ?'); params.push(toIntOrThrow(person_id, 'person_id')); }
      if (status) {
        if (!STATUSES.includes(status)) throw badRequest('status filtresi geçersiz');
        where.push('status = ?'); params.push(status);
      }
      res.json(listQuery(db, {
        select: SELECT, from: 'assignments', where, params,
        orderBy: 'assigned_date DESC, id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.post('/assignments', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const p = validatePayload(db, req.body || {});
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO assignments (person_id, title, description, assigned_date, status, created_by)
        VALUES (@person_id, @title, @description, @assigned_date, @status, @created_by)`)
        .run({ ...p, created_by: req.user.id });
      const row = getOne(lastInsertRowid);
      auditLog(db, { entity: 'assignments', entityId: row.id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/assignments/:id', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Görev ataması bulunamadı');
      const p = validatePayload(db, req.body || {});
      db.prepare(`
        UPDATE assignments SET person_id=@person_id, title=@title, description=@description,
          assigned_date=@assigned_date, status=@status WHERE id=@id`)
        .run({ ...p, id: before.id });
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'assignments', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  return r;
}
