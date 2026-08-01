// Yönetim Paneli — Kullanıcı Yönetimi (denetim raporu Y-2: paylaşımlı tek saha hesabı riski).
// Kullanıcılar pasifleştirilebilir ve bölge/il kapsamı taşıyabilir.
export const id = '010_users_v2';

export function up(db) {
  const cols = db.prepare('PRAGMA table_info(users)').all().map((c) => c.name);
  const add = (sql) => db.exec(`ALTER TABLE users ADD COLUMN ${sql}`);

  if (!cols.includes('is_active')) add('is_active INTEGER NOT NULL DEFAULT 1');
  if (!cols.includes('region_id')) add('region_id INTEGER REFERENCES regions(id)');
  if (!cols.includes('province_id')) add('province_id INTEGER REFERENCES provinces(id)');
  if (!cols.includes('updated_at')) add("updated_at TEXT NOT NULL DEFAULT ''");

  // DEFAULT '' ile eklenen sütunu anlamlı bir değere çek (SQLite ADD COLUMN'da
  // datetime('now') gibi sabit olmayan varsayılanlara izin vermez).
  db.exec("UPDATE users SET updated_at = created_at WHERE updated_at = ''");

  db.exec('CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active)');
}
