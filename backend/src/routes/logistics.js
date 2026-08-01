/**
 * SPEC-V2 §3.3 — Lojistik: talep → gönderi → stok hareketi.
 *
 * Gönderi kaydı stok çıkışını ve talep durumunu TEK transaction içinde günceller;
 * yarım kalmış "gönderildi ama stok düşmedi" durumu oluşamaz.
 */
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  ApiError, badRequest, notFound, listQuery, requireFields, validDate, toIntOrThrow,
} from '../helpers.js';
import {
  resolveGeo, requireLookup, optionalLookup, optionalOrgUnit,
  optionalText, optionalDate, optionalInt,
} from '../v2.js';

const REQUEST_STATUSES = ['talep', 'onaylandi', 'gonderildi', 'teslim_edildi', 'iptal'];

const REQ_SELECT = `mr.id, mr.request_date, mr.org_unit_id, mr.region_id, mr.province_id,
  mr.district_id, mr.product_id, mr.quantity, mr.status, mr.requested_by_person_id, mr.notes,
  li.name AS product_name, ou.name AS org_unit_name, rg.name AS region_name,
  pr.name AS province_name, d.name AS district_name,
  (p.first_name || ' ' || p.last_name) AS requested_by_name,
  (SELECT COALESCE(SUM(s.quantity), 0) FROM shipments s WHERE s.request_id = mr.id) AS shipped_quantity,
  mr.created_by, u.name AS created_by_name, mr.created_at, mr.updated_at`;
const REQ_FROM = `material_requests mr
  JOIN lookup_items li ON li.id = mr.product_id
  LEFT JOIN org_units ou ON ou.id = mr.org_unit_id
  LEFT JOIN regions rg ON rg.id = mr.region_id
  LEFT JOIN provinces pr ON pr.id = mr.province_id
  LEFT JOIN districts d ON d.id = mr.district_id
  LEFT JOIN persons p ON p.id = mr.requested_by_person_id
  LEFT JOIN users u ON u.id = mr.created_by`;
const REQ_FIELDS = ['request_date', 'org_unit_id', 'region_id', 'province_id', 'district_id',
  'product_id', 'quantity', 'status', 'requested_by_person_id', 'notes'];

const SHIP_SELECT = `s.id, s.request_id, s.shipment_date, s.shipping_method_id, s.tracking_no,
  s.quantity, s.received_by, s.received_date, s.notes,
  mr.request_date, mr.product_id, mr.org_unit_id,
  li.name AS product_name, sm.name AS shipping_method_name, ou.name AS org_unit_name,
  s.created_by, u.name AS created_by_name, s.created_at, s.updated_at`;
const SHIP_FROM = `shipments s
  JOIN material_requests mr ON mr.id = s.request_id
  JOIN lookup_items li ON li.id = mr.product_id
  LEFT JOIN lookup_items sm ON sm.id = s.shipping_method_id
  LEFT JOIN org_units ou ON ou.id = mr.org_unit_id
  LEFT JOIN users u ON u.id = s.created_by`;
const SHIP_FIELDS = ['request_id', 'shipment_date', 'shipping_method_id', 'tracking_no',
  'quantity', 'received_by', 'received_date', 'notes'];

