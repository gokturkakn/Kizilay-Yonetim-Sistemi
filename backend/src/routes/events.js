// SPEC-V2 §3.2C — Etkinlikler. Etkinlik adı YAZILMAZ; `calendar_events`ten SEÇİLİR.
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  badRequest, notFound, listQuery, requireFields, validDate, toIntOrThrow,
} from '../helpers.js';
import {
  resolveGeo, optionalLookup, optionalOrgUnit, optionalText,
  nonNegativeInt, attachmentCountSql,
} from '../v2.js';

const SELECT = `e.id, e.event_date, e.calendar_event_id, e.event_type_id, e.region_id,
  e.province_id, e.district_id, e.org_unit_id, e.participant_count, e.volunteer_count,
  e.beneficiary_count, e.notes,
  ce.name AS calendar_event_name, ce.category AS calendar_event_category,
  et.name AS event_type_name,
  rg.name AS region_name, pr.name AS province_name, d.name AS district_name,
  ou.name AS org_unit_name,
  ${attachmentCountSql('events', 'e')},
  e.created_by, u.name AS created_by_name, e.created_at, e.updated_at`;
const FROM = `events e
  JOIN calendar_events ce ON ce.id = e.calendar_event_id
  LEFT JOIN lookup_items et ON et.id = e.event_type_id
  LEFT JOIN regions rg ON rg.id = e.region_id
  LEFT JOIN provinces pr ON pr.id = e.province_id
  LEFT JOIN districts d ON d.id = e.district_id
  LEFT JOIN org_units ou ON ou.id = e.org_unit_id
  LEFT JOIN users u ON u.id = e.created_by`;
const FIELDS = ['event_date', 'calendar_event_id', 'event_type_id', 'region_id', 'province_id',
  'district_id', 'org_unit_id', 'participant_count', 'volunteer_count', 'beneficiary_count', 'notes'];

export default function eventRoutes(db) {
  const r = Router();
  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE e.id = ?`).get(id);

  function validate(body, existing = null) {
    const pick = (k) => (body[k] !== undefined ? body[k] : existing?.[k]);
    const calId = toIntOrThrow(pick('calendar_event_id'), 'calendar_event_id');
    if (!db.prepare('SELECT id FROM calendar_events WHERE id = ?').get(calId)) {
      throw badRequest('calendar_event_id geçersiz (etkinlik adı takvimden seçilmelidir)');
    }
    return {
      event_date: validDate(pick('event_date'), 'event_date'),
      calendar_event_id: calId,
      event_type_id: optionalLookup(db, pick('event_type_id'), 'etkinlik_turu', 'event_type_id'),
      ...resolveGeo(db, {
        region_id: pick('region_id'), province_id: pick('province_id'), district_id: pick('district_id'),
      }),
      org_unit_id: optionalOrgUnit(db, pick('org_unit_id')),
      participant_count: nonNegativeInt(pick('participant_count'), 'participant_count'),
      volunteer_count: nonNegativeInt(pick('volunteer_count'), 'volunteer_count'),
      beneficiary_count: nonNegativeInt(pick('beneficiary_count'), 'beneficiary_count'),
      notes: optionalText(pick('notes')),
    };
  }

  r.get('/events', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      for (const [q, col] of [['calendar_event_id', 'e.calendar_event_id'],
        ['event_type_id', 'e.event_type_id'], ['region_id', 'e.region_id'],
        ['province_id', 'e.province_id'], ['org_unit_id', 'e.org_unit_id']]) {
        if (req.query[q]) { where.push(`${col} = ?`); params.push(toIntOrThrow(req.query[q], q)); }
      }
      if (req.query.from) { where.push('e.event_date >= ?'); params.push(validDate(req.query.from, 'from')); }
      if (req.query.to) { where.push('e.event_date <= ?'); params.push(validDate(req.query.to, 'to')); }
      res.json(listQuery(db, {
        select: SELECT, from: FROM, where, params,
        orderBy: 'e.event_date DESC, e.id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/events/:id', (req, res, next) => {
    try {
      const row = getOne(req.params.id);
      if (!row) throw notFound('Etkinlik kaydı bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  r.post('/events', (req, res, next) => {
    try {
      requireFields(req.body || {}, ['event_date', 'calendar_event_id']);
      const p = validate(req.body);
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO events (event_date, calendar_event_id, event_type_id, region_id, province_id,
          district_id, org_unit_id, participant_count, volunteer_count, beneficiary_count, notes, created_by)
        VALUES (@event_date, @calendar_event_id, @event_type_id, @region_id, @province_id,
          @district_id, @org_unit_id, @participant_count, @volunteer_count, @beneficiary_count,
          @notes, @created_by)`).run({ ...p, created_by: req.user.id });
      const row = getOne(lastInsertRowid);
      auditLog(db, { entity: 'events', entityId: row.id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/events/:id', (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Etkinlik kaydı bulunamadı');
      const p = validate(req.body || {}, before);
      db.prepare(`
        UPDATE events SET event_date=@event_date, calendar_event_id=@calendar_event_id,
          event_type_id=@event_type_id, region_id=@region_id, province_id=@province_id,
          district_id=@district_id, org_unit_id=@org_unit_id, participant_count=@participant_count,
          volunteer_count=@volunteer_count, beneficiary_count=@beneficiary_count, notes=@notes,
          updated_at=datetime('now')
        WHERE id=@id`).run({ ...p, id: before.id });
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'events', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.delete('/events/:id', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Etkinlik kaydı bulunamadı');
      db.prepare('DELETE FROM events WHERE id = ?').run(before.id);
      auditLog(db, { entity: 'events', entityId: before.id, action: 'delete', changedBy: req.user.id, changes: before });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  return r;
}
