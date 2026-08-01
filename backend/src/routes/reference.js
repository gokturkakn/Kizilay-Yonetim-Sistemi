// İl/ilçe, komisyonlar, görev alanları, kurul/komisyon (bodies) referans uçları.
import { Router } from 'express';
import { requireRole } from '../auth.js';
import { listQuery, notFound, requireFields } from '../helpers.js';

export default function referenceRoutes(db) {
  const r = Router();

  // v2: `region_id` alanı eklendi ve filtre olarak kabul ediliyor (alan ekleme kırıcı değildir).
  r.get('/provinces', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      if (req.query.region_id) {
        where.push('region_id = ?');
        params.push(Number(req.query.region_id));
      }
      res.json(listQuery(db, {
        select: 'id, code, name, region_id',
        from: 'provinces',
        where,
        params,
        orderBy: 'code',
        query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/provinces/:id/districts', (req, res, next) => {
    try {
      const prov = db.prepare('SELECT id FROM provinces WHERE id = ?').get(req.params.id);
      if (!prov) throw notFound('İl bulunamadı');
      res.json(listQuery(db, {
        select: 'id, name, province_id',
        from: 'districts',
        where: ['province_id = ?'],
        params: [prov.id],
        orderBy: 'name',
        query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/commissions', (req, res) => {
    res.json(listQuery(db, {
      select: 'id, name, is_active',
      from: 'bodies',
      where: ["type = 'komisyon'"],
      orderBy: 'id',
      query: req.query,
    }));
  });

  r.post('/commissions', requireRole('genel_merkez'), (req, res, next) => {
    try {
      requireFields(req.body || {}, ['name']);
      const { lastInsertRowid } = db
        .prepare("INSERT INTO bodies (type, name) VALUES ('komisyon', ?)")
        .run(String(req.body.name).trim());
      const row = db.prepare('SELECT id, name, is_active FROM bodies WHERE id = ?').get(lastInsertRowid);
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.get('/task-areas', (req, res) => {
    res.json(listQuery(db, {
      select: 'id, name, is_active',
      from: 'task_areas',
      orderBy: 'id',
      query: req.query,
    }));
  });

  r.post('/task-areas', requireRole('genel_merkez'), (req, res, next) => {
    try {
      requireFields(req.body || {}, ['name']);
      const { lastInsertRowid } = db
        .prepare('INSERT INTO task_areas (name) VALUES (?)')
        .run(String(req.body.name).trim());
      const row = db.prepare('SELECT id, name, is_active FROM task_areas WHERE id = ?').get(lastInsertRowid);
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.get('/bodies', (req, res) => {
    res.json(listQuery(db, {
      select: 'id, type, name',
      from: 'bodies',
      orderBy: "CASE type WHEN 'koordinasyon_kurulu' THEN 0 ELSE 1 END, id",
      query: req.query,
    }));
  });

  return r;
}
