/**
 * Profil fotoğrafı (avatar) — v2.3.
 *
 * Müşteri isteği: *"her kullanıcı kendi profilini düzenleyebilmeli (profil resmi de
 * dahil olmak üzere). Onların profil resimlerini ben kullanıcı yönetimi kısmında
 * görebilmeliyim."*
 *
 * ---------------------------------------------------------------------------
 * YETKİ KURALI (tek tanım — hem `/auth/me/avatar` hem `/attachments` bunu kullanır)
 * ---------------------------------------------------------------------------
 *   YAZMA  (yükleme / değiştirme / silme):
 *       genel_merkez → herkesin avatarı
 *       diğer roller → YALNIZ kendi avatarı (`entity_id === req.user.id`), aksi 403
 *   OKUMA  (meta / indirme / listeleme):
 *       genel_merkez → herkesin avatarı (kullanıcı yönetiminde fotoğrafları görmesi
 *                      GEREKİR; aksi halde müşterinin istediği ekran kurulamaz)
 *       diğer roller → YALNIZ kendi avatarı; başkasınınki 404 (403 DEĞİL — 403 "böyle
 *                      bir ek var" bilgisini sızdırır ve kimlik sayımına (enumeration)
 *                      zemin hazırlar)
 *
 * Bu kural YALNIZ `entity='users'` eklerine uygulanır; diğer varlıkların ek davranışı
 * (görev fotoğrafı, doküman dosyası …) bilinçli olarak DEĞİŞTİRİLMEMİŞTİR.
 *
 * ---------------------------------------------------------------------------
 * DOSYA KURALLARI
 * ---------------------------------------------------------------------------
 * Genel ek sınırı 10 MB ve 7 MIME türüdür. Avatar için ikisi de daraltılır:
 *   - Yalnız JPEG / PNG / WEBP. PDF ya da DOCX bir profil fotoğrafı değildir; GIF de
 *     kapsam dışı (hareketli görsel liste ekranında istenmez).
 *   - Azami 2 MB. 500 kullanıcılık bir teşkilatta 10 MB sınırı 5 GB'lık avatar demektir;
 *     tek diskli bir dağıtımda (Render) bu kabul edilemez.
 *   - Kullanıcı başına EN FAZLA BİR avatar. Yenisi yüklendiğinde eskisinin hem satırı
 *     hem DİSKTEKİ DOSYASI silinir — sahipsiz dosya birikmez.
 */
import multer from 'multer';
import { auditLog } from './audit.js';
import { ApiError, badRequest } from './helpers.js';
import { newStoredName, removeStoredFile, safeDisplayName, writeStoredFile } from './storage.js';

/** Avatar eklerinin `attachments.entity` değeri. */
export const AVATAR_ENTITY = 'users';
/** Avatar eklerinin `kind` değeri — tek geçerli değer. */
export const AVATAR_KIND = 'fotograf';
/** MIME → uzantı. Genel beyaz listenin (7 tür) alt kümesi. */
export const AVATAR_MIME = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};
export const AVATAR_MAX_BYTES = 2 * 1024 * 1024;

const MB = (bytes) => Math.round((bytes / 1024 / 1024) * 10) / 10;

export const AVATAR_TYPE_MESSAGE = 'Profil fotoğrafı yalnız JPEG, PNG veya WEBP olabilir';
export const AVATAR_SIZE_MESSAGE =
  `Profil fotoğrafı en fazla ${MB(AVATAR_MAX_BYTES)} MB olabilir`;

/** Dosya türü ve boyutu — genel ek sınırından BAĞIMSIZ, daha dar kontrol. */
export function assertAvatarFile(file) {
  if (!file || !file.buffer) {
    throw badRequest("Dosya gerekli: multipart 'file' alanında yükleyin");
  }
  if (!AVATAR_MIME[file.mimetype]) {
    throw new ApiError(400, 'UNSUPPORTED_FILE_TYPE',
      `${AVATAR_TYPE_MESSAGE}. Gönderilen tür: ${file.mimetype}`);
  }
  if (file.size > AVATAR_MAX_BYTES) {
    throw new ApiError(400, 'FILE_TOO_LARGE', AVATAR_SIZE_MESSAGE);
  }
  return file;
}

