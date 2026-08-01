import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  badRequest, notFound, listQuery, requireFields, validDate, toIntOrThrow,
} from '../helpers.js';

const FIELDS = ['task_area_id', 'activity_date', 'volunteer_count', 'beneficiary_count', 'province_id', 'district_id', 'notes'];
const SELECT = `id, task_area_id, activity_date, volunteer_count, beneficiary_count,
  province_id, district_id, notes, created_by, created_at`;

function validatePayload(db, body) {
  requireFields(body, ['task_area_id', 'activity_date']);
  if (body.volunteer_count === undefined || body.volunteer_count === null) {
    throw badRequest("'volunteer_count' alanı zorunludur");
  }
  if (body.beneficiary_count === undefined || body.beneficiary_count === null) {
    throw badRequest("'beneficiary_count' alanı zorunludur");
  }

  const taskAreaId = toIntOrThrow(body.task_area_id, 'task_area_id');
  if (!db.prepare('SELECT id FROM task_areas WHERE id = ?').get(taskAreaId)) {
    throw badRequest('task_area_id geçersiz');
  }
  validDate(body.activity_date, 'activity_date');

  const volunteerCount = toIntOrThrow(body.volunteer_count, 'volunteer_count');
  const beneficiaryCount = toIntOrThrow(body.beneficiary_count, 'beneficiary_count');
  if (volunteerCount < 0 || beneficiaryCount < 0) {
    throw badRequest('Gönüllü ve yararlanıcı sayıları negatif olamaz');
  }

  let provinceId = null;
  if (body.province_id !== undefined && body.province_id !== null && body.province_id !== '') {
    provinceId = toIntOrThrow(body.province_id, 'province_id');
    if (!db.prepare('SELECT id FROM provinces WHERE id = ?').get(provinceId)) {
      throw badRequest('province_id geçersiz');
    }
  }
  let districtId = null;
  if (body.district_id !== undefined && body.district_id !== null && body.district_id !== '') {
    districtId = toIntOrThrow(body.district_id, 'district_id');
    const dist = db.prepare('SELECT id, province_id FROM districts WHERE id = ?').get(districtId);
    if (!dist) throw badRequest('district_id geçersiz');
    if (provinceId !== null && dist.province_id !== provinceId) {
      throw badRequest('İlçe, seçilen ile ait değil');
    }
  }

  return {
    task_area_id: taskAreaId,
    activity_date: body.activity_date,
    volunteer_count: volunteerCount,
    beneficiary_count: beneficiaryCount,
    province_id: provinceId,
    district_id: districtId,
    notes: body.notes ? String(body.notes) : null,
  };
}

export default function fieldActivityRoutes(db) {
  const r = Router();
  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM field_activities WHERE id = ?`).get(id);

  r.get('/field-activities', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      const { task_area_id, province_id, from, to } = req.query;
      if (task_area_id) { where.push('task_area_id = ?'); params.push(toIntOrThrow(task_area_id, 'task_area_id')); }
      if (province_id) { where.push('province_id = ?'); params.push(toIntOrThrow(province_id, 'province_id')); }
      if (from) { where.push('activity_date >= ?'); params.push(validDate(from, 'from')); }
      if (to) { where.push('activity_date <= ?'); params.push(validDate(to, 'to')); }
      res.json(listQuery(db, {
        select: SELECT, from: 'field_activities', where, params,
        orderBy: 'activity_date DESC, id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.post('/field-activities', (req, res, next) => {
    try {
      const p = validatePayload(db, req.body || {});
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO field_activities (task_area_id, activity_date, volunteer_count,
          beneficiary_count, province_id, district_id, notes, created_by)
        VALUES (@task_area_id, @activity_date, @volunteer_count, @beneficiary_count,
                @province_id, @district_id, @notes, @created_by)`)
        .run({ ...p, created_by: req.user.id });
      const row = getOne(lastInsertRowid);
      auditLog(db, { entity: 'field_activities', entityId: row.id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/field-activities/:id', (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Saha faaliyeti bulunamadı');
      const p = validatePayload(db, req.body || {});
      db.prepare(`
        UPDATE field_activities SET task_area_id=@task_area_id, activity_date=@activity_date,
          volunteer_count=@volunteer_count, beneficiary_count=@beneficiary_count,
          province_id=@province_id, district_id=@district_id, notes=@notes
        WHERE id=@id`).run({ ...p, id: before.id });
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'field_activities', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.delete('/field-activities/:id', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Saha faaliyeti bulunamadı');
      db.prepare('DELETE FROM field_activities WHERE id = ?').run(before.id);
      auditLog(db, { entity: 'field_activities', entityId: before.id, action: 'delete', changedBy: req.user.id, changes: before });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  return r;
}
