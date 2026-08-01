// SPEC-V2 §3.2B — Eğitimler. Kategori (Gönüllü/Halka Açık) × Yöntem (Yüz Yüze/Çevrim İçi).
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import { notFound, listQuery, requireFields, validDate, toIntOrThrow } from '../helpers.js';
import {
  resolveGeo, requireLookup, optionalLookup, optionalOrgUnit,
  optionalText, nonNegativeInt, optionalHours, attachmentCountSql,
} from '../v2.js';

const SELECT = `t.id, t.training_date, t.region_id, t.province_id, t.district_id, t.org_unit_id,
  t.trainer, t.topic_id, t.category_id, t.method_id, t.participant_count, t.volunteer_count,
  t.duration_hours, t.notes,
  tp.name AS topic_name, ct.name AS category_name, mt.name AS method_name,
  rg.name AS region_name, pr.name AS province_name, d.name AS district_name,
  ou.name AS org_unit_name,
  ${attachmentCountSql('trainings', 't')},
  t.created_by, u.name AS created_by_name, t.created_at, t.updated_at`;
const FROM = `trainings t
  JOIN lookup_items tp ON tp.id = t.topic_id
  LEFT JOIN lookup_items ct ON ct.id = t.category_id
  LEFT JOIN lookup_items mt ON mt.id = t.method_id
  LEFT JOIN regions rg ON rg.id = t.region_id
  LEFT JOIN provinces pr ON pr.id = t.province_id
  LEFT JOIN districts d ON d.id = t.district_id
  LEFT JOIN org_units ou ON ou.id = t.org_unit_id
  LEFT JOIN users u ON u.id = t.created_by`;
const FIELDS = ['training_date', 'region_id', 'province_id', 'district_id', 'org_unit_id', 'trainer',
  'topic_id', 'category_id', 'method_id', 'participant_count', 'volunteer_count', 'duration_hours', 'notes'];

export default function trainingRoutes(db) {
  const r = Router();
  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE t.id = ?`).get(id);

  function validate(body, existing = null) {
    const pick = (k) => (body[k] !== undefined ? body[k] : existing?.[k]);
    return {
      training_date: validDate(pick('training_date'), 'training_date'),
      ...resolveGeo(db, {
        region_id: pick('region_id'), province_id: pick('province_id'), district_id: pick('district_id'),
      }),
      org_unit_id: optionalOrgUnit(db, pick('org_unit_id')),
      trainer: optionalText(pick('trainer')),
      topic_id: requireLookup(db, pick('topic_id'), 'egitim_konusu', 'topic_id').id,
      category_id: optionalLookup(db, pick('category_id'), 'egitim_kategorisi', 'category_id'),
      method_id: optionalLookup(db, pick('method_id'), 'egitim_yontemi', 'method_id'),
      participant_count: nonNegativeInt(pick('participant_count'), 'participant_count'),
      volunteer_count: nonNegativeInt(pick('volunteer_count'), 'volunteer_count'),
      duration_hours: optionalHours(pick('duration_hours'), 'duration_hours'),
      notes: optionalText(pick('notes')),
    };
  }

  r.get('/trainings', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      for (const [q, col] of [['topic_id', 't.topic_id'], ['category_id', 't.category_id'],
        ['method_id', 't.method_id'], ['region_id', 't.region_id'],
        ['province_id', 't.province_id'], ['org_unit_id', 't.org_unit_id']]) {
        if (req.query[q]) { where.push(`${col} = ?`); params.push(toIntOrThrow(req.query[q], q)); }
      }
      if (req.query.from) { where.push('t.training_date >= ?'); params.push(validDate(req.query.from, 'from')); }
      if (req.query.to) { where.push('t.training_date <= ?'); params.push(validDate(req.query.to, 'to')); }
      res.json(listQuery(db, {
        select: SELECT, from: FROM, where, params,
        orderBy: 't.training_date DESC, t.id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/trainings/:id', (req, res, next) => {
    try {
      const row = getOne(req.params.id);
      if (!row) throw notFound('Eğitim kaydı bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  r.post('/trainings', (req, res, next) => {
    try {
      requireFields(req.body || {}, ['training_date', 'topic_id']);
      const p = validate(req.body);
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO trainings (training_date, region_id, province_id, district_id, org_unit_id,
          trainer, topic_id, category_id, method_id, participant_count, volunteer_count,
          duration_hours, notes, created_by)
        VALUES (@training_date, @region_id, @province_id, @district_id, @org_unit_id,
          @trainer, @topic_id, @category_id, @method_id, @participant_count, @volunteer_count,
          @duration_hours, @notes, @created_by)`).run({ ...p, created_by: req.user.id });
      const row = getOne(lastInsertRowid);
      auditLog(db, { entity: 'trainings', entityId: row.id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/trainings/:id', (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Eğitim kaydı bulunamadı');
      const p = validate(req.body || {}, before);
      db.prepare(`
        UPDATE trainings SET training_date=@training_date, region_id=@region_id,
          province_id=@province_id, district_id=@district_id, org_unit_id=@org_unit_id,
          trainer=@trainer, topic_id=@topic_id, category_id=@category_id, method_id=@method_id,
          participant_count=@participant_count, volunteer_count=@volunteer_count,
          duration_hours=@duration_hours, notes=@notes, updated_at=datetime('now')
        WHERE id=@id`).run({ ...p, id: before.id });
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'trainings', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.delete('/trainings/:id', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Eğitim kaydı bulunamadı');
      db.prepare('DELETE FROM trainings WHERE id = ?').run(before.id);
      auditLog(db, { entity: 'trainings', entityId: before.id, action: 'delete', changedBy: req.user.id, changes: before });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  return r;
}
