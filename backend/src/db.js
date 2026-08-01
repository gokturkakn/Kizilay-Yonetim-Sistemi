/**
 * Veritabanı bağlantısı ve şema yönetimi.
 *
 * v2'den itibaren şema `CREATE TABLE IF NOT EXISTS` bloğuyla değil, `src/migrations/`
 * altındaki sıralı göçlerle yönetilir (denetim raporu Y-4: "şema göçü altyapısı yok").
 * Mevcut bir v1 veritabanı ilk açılışta yerinde yükseltilir; veri kaybı olmaz.
 */
import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import { DB_PATH } from './config.js';
import { runMigrations } from './migrations/index.js';

/** Bağlantıyı açar (göç ÇALIŞTIRMAZ). Göç testleri bunu kullanır. */
export function connect(dbPath = DB_PATH) {
  fs.mkdirSync(path.dirname(dbPath), { recursive: true });
  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  return db;
}

/** Bağlantıyı açar ve bekleyen göçleri uygular. */
export async function createDb(dbPath = DB_PATH, opts = {}) {
  const db = connect(dbPath);
  await runMigrations(db, opts);
  return db;
}

let singleton = null;
export async function getDb() {
  if (!singleton) singleton = await createDb();
  return singleton;
}

/** Uygulanmış son göç kimliği (sağlık ucu için). */
export function schemaVersion(db) {
  try {
    const row = db.prepare('SELECT id FROM schema_migrations ORDER BY id DESC LIMIT 1').get();
    return row ? row.id : null;
  } catch {
    return null;
  }
}

export function migrationCount(db) {
  try {
    return db.prepare('SELECT COUNT(*) AS c FROM schema_migrations').get().c;
  } catch {
    return 0;
  }
}
