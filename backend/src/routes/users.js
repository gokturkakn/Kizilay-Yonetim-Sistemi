/**
 * Yönetim Paneli — Kullanıcı Yönetimi.
 *
 * Denetim raporu Y-2'nin doğrudan karşılığı: v1'de ülke genelinde tek paylaşımlı `saha`
 * hesabı vardı ve ikinci bir hesap açmanın yolu yoktu; bu, `created_by` alanını ve
 * dolayısıyla tüm denetim izini anlamsızlaştırıyordu.
 *
 * `password_hash` hiçbir yanıtta dönmez.
 */
import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import {
  ApiError, badRequest, conflict, notFound, listQuery, parseBoolFlag,
  requireFields, EMAIL_RE, toIntOrThrow,
} from '../helpers.js';
import { optionalInt } from '../v2.js';

const ROLES = ['genel_merkez', 'saha'];
const MIN_PASSWORD = 8;
const SELECT = `u.id, u.name, u.email, u.role, u.region_id, u.province_id, u.is_active,
  rg.name AS region_name, pr.name AS province_name, u.created_at, u.updated_at`;
const FROM = `users u
  LEFT JOIN regions rg ON rg.id = u.region_id
  LEFT JOIN provinces pr ON pr.id = u.province_id`;
const FIELDS = ['name', 'email', 'role', 'region_id', 'province_id', 'is_active'];

function checkPassword(value) {
  const pwd = String(value ?? '');
  if (pwd.length < MIN_PASSWORD) {
    throw new ApiError(400, 'WEAK_PASSWORD', `Şifre en az ${MIN_PASSWORD} karakter olmalı`);
  }
  return pwd;
}