/** Avatar `kind`'ı: verilmemişse türetilir, farklı bir değer verildiyse reddedilir. */
export function assertAvatarKind(kind) {
  if (kind === undefined || kind === null || kind === '') return AVATAR_KIND;
  if (kind !== AVATAR_KIND) {
    throw badRequest(`Profil fotoğrafının 'kind' değeri '${AVATAR_KIND}' olmalıdır`);
  }
  return AVATAR_KIND;
}

/** Yazma yetkisi: genel merkez herkesin, diğerleri yalnız kendi avatarını yönetir. */
export function assertMayWriteAvatar(user, targetUserId) {
  if (user.role === 'genel_merkez') return;
  if (Number(targetUserId) !== Number(user.id)) {
    throw new ApiError(403, 'FORBIDDEN',
      'Yalnız kendi profil fotoğrafınızı yükleyebilir ya da silebilirsiniz');
  }
}

/** Okuma yetkisi (boolean). Çağıran, `false` halinde 404 döndürmelidir. */
export function mayReadAvatar(user, targetUserId) {
  return user.role === 'genel_merkez' || Number(targetUserId) === Number(user.id);
}

/** İstemcinin fotoğrafı çizebilmesi için gereken asgari gövde. */
export function avatarBody(row) {
  if (!row || !row.id) return null;
  return {
    attachment_id: row.id,
    url: `/api/v1/attachments/${row.id}/download`,
    mime: row.mime,
    size: row.size,
    file_name: row.file_name,
  };
}

/** Kullanıcının geçerli avatar ek satırı (yoksa null). */
export function currentAvatar(db, userId) {
  return db.prepare(`
    SELECT a.* FROM attachments a
    JOIN users u ON u.avatar_attachment_id = a.id
    WHERE u.id = ?`).get(userId) ?? null;
}

/**
 * Avatarı yükler/DEĞİŞTİRİR.
 *
 * Sıra bilinçlidir: önce YENİ satır, sonra kullanıcı işareti, EN SON eski satırlar.
 * Ters sırada `ON DELETE SET NULL` yeni işareti de silerdi. Disk silme işlemi
 * transaction'ın DIŞINDA ve SONRASINDA yapılır: veritabanı geri alınırsa dosya
 * hâlâ yerindedir (geri alınamaz tarafta hata yapmamak için).
 */
export function storeAvatar(db, { targetUserId, file, actorId }) {
  assertAvatarFile(file);
  const storedName = newStoredName(AVATAR_MIME[file.mimetype]);
  // Kullanıcı başına tek avatar: geçerli olan da, geçmişten kalmış olası artıklar da
  // aynı sorguyla toplanır. Böylece işlem sonunda diskte tek dosya kalır.
  const previous = db.prepare(
    'SELECT * FROM attachments WHERE entity = ? AND entity_id = ?'
  ).all(AVATAR_ENTITY, targetUserId);
  const before = db.prepare('SELECT avatar_attachment_id FROM users WHERE id = ?').get(targetUserId);

  writeStoredFile(storedName, file.buffer);

  let newId = null;
  try {
    newId = db.transaction(() => {
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO attachments (entity, entity_id, kind, file_name, stored_name, mime, size,
                                 path, uploaded_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
        AVATAR_ENTITY, targetUserId, AVATAR_KIND,
        safeDisplayName(file.originalname), storedName,
        file.mimetype, file.size, storedName, actorId
      );
      db.prepare(`UPDATE users SET avatar_attachment_id = ?, updated_at = datetime('now')
        WHERE id = ?`).run(lastInsertRowid, targetUserId);
      for (const row of previous) {
        db.prepare('DELETE FROM attachments WHERE id = ?').run(row.id);
      }
      return lastInsertRowid;
    })();
  } catch (e) {
    removeStoredFile(storedName); // yazılan dosya sahipsiz kalmasın
    throw e;
  }

  for (const row of previous) removeStoredFile(row.stored_name);

  const row = db.prepare('SELECT * FROM attachments WHERE id = ?').get(newId);
  auditLog(db, {
    entity: 'attachments', entityId: newId, action: 'create', changedBy: actorId,
    changes: {
      entity: AVATAR_ENTITY, entity_id: targetUserId, kind: AVATAR_KIND,
      file_name: row.file_name, mime: row.mime, size: row.size,
    },
  });
  auditLog(db, {
    entity: 'users', entityId: Number(targetUserId), action: 'avatar_update', changedBy: actorId,
    changes: {
      avatar_attachment_id: { old: before?.avatar_attachment_id ?? null, new: newId },
      removed_attachments: previous.map((p) => p.id),
      mime: row.mime, size: row.size,
    },
  });
  return { attachment: row, removed: previous };
}

