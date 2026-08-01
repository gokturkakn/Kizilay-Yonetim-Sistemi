import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  badRequest, notFound, listQuery, requireFields, validDate, toIntOrThrow,
} from '../helpers.js';

const FIELDS = ['body_id', 'meeting_date', 'decision', 'outcome'];
const SELECT = 'id, body_id, meeting_date, decision, outcome, created_by, created_at';

function validatePayload(db, body) {
  requireFields(body, ['body_id', 'meeting_date', 'decision']);
  const bodyId = toIntOrThrow(body.body_id, 'body_id');
  if (!db.prepare('SELECT id FROM bodies WHERE id = ?').get(bodyId)) {
    throw badRequest('body_id geçersiz');
  }
  validDate(body.meeting_date, 'meeting_date');
  return {
    body_id: bodyId,
    meeting_date: body.meeting_date,
    decision: String(body.decision).trim(),
    outcome: body.outcome ? String(body.outcome).trim() : null,
  };
}

export default function meetingRoutes(db) {
  const r = Router();
  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM meetings WHERE id = ?`).get(id);

  r.get('/meetings', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      const { body_id, from, to } = req.query;
      if (body_id) { where.push('body_id = ?'); params.push(toIntOrThrow(body_id, 'body_id')); }
      if (from) { where.push('meeting_date >= ?'); params.push(validDate(from, 'from')); }
      if (to) { where.push('meeting_date <= ?'); params.push(validDate(to, 'to')); }
      res.json(listQuery(db, {
        select: SELECT, from: 'meetings', where, params,
        orderBy: 'meeting_date DESC, id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.post('/meetings', (req, res, next) => {
    try {
      const p = validatePayload(db, req.body || {});
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO meetings (body_id, meeting_date, decision, outcome, created_by)
        VALUES (@body_id, @meeting_date, @decision, @outcome, @created_by)`)
        .run({ ...p, created_by: req.user.id });
      const row = getOne(lastInsertRowid);
      auditLog(db, { entity: 'meetings', entityId: row.id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/meetings/:id', (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Toplantı bulunamadı');
      const p = validatePayload(db, req.body || {});
      db.prepare(`
        UPDATE meetings SET body_id=@body_id, meeting_date=@meeting_date,
          decision=@decision, outcome=@outcome WHERE id=@id`)
        .run({ ...p, id: before.id });
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'meetings', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.delete('/meetings/:id', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Toplantı bulunamadı');
      db.prepare('DELETE FROM meetings WHERE id = ?').run(before.id);
      auditLog(db, { entity: 'meetings', entityId: before.id, action: 'delete', changedBy: req.user.id, changes: before });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  return r;
}