export default function userRoutes(db) {
  const r = Router();
  const admin = requireRole('genel_merkez');

  const getOne = (id) => db.prepare(`SELECT ${SELECT} FROM ${FROM} WHERE u.id = ?`).get(id);

  function validateScope(body, existing = null) {
    const regionId = body.region_id !== undefined ? optionalInt(body.region_id, 'region_id') : (existing?.region_id ?? null);
    if (regionId !== null && !db.prepare('SELECT id FROM regions WHERE id = ?').get(regionId)) {
      throw badRequest('region_id geçersiz');
    }
    const provinceId = body.province_id !== undefined ? optionalInt(body.province_id, 'province_id') : (existing?.province_id ?? null);
    if (provinceId !== null && !db.prepare('SELECT id FROM provinces WHERE id = ?').get(provinceId)) {
      throw badRequest('province_id geçersiz');
    }
    return { region_id: regionId, province_id: provinceId };
  }

  function activeAdminCount(excludeId = null) {
    return db.prepare(
      "SELECT COUNT(*) AS c FROM users WHERE role = 'genel_merkez' AND is_active = 1 AND id <> ?"
    ).get(excludeId ?? -1).c;
  }

  r.get('/users', admin, (req, res, next) => {
    try {
      const where = [];
      const params = [];
      if (req.query.role) {
        if (!ROLES.includes(req.query.role)) throw badRequest('role filtresi geçersiz');
        where.push('u.role = ?'); params.push(req.query.role);
      }
      const active = parseBoolFlag(req.query.is_active);
      if (active !== undefined) { where.push('u.is_active = ?'); params.push(active); }
      if (req.query.q) { where.push('(u.name LIKE ? OR u.email LIKE ?)'); params.push(`%${req.query.q}%`, `%${req.query.q}%`); }
      res.json(listQuery(db, {
        select: SELECT, from: FROM, where, params, orderBy: 'u.name', query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/users/:id', admin, (req, res, next) => {
    try {
      const row = getOne(req.params.id);
      if (!row) throw notFound('Kullanıcı bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  r.post('/users', admin, (req, res, next) => {
    try {
      const b = req.body || {};
      requireFields(b, ['name', 'email', 'password', 'role']);
      const email = String(b.email).trim().toLowerCase();
      if (!EMAIL_RE.test(email)) throw badRequest('E-posta biçimi geçersiz');
      if (!ROLES.includes(b.role)) throw badRequest(`role şunlardan biri olmalı: ${ROLES.join(', ')}`);
      if (db.prepare('SELECT id FROM users WHERE email = ?').get(email)) {
        throw conflict('Bu e-posta ile kayıtlı bir kullanıcı zaten var');
      }
      const password = checkPassword(b.password);
      const scope = validateScope(b);

      const { lastInsertRowid } = db.prepare(`
        INSERT INTO users (name, email, password_hash, role, region_id, province_id, is_active, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))`).run(
        String(b.name).trim(), email, bcrypt.hashSync(password, 10), b.role,
        scope.region_id, scope.province_id, parseBoolFlag(b.is_active) ?? 1
      );
      const row = getOne(lastInsertRowid);
      auditLog(db, {
        entity: 'users', entityId: row.id, action: 'create', changedBy: req.user.id,
        changes: { name: row.name, email: row.email, role: row.role, region_id: row.region_id, province_id: row.province_id },
      });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/users/:id', admin, (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Kullanıcı bulunamadı');
      const b = req.body || {};
      const email = b.email !== undefined ? String(b.email).trim().toLowerCase() : before.email;
      if (!EMAIL_RE.test(email)) throw badRequest('E-posta biçimi geçersiz');
      const dupe = db.prepare('SELECT id FROM users WHERE email = ? AND id <> ?').get(email, before.id);
      if (dupe) throw conflict('Bu e-posta ile kayıtlı bir kullanıcı zaten var');
      const role = b.role !== undefined ? b.role : before.role;
      if (!ROLES.includes(role)) throw badRequest(`role şunlardan biri olmalı: ${ROLES.join(', ')}`);
      // Son aktif genel merkez hesabının rolü düşürülemez.
      if (before.role === 'genel_merkez' && role !== 'genel_merkez'
        && before.is_active === 1 && activeAdminCount(before.id) === 0) {
        throw new ApiError(409, 'LAST_ADMIN', 'Sistemdeki son genel merkez hesabının rolü değiştirilemez');
      }
      const scope = validateScope(b, before);

      db.prepare(`
        UPDATE users SET name = ?, email = ?, role = ?, region_id = ?, province_id = ?,
          updated_at = datetime('now') WHERE id = ?`).run(
        b.name !== undefined ? String(b.name).trim() : before.name,
        email, role, scope.region_id, scope.province_id, before.id
      );
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'users', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.patch('/users/:id/active', admin, (req, res, next) => {
    try {
      const before = getOne(req.params.id);
      if (!before) throw notFound('Kullanıcı bulunamadı');
      const flag = parseBoolFlag((req.body || {}).is_active);
      if (flag === undefined) throw badRequest("'is_active' alanı zorunludur");
      if (flag === 0 && before.role === 'genel_merkez' && activeAdminCount(before.id) === 0) {
        throw new ApiError(409, 'LAST_ADMIN', 'Sistemdeki son aktif genel merkez hesabı pasifleştirilemez');
      }
      db.prepare("UPDATE users SET is_active = ?, updated_at = datetime('now') WHERE id = ?")
        .run(flag, before.id);
      const after = getOne(before.id);
      auditLog(db, {
        entity: 'users', entityId: before.id, action: 'active_toggle', changedBy: req.user.id,
        changes: { is_active: { old: before.is_active, new: flag } },
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.put('/users/:id/password', admin, (req, res, next) => {
    try {
      const user = getOne(req.params.id);
      if (!user) throw notFound('Kullanıcı bulunamadı');
      const password = checkPassword((req.body || {}).password);
      db.prepare("UPDATE users SET password_hash = ?, updated_at = datetime('now') WHERE id = ?")
        .run(bcrypt.hashSync(password, 10), user.id);
      // Şifrenin kendisi ASLA günlüğe yazılmaz.
      auditLog(db, {
        entity: 'users', entityId: user.id, action: 'password_reset', changedBy: req.user.id,
        changes: { password: 'değiştirildi' },
      });
      res.json({ ok: true });
    } catch (e) { next(e); }
  });

  return r;
}

/** Kullanıcının kendi şifresini değiştirmesi (rol farketmez). */
export function selfPasswordRoute(db) {
  const r = Router();
  r.post('/auth/change-password', (req, res, next) => {
    try {
      const b = req.body || {};
      requireFields(b, ['current_password', 'new_password']);
      const row = db.prepare('SELECT id, password_hash FROM users WHERE id = ?').get(req.user.id);
      if (!row) throw notFound('Kullanıcı bulunamadı');
      if (!bcrypt.compareSync(String(b.current_password), row.password_hash)) {
        throw new ApiError(401, 'UNAUTHORIZED', 'Mevcut şifre hatalı');
      }
      const password = checkPassword(b.new_password);
      db.prepare("UPDATE users SET password_hash = ?, updated_at = datetime('now') WHERE id = ?")
        .run(bcrypt.hashSync(password, 10), row.id);
      auditLog(db, {
        entity: 'users', entityId: row.id, action: 'password_change', changedBy: req.user.id,
        changes: { password: 'değiştirildi' },
      });
      res.json({ ok: true });
    } catch (e) { next(e); }
  });
  return r;
}

export { toIntOrThrow };
