/**
 * Gelir Getirici Faaliyetler — SPEC-V2 §3.2E.
 *
 * Saha Faaliyetleri'nin 5. kardeşi (Görevler/Eğitimler/Etkinlikler/Toplantılar'ın yanında).
 * Ayrı bir modüldür çünkü gelir getirici bir faaliyet (kermes, bağış kampanyası, hayır
 * yemeği ...) diğer dördünden farklı olarak kendi MALİ SONUCU olan bir faaliyettir —
 * Gelir Getirici Faaliyetler Komisyonu'nun performans takibi bu ayrı raporlanabilirliğe
 * dayanır (bkz. docs/SPEC-V2.md §3.2E).
 *
 * `net_income` fiziksel bir sütun DEĞİLDİR, her SELECT'te hesaplanır — bkz. migration
 * 015'teki not.
 */
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  badRequest, notFound, listQuery, requireFields, validDate, toIntOrThrow,
} from '../helpers.js';
import {
  resolveGeo, requireLookup, optionalOrgUnit, optionalText, nonNegativeInt,
  optionalAmount, requiredAmount, attachmentCountSql,
} from '../v2.js';

const ACTIVITY_TYPE_CATEGORY = 'gelir_getirici_faaliyet_turu';

const FIELDS = ['name', 'activity_type_id', 'purpose', 'activity_date', 'region_id',
  'province_id', 'district_id', 'org_unit_id', 'location', 'target_income', 'income_amount',
  'expense_amount', 'participant_count', 'volunteer_count', 'supporting_orgs', 'sponsors', 'notes'];

const SELECT = `x.id, x.name, x.activity_type_id, x.purpose, x.activity_date,
  x.region_id, x.province_id, x.district_id, x.org_unit_id, x.location,
  x.target_income, x.income_amount, x.expense_amount,
  (x.income_amount - COALESCE(x.expense_amount, 0)) AS net_income,
  x.participant_count, x.volunteer_count, x.supporting_orgs, x.sponsors, x.notes,
  li.name AS activity_type_name,
  ou.name AS org_unit_name, rg.name AS region_name, pr.name AS province_name,
  d.name AS district_name,
  ${attachmentCountSql('income_activities', 'x')},
  x.created_by, u.name AS created_by_name, x.created_at, x.updated_at`;
const FROM = `income_activities x
  JOIN lookup_items li ON li.id = x.activity_type_id
  LEFT JOIN org_units ou ON ou.id = x.org_unit_id
  LEFT JOIN regions rg ON rg.id = x.region_id
  LEFT JOIN provinces pr ON pr.id = x.province_id
  LEFT JOIN districts d ON d.id = x.district_id
  LEFT JOIN users u ON u.id = x.created_by`;

export default function incomeActivityRoutes(db) {
  const r = Router();
  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE x.id = ?`).get(id);

  function validate(body, existing = null) {
    const pick = (k) => (body[k] !== undefined ? body[k] : existing?.[k]);

    const name = optionalText(pick('name'));
    if (!name) throw badRequest("'name' alanı boş bırakılamaz");

    return {
      name,
      activity_type_id: requireLookup(
        db, pick('activity_type_id'), ACTIVITY_TYPE_CATEGORY, 'activity_type_id'
      ).id,
      purpose: optionalText(pick('purpose')),
      activity_date: validDate(pick('activity_date'), 'activity_date'),
      ...resolveGeo(db, {
        region_id: pick('region_id'), province_id: pick('province_id'), district_id: pick('district_id'),
      }),
      org_unit_id: optionalOrgUnit(db, pick('org_unit_id')),
      location: optionalText(pick('location')),
      target_income: optionalAmount(pick('target_income'), 'target_income'),
      income_amount: requiredAmount(pick('income_amount'), 'income_amount'),
      expense_amount: optionalAmount(pick('expense_amount'), 'expense_amount'),
      participant_count: nonNegativeInt(pick('participant_count'), 'participant_count'),
      volunteer_count: nonNegativeInt(pick('volunteer_count'), 'volunteer_count'),
      supporting_orgs: optionalText(pick('supporting_orgs')),
      sponsors: optionalText(pick('sponsors')),
      notes: optionalText(pick('notes')),
    };
  }

  r.get('/income-activities', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      for (const [q, col] of [['activity_type_id', 'x.activity_type_id'],
        ['org_unit_id', 'x.org_unit_id'], ['region_id', 'x.region_id'],
        ['province_id', 'x.province_id'], ['district_id', 'x.district_id']]) {
        if (req.query[q]) { where.push(`${col} = ?`); params.push(toIntOrThrow(req.query[q], q)); }
      }
      if (req.query.from) { where.push('x.activity_date >= ?'); params.push(validDate(req.query.from, 'from')); }
      if (req.query.to) { where.push('x.activity_date <= ?'); params.push(validDate(req.query.to, 'to')); }
      if (req.query.q) { where.push('x.name LIKE ?'); params.push(`%${req.query.q}%`); }
      res.json(listQuery(db, {
        select: SELECT, from: FROM, where, params,
        orderBy: 'x.activity_date DESC, x.id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/income-activities/:id', (req, res, next) => {
    try {
      const row = getOne(req.params.id);
      if (!row) throw notFound('Gelir getirici faaliyet kaydı bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  r.post('/income-activities', (req, res, next) => {
    try {
      requireFields(req.body || {}, ['name', 'activity_type_id', 'activity_date', 'income_amount']);
      const p = validate(req.body);
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO income_activities (name, activity_type_id, purpose, activity_date,
          region_id, province_id, district_id, org_unit_id, location, target_income,
          income_amount, expense_amount, participant_count, volunteer_count,
          supporting_orgs, sponsors, notes, created_by)
        VALUES (@name, @activity_type_id, @purpose, @activity_date,
          @region_id, @province_id, @district_id, @org_unit_id, @location, @target_income,
          @income_amount, @expense_amount, @participant_count, @volunteer_count,
          @supporting_orgs, @sponsors, @notes, @created_by)`)
        .run({ ...p, created_by: req.user.id });
      const row = getOne(lastInsertRowid);
      auditLog(db, {
        entity: 'income_activities', entityId: row.id, action: 'create',
        changedBy: req.user.id, changes: p,
      });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/income-activities/:id', (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Gelir getirici faaliyet kaydı bulunamadı');
      const p = validate(req.body || {}, before);
      db.prepare(`
        UPDATE income_activities SET name=@name, activity_type_id=@activity_type_id,
          purpose=@purpose, activity_date=@activity_date, region_id=@region_id,
          province_id=@province_id, district_id=@district_id, org_unit_id=@org_unit_id,
          location=@location, target_income=@target_income, income_amount=@income_amount,
          expense_amount=@expense_amount, participant_count=@participant_count,
          volunteer_count=@volunteer_count, supporting_orgs=@supporting_orgs,
          sponsors=@sponsors, notes=@notes, updated_at=datetime('now')
        WHERE id=@id`).run({ ...p, id: before.id });
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'income_activities', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.delete('/income-activities/:id', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Gelir getirici faaliyet kaydı bulunamadı');
      db.prepare('DELETE FROM income_activities WHERE id = ?').run(before.id);
      auditLog(db, {
        entity: 'income_activities', entityId: before.id, action: 'delete',
        changedBy: req.user.id, changes: before,
      });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  return r;
}
