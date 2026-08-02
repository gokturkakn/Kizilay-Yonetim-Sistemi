/**
 * SPEC-V2 §3.4 — Raporlama ve Dashboard.
 *
 * Tüm sayaçlar TEK istekte, gruplu sorgularla üretilir (N+1 yok).
 * SPEC-V2 §3.4'ün şart koştuğu beş filtre HER UÇTA geçerlidir:
 *   Bölge (`region_id`) · İl (`province_id`) · İlçe (`district_id`) ·
 *   Tarih Aralığı (`from`/`to`) · Faaliyet Türü (`activity_type`).
 */
import { Router } from 'express';
import { badRequest, validDate, toIntOrThrow } from '../helpers.js';

const BLANK = () => ({ aktif: 0, pasif: 0, teskilat_yok: 0, total: 0 });

/** Faaliyet türü → tablo/tarih sütunu eşlemesi. Dördünün de tam coğrafya boyutu vardır. */
const ACTIVITY_TABLES = {
  gorev: { table: 'tasks', dateCol: 'task_date' },
  egitim: { table: 'trainings', dateCol: 'training_date' },
  etkinlik: { table: 'events', dateCol: 'event_date' },
  toplanti: { table: 'meetings', dateCol: 'meeting_date' },
};
const ACTIVITY_TYPES = Object.keys(ACTIVITY_TABLES);

const METRICS = {
  gorev: { table: 'tasks', dateCol: 'task_date' },
  egitim: { table: 'trainings', dateCol: 'training_date' },
  etkinlik: { table: 'events', dateCol: 'event_date' },
  toplanti: { table: 'meetings', dateCol: 'meeting_date' },
  // Toplam alanlar birden çok tabloya yayılır; dönem bazında toplanır.
  gonullu: {
    sources: [
      { table: 'tasks', dateCol: 'task_date', col: 'volunteer_count' },
      { table: 'trainings', dateCol: 'training_date', col: 'volunteer_count' },
      { table: 'events', dateCol: 'event_date', col: 'volunteer_count' },
    ],
  },
  yararlanici: {
    sources: [
      { table: 'tasks', dateCol: 'task_date', col: 'beneficiary_count' },
      { table: 'events', dateCol: 'event_date', col: 'beneficiary_count' },
    ],
  },
};
const METRIC_NAMES = Object.keys(METRICS);

