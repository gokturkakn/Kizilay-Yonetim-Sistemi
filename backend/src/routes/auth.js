import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { signToken } from '../auth.js';
import { ApiError, requireFields } from '../helpers.js';
import { createLoginRateLimiter, clientIp } from '../loginRateLimit.js';
import { IS_PRODUCTION_LIKE } from '../config.js';

/** Yanıtlarda dönen kullanıcı gövdesi — `password_hash` asla dışarı çıkmaz. */
export function publicUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    region_id: user.region_id ?? null,
    province_id: user.province_id ?? null,
    district_id: user.district_id ?? null,
    must_change_password: user.must_change_password === 1 ? 1 : 0,
  };
}

export default function authRoutes(db) {
  const r = Router();
  // Vekil arkasındaysak (Render) gerçek istemci adresi X-Forwarded-For'dadır;
  // değilsek başlığa güvenilmez, aksi halde kilit uydurma başlıkla atlatılırdı.
  const trustProxy = process.env.KK_TRUST_PROXY === '1' || IS_PRODUCTION_LIKE;
  const limiter = createLoginRateLimiter();

  r.post('/auth/login', (req, res, next) => {
    const ip = clientIp(req, { trustProxy });
    let email = null;
    try {
      requireFields(req.body || {}, ['email', 'password']);
      email = String(req.body.email).trim().toLowerCase();

      // Denetim Y-3: kaba kuvvet koruması. Kilit kontrolü şifre karşılaştırmasından
      // ÖNCE yapılır; kilitliyken bcrypt maliyetini de ödemeyiz.
      try {
        limiter.assertAllowed(ip, email);
      } catch (e) {
        if (e.retryAfter) res.setHeader('Retry-After', String(e.retryAfter));
        throw e;
      }

      const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
      if (!user || !bcrypt.compareSync(String(req.body.password), user.password_hash)) {
        limiter.registerFailure(ip, email);
        throw new ApiError(401, 'INVALID_CREDENTIALS', 'E-posta veya şifre hatalı');
      }
      // v2: pasifleştirilmiş hesap giriş yapamaz (Kullanıcı Yönetimi).
      // Bu bir kimlik hatası değildir; sayaç artırılmaz.
      if (user.is_active === 0) {
        throw new ApiError(401, 'ACCOUNT_DISABLED', 'Bu hesap pasif durumda; yöneticinize başvurun');
      }

      limiter.registerSuccess(ip, email);
      res.json({ token: signToken(user), user: publicUser(user) });
    } catch (e) {
      next(e);
    }
  });

  return r;
}