export default function logisticsRoutes(db) {
  const r = Router();
  const admin = requireRole('genel_merkez');

  const getRequest = (id) => db.prepare(`SELECT ${REQ_SELECT} FROM ${REQ_FROM} WHERE mr.id = ?`).get(id);
  const getShipment = (id) => db.prepare(`SELECT ${SHIP_SELECT} FROM ${SHIP_FROM} WHERE s.id = ?`).get(id);

  /** Stok hareketi yazar ve stok bakiyesini günceller. Aynı transaction içinde çağrılır. */
  function applyMovement({ productId, direction, quantity, reason, refType, refId, userId, allowNegative = false }) {
    db.prepare('INSERT OR IGNORE INTO stock_items (product_id, quantity, min_quantity) VALUES (?, 0, 0)')
      .run(productId);
    const current = db.prepare('SELECT quantity FROM stock_items WHERE product_id = ?').get(productId).quantity;
    const delta = direction === 'giris' ? quantity : -quantity;
    if (!allowNegative && current + delta < 0) {
      throw new ApiError(400, 'INSUFFICIENT_STOCK',
        `Stok yetersiz: mevcut ${current}, istenen çıkış ${quantity}`);
    }
    db.prepare(`INSERT INTO stock_movements (product_id, direction, quantity, reason, ref_type, ref_id, created_by)
      VALUES (?, ?, ?, ?, ?, ?, ?)`).run(productId, direction, quantity, reason ?? null, refType ?? null, refId ?? null, userId);
    db.prepare("UPDATE stock_items SET quantity = quantity + ?, updated_at = datetime('now') WHERE product_id = ?")
      .run(delta, productId);
  }

  // ======================================================= malzeme talepleri
  r.get('/material-requests', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      if (req.query.status) {
        if (!REQUEST_STATUSES.includes(req.query.status)) throw badRequest('status filtresi geçersiz');
        where.push('mr.status = ?'); params.push(req.query.status);
      }
      for (const [q, col] of [['product_id', 'mr.product_id'], ['org_unit_id', 'mr.org_unit_id'],
        ['region_id', 'mr.region_id'], ['province_id', 'mr.province_id']]) {
        if (req.query[q]) { where.push(`${col} = ?`); params.push(toIntOrThrow(req.query[q], q)); }
      }
      if (req.query.from) { where.push('mr.request_date >= ?'); params.push(validDate(req.query.from, 'from')); }
      if (req.query.to) { where.push('mr.request_date <= ?'); params.push(validDate(req.query.to, 'to')); }
      res.json(listQuery(db, {
        select: REQ_SELECT, from: REQ_FROM, where, params,
        orderBy: 'mr.request_date DESC, mr.id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/material-requests/:id', (req, res, next) => {
    try {
      const row = getRequest(req.params.id);
      if (!row) throw notFound('Malzeme talebi bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  function validateRequest(body, existing = null) {
    const pick = (k) => (body[k] !== undefined ? body[k] : existing?.[k]);
    const quantity = toIntOrThrow(pick('quantity'), 'quantity');
    if (quantity <= 0) throw badRequest("'quantity' 0'dan büyük olmalı");
    const personId = optionalInt(pick('requested_by_person_id'), 'requested_by_person_id');
    if (personId !== null && !db.prepare('SELECT id FROM persons WHERE id = ?').get(personId)) {
      throw badRequest('requested_by_person_id geçersiz');
    }
    const status = pick('status');
    if (status !== undefined && status !== null && status !== '' && !REQUEST_STATUSES.includes(status)) {
      throw badRequest(`status şunlardan biri olmalı: ${REQUEST_STATUSES.join(', ')}`);
    }
    return {
      request_date: validDate(pick('request_date'), 'request_date'),
      org_unit_id: optionalOrgUnit(db, pick('org_unit_id')),
      ...resolveGeo(db, {
        region_id: pick('region_id'), province_id: pick('province_id'), district_id: pick('district_id'),
      }),
      product_id: requireLookup(db, pick('product_id'), 'lojistik_urun', 'product_id').id,
      quantity,
      status: status || existing?.status || 'talep',
      requested_by_person_id: personId,
      notes: optionalText(pick('notes')),
    };
  }

  r.post('/material-requests', (req, res, next) => {
    try {
      requireFields(req.body || {}, ['request_date', 'product_id', 'quantity']);
      const p = validateRequest(req.body);
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO material_requests (request_date, org_unit_id, region_id, province_id, district_id,
          product_id, quantity, status, requested_by_person_id, notes, created_by)
        VALUES (@request_date, @org_unit_id, @region_id, @province_id, @district_id,
          @product_id, @quantity, @status, @requested_by_person_id, @notes, @created_by)`)
        .run({ ...p, created_by: req.user.id });
      const row = getRequest(lastInsertRowid);
      auditLog(db, { entity: 'material_requests', entityId: row.id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/material-requests/:id', (req, res, next) => {
    try {
      const before = getRequest(req.params.id);
      if (!before) throw notFound('Malzeme talebi bulunamadı');
      const p = validateRequest(req.body || {}, before);
      db.prepare(`
        UPDATE material_requests SET request_date=@request_date, org_unit_id=@org_unit_id,
          region_id=@region_id, province_id=@province_id, district_id=@district_id,
          product_id=@product_id, quantity=@quantity, status=@status,
          requested_by_person_id=@requested_by_person_id, notes=@notes, updated_at=datetime('now')
        WHERE id=@id`).run({ ...p, id: before.id });
      const after = getRequest(before.id);
      auditLog(db, {
        entity: 'material_requests', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, REQ_FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.patch('/material-requests/:id/status', admin, (req, res, next) => {
    try {
      const before = getRequest(req.params.id);
      if (!before) throw notFound('Malzeme talebi bulunamadı');
      const status = (req.body || {}).status;
      if (!REQUEST_STATUSES.includes(status)) {
        throw badRequest(`status şunlardan biri olmalı: ${REQUEST_STATUSES.join(', ')}`);
      }
      db.prepare("UPDATE material_requests SET status = ?, updated_at = datetime('now') WHERE id = ?")
        .run(status, before.id);
      auditLog(db, {
        entity: 'material_requests', entityId: before.id, action: 'status_change', changedBy: req.user.id,
        changes: { status: { old: before.status, new: status } },
      });
      res.json(getRequest(before.id));
    } catch (e) { next(e); }
  });

  r.delete('/material-requests/:id', admin, (req, res, next) => {
    try {
      const before = getRequest(req.params.id);
      if (!before) throw notFound('Malzeme talebi bulunamadı');
      if (db.prepare('SELECT 1 FROM shipments WHERE request_id = ? LIMIT 1').get(before.id)) {
        throw new ApiError(409, 'IN_USE', 'Bu talebe bağlı gönderi var; önce gönderiyi silin');
      }
      db.prepare('DELETE FROM material_requests WHERE id = ?').run(before.id);
      auditLog(db, { entity: 'material_requests', entityId: before.id, action: 'delete', changedBy: req.user.id, changes: before });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  // ============================================================== gönderiler
  r.get('/shipments', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      for (const [q, col] of [['request_id', 's.request_id'], ['shipping_method_id', 's.shipping_method_id'],
        ['product_id', 'mr.product_id']]) {
        if (req.query[q]) { where.push(`${col} = ?`); params.push(toIntOrThrow(req.query[q], q)); }
      }
      if (req.query.from) { where.push('s.shipment_date >= ?'); params.push(validDate(req.query.from, 'from')); }
      if (req.query.to) { where.push('s.shipment_date <= ?'); params.push(validDate(req.query.to, 'to')); }
      res.json(listQuery(db, {
        select: SHIP_SELECT, from: SHIP_FROM, where, params,
        orderBy: 's.shipment_date DESC, s.id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/shipments/:id', (req, res, next) => {
    try {
      const row = getShipment(req.params.id);
      if (!row) throw notFound('Gönderi bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  function validateShipment(body, existing = null) {
    const pick = (k) => (body[k] !== undefined ? body[k] : existing?.[k]);
    const requestId = toIntOrThrow(pick('request_id'), 'request_id');
    const request = db.prepare('SELECT id, product_id FROM material_requests WHERE id = ?').get(requestId);
    if (!request) throw badRequest('request_id geçersiz');
    const quantity = toIntOrThrow(pick('quantity'), 'quantity');
    if (quantity <= 0) throw badRequest("'quantity' 0'dan büyük olmalı");
    return {
      request_id: requestId,
      product_id: request.product_id,
      shipment_date: validDate(pick('shipment_date'), 'shipment_date'),
      shipping_method_id: optionalLookup(db, pick('shipping_method_id'), 'gonderim_sekli', 'shipping_method_id'),
      tracking_no: optionalText(pick('tracking_no')),
      quantity,
      received_by: optionalText(pick('received_by')),
      received_date: optionalDate(pick('received_date'), 'received_date'),
      notes: optionalText(pick('notes')),
    };
  }

  r.post('/shipments', (req, res, next) => {
    try {
      requireFields(req.body || {}, ['request_id', 'shipment_date', 'quantity']);
      const p = validateShipment(req.body);
      const id = db.transaction(() => {
        const { lastInsertRowid } = db.prepare(`
          INSERT INTO shipments (request_id, shipment_date, shipping_method_id, tracking_no,
            quantity, received_by, received_date, notes, created_by)
          VALUES (@request_id, @shipment_date, @shipping_method_id, @tracking_no,
            @quantity, @received_by, @received_date, @notes, @created_by)`)
          .run({ ...p, created_by: req.user.id });
        const shipmentId = Number(lastInsertRowid);
        applyMovement({
          productId: p.product_id, direction: 'cikis', quantity: p.quantity,
          reason: `Gönderi #${shipmentId}`, refType: 'shipments', refId: shipmentId, userId: req.user.id,
        });
        db.prepare("UPDATE material_requests SET status = ?, updated_at = datetime('now') WHERE id = ?")
          .run(p.received_date ? 'teslim_edildi' : 'gonderildi', p.request_id);
        return shipmentId;
      })();
      const row = getShipment(id);
      auditLog(db, { entity: 'shipments', entityId: id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/shipments/:id', (req, res, next) => {
    try {
      const before = getShipment(req.params.id);
      if (!before) throw notFound('Gönderi bulunamadı');
      const p = validateShipment(req.body || {}, before);
      db.transaction(() => {
        db.prepare(`
          UPDATE shipments SET request_id=@request_id, shipment_date=@shipment_date,
            shipping_method_id=@shipping_method_id, tracking_no=@tracking_no, quantity=@quantity,
            received_by=@received_by, received_date=@received_date, notes=@notes,
            updated_at=datetime('now')
          WHERE id=@id`).run({ ...p, id: before.id });
        // Miktar değiştiyse stoğu farkla düzelt.
        const delta = p.quantity - before.quantity;
        if (delta !== 0) {
          applyMovement({
            productId: p.product_id, direction: delta > 0 ? 'cikis' : 'giris', quantity: Math.abs(delta),
            reason: `Gönderi #${before.id} miktar düzeltmesi`, refType: 'shipments', refId: before.id,
            userId: req.user.id,
          });
        }
        if (p.received_date) {
          db.prepare("UPDATE material_requests SET status = 'teslim_edildi', updated_at = datetime('now') WHERE id = ?")
            .run(p.request_id);
        }
      })();
      const after = getShipment(before.id);
      auditLog(db, {
        entity: 'shipments', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, SHIP_FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.delete('/shipments/:id', admin, (req, res, next) => {
    try {
      const before = getShipment(req.params.id);
      if (!before) throw notFound('Gönderi bulunamadı');
      db.transaction(() => {
        db.prepare('DELETE FROM shipments WHERE id = ?').run(before.id);
        // Stok çıkışını geri al.
        applyMovement({
          productId: before.product_id, direction: 'giris', quantity: before.quantity,
          reason: `Gönderi #${before.id} iptali`, refType: 'shipments', refId: before.id,
          userId: req.user.id,
        });
        db.prepare("UPDATE material_requests SET status = 'talep', updated_at = datetime('now') WHERE id = ?")
          .run(before.request_id);
      })();
      auditLog(db, { entity: 'shipments', entityId: before.id, action: 'delete', changedBy: req.user.id, changes: before });
      res.status(204).end();
    } catch (e) { next(e); }
  });

  // ==================================================================== stok
  r.get('/stock-items', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      if (req.query.product_id) {
        where.push('si.product_id = ?'); params.push(toIntOrThrow(req.query.product_id, 'product_id'));
      }
      if (req.query.low_only === '1' || req.query.low_only === 'true') {
        where.push('si.quantity <= si.min_quantity AND si.min_quantity > 0');
      }
      res.json(listQuery(db, {
        select: `si.id, si.product_id, li.name AS product_name, si.quantity, si.min_quantity,
          CASE WHEN si.min_quantity > 0 AND si.quantity <= si.min_quantity THEN 1 ELSE 0 END AS is_low,
          si.updated_at`,
        from: 'stock_items si JOIN lookup_items li ON li.id = si.product_id',
        where, params, orderBy: 'li.sort_order, li.name', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.put('/stock-items/:productId', admin, (req, res, next) => {
    try {
      const productId = toIntOrThrow(req.params.productId, 'productId');
      requireLookup(db, productId, 'lojistik_urun', 'productId');
      const minQty = toIntOrThrow((req.body || {}).min_quantity, 'min_quantity');
      if (minQty < 0) throw badRequest("'min_quantity' negatif olamaz");
      db.prepare('INSERT OR IGNORE INTO stock_items (product_id, quantity, min_quantity) VALUES (?, 0, 0)')
        .run(productId);
      db.prepare("UPDATE stock_items SET min_quantity = ?, updated_at = datetime('now') WHERE product_id = ?")
        .run(minQty, productId);
      const row = db.prepare(`
        SELECT si.id, si.product_id, li.name AS product_name, si.quantity, si.min_quantity, si.updated_at
        FROM stock_items si JOIN lookup_items li ON li.id = si.product_id WHERE si.product_id = ?`).get(productId);
      auditLog(db, { entity: 'stock_items', entityId: row.id, action: 'update', changedBy: req.user.id, changes: { min_quantity: minQty } });
      res.json(row);
    } catch (e) { next(e); }
  });

  r.get('/stock-movements', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      if (req.query.product_id) { where.push('sm.product_id = ?'); params.push(toIntOrThrow(req.query.product_id, 'product_id')); }
      if (req.query.direction) {
        if (!['giris', 'cikis'].includes(req.query.direction)) throw badRequest("direction 'giris' veya 'cikis' olmalı");
        where.push('sm.direction = ?'); params.push(req.query.direction);
      }
      if (req.query.from) { where.push('sm.created_at >= ?'); params.push(validDate(req.query.from, 'from')); }
      if (req.query.to) { where.push('sm.created_at <= ?'); params.push(`${validDate(req.query.to, 'to')} 23:59:59`); }
      res.json(listQuery(db, {
        select: `sm.id, sm.product_id, li.name AS product_name, sm.direction, sm.quantity,
          sm.reason, sm.ref_type, sm.ref_id, sm.created_by, u.name AS created_by_name, sm.created_at`,
        from: `stock_movements sm JOIN lookup_items li ON li.id = sm.product_id
               LEFT JOIN users u ON u.id = sm.created_by`,
        where, params, orderBy: 'sm.created_at DESC, sm.id DESC', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.post('/stock-movements', admin, (req, res, next) => {
    try {
      const b = req.body || {};
      requireFields(b, ['product_id', 'direction', 'quantity']);
      if (!['giris', 'cikis'].includes(b.direction)) throw badRequest("direction 'giris' veya 'cikis' olmalı");
      const productId = requireLookup(db, b.product_id, 'lojistik_urun', 'product_id').id;
      const quantity = toIntOrThrow(b.quantity, 'quantity');
      if (quantity <= 0) throw badRequest("'quantity' 0'dan büyük olmalı");

      const id = db.transaction(() => {
        applyMovement({
          productId, direction: b.direction, quantity, reason: optionalText(b.reason),
          refType: null, refId: null, userId: req.user.id,
        });
        return db.prepare('SELECT MAX(id) AS id FROM stock_movements').get().id;
      })();
      const row = db.prepare(`
        SELECT sm.id, sm.product_id, li.name AS product_name, sm.direction, sm.quantity,
          sm.reason, sm.created_by, sm.created_at
        FROM stock_movements sm JOIN lookup_items li ON li.id = sm.product_id WHERE sm.id = ?`).get(id);
      auditLog(db, { entity: 'stock_movements', entityId: id, action: 'create', changedBy: req.user.id, changes: row });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  return r;
}