export default function dashboardRoutes(db) {
  const r = Router();

  function parseFilters(query) {
    const activityType = query.activity_type ? String(query.activity_type) : null;
    if (activityType && !ACTIVITY_TYPES.includes(activityType)) {
      throw badRequest(`activity_type şunlardan biri olmalı: ${ACTIVITY_TYPES.join(', ')}`);
    }
    return {
      region_id: query.region_id ? toIntOrThrow(query.region_id, 'region_id') : null,
      province_id: query.province_id ? toIntOrThrow(query.province_id, 'province_id') : null,
      district_id: query.district_id ? toIntOrThrow(query.district_id, 'district_id') : null,
      from: query.from ? validDate(query.from, 'from') : null,
      to: query.to ? validDate(query.to, 'to') : null,
      activity_type: activityType,
      task_type_id: query.task_type_id ? toIntOrThrow(query.task_type_id, 'task_type_id') : null,
    };
  }

  /** Faaliyet tabloları için ortak coğrafya + tarih filtresi. */
  function activityWhere(alias, dateCol, f, { extra = [], extraParams = [] } = {}) {
    const where = [...extra];
    const params = [...extraParams];
    if (f.region_id) { where.push(`${alias}.region_id = ?`); params.push(f.region_id); }
    if (f.province_id) { where.push(`${alias}.province_id = ?`); params.push(f.province_id); }
    if (f.district_id) { where.push(`${alias}.district_id = ?`); params.push(f.district_id); }
    if (f.from) { where.push(`${alias}.${dateCol} >= ?`); params.push(f.from); }
    if (f.to) { where.push(`${alias}.${dateCol} <= ?`); params.push(f.to); }
    return { sql: where.length ? ` WHERE ${where.join(' AND ')}` : '', where, params };
  }

  // ==========================================================  /dashboard/summary
  r.get('/dashboard/summary', (req, res, next) => {
    try {
      const f = parseFilters(req.query);
      // activity_type verilmişse seçilmeyen türler SIFIRLANIR — anahtarlar yine döner ki
      // istemci sabit bir şekil görsün (grafikler alan yokluğuna karşı kırılgandır).
      const wanted = (type) => !f.activity_type || f.activity_type === type;

      // --- Teşkilatlanma -------------------------------------------------
      const personWhere = [];
      const personParams = [];
      if (f.region_id) { personWhere.push('pr.region_id = ?'); personParams.push(f.region_id); }
      if (f.province_id) { personWhere.push('p.province_id = ?'); personParams.push(f.province_id); }
      if (f.district_id) { personWhere.push('p.district_id = ?'); personParams.push(f.district_id); }
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
      if (f.district_id) { unitWhere.push('district_id = ?'); unitParams.push(f.district_id); }
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
      const taskExtra = f.task_type_id
        ? { extra: ['t.task_type_id = ?'], extraParams: [f.task_type_id] } : {};
      const tw = activityWhere('t', 'task_date', f, taskExtra);
      const tasks = wanted('gorev') ? db.prepare(`
        SELECT COUNT(*) AS count, COALESCE(SUM(volunteer_count),0) AS volunteers,
          COALESCE(SUM(beneficiary_count),0) AS beneficiaries,
          COALESCE(SUM(duration_hours),0) AS hours
        FROM tasks t${tw.sql}`).get(...tw.params)
        : { count: 0, volunteers: 0, beneficiaries: 0, hours: 0 };

      const rw = activityWhere('t', 'training_date', f);
      const trainings = wanted('egitim') ? db.prepare(`
        SELECT COUNT(*) AS count, COALESCE(SUM(participant_count),0) AS participants,
          COALESCE(SUM(volunteer_count),0) AS volunteers, COALESCE(SUM(duration_hours),0) AS hours
        FROM trainings t${rw.sql}`).get(...rw.params)
        : { count: 0, participants: 0, volunteers: 0, hours: 0 };

      const ew = activityWhere('e', 'event_date', f);
      const events = wanted('etkinlik') ? db.prepare(`
        SELECT COUNT(*) AS count, COALESCE(SUM(participant_count),0) AS participants,
          COALESCE(SUM(volunteer_count),0) AS volunteers,
          COALESCE(SUM(beneficiary_count),0) AS beneficiaries
        FROM events e${ew.sql}`).get(...ew.params)
        : { count: 0, participants: 0, volunteers: 0, beneficiaries: 0 };

      const mw = activityWhere('m', 'meeting_date', f);
      const meetings = wanted('toplanti') ? db.prepare(`
        SELECT COUNT(*) AS count, COALESCE(SUM(participant_count),0) AS participants
        FROM meetings m${mw.sql}`).get(...mw.params)
        : { count: 0, participants: 0 };

      // v1 tablosu — geriye dönük görünürlük için özet içinde kalır.
      // (v1 `field_activities` bir görev kaydıdır; bu yüzden activity_type=gorev ile gelir.)
      const faWhere = [];
      const faParams = [];
      if (f.province_id) { faWhere.push('fa.province_id = ?'); faParams.push(f.province_id); }
      if (f.district_id) { faWhere.push('fa.district_id = ?'); faParams.push(f.district_id); }
      if (f.region_id) { faWhere.push('pv.region_id = ?'); faParams.push(f.region_id); }
      if (f.from) { faWhere.push('fa.activity_date >= ?'); faParams.push(f.from); }
      if (f.to) { faWhere.push('fa.activity_date <= ?'); faParams.push(f.to); }
      const fieldActivities = wanted('gorev') ? db.prepare(`
        SELECT COUNT(*) AS count, COALESCE(SUM(fa.volunteer_count),0) AS volunteers,
          COALESCE(SUM(fa.beneficiary_count),0) AS beneficiaries
        FROM field_activities fa LEFT JOIN provinces pv ON pv.id = fa.province_id
        ${faWhere.length ? `WHERE ${faWhere.join(' AND ')}` : ''}`).get(...faParams)
        : { count: 0, volunteers: 0, beneficiaries: 0 };

      // --- Lojistik -------------------------------------------------------
      const lw = activityWhere('mr', 'request_date', f);
      const requests = { talep: 0, onaylandi: 0, gonderildi: 0, teslim_edildi: 0, iptal: 0, total: 0 };
      for (const row of db.prepare(
        `SELECT status, COUNT(*) AS c FROM material_requests mr${lw.sql} GROUP BY status`
      ).all(...lw.params)) {
        requests[row.status] += row.c;
        requests.total += row.c;
      }
      const shipments = db.prepare(
        'SELECT COUNT(*) AS count, COALESCE(SUM(quantity),0) AS quantity FROM shipments'
      ).get();
      const stock = db.prepare(`
        SELECT COUNT(*) AS products, COALESCE(SUM(quantity),0) AS total_quantity,
          COALESCE(SUM(CASE WHEN min_quantity > 0 AND quantity <= min_quantity THEN 1 ELSE 0 END),0) AS low_stock
        FROM stock_items`).get();

      // --- En çok yapılan görev türleri ------------------------------------
      const topTaskTypes = wanted('gorev') ? db.prepare(`
        SELECT t.task_type_id, li.name, COUNT(*) AS count
        FROM tasks t JOIN lookup_items li ON li.id = t.task_type_id${tw.sql}
        GROUP BY t.task_type_id ORDER BY count DESC, li.name LIMIT 10`).all(...tw.params) : [];

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

  // =======================================================  /dashboard/timeseries
  /** `from`/`to` verilmezse varsayılan aralık: son 12 ay (içinde bulunulan ay dahil). */
  function defaultRange(interval) {
    const now = new Date();
    const y = now.getUTCFullYear();
    const m = now.getUTCMonth(); // 0-11
    if (interval === 'year') return { from: `${y - 4}-01-01`, to: `${y}-12-31` };
    const start = new Date(Date.UTC(y, m - 11, 1));
    const end = new Date(Date.UTC(y, m + 1, 0)); // içinde bulunulan ayın son günü
    return { from: start.toISOString().slice(0, 10), to: end.toISOString().slice(0, 10) };
  }

  /**
   * Aralıktaki TÜM dönemleri üretir. Grafik ay atlamamalıdır: veri olmayan dönemler
   * de listede `count: 0` olarak bulunur.
   */
  function periodsBetween(from, to, interval) {
    const out = [];
    if (interval === 'year') {
      for (let y = Number(from.slice(0, 4)); y <= Number(to.slice(0, 4)) && out.length < 200; y += 1) {
        out.push(String(y));
      }
      return out;
    }
    let y = Number(from.slice(0, 4));
    let m = Number(from.slice(5, 7));
    const endY = Number(to.slice(0, 4));
    const endM = Number(to.slice(5, 7));
    // 600 dönem üst sınırı: hatalı/aşırı geniş aralıkların yanıtı şişirmesini engeller.
    while ((y < endY || (y === endY && m <= endM)) && out.length < 600) {
      out.push(`${y}-${String(m).padStart(2, '0')}`);
      m += 1;
      if (m > 12) { m = 1; y += 1; }
    }
    return out;
  }

  r.get('/dashboard/timeseries', (req, res, next) => {
    try {
      const metric = String(req.query.metric || '');
      if (!METRIC_NAMES.includes(metric)) {
        throw badRequest(`'metric' şunlardan biri olmalı: ${METRIC_NAMES.join(', ')}`);
      }
      const interval = req.query.interval ? String(req.query.interval) : 'month';
      if (!['month', 'year'].includes(interval)) {
        throw badRequest("'interval' 'month' veya 'year' olmalı");
      }
      const f = parseFilters(req.query);
      const range = defaultRange(interval);
      const from = f.from || range.from;
      const to = f.to || range.to;
      if (to < from) throw badRequest("'to' tarihi 'from' tarihinden önce olamaz");

      const fmt = interval === 'year' ? '%Y' : '%Y-%m';
      const def = METRICS[metric];
      const buckets = new Map();

      const collect = (table, dateCol, valueExpr) => {
        const w = activityWhere('x', dateCol, { ...f, from, to });
        for (const row of db.prepare(`
          SELECT strftime('${fmt}', x.${dateCol}) AS period, ${valueExpr} AS value
          FROM ${table} x${w.sql}
          GROUP BY period`).all(...w.params)) {
          if (!row.period) continue;
          buckets.set(row.period, (buckets.get(row.period) || 0) + Number(row.value || 0));
        }
      };

      if (def.sources) {
        for (const src of def.sources) collect(src.table, src.dateCol, `COALESCE(SUM(x.${src.col}),0)`);
      } else {
        collect(def.table, def.dateCol, 'COUNT(*)');
      }

      const data = periodsBetween(from, to, interval)
        .map((period) => ({ period, count: buckets.get(period) || 0 }));

      res.json({ metric, interval, from, to, data });
    } catch (e) { next(e); }
  });

  // ========================================================  /dashboard/provinces
  r.get('/dashboard/provinces', (req, res, next) => {
    try {
      const f = parseFilters(req.query);
      const wanted = (type) => !f.activity_type || f.activity_type === type;

      const where = [];
      const params = [];
      if (f.region_id) { where.push('p.region_id = ?'); params.push(f.region_id); }
      if (f.province_id) { where.push('p.id = ?'); params.push(f.province_id); }
      const whereSql = where.length ? ` WHERE ${where.join(' AND ')}` : '';

      const provinces = db.prepare(`
        SELECT p.id AS province_id, p.code AS province_code, p.name AS province_name,
               p.region_id, rg.name AS region_name
        FROM provinces p LEFT JOIN regions rg ON rg.id = p.region_id
        ${whereSql} ORDER BY p.code`).all(...params);

      // Sayaçlar il bazında GRUPLU tek sorgularla toplanır (81 il × N sorgu değil).
      const orgParams = [];
      const orgWhere = ['province_id IS NOT NULL'];
      if (f.district_id) { orgWhere.push('district_id = ?'); orgParams.push(f.district_id); }
      const orgByProvince = new Map();
      for (const row of db.prepare(`
        SELECT province_id, status, COUNT(*) AS c FROM org_units
        WHERE ${orgWhere.join(' AND ')} GROUP BY province_id, status`).all(...orgParams)) {
        if (!orgByProvince.has(row.province_id)) {
          orgByProvince.set(row.province_id, { aktif: 0, pasif: 0, teskilat_yok: 0 });
        }
        orgByProvince.get(row.province_id)[row.status] += row.c;
      }

      const personWhere = ['province_id IS NOT NULL'];
      const personParams = [];
      if (f.district_id) { personWhere.push('district_id = ?'); personParams.push(f.district_id); }
      const personByProvince = new Map(db.prepare(`
        SELECT province_id, COUNT(*) AS c FROM persons
        WHERE ${personWhere.join(' AND ')} GROUP BY province_id`).all(...personParams)
        .map((row) => [row.province_id, row.c]));

      const activityByProvince = new Map();
      for (const [type, def] of Object.entries(ACTIVITY_TABLES)) {
        if (!wanted(type)) continue;
        const w = activityWhere('x', def.dateCol, f);
        for (const row of db.prepare(`
          SELECT x.province_id, COUNT(*) AS c FROM ${def.table} x${w.sql}
          ${w.sql ? 'AND' : 'WHERE'} x.province_id IS NOT NULL
          GROUP BY x.province_id`).all(...w.params)) {
          activityByProvince.set(row.province_id, (activityByProvince.get(row.province_id) || 0) + row.c);
        }
      }

      const data = provinces.map((p) => {
        const org = orgByProvince.get(p.province_id) || { aktif: 0, pasif: 0, teskilat_yok: 0 };
        return {
          province_id: p.province_id,
          province_code: p.province_code,
          province_name: p.province_name,
          region_id: p.region_id,
          region_name: p.region_name,
          org_active: org.aktif,
          org_passive: org.pasif,
          org_none: org.teskilat_yok,
          person_count: personByProvince.get(p.province_id) || 0,
          activity_count: activityByProvince.get(p.province_id) || 0,
        };
      });

      res.json({ filters: f, data, total: data.length });
    } catch (e) { next(e); }
  });

  // =========================================================  /dashboard/by-region
  r.get('/dashboard/by-region', (req, res, next) => {
    try {
      const f = parseFilters(req.query);
      const wanted = (type) => !f.activity_type || f.activity_type === type;

      const counts = {};
      for (const [type, def] of Object.entries(ACTIVITY_TABLES)) {
        counts[type] = new Map();
        if (!wanted(type)) continue;
        const w = activityWhere('x', def.dateCol, f);
        for (const row of db.prepare(`
          SELECT x.region_id, COUNT(*) AS c FROM ${def.table} x${w.sql}
          ${w.sql ? 'AND' : 'WHERE'} x.region_id IS NOT NULL
          GROUP BY x.region_id`).all(...w.params)) {
          counts[type].set(row.region_id, row.c);
        }
      }

      const data = db.prepare(`
        SELECT rg.id AS region_id, rg.name AS region_name,
          (SELECT COUNT(*) FROM org_units o WHERE o.region_id = rg.id AND o.status = 'aktif') AS org_units_aktif,
          (SELECT COUNT(*) FROM org_units o WHERE o.region_id = rg.id AND o.status = 'teskilat_yok') AS org_units_teskilat_yok,
          (SELECT COUNT(*) FROM provinces p WHERE p.region_id = rg.id) AS province_count
        FROM regions rg ORDER BY rg.sort_order`).all()
        .map((row) => ({
          ...row,
          tasks: counts.gorev.get(row.region_id) || 0,
          trainings: counts.egitim.get(row.region_id) || 0,
          events: counts.etkinlik.get(row.region_id) || 0,
          meetings: counts.toplanti.get(row.region_id) || 0,
        }));

      res.json({ filters: f, data, total: data.length });
    } catch (e) { next(e); }
  });

  return r;
}
