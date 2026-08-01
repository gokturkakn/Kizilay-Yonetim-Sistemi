/**
 * SPEC-V2 §3.4 — Raporlama ve Dashboard.
 *
 * Tüm sayaçlar TEK istekte, gruplu sorgularla üretilir (N+1 yok).
 * Filtreler: bölge · il · tarih aralığı.
 */
import { Router } from 'express';
import { validDate, toIntOrThrow } from '../helpers.js';

const BLANK = () => ({ aktif: 0, pasif: 0, teskilat_yok: 0, total: 0 });

export default function dashboardRoutes(db) {
  const r = Router();

  /** Faaliyet tabloları için ortak filtre parçası. */
  function activityFilter(alias, dateCol, f) {
    const where = [];
    const params = [];
    if (f.region_id) { where.push(`${alias}.region_id = ?`); params.push(f.region_id); }
    if (f.province_id) { where.push(`${alias}.province_id = ?`); params.push(f.province_id); }
    if (f.from) { where.push(`${alias}.${dateCol} >= ?`); params.push(f.from); }
    if (f.to) { where.push(`${alias}.${dateCol} <= ?`); params.push(f.to); }
    return { sql: where.length ? ` WHERE ${where.join(' AND ')}` : '', params };
  }

  function parseFilters(query) {
    return {
      region_id: query.region_id ? toIntOrThrow(query.region_id, 'region_id') : null,
      province_id: query.province_id ? toIntOrThrow(query.province_id, 'province_id') : null,
      from: query.from ? validDate(query.from, 'from') : null,
      to: query.to ? validDate(query.to, 'to') : null,
    };
  }

  r.get('/dashboard/summary', (req, res, next) => {
    try {
      const f = parseFilters(req.query);

      // --- Teşkilatlanma -------------------------------------------------
      const personWhere = [];
      const personParams = [];
      if (f.region_id) { personWhere.push('pr.region_id = ?'); personParams.push(f.region_id); }
      if (f.province_id) { personWhere.push('p.province_id = ?'); personParams.push(f.province_id); }
      const personSql = personWhere.length ? ` WHERE ${personWhere.join(' AND ')}` : '';
      const persons = BLANK();
      for (const row of db.prepare(
        `SELECT p.status, COUNT(*) AS c FROM persons p JOIN provinces pr ON pr.id = p.province_id${personSql} GROUP BY p.status`
      ).all(...personParams)) {
        persons[row.status] += row.c;
        persons.total += row.c;
      }

      const unitWhere = [];
      const unitParams = [];
      if (f.region_id) { unitWhere.push('region_id = ?'); unitParams.push(f.region_id); }
      if (f.province_id) { unitWhere.push('province_id = ?'); unitParams.push(f.province_id); }
      const unitSql = unitWhere.length ? ` WHERE ${unitWhere.join(' AND ')}` : '';
      const orgUnits = BLANK();
      const byType = new Map();
      for (const row of db.prepare(
        `SELECT type, status, COUNT(*) AS c FROM org_units${unitSql} GROUP BY type, status`
      ).all(...unitParams)) {
        orgUnits[row.status] += row.c;
        orgUnits.total += row.c;
        if (!byType.has(row.type)) byType.set(row.type, { type: row.type, ...BLANK() });
        const t = byType.get(row.type);
        t[row.status] += row.c;
        t.total += row.c;
      }

      const byRegion = db.prepare(`
        SELECT rg.id AS region_id, rg.name AS region_name,
          (SELECT COUNT(*) FROM org_units o WHERE o.region_id = rg.id) AS org_units_total,
          (SELECT COUNT(*) FROM org_units o WHERE o.region_id = rg.id AND o.status = 'aktif') AS org_units_aktif,
          (SELECT COUNT(*) FROM org_units o WHERE o.region_id = rg.id AND o.status = 'teskilat_yok') AS org_units_teskilat_yok,
          (SELECT COUNT(*) FROM persons p JOIN provinces pv ON pv.id = p.province_id
             WHERE pv.region_id = rg.id AND p.status = 'aktif') AS persons_aktif
        FROM regions rg ORDER BY rg.sort_order`).all();

      // --- Faaliyetler ----------------------------------------------------
      const t = activityFilter('t', 'task_date', f);
      const tasks = db.prepare(`
        SELECT COUNT(*) AS count, COALESCE(SUM(volunteer_count),0) AS volunteers,
          COALESCE(SUM(beneficiary_count),0) AS beneficiaries,
          COALESCE(SUM(duration_hours),0) AS hours
        FROM tasks t${t.sql}`).get(...t.params);

      const tr = activityFilter('t', 'training_date', f);
      const trainings = db.prepare(`
        SELECT COUNT(*) AS count, COALESCE(SUM(participant_count),0) AS participants,
          COALESCE(SUM(volunteer_count),0) AS volunteers, COALESCE(SUM(duration_hours),0) AS hours
        FROM trainings t${tr.sql}`).get(...tr.params);

      const ev = activityFilter('e', 'event_date', f);
      const events = db.prepare(`
        SELECT COUNT(*) AS count, COALESCE(SUM(participant_count),0) AS participants,
          COALESCE(SUM(volunteer_count),0) AS volunteers,
          COALESCE(SUM(beneficiary_count),0) AS beneficiaries
        FROM events e${ev.sql}`).get(...ev.params);

      const mt = activityFilter('m', 'meeting_date', f);
      const meetings = db.prepare(`SELECT COUNT(*) AS count FROM meetings m${mt.sql}`).get(...mt.params);

      // v1 tablosu — geriye dönük görünürlük için özet içinde kalır.
      const faWhere = [];
      const faParams = [];
      if (f.province_id) { faWhere.push('fa.province_id = ?'); faParams.push(f.province_id); }
      if (f.region_id) { faWhere.push('pv.region_id = ?'); faParams.push(f.region_id); }
      if (f.from) { faWhere.push('fa.activity_date >= ?'); faParams.push(f.from); }
      if (f.to) { faWhere.push('fa.activity_date <= ?'); faParams.push(f.to); }
      const fieldActivities = db.prepare(`
        SELECT COUNT(*) AS count, COALESCE(SUM(fa.volunteer_count),0) AS volunteers,
          COALESCE(SUM(fa.beneficiary_count),0) AS beneficiaries
        FROM field_activities fa LEFT JOIN provinces pv ON pv.id = fa.province_id
        ${faWhere.length ? `WHERE ${faWhere.join(' AND ')}` : ''}`).get(...faParams);

      // --- Lojistik -------------------------------------------------------
      const mr = activityFilter('mr', 'request_date', f);
      const requests = { talep: 0, onaylandi: 0, gonderildi: 0, teslim_edildi: 0, iptal: 0, total: 0 };
      for (const row of db.prepare(
        `SELECT status, COUNT(*) AS c FROM material_requests mr${mr.sql} GROUP BY status`
      ).all(...mr.params)) {
        requests[row.status] += row.c;
        requests.total += row.c;
      }
      const shipments = db.prepare(`
        SELECT COUNT(*) AS count, COALESCE(SUM(quantity),0) AS quantity FROM shipments`).get();
      const stock = db.prepare(`
        SELECT COUNT(*) AS products, COALESCE(SUM(quantity),0) AS total_quantity,
          COALESCE(SUM(CASE WHEN min_quantity > 0 AND quantity <= min_quantity THEN 1 ELSE 0 END),0) AS low_stock
        FROM stock_items`).get();

      // --- En çok yapılan görev türleri ------------------------------------
      const topTaskTypes = db.prepare(`
        SELECT t.task_type_id, li.name, COUNT(*) AS count
        FROM tasks t JOIN lookup_items li ON li.id = t.task_type_id${t.sql}
        GROUP BY t.task_type_id ORDER BY count DESC LIMIT 10`).all(...t.params);

      res.json({
        filters: f,
        organization: {
          persons,
          org_units: orgUnits,
          by_type: [...byType.values()],
          by_region: byRegion,
        },
        activity: {
          tasks, trainings, events, meetings, field_activities: fieldActivities,
        },
        logistics: { requests, shipments, stock },
        top_task_types: topTaskTypes,
      });
    } catch (e) { next(e); }
  });

  r.get('/dashboard/by-region', (req, res, next) => {
    try {
      const f = parseFilters(req.query);
      const dateClause = (alias, col) => {
        const parts = [];
        if (f.from) parts.push(`AND ${alias}.${col} >= '${f.from}'`);
        if (f.to) parts.push(`AND ${alias}.${col} <= '${f.to}'`);
        return parts.join(' ');
      };
      // Tarihler validDate()'ten geçtiği için YYYY-MM-DD dışında bir şey olamaz.
      const data = db.prepare(`
        SELECT rg.id AS region_id, rg.name AS region_name,
          (SELECT COUNT(*) FROM tasks t WHERE t.region_id = rg.id ${dateClause('t', 'task_date')}) AS tasks,
          (SELECT COUNT(*) FROM trainings tr WHERE tr.region_id = rg.id ${dateClause('tr', 'training_date')}) AS trainings,
          (SELECT COUNT(*) FROM events e WHERE e.region_id = rg.id ${dateClause('e', 'event_date')}) AS events,
          (SELECT COUNT(*) FROM meetings m WHERE m.region_id = rg.id ${dateClause('m', 'meeting_date')}) AS meetings,
          (SELECT COUNT(*) FROM org_units o WHERE o.region_id = rg.id AND o.status = 'aktif') AS org_units_aktif,
          (SELECT COUNT(*) FROM org_units o WHERE o.region_id = rg.id AND o.status = 'teskilat_yok') AS org_units_teskilat_yok,
          (SELECT COUNT(*) FROM provinces p WHERE p.region_id = rg.id) AS province_count
        FROM regions rg ORDER BY rg.sort_order`).all();
      res.json({ data, total: data.length });
    } catch (e) { next(e); }
  });

  return r;
}
