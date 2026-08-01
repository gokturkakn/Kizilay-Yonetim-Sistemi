// K2 — Bölgeler. Tüm raporlar bölge kırılımı alabilir.
import { Router } from 'express';
import { listQuery, notFound } from '../helpers.js';

export default function regionRoutes(db) {
  const r = Router();

  r.get('/regions', (req, res, next) => {
    try {
      res.json(listQuery(db, {
        select: `rg.id, rg.code, rg.name, rg.sort_order,
          (SELECT COUNT(*) FROM provinces p WHERE p.region_id = rg.id) AS province_count`,
        from: 'regions rg',
        orderBy: 'rg.sort_order',
        query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/regions/:id/provinces', (req, res, next) => {
    try {
      const region = db.prepare('SELECT id FROM regions WHERE id = ?').get(req.params.id);
      if (!region) throw notFound('Bölge bulunamadı');
      res.json(listQuery(db, {
        select: 'id, code, name, region_id',
        from: 'provinces',
        where: ['region_id = ?'],
        params: [region.id],
        orderBy: 'code',
        query: req.query,
      }));
    } catch (e) { next(e); }
  });

  return r;
}
