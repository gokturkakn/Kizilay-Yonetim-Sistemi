import jwt from 'jsonwebtoken';
import { JWT_SECRET, JWT_EXPIRES_IN } from './config.js';
import { ApiError } from './helpers.js';

export function signToken(user) {
  return jwt.sign(
    { id: user.id, name: user.name, email: user.email, role: user.role },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
}

export function authenticate(req, _res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return next(new ApiError(401, 'UNAUTHORIZED', 'Oturum bulunamadı (Bearer token gerekli)'));
  }
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    next(new ApiError(401, 'UNAUTHORIZED', 'Geçersiz ya da süresi dolmuş token'));
  }
}

export function requireRole(...roles) {
  return (req, _res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return next(new ApiError(403, 'FORBIDDEN', 'Bu işlem için yetkiniz yok'));
    }
    next();
  };
}

/**
 * `must_change_password` kapısı.
 *
 * Bayrak açıkken YALNIZCA iki uç çalışır:
 *   • `GET  /auth/me`              — istemcinin kimin bağlı olduğunu ve neden kilitli
 *                                    olduğunu öğrenmesi için (aksi halde giriş ekranı
 *                                    kullanıcıyı boş bir 403 duvarına çarpar).
 *   • `POST /auth/change-password` — kilidin tek çıkış yolu.
 * Diğer her istek 403 `PASSWORD_CHANGE_REQUIRED` alır.
 *
 * Bayrak HER İSTEKTE veritabanından okunur, token'dan değil: şifre değiştirildikten
 * sonra kullanıcının elindeki eski token da anında serbest kalmalıdır (yeniden giriş
 * zorunluluğu yok). Sorgu birincil anahtar üzerinden tek satırlıktır.
 */
export const PASSWORD_CHANGE_ALLOWED = [
  { method: 'GET', path: '/auth/me' },
  { method: 'POST', path: '/auth/change-password' },
];

export function requirePasswordChange(db) {
  const read = db.prepare('SELECT must_change_password FROM users WHERE id = ?');
  return (req, _res, next) => {
    try {
      if (!req.user) return next();
      const allowed = PASSWORD_CHANGE_ALLOWED
        .some((a) => a.method === req.method && a.path === req.path);
      if (allowed) return next();
      const row = read.get(req.user.id);
      if (row && row.must_change_password === 1) {
        return next(new ApiError(403, 'PASSWORD_CHANGE_REQUIRED',
          'Bu hesap için şifre değişikliği zorunludur. '
          + 'Devam etmeden önce POST /auth/change-password ile şifrenizi güncelleyin.'));
      }
      return next();
    } catch (e) { return next(e); }
  };
}
