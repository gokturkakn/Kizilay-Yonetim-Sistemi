// SPEC-V2 §3.2A — Görevler. 12 ana başlık + Yönetim Paneli'nden tanımlanan alt görevler.
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  badRequest, notFound, listQuery, requireFields, validDate, toIntOrThrow,
} from '../helpers.js';
import {
  resolveGeo, requireLookup, optionalLookup, optionalOrgUnit,
  optionalText, nonNegativeInt, optionalHours, attachmentCountSql,
} from '../v2.js';

const SELECT = `t.id, t.task_date, t.region_id, t.province_id, t.district_id, t.branch,
  t.org_unit_id, t.task_type_id, t.sub_task_id, t.volunteer_count, t.beneficiary_count,
  t.duration_hours, t.notes,
  tt.name AS task_type_name, st.name AS sub_task_name,
  rg.name AS region_name, pr.name AS province_name, d.name AS district_name,
  ou.name AS org_unit_name,
  ${attachmentCountSql('tasks', 't')},
  t.created_by, u.name AS created_by_name, t.created_at, t.updated_at`;
const FROM = `tasks t
  JOIN lookup_items tt ON tt.id = t.task_type_id
  LEFT JOIN lookup_items st ON st.id = t.sub_task_id
  LEFT JOIN regions rg ON rg.id = t.region_id
  LEFT JOIN provinces pr ON pr.id = t.province_id
  LEFT JOIN districts d ON d.id = t.district_id
  LEFT JOIN org_units ou ON ou.id = t.org_unit_id
  LEFT JOIN users u ON u.id = t.created_by`;
const FIELDS = ['task_date', 'region_id', 'province_id', 'district_id', 'branch', 'org_unit_id',
  'task_type_id', 'sub_task_id', 'volunteer_count', 'beneficiary_count', 'duration_hours', 'notes'];

export default function taskRoutes(db) {
  const r = Router();
  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE t.id = ?`).get(id);

  function validate(body, existing = null) {
    const pick = (k) => (body[k] !== undefined ? body[k] : existing?.[k]);

    const taskDate = validDate(pick('task_date'), 'task_date');
    const taskType = requireLookup(db, pick('task_type_id'), 'gorev_turu', 'task_type_id');

    // Alt görev, seçilen ana görevin ÇOCUĞU olmalıdır (K1 hiyerarşisi).
    let subTaskId = null;
    const rawSub = body.sub_task_id !== undefined ? body.sub_task_id : existing?.sub_task_id;
    if (rawSub !== undefined && rawSub !== null && rawSub !== '') {
      const sub = requireLookup(db, rawSub, 'alt_gorev', 'sub_task_id');
      if (sub.parent_id !== taskType.id) {
        throw badRequest(`'${sub.name}' alt görevi '${taskType.name}' görev türüne bağlı değil`);
      }
      subTaskId = sub.id;
    }

    return {
      task_date: taskDate,
      ...resolveGeo(db, {
        region_id: pick('region_id'), province_id: pick('province_id'), district_id: pick('district_id'),
      }),
      branch: optionalText(pick('branch')),
      org_unit_id: optionalOrgUnit(db, pick('org_unit_id')),
      task_type_id: taskType.id,
      sub_task_id: subTaskId,
      volunteer_count: nonNegativeInt(pick('volunteer_count'), 'volunteer_count'),
      beneficiary_count: nonNegativeInt(pick('beneficiary_count'), 'beneficiary_count'),
      duration_hours: optionalHours(pick('duration_hours'), 'duration_hours'),
      notes: optionalText(pick('notes')),
    };
  }

  r.get('/tasks', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      for (const [q, col] of [['task_type_id', 't.task_type_id'], ['sub_task_id', 't.sub_task_id'],
        ['region_id', 't.region_id'], ['province_id', 't.province_id'],
        ['district_id', 't.district_id'], ['org_unit_id', 't.org_unit_id']]) {
        if (req.query[q]) { where.push(`${col} = ?`); params.push(toIntOrThrow(req.query[q], q)); }
      }
      if (req.query.from) { where.push('t.task_date >= ?'); params.push(validDate(req.query.from, 'from')); }
      if (req.query.to) { where.push('t.task_date <= ?'); params.push(validDate(req.query.to, 'to')); }
      if (req.query.q) { where.push('(t.notes LIKE ? OR t.branch LIKE ?)'); params.push(`%${req.query.q}%`, `%${req.query.q}%`); }
      res.json(listQuery(db, {
        select: SELECT, from: FROM, where, params,
        orderBy: 't.task_date DESC, t.id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/tasks/:id', (req, res, next) => {
    try {
      const row = getOne(req.params.id);
      if (!row) throw notFound('Görev kaydı bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  r.post('/tasks', (req, res, next) => {
    try {
      requireFields(req.body || {}, ['task_date', 'task_type_id']);
      const p = validate(req.body);
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO tasks (task_date, region_id, province_id, district_id, branch, org_unit_id,
          task_type_id, sub_task_id, volunteer_count, beneficiary_count, duration_hours, notes, created_by)
        VALUES (@task_date, @region_id, @province_id, @district_id, @branch, @org_unit_id,
          @task_type_id, @sub_task_id, @volunteer_count, @beneficiary_count, @duration_hours, @notes, @created_by)`)
        .run({ ...p, created_by: req.user.id });
      const row = getOne(lastInsertRowid);
      auditLog(db, { entity: 'tasks', entityId: row.id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/tasks/:id', (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Görev kaydı bulunamadı');
      const p = validate(req.body || {}, before);
      db.prepare(`
        UPDATE tasks SET task_date=@task_date, region_id=@region_id, province_id=@province_id,
          district_id=@district_id, branch=@branch, org_unit_id=@org_unit_id,
          task_type_id=@task_type_id, sub_task_id=@sub_task_id, volunteer_count=@volunteer_count,
          beneficiary_count=@beneficiary_count, duration_hours=@duration_hours, notes=@notes,
          updated_at=datetime('now')
        WHERE id=@id`).run({ ...p, id: before.id });
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'tasks', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.delete('/tasks/:id', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Görev kaydı bulunamadı');
      db.prepare('DELETE FROM tasks WHERE id = ?').run(before.id);
      auditLog(db, { entity: 'tasks', entityId: before.id, action: 'delete', changedBy: req.user.id, changes: before });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  return r;
}
