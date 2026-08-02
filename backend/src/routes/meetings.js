/**
 * Toplantılar — v1 ucu SPEC-V2 §3.2D için genişletildi (yeni uç açılmadı).
 *
 * Geriye dönük uyum: v1 gövdesi (`body_id`, `meeting_date`, `decision`, `outcome`) aynen
 * çalışır. v2'de `body_id` opsiyoneldir (Kamp/Çalıştay bir kurula bağlı değildir) ve
 * `decision` ("Alınan Kararlar") zorunlu olmaktan çıkmıştır — sözleşme gevşetildi,
 * dolayısıyla v1 istemcisi etkilenmez.
 *
 * Dinamik alan kuralı: yöntem "Yüz Yüze" ise Toplantı Yeri, "Çevrim İçi" ise Platform
 * alınır; yanlış olan alan gönderilirse 400 döner.
 */
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  badRequest, notFound, listQuery, requireFields, validDate, toIntOrThrow,
} from '../helpers.js';
import {
  resolveGeo, optionalLookup, optionalOrgUnit, optionalText, attachmentCountSql,
} from '../v2.js';
import { nonNegativeInt } from '../v2.js';

const FIELDS = ['body_id', 'meeting_type_id', 'method_id', 'location', 'platform', 'org_unit_id',
  'region_id', 'province_id', 'district_id', 'meeting_date', 'participants', 'participant_count',
  'agenda', 'decision', 'outcome'];
const SELECT = `m.id, m.body_id, m.meeting_type_id, m.method_id, m.location, m.platform,
  m.org_unit_id, m.region_id, m.province_id, m.district_id, m.meeting_date, m.participants,
  m.participant_count, m.agenda, m.decision, m.outcome,
  b.name AS body_name, mt.name AS meeting_type_name, mm.name AS method_name,
  ou.name AS org_unit_name, rg.name AS region_name, pr.name AS province_name, d.name AS district_name,
  ${attachmentCountSql('meetings', 'm')},
  m.created_by, u.name AS created_by_name, m.created_at, m.updated_at`;
const FROM = `meetings m
  LEFT JOIN bodies b ON b.id = m.body_id
  LEFT JOIN lookup_items mt ON mt.id = m.meeting_type_id
  LEFT JOIN lookup_items mm ON mm.id = m.method_id
  LEFT JOIN org_units ou ON ou.id = m.org_unit_id
  LEFT JOIN regions rg ON rg.id = m.region_id
  LEFT JOIN provinces pr ON pr.id = m.province_id
  LEFT JOIN districts d ON d.id = m.district_id
  LEFT JOIN users u ON u.id = m.created_by`;

const ONLINE = 'Çevrim İçi';
const IN_PERSON = 'Yüz Yüze';

export default function meetingRoutes(db) {
  const r = Router();
  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE m.id = ?`).get(id);

  function validate(body, existing = null) {
    const pick = (k) => (body[k] !== undefined ? body[k] : existing?.[k]);

    let bodyId = null;
    const rawBody = pick('body_id');
    if (rawBody !== undefined && rawBody !== null && rawBody !== '') {
      bodyId = toIntOrThrow(rawBody, 'body_id');
      if (!db.prepare('SELECT id FROM bodies WHERE id = ?').get(bodyId)) {
        throw badRequest('body_id geçersiz');
      }
    }

    const methodId = optionalLookup(db, pick('method_id'), 'toplanti_yontemi', 'method_id');
    const methodName = methodId
      ? db.prepare('SELECT name FROM lookup_items WHERE id = ?').get(methodId).name
      : null;

    const location = optionalText(pick('location'));
    const platform = optionalText(pick('platform'));
    if (methodName === IN_PERSON && platform !== null) {
      throw badRequest("Yüz yüze toplantıda 'platform' alanı doldurulamaz; 'location' kullanın");
    }
    if (methodName === ONLINE && location !== null) {
      throw badRequest("Çevrim içi toplantıda 'location' alanı doldurulamaz; 'platform' kullanın");
    }

    const geo = resolveGeo(db, {
      region_id: pick('region_id'), province_id: pick('province_id'), district_id: pick('district_id'),
    });
    const rawDecision = pick('decision');

    return {
      body_id: bodyId,
      meeting_type_id: optionalLookup(db, pick('meeting_type_id'), 'toplanti_turu', 'meeting_type_id'),
      method_id: methodId,
      location,
      platform,
      org_unit_id: optionalOrgUnit(db, pick('org_unit_id')),
      region_id: geo.region_id,
      province_id: geo.province_id,
      district_id: geo.district_id,
      meeting_date: validDate(pick('meeting_date'), 'meeting_date'),
      participants: optionalText(pick('participants')),
      // Katılımcı SAYISI: serbest metin `participants` alanının yanında sayısal toplanabilir alan.
      participant_count: pick('participant_count') === undefined || pick('participant_count') === null
        || pick('participant_count') === ''
        ? null
        : nonNegativeInt(pick('participant_count'), 'participant_count'),
      agenda: optionalText(pick('agenda')),
      // v1'de zorunluydu; v2'de boş olabilir (toplantı öncesi kayıt açma).
      decision: rawDecision === undefined || rawDecision === null ? '' : String(rawDecision).trim(),
      outcome: optionalText(pick('outcome')),
    };
  }

  r.get('/meetings', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      for (const [q, col] of [['body_id', 'm.body_id'], ['meeting_type_id', 'm.meeting_type_id'],
        ['method_id', 'm.method_id'], ['org_unit_id', 'm.org_unit_id'],
        ['region_id', 'm.region_id'], ['province_id', 'm.province_id'],
        ['district_id', 'm.district_id']]) {
        if (req.query[q]) { where.push(`${col} = ?`); params.push(toIntOrThrow(req.query[q], q)); }
      }
      if (req.query.from) { where.push('m.meeting_date >= ?'); params.push(validDate(req.query.from, 'from')); }
      if (req.query.to) { where.push('m.meeting_date <= ?'); params.push(validDate(req.query.to, 'to')); }
      res.json(listQuery(db, {
        select: SELECT, from: FROM, where, params,
        orderBy: 'm.meeting_date DESC, m.id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/meetings/:id', (req, res, next) => {
    try {
      const row = getOne(req.params.id);
      if (!row) throw notFound('Toplantı bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  r.post('/meetings', (req, res, next) => {
    try {
      requireFields(req.body || {}, ['meeting_date']);
      const p = validate(req.body);
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO meetings (body_id, meeting_type_id, method_id, location, platform, org_unit_id,
          region_id, province_id, district_id, meeting_date, participants, participant_count,
          agenda, decision, outcome, created_by)
        VALUES (@body_id, @meeting_type_id, @method_id, @location, @platform, @org_unit_id,
          @region_id, @province_id, @district_id, @meeting_date, @participants, @participant_count,
          @agenda, @decision, @outcome, @created_by)`)
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
      const p = validate(req.body || {}, before);
      db.prepare(`
        UPDATE meetings SET body_id=@body_id, meeting_type_id=@meeting_type_id, method_id=@method_id,
          location=@location, platform=@platform, org_unit_id=@org_unit_id, region_id=@region_id,
          province_id=@province_id, district_id=@district_id, meeting_date=@meeting_date,
          participants=@participants, participant_count=@participant_count,
          agenda=@agenda, decision=@decision, outcome=@outcome, updated_at=datetime('now')
        WHERE id=@id`).run({ ...p, id: before.id });
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
