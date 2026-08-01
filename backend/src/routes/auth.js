import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { signToken } from '../auth.js';
import { ApiError, requireFields } from '../helpers.js';

export default function authRoutes(db) {
  const r = Router();

  r.post('/auth/login', (req, res, next) => {
    try {
      requireFields(req.body || {}, ['email', 'password']);
      const { email, password } = req.body;
      const user = db.prepare('SELECT * FROM users WHERE email = ?').get(String(email).trim().toLowerCase());
      if (!user || !bcrypt.compareSync(String(password), user.password_hash)) {
        throw new ApiError(401, 'INVALID_CREDENTIALS', 'E-posta veya şifre hatalı');
      }
      res.json({
        token: signToken(user),
        user: { id: user.id, name: user.name, email: user.email, role: user.role },
      });
    } catch (e) {
      next(e);
    }
  });

  return r;
}
