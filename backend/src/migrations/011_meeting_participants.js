/**
 * UX-V2 §11 N-6 — Toplantı katılımcı SAYISI.
 *
 * v2'de `meetings.participants` yalnız serbest metindi ("35 bölge temsilcisi"), bu yüzden
 * toplantı katılımı raporlarda sayısal olarak toplanamıyordu. `participant_count` bunu çözer;
 * serbest metin alanı (kimlerin katıldığı) korunur.
 *
 * Ayrıca `district_id` eklenir: görev/eğitim/etkinlik tablolarının üçünde de ilçe boyutu
 * varken toplantıda yoktu; bu yüzden dashboard'un ilçe filtresi toplantıları kapsayamıyordu.
 */
export const id = '011_meeting_participants';

export function up(db) {
  const cols = db.prepare('PRAGMA table_info(meetings)').all().map((c) => c.name);

  if (!cols.includes('participant_count')) {
    db.exec('ALTER TABLE meetings ADD COLUMN participant_count INTEGER');
  }
  if (!cols.includes('district_id')) {
    db.exec('ALTER TABLE meetings ADD COLUMN district_id INTEGER REFERENCES districts(id)');
  }
  db.exec('CREATE INDEX IF NOT EXISTS idx_meetings_district ON meetings(district_id)');
}
