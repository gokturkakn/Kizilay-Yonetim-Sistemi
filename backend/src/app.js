import express from 'express';
import { authenticate } from './auth.js';
import { ApiError, errorBody } from './helpers.js';
import authRoutes from './routes/auth.js';
import referenceRoutes from './routes/reference.js';
import personRoutes from './routes/persons.js';
import membershipRoutes from './routes/memberships.js';
import fieldActivityRoutes from './routes/fieldActivities.js';
import meetingRoutes from './routes/meetings.js';
import assignmentRoutes from './routes/assignments.js';
import auditLogRoutes from './routes/auditLogs.js';
import exportRoutes from './routes/exports.js';

export function createApp(db) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '2mb' }));

  // Basit CORS (mobil/web istemci geliştirmesi için)
  app.use((req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
    if (req.method === 'OPTIONS') return res.status(204).end();
    next();
  });

  app.get('/health', (_req, res) => {
    try {
      const provinces = db.prepare('SELECT COUNT(*) AS c FROM provinces').get().c;
      const districts = db.prepare('SELECT COUNT(*) AS c FROM districts').get().c;
      const commissions = db.prepare("SELECT COUNT(*) AS c FROM bodies WHERE type = 'komisyon'").get().c;
      res.json({ status: 'ok', db: 'ok', seeded: { provinces, districts, commissions } });
    } catch {
      res.status(500).json({ status: 'error', db: 'error' });
    }
  });

  const api = express.Router();
  api.use(authRoutes(db)); // /auth/login — token gerektirmez

  const secured = express.Router();
  secured.use(authenticate);
  secured.use(referenceRoutes(db));
  secured.use(personRoutes(db));
  secured.use(membershipRoutes(db));
  secured.use(fieldActivityRoutes(db));
  secured.use(meetingRoutes(db));
  secured.use(assignmentRoutes(db));
  secured.use(auditLogRoutes(db));
  secured.use(exportRoutes(db));
  api.use(secured);

  app.use('/api/v1', api);

  app.use((req, res) => {
    res.status(404).json(errorBody('NOT_FOUND', `Uç nokta bulunamadı: ${req.method} ${req.path}`));
  });

  // Merkezî hata işleyici — sözleşmedeki {error:{code,message}} gövdesi.
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, _next) => {
    if (err instanceof ApiError) {
      return res.status(err.status).json(errorBody(err.code, err.message));
    }
    if (err && err.type === 'entity.parse.failed') {
      return res.status(400).json(errorBody('INVALID_JSON', 'Gövde geçerli JSON değil'));
    }
    if (err && /UNIQUE constraint failed/.test(err.message || '')) {
      return res.status(409).json(errorBody('CONFLICT', 'Kayıt benzersizlik kuralına takıldı (aynı isim/numara mevcut)'));
    }
    console.error('[hata]', req.method, req.path, err);
    return res.status(500).json(errorBody('INTERNAL', 'Beklenmeyen sunucu hatası'));
  });

  return app;
}
