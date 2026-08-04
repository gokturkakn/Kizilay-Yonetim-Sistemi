import express from 'express';
import { authenticate, requirePasswordChange } from './auth.js';
import { ApiError, errorBody } from './helpers.js';
import { schemaVersion, migrationCount } from './db.js';
import { MAX_UPLOAD_BYTES } from './config.js';
import authRoutes from './routes/auth.js';
import referenceRoutes from './routes/reference.js';
import personRoutes from './routes/persons.js';
import membershipRoutes from './routes/memberships.js';
import fieldActivityRoutes from './routes/fieldActivities.js';
import meetingRoutes from './routes/meetings.js';
import assignmentRoutes from './routes/assignments.js';
import auditLogRoutes from './routes/auditLogs.js';
import exportRoutes from './routes/exports.js';
// --- v2 ---
import lookupRoutes from './routes/lookups.js';
import regionRoutes from './routes/regions.js';
import orgUnitRoutes from './routes/orgUnits.js';
import taskRoutes from './routes/tasks.js';
import trainingRoutes from './routes/trainings.js';
import eventRoutes from './routes/events.js';
import incomeActivityRoutes from './routes/incomeActivities.js';
import logisticsRoutes from './routes/logistics.js';
import attachmentRoutes from './routes/attachments.js';
import calendarRoutes from './routes/calendar.js';
import contentBlockRoutes from './routes/contentBlocks.js';
import userRoutes, { selfRoutes } from './routes/users.js';
import dashboardRoutes from './routes/dashboard.js';
// --- v2.1 (M6) ---
import documentRoutes from './routes/documents.js';

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

  // v1 sağlık gövdesi korunur; v2 sayaçları `seeded` altına EKLENİR.
  function healthBody() {
    const count = (sql) => db.prepare(sql).get().c;
    return {
      status: 'ok',
      db: 'ok',
      schema_version: schemaVersion(db),
      migrations_applied: migrationCount(db),
      seeded: {
        provinces: count('SELECT COUNT(*) AS c FROM provinces'),
        districts: count('SELECT COUNT(*) AS c FROM districts'),
        commissions: count("SELECT COUNT(*) AS c FROM bodies WHERE type = 'komisyon'"),
        regions: count('SELECT COUNT(*) AS c FROM regions'),
        provinces_mapped_to_region: count('SELECT COUNT(*) AS c FROM provinces WHERE region_id IS NOT NULL'),
        lookup_categories: count('SELECT COUNT(*) AS c FROM lookup_categories'),
        lookup_items: count('SELECT COUNT(*) AS c FROM lookup_items'),
        org_units: count('SELECT COUNT(*) AS c FROM org_units'),
        calendar_events: count('SELECT COUNT(*) AS c FROM calendar_events'),
        content_blocks: count('SELECT COUNT(*) AS c FROM content_blocks'),
        stock_items: count('SELECT COUNT(*) AS c FROM stock_items'),
      },
    };
  }

  const health = (_req, res) => {
    try {
      res.json(healthBody());
    } catch {
      res.status(500).json({ status: 'error', db: 'error' });
    }
  };

  app.get('/health', health);

  const api = express.Router();
  api.use(authRoutes(db)); // /auth/login — token gerektirmez
  api.get('/health', health); // denetim D-1: /api/v1/health de yanıt versin

  const secured = express.Router();
  secured.use(authenticate);
  // Zorunlu şifre değişikliği kapısı — kimlik doğrulamadan HEMEN SONRA, her uçtan ÖNCE.
  // Yalnız `GET /auth/me` ve `POST /auth/change-password` geçer (bkz. src/auth.js).
  secured.use(requirePasswordChange(db));
  // Kullanıcının kendi uçları (kapının izin verdiği ikisi burada tanımlıdır).
  secured.use(selfRoutes(db));
  // v1 uçları — davranışları korunur
  secured.use(referenceRoutes(db));
  secured.use(personRoutes(db));
  secured.use(membershipRoutes(db));
  secured.use(fieldActivityRoutes(db));
  secured.use(meetingRoutes(db));
  secured.use(assignmentRoutes(db));
  secured.use(auditLogRoutes(db));
  secured.use(exportRoutes(db));
  // v2 uçları
  secured.use(lookupRoutes(db));
  secured.use(regionRoutes(db));
  secured.use(orgUnitRoutes(db));
  secured.use(taskRoutes(db));
  secured.use(trainingRoutes(db));
  secured.use(eventRoutes(db));
  secured.use(incomeActivityRoutes(db));
  secured.use(logisticsRoutes(db));
  secured.use(attachmentRoutes(db));
  secured.use(calendarRoutes(db));
  secured.use(contentBlockRoutes(db));
  secured.use(userRoutes(db));
  secured.use(dashboardRoutes(db));
  // v2.1 — Kılavuz ve Dokümanlar (SPEC-V2-M6)
  secured.use(documentRoutes(db));
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
    // multer sınırları — sözleşmedeki kodlarla eşleştirilir.
    if (err && err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json(errorBody('FILE_TOO_LARGE',
        `Dosya boyutu sınırı aşıldı (azami ${Math.round(MAX_UPLOAD_BYTES / 1024 / 1024)} MB)`));
    }
    if (err && typeof err.code === 'string' && err.code.startsWith('LIMIT_')) {
      return res.status(400).json(errorBody('VALIDATION_ERROR', `Dosya yükleme hatası: ${err.code}`));
    }
    if (err && /UNIQUE constraint failed/.test(err.message || '')) {
      return res.status(409).json(errorBody('CONFLICT', 'Kayıt benzersizlik kuralına takıldı (aynı isim/numara mevcut)'));
    }
    if (err && /CHECK constraint failed/.test(err.message || '')) {
      return res.status(400).json(errorBody('VALIDATION_ERROR', 'Kayıt veri doğrulama kuralına takıldı'));
    }
    if (err && /FOREIGN KEY constraint failed/.test(err.message || '')) {
      return res.status(409).json(errorBody('IN_USE', 'Bu kayda bağlı başka kayıtlar var'));
    }
    console.error('[hata]', req.method, req.path, err);
    return res.status(500).json(errorBody('INTERNAL', 'Beklenmeyen sunucu hatası'));
  });

  return app;
}
