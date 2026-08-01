// K1 — Genel "Tanımlar" (lookup) altyapısı.
// Tüm açılır listeler bu iki tabloda toplanır; yeni kalem eklemek kod değişikliği gerektirmez.
export const id = '002_lookups';

export function up(db) {
  db.exec(`
CREATE TABLE IF NOT EXISTS lookup_categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  is_system INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS lookup_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER NOT NULL REFERENCES lookup_categories(id) ON DELETE CASCADE,
  parent_id INTEGER REFERENCES lookup_items(id),
  code TEXT,
  name TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_lookup_items_category ON lookup_items(category_id);
CREATE INDEX IF NOT EXISTS idx_lookup_items_parent ON lookup_items(parent_id);

-- parent_id NULL olabildiği için düz UNIQUE yetmez (SQLite NULL'ları farklı sayar).
CREATE UNIQUE INDEX IF NOT EXISTS ux_lookup_items_name
  ON lookup_items(category_id, COALESCE(parent_id, 0), name);
  `);
}
