// K2 — Bölge boyutu. 7 coğrafi bölge; iller bölgeye bağlanır.
// (Eşleme verisi seed.js içindedir; bu göç yalnız yapıyı kurar.)
export const id = '003_regions';

export function up(db) {
  db.exec(`
CREATE TABLE IF NOT EXISTS regions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL UNIQUE,
  sort_order INTEGER NOT NULL DEFAULT 0
);
  `);

  const cols = db.prepare('PRAGMA table_info(provinces)').all().map((c) => c.name);
  if (!cols.includes('region_id')) {
    // ADD COLUMN + FK: SQLite varsayılanın NULL olmasını şart koşar — zaten istediğimiz bu.
    db.exec('ALTER TABLE provinces ADD COLUMN region_id INTEGER REFERENCES regions(id)');
  }
  db.exec('CREATE INDEX IF NOT EXISTS idx_provinces_region ON provinces(region_id)');
}
