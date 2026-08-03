/**
 * 014 — Kullanıcının kendi profili: iletişim alanları + profil fotoğrafı.
 *
 * Müşteri isteği (v2.3): *"her kullanıcı kendi profilini düzenleyebilmeli (profil resmi
 * de dahil olmak üzere). Onların profil resimlerini ben kullanıcı yönetimi kısmında
 * görebilmeliyim."*
 *
 * 1) `phone` / `title`: `users` tablosunda kullanıcının kendisi hakkında yazabileceği
 *    tek alan `name` idi. Teşkilatta kime ulaşılacağını bilmek için telefon ve unvan
 *    (ör. "İl Başkanı") gerekir; bu bilgi bugüne kadar yalnız `persons` tarafında vardı
 *    ve giriş yapan hesapla ilişkilendirilemiyordu.
 *
 * 2) `avatar_attachment_id`: profil fotoğrafı GÖVDEDE taşınmaz (§1.4 sözleşmesi). Dosya
 *    her zamanki gibi `attachments` tablosuna `entity='users'` ile yüklenir; burada
 *    tutulan yalnızca "hangi ek GEÇERLİ avatar" işaretidir. Kullanıcı başına EN FAZLA
 *    BİR avatar olur — yenisi yüklendiğinde eskisi hem satır hem disk olarak silinir.
 *
 *    `ON DELETE SET NULL` bilinçlidir: ek `DELETE /attachments/:id` ile silindiğinde
 *    kullanıcı satırında ölü bir kimlik kalmamalı. Aksi halde `GET /users` var olmayan
 *    bir eke `download_url` üretir ve istemci kırık görsel gösterirdi.
 *
 * Tüm sütunlar NULL kabul eder: yükseltmede hiçbir hesap bozulmaz, hiçbir alan zorunlu
 * hale gelmez (geriye dönük uyum).
 */
export const id = '014_users_profile';

export function up(db) {
  const cols = db.prepare('PRAGMA table_info(users)').all().map((c) => c.name);
  const add = (sql) => db.exec(`ALTER TABLE users ADD COLUMN ${sql}`);

  if (!cols.includes('phone')) add('phone TEXT');
  if (!cols.includes('title')) add('title TEXT');
  if (!cols.includes('avatar_attachment_id')) {
    add('avatar_attachment_id INTEGER REFERENCES attachments(id) ON DELETE SET NULL');
  }

  // Yönetici listesi (GET /users) her satır için avatarı JOIN'ler; tekil arama indeksi.
  // (`entity='users'` ekleri için gereken (entity, entity_id) indeksi 006'da zaten var.)
  db.exec('CREATE INDEX IF NOT EXISTS idx_users_avatar ON users(avatar_attachment_id)');
}
