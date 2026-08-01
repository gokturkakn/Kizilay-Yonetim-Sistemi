/**
 * Sıralı göç (migration) çalıştırıcısı.
 *
 * Tasarım kararları:
 *  - Göçler `src/migrations/NNN_ad.js` dosyalarıdır; dosya adı sıralamayı belirler.
 *  - Her göç `{ id, up(db) }` dışa aktarır. `id` dosya adının uzantısız halidir.
 *  - Uygulananlar `schema_migrations` tablosunda tutulur; ikinci kez çalıştırılmaz.
 *  - Her göç KENDİ transaction'ında çalışır. Hata halinde o göç geri alınır ve hata
 *    yukarı fırlatılır (sunucu açılmaz — fail-fast). Yarım uygulanmış şema kalmaz.
 *  - `PRAGMA foreign_keys` göçler boyunca KAPALIDIR: SQLite'ta tablo yeniden inşası
 *    (004'teki persons dönüşümü gibi) resmî prosedür gereği bunu ister. Göçlerin sonunda
 *    `PRAGMA foreign_key_check` ile bütünlük doğrulanır ve kısıt yeniden açılır.
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

const MIGRATIONS_DIR = path.dirname(fileURLToPath(import.meta.url));

function ensureTable(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id TEXT PRIMARY KEY,
      applied_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);
}

export function migrationFiles() {
  return fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.js') && f !== 'index.js')
    .sort();
}

/**
 * Bekleyen tüm göçleri uygular.
 * @returns {{applied: string[], skipped: string[], version: string|null}}
 */
export async function runMigrations(db, { log = () => {} } = {}) {
  ensureTable(db);

  const done = new Set(db.prepare('SELECT id FROM schema_migrations').all().map((r) => r.id));
  const applied = [];
  const skipped = [];

  const fkWasOn = db.pragma('foreign_keys', { simple: true });
  db.pragma('foreign_keys = OFF');

  try {
    for (const file of migrationFiles()) {
      const id = file.replace(/\.js$/, '');
      if (done.has(id)) { skipped.push(id); continue; }

      const mod = await import(pathToFileURL(path.join(MIGRATIONS_DIR, file)).href);
      if (typeof mod.up !== 'function') {
        throw new Error(`Göç dosyası 'up(db)' dışa aktarmıyor: ${file}`);
      }

      db.transaction(() => {
        mod.up(db);
        db.prepare('INSERT INTO schema_migrations (id) VALUES (?)').run(id);
      })();

      applied.push(id);
      log(`  ↑ göç uygulandı: ${id}`);
    }

    // Tablo yeniden inşalarından sonra yabancı anahtar bütünlüğünü doğrula.
    const violations = db.pragma('foreign_key_check');
    if (violations.length > 0) {
      throw new Error(
        `Göç sonrası yabancı anahtar ihlali (${violations.length} satır): ` +
        JSON.stringify(violations.slice(0, 5))
      );
    }
  } finally {
    if (fkWasOn) db.pragma('foreign_keys = ON');
  }

  const version = db
    .prepare('SELECT id FROM schema_migrations ORDER BY id DESC LIMIT 1')
    .get();

  return { applied, skipped, version: version ? version.id : null };
}
