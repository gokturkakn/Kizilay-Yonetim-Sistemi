import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog } from '../audit.js';
import {
  badRequest, notFound, pagination, parseBoolFlag, requireFields, toIntOrThrow,
} from '../helpers.js';
import { maskTcNo } from '../tc.js';

const PERSON_SELECT = `p.id, p.first_name, p.last_name, p.tc_no, p.birth_date, p.phone, p.email,
  p.profession, p.unit_type, p.province_id, p.district_id, p.status AS person_status,
  CASE WHEN p.status = 'aktif' THEN 1 ELSE 0 END AS person_is_active`;

export default function membershipRoutes(db) {
  const r = Router();

  r.get('/bodies/:id/members', (req, res, next) => {
    try {
      const body = db.prepare('SELECT id FROM bodies WHERE id = ?').get(req.params.id);
      if (!body) throw notFound('Kurul/komisyon bulunamadı');

      const where = ['m.body_id = ?'];
      const params = [body.id];
      const active = parseBoolFlag(req.query.is_active);
      if (active !== undefined) { where.push('m.is_active = ?'); params.push(active); }
      const whereSql = ` WHERE ${where.join(' AND ')}`;

      const total = db.prepare(`SELECT COUNT(*) AS c FROM memberships m${whereSql}`).get(...params).c;
      const { limit, offset } = pagination(req.query);
      const rows = db.prepare(`
        SELECT m.id AS membership_id, m.role_title, m.is_active, ${PERSON_SELECT}
        FROM memberships m JOIN persons p ON p.id = m.person_id
        ${whereSql} ORDER BY m.id LIMIT ? OFFSET ?`).all(...params, limit, offset);

      const data = rows.map((row) => ({
        membership_id: row.membership_id,
        role_title: row.role_title,
        is_active: row.is_active,
        person: {
          id: row.id,
          first_name: row.first_name,
          last_name: row.last_name,
          // KVKK (Y-1): üye listesi de bir listedir; TC maskelenir.
          // Tam numara yalnız `GET /persons/:id` üzerinden ve yalnız genel merkeze açıktır.
          tc_no: maskTcNo(row.tc_no),
          tc_masked: 1,
          birth_date: row.birth_date,
          phone: row.phone,
          email: row.email,
          profession: row.profession,
          unit_type: row.unit_type,
          province_id: row.province_id,
          district_id: row.district_id,
          status: row.person_status,
          is_active: row.person_is_active,
        },
      }));
      res.json({ data, total });
    } catch (e) { next(e); }
  });

  r.post('/bodies/:id/members', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const body = db.prepare('SELECT id FROM bodies WHERE id = ?').get(req.params.id);
      if (!body) throw notFound('Kurul/komisyon bulunamadı');
      requireFields(req.body || {}, ['person_id']);
      const personId = toIntOrThrow(req.body.person_id, 'person_id');
      const person = db.prepare('SELECT id FROM persons WHERE id = ?').get(personId);
      if (!person) throw badRequest('person_id geçersiz');
      const existing = db.prepare(
        'SELECT id FROM memberships WHERE body_id = ? AND person_id = ? AND is_active = 1'
      ).get(body.id, personId);
      if (existing) throw badRequest('Bu kişi zaten bu kurul/komisyonun aktif üyesi');

      const roleTitle = req.body.role_title ? String(req.body.role_title).trim() : null;
      const { lastInsertRowid } = db.prepare(
        'INSERT INTO memberships (body_id, person_id, role_title) VALUES (?, ?, ?)'
      ).run(body.id, personId, roleTitle);
      const row = db.prepare('SELECT * FROM memberships WHERE id = ?').get(lastInsertRowid);
      auditLog(db, {
        entity: 'memberships', entityId: row.id, action: 'create', changedBy: req.user.id,
        changes: { body_id: body.id, person_id: personId, role_title: roleTitle },
      });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.delete('/memberships/:id', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const row = db.prepare('SELECT * FROM memberships WHERE id = ?').get(req.params.id);
      if (!row) throw notFound('Üyelik bulunamadı');
      db.prepare('DELETE FROM memberships WHERE id = ?').run(row.id);
      auditLog(db, {
        entity: 'memberships', entityId: row.id, action: 'delete', changedBy: req.user.id,
        changes: { body_id: row.body_id, person_id: row.person_id, role_title: row.role_title },
      });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  r.patch('/memberships/:id/active', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const row = db.prepare('SELECT * FROM memberships WHERE id = ?').get(req.params.id);
      if (!row) throw notFound('Üyelik bulunamadı');
      const flag = parseBoolFlag((req.body || {}).is_active);
      if (flag === undefined) throw badRequest("'is_active' alanı zorunludur");
      db.prepare('UPDATE memberships SET is_active = ? WHERE id = ?').run(flag, row.id);
      const after = db.prepare('SELECT * FROM memberships WHERE id = ?').get(row.id);
      auditLog(db, {
        entity: 'memberships', entityId: row.id, action: 'active_toggle', changedBy: req.user.id,
        changes: { is_active: { old: row.is_active, new: flag } },
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  return r;
}
