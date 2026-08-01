import jwt from 'jsonwebtoken';
import { JWT_SECRET } from './config.js';
import { ApiError } from './helpers.js';

export function signToken(user) {
  return jwt.sign(
    { id: user.id, name: user.name, email: user.email, role: user.role },
    JWT_SECRET,
    { expiresIn: '12h' }
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
