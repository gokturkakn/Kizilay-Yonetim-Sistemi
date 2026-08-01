import { Router } from 'express';
import { requireRole } from '../auth.js';
import { listQuery, validDate } from '../helpers.js';

// Denetim izi "kimin" değiştirdiğini isimle göstermeli (SPEC §4) — ham ID yetmez.
const SELECT = `a.id, a.entity, a.entity_id, a.action, a.changed_by,
  COALESCE(u.name, 'Bilinmeyen kullanıcı (#' || a.changed_by || ')') AS changed_by_name,
  a.changes, a.created_at`;

export default function auditLogRoutes(db) {
  const r = Router();

  r.get('/audit-logs', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const where = [];
      const params = [];
      const { entity, from, to } = req.query;
      if (entity) { where.push('a.entity = ?'); params.push(String(entity)); }
      if (from) { where.push("a.created_at >= ?"); params.push(`${validDate(from, 'from')} 00:00:00`); }
      if (to) { where.push("a.created_at <= ?"); params.push(`${validDate(to, 'to')} 23:59:59`); }
      const result = listQuery(db, {
        select: SELECT, from: 'audit_logs a LEFT JOIN users u ON u.id = a.changed_by',
        where, params, orderBy: 'a.id DESC', query: req.query,
      });
      result.data = result.data.map((row) => ({
        ...row,
        changes: row.changes ? JSON.parse(row.changes) : null,
      }));
      res.json(result);
    } catch (e) { next(e); }
  });

  return r;
}
