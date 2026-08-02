/**
 * SPEC-V2-M6 — Kılavuz ve Dokümanlar (6. ana modül).
 *
 * Tasarım kararı (SPEC-V2-M6 §2): TÜR ve KAPSAM birbirine dik iki eksendir.
 *  - Tür  → `category_id` (K1 tanım altyapısı, `dokuman_kategorisi` kategorisi)
 *  - Kapsam → `scope` + ilgili coğrafya alanları
 * Bu yüzden "yerelde kullanılacak olanlar" bir kategori DEĞİL, her kategoride
 * çalışan bir filtredir.
 *
 * Dosyanın kendisi bu tabloda tutulmaz: mevcut K5 `attachments` altyapısı
 * (`entity='documents'`) kullanılır — bir dokümanın birden çok dosyası olabilir
 * (ör. Word + PDF sürümü).
 *
 * `is_active` silme değil YAYINDAN KALDIRMA anlamındadır; geçmiş korunur.
 * `valid_until` özellikle matbu izin belgeleri içindir: süresi geçmiş bir izin
 * belgesinin sahada kullanılması gerçek bir risktir.
 */
export const id = '012_documents';

export function up(db) {
  db.exec(`
CREATE TABLE IF NOT EXISTS documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT,
  category_id INTEGER NOT NULL REFERENCES lookup_items(id),
  scope TEXT NOT NULL DEFAULT 'genel' CHECK (scope IN ('genel', 'bolge', 'il', 'ilce')),
  region_id INTEGER REFERENCES regions(id),
  province_id INTEGER REFERENCES provinces(id),
  district_id INTEGER REFERENCES districts(id),
  version TEXT,
  published_at TEXT,
  valid_until TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  download_count INTEGER NOT NULL DEFAULT 0 CHECK (download_count >= 0),
  created_by INTEGER REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_documents_category ON documents(category_id);
CREATE INDEX IF NOT EXISTS idx_documents_scope ON documents(scope);
CREATE INDEX IF NOT EXISTS idx_documents_active ON documents(is_active);
-- "Yalnız bana ait olanlar" anahtarı bu üç sütun üzerinden çalışır.
CREATE INDEX IF NOT EXISTS idx_documents_geo ON documents(region_id, province_id, district_id);
  `);
}
