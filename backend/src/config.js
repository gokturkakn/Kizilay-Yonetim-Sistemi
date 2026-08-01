import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const ROOT_DIR = path.resolve(__dirname, '..');
export const DATA_DIR = path.join(ROOT_DIR, 'data');
// K5 — dosya ekleri. Yerel disk; üretimde nesne depolamaya taşınabilir (tek yerden değişir).
export const UPLOAD_DIR = process.env.KK_UPLOAD_DIR || path.join(ROOT_DIR, 'uploads');
export const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;

export const PORT = Number(process.env.PORT || 4141);
export const DB_PATH = process.env.KK_DB_PATH || path.join(DATA_DIR, 'app.db');
export const JWT_SECRET = process.env.KK_JWT_SECRET || 'kizilay-kadin-mvp-dev-secret';
export const JWT_EXPIRES_IN = '12h';
