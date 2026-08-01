// K5 — Dosya ekleri. Yerel disk (backend/uploads/); üretimde nesne depolamaya taşınabilir.
// `stored_name` sunucunun ürettiği addır; istemciden gelen ad ASLA dosya sisteminde kullanılmaz.
export const id = '006_attachments';

export function up(db) {
  db.exec(`
CREATE TABLE IF NOT EXISTS attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity TEXT NOT NULL,
  entity_id INTEGER NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN (
    'fotograf', 'dokuman', 'tutanak', 'sunum', 'katilim_listesi'
  )),
  file_name TEXT NOT NULL,
  stored_name TEXT NOT NULL UNIQUE,
  mime TEXT NOT NULL,
  size INTEGER NOT NULL CHECK (size >= 0),
  path TEXT NOT NULL,
  uploaded_by INTEGER REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_attachments_entity ON attachments(entity, entity_id);
CREATE INDEX IF NOT EXISTS idx_attachments_kind ON attachments(kind);
  `);
}