/** Avatarı kaldırır. Avatar yoksa `null` döner (çağıran 404 verebilir). */
export function clearAvatar(db, { targetUserId, actorId }) {
  const rows = db.prepare(
    'SELECT * FROM attachments WHERE entity = ? AND entity_id = ?'
  ).all(AVATAR_ENTITY, targetUserId);
  const before = db.prepare('SELECT avatar_attachment_id FROM users WHERE id = ?').get(targetUserId);
  if (rows.length === 0 && !before?.avatar_attachment_id) return null;

  db.transaction(() => {
    db.prepare(`UPDATE users SET avatar_attachment_id = NULL, updated_at = datetime('now')
      WHERE id = ?`).run(targetUserId);
    for (const row of rows) db.prepare('DELETE FROM attachments WHERE id = ?').run(row.id);
  })();
  for (const row of rows) removeStoredFile(row.stored_name);

  for (const row of rows) {
    auditLog(db, {
      entity: 'attachments', entityId: row.id, action: 'delete', changedBy: actorId,
      changes: { entity: AVATAR_ENTITY, entity_id: Number(targetUserId), file_name: row.file_name },
    });
  }
  auditLog(db, {
    entity: 'users', entityId: Number(targetUserId), action: 'avatar_delete', changedBy: actorId,
    changes: { avatar_attachment_id: { old: before?.avatar_attachment_id ?? null, new: null } },
  });
  return rows;
}

/**
 * `POST /auth/me/avatar` için multipart ara katmanı.
 *
 * Genel `/attachments` ucundan AYRI bir multer örneği kullanılır: sınır 10 MB değil
 * 2 MB'tır, dolayısıyla 9 MB'lık bir dosya belleğe hiç ALINMAZ (genel uçta alınıp
 * sonra reddedilir). Multer'ın `LIMIT_FILE_SIZE` hatası burada avatara özgü Türkçe
 * mesaja çevrilir; merkezî işleyicinin "azami 10 MB" metni yanıltıcı olurdu.
 */
export function avatarUpload() {
  const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: AVATAR_MAX_BYTES, files: 1 },
    fileFilter: (_req, file, cb) => {
      if (!AVATAR_MIME[file.mimetype]) {
        return cb(new ApiError(400, 'UNSUPPORTED_FILE_TYPE',
          `${AVATAR_TYPE_MESSAGE}. Gönderilen tür: ${file.mimetype}`));
      }
      return cb(null, true);
    },
  }).single('file');

  return (req, res, next) => upload(req, res, (err) => {
    if (err && err.code === 'LIMIT_FILE_SIZE') {
      return next(new ApiError(400, 'FILE_TOO_LARGE', AVATAR_SIZE_MESSAGE));
    }
    return next(err ?? undefined);
  });
}
