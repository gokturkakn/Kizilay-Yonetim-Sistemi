/**
 * Gelir Getirici Faaliyetler — SPEC-V2 §3.2E.
 *
 * Görev/Eğitim/Etkinlik/Toplantı'nın 5. kardeşi. Ayrı bir modüldür çünkü gelir getirici
 * bir faaliyet (kermes, bağış kampanyası, hayır yemeği ...) sahadaki diğer dördünden farklı
 * olarak kendi planlaması, çıktısı ve MALİ SONUCU olan bir faaliyettir; bu yüzden `notes`
 * içine gömülü bir tutar değil, ayrı raporlanabilir `income_amount`/`expense_amount`
 * sütunlarına ihtiyaç vardır (Gelir Getirici Faaliyetler Komisyonu'nun performans takibi).
 *
 * `net_income` STORED bir sütun DEĞİLDİR — `income_amount - expense_amount` her zaman
 * SELECT anında hesaplanır (bkz. routes/incomeActivities.js). Tek kaynak ilkesi: iki
 * sütunu ayrı ayrı güncelleyip net'i senkron tutmaya çalışmak yerine, hiç saklamamak.
 */
export const id = '015_income_activities';

export function up(db) {
  db.exec(`
CREATE TABLE IF NOT EXISTS income_activities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  activity_type_id INTEGER NOT NULL REFERENCES lookup_items(id),
  purpose TEXT,
  activity_date TEXT NOT NULL,
  region_id INTEGER REFERENCES regions(id),
  province_id INTEGER REFERENCES provinces(id),
  district_id INTEGER REFERENCES districts(id),
  org_unit_id INTEGER REFERENCES org_units(id),
  location TEXT,
  target_income REAL CHECK (target_income IS NULL OR target_income >= 0),
  income_amount REAL NOT NULL DEFAULT 0 CHECK (income_amount >= 0),
  expense_amount REAL CHECK (expense_amount IS NULL OR expense_amount >= 0),
  participant_count INTEGER NOT NULL DEFAULT 0 CHECK (participant_count >= 0),
  volunteer_count INTEGER NOT NULL DEFAULT 0 CHECK (volunteer_count >= 0),
  supporting_orgs TEXT,
  sponsors TEXT,
  notes TEXT,
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_income_activities_date ON income_activities(activity_date);
CREATE INDEX IF NOT EXISTS idx_income_activities_type ON income_activities(activity_type_id);
CREATE INDEX IF NOT EXISTS idx_income_activities_region ON income_activities(region_id);
CREATE INDEX IF NOT EXISTS idx_income_activities_province ON income_activities(province_id);
  `);
}
