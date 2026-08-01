// K6 — Etkinlik takvimi. Etkinlik modülü adları buradan seçer.
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  ApiError, badRequest, conflict, notFound, listQuery, parseBoolFlag,
  requireFields, validDate, toIntOrThrow,
} from '../helpers.js';
import { optionalText } from '../v2.js';

const CATEGORIES = ['milli_bayram', 'dini_bayram', 'dini_gun', 'resmi_gun', 'onemli_gun', 'onemli_hafta'];
const SELECT = `id, name, category, month, day, end_month, end_day, is_fixed, note, is_active,
  created_at, updated_at`;
const FIELDS = ['name', 'category', 'month', 'day', 'end_month', 'end_day', 'is_fixed', 'note', 'is_active'];

export default function calendarRoutes(db) {
  const r = Router();
  const admin = requireRole('genel_merkez');

  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM calendar_events WHERE id = ?`).get(id);
  const datesOf = (id) => db.prepare(
    'SELECT id, year, start_date, end_date FROM calendar_event_dates WHERE event_id = ? ORDER BY year'
  ).all(id);

  /** `year` verilmişse hareketli etkinliğin o yıla ait tarihini ekler. */
  function withResolvedDate(row, year) {
    if (!year) return row;
    if (row.is_fixed) {
      return { ...row, resolved_date: `${year}-${String(row.month).padStart(2, '0')}-${String(row.day).padStart(2, '0')}` };
    }
    const d = db.prepare('SELECT start_date, end_date FROM calendar_event_dates WHERE event_id = ? AND year = ?')
      .get(row.id, year);
    return { ...row, resolved_date: d ? d.start_date : null, resolved_end_date: d ? d.end_date : null };
  }

  r.get('/calendar-events', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      if (req.query.category) {
        if (!CATEGORIES.includes(req.query.category)) throw badRequest('category filtresi geçersiz');
        where.push('category = ?'); params.push(req.query.category);
      }
      if (req.query.month) { where.push('month = ?'); params.push(toIntOrThrow(req.query.month, 'month')); }
      const fixed = parseBoolFlag(req.query.is_fixed);
      if (fixed !== undefined) { where.push('is_fixed = ?'); params.push(fixed); }
      const active = parseBoolFlag(req.query.is_active);
      if (active !== undefined) { where.push('is_active = ?'); params.push(active); }
      if (req.query.q) { where.push('name LIKE ?'); params.push(`%${req.query.q}%`); }

      const result = listQuery(db, {
        select: SELECT, from: 'calendar_events', where, params,
        orderBy: 'is_fixed DESC, month, day, name', query: req.query,
      });
      const year = req.query.year ? toIntOrThrow(req.query.year, 'year') : null;
      if (year) result.data = result.data.map((row) => withResolvedDate(row, year));
      res.json(result);
    } catch (e) { next(e); }
  });

  r.get('/calendar-events/:id', (req, res, next) => {
    try {
      const row = getOne(req.params.id);
      if (!row) throw notFound('Takvim kaydı bulunamadı');
      res.json({ ...row, dates: datesOf(row.id) });
    } catch (e) { next(e); }
  });

  function validate(body, existing = null) {
    const pick = (k) => (body[k] !== undefined ? body[k] : existing?.[k]);
    const category = pick('category');
    if (!CATEGORIES.includes(category)) {
      throw badRequest(`category şunlardan biri olmalı: ${CATEGORIES.join(', ')}`);
    }
    const isFixed = parseBoolFlag(pick('is_fixed')) ?? 1;
    const num = (v, field, max) => {
      if (v === undefined || v === null || v === '') return null;
      const n = toIntOrThrow(v, field);
      if (n < 1 || n > max) throw badRequest(`'${field}' 1–${max} aralığında olmalı`);
      return n;
    };
    const month = isFixed ? num(pick('month'), 'month', 12) : null;
    const day = isFixed ? num(pick('day'), 'day', 31) : null;
    if (isFixed && (month === null || day === null)) {
      throw badRequest("Sabit tarihli kayıtta 'month' ve 'day' zorunludur");
    }
    return {
      name: String(pick('name')).trim(),
      category,
      month,
      day,
      end_month: isFixed ? num(pick('end_month'), 'end_month', 12) : null,
      end_day: isFixed ? num(pick('end_day'), 'end_day', 31) : null,
      is_fixed: isFixed,
      note: optionalText(pick('note')),
      is_active: parseBoolFlag(pick('is_active')) ?? 1,
    };
  }

  r.post('/calendar-events', admin, (req, res, next) => {
    try {
      requireFields(req.body || {}, ['name', 'category']);
      const p = validate(req.body);
      if (db.prepare('SELECT id FROM calendar_events WHERE name = ?').get(p.name)) {
        throw conflict('Bu isimde bir takvim kaydı zaten var');
      }
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO calendar_events (name, category, month, day, end_month, end_day, is_fixed, note, is_active)
        VALUES (@name, @category, @month, @day, @end_month, @end_day, @is_fixed, @note, @is_active)`).run(p);
      const row = getOne(lastInsertRowid);
      auditLog(db, { entity: 'calendar_events', entityId: row.id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json({ ...row, dates: [] });
    } catch (e) { next(e); }
  });

  r.put('/calendar-events/:id', admin, (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Takvim kaydı bulunamadı');
      const p = validate(req.body || {}, before);
      db.prepare(`
        UPDATE calendar_events SET name=@name, category=@category, month=@month, day=@day,
          end_month=@end_month, end_day=@end_day, is_fixed=@is_fixed, note=@note,
          is_active=@is_active, updated_at=datetime('now')
        WHERE id=@id`).run({ ...p, id: before.id });
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'calendar_events', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json({ ...after, dates: datesOf(after.id) });
    } catch (e) { next(e); }
  });

  r.delete('/calendar-events/:id', admin, (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Takvim kaydı bulunamadı');
      if (db.prepare('SELECT 1 FROM events WHERE calendar_event_id = ? LIMIT 1').get(before.id)) {
        throw new ApiError(409, 'IN_USE',
          'Bu takvim kaydı etkinliklerde kullanılıyor; silmek yerine pasifleştirin');
      }
      db.prepare('DELETE FROM calendar_events WHERE id = ?').run(before.id);
      auditLog(db, { entity: 'calendar_events', entityId: before.id, action: 'delete', changedBy: req.user.id, changes: before });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  // -------------------------------------------------- yıl bazlı tarihler
  r.get('/calendar-events/:id/dates', (req, res, next) => {
    try {
      const ev = getOne(req.params.id);
      if (!ev) throw notFound('Takvim kaydı bulunamadı');
      const data = datesOf(ev.id);
      res.json({ data, total: data.length });
    } catch (e) { next(e); }
  });

  r.post('/calendar-events/:id/dates', admin, (req, res, next) => {
    try {
      const ev = getOne(req.params.id);
      if (!ev) throw notFound('Takvim kaydı bulunamadı');
      requireFields(req.body || {}, ['year', 'start_date']);
      const year = toIntOrThrow(req.body.year, 'year');
      if (year < 2000 || year > 2100) throw badRequest("'year' 2000–2100 aralığında olmalı");
      const startDate = validDate(req.body.start_date, 'start_date');
      const endDate = req.body.end_date ? validDate(req.body.end_date, 'end_date') : null;
      if (endDate && endDate < startDate) throw badRequest('Bitiş tarihi başlangıçtan önce olamaz');
      if (db.prepare('SELECT id FROM calendar_event_dates WHERE event_id = ? AND year = ?').get(ev.id, year)) {
        throw conflict('Bu etkinlik için bu yıla ait tarih zaten girilmiş');
      }
      const { lastInsertRowid } = db.prepare(
        'INSERT INTO calendar_event_dates (event_id, year, start_date, end_date) VALUES (?, ?, ?, ?)'
      ).run(ev.id, year, startDate, endDate);
      const row = db.prepare('SELECT id, event_id, year, start_date, end_date FROM calendar_event_dates WHERE id = ?')
        .get(lastInsertRowid);
      auditLog(db, { entity: 'calendar_events', entityId: ev.id, action: 'update', changedBy: req.user.id, changes: { added_date: row } });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.delete('/calendar-event-dates/:id', admin, (req, res, next) => {
    try {
      const row = db.prepare('SELECT * FROM calendar_event_dates WHERE id = ?').get(req.params.id);
      if (!row) throw notFound('Tarih kaydı bulunamadı');
      db.prepare('DELETE FROM calendar_event_dates WHERE id = ?').run(row.id);
      auditLog(db, { entity: 'calendar_events', entityId: row.event_id, action: 'update', changedBy: req.user.id, changes: { removed_date: row } });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  return r;
}
