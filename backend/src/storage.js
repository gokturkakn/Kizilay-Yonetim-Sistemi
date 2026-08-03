/**
 * Yüklenen dosyaların disk katmanı — TEK yer.
 *
 * `routes/attachments.js` ve `avatars.js` aynı kuralları paylaşır; kopyalanmış bir
 * `path.join` bu sistemde yol kaçışı (path traversal) demektir. Bu yüzden dosya adı
 * üretimi, güvenli yol kurulumu ve silme burada toplanmıştır.
 *
 * Değişmez kural: istemciden gelen dosya adı ASLA dosya sisteminde kullanılmaz.
 * Sunucu `randomUUID()` ile ad üretir, uzantı MIME beyaz listesinden türetilir.
 */
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { UPLOAD_DIR } from './config.js';
import { ApiError } from './helpers.js';

// Kontrol karakterleri + dizin ayırıcıları + tırnak: gösterim adından temizlenir.
const UNSAFE_NAME_CHARS = /[\x00-\x1f\x7f/\\"]/g;

/** Görüntüleme adını temizler: dizin bileşenleri ve kontrol karakterleri atılır. */
export function safeDisplayName(original) {
  const base = path.basename(String(original || 'dosya'));
  const cleaned = base.replace(UNSAFE_NAME_CHARS, '_').trim();
  return (cleaned || 'dosya').slice(0, 180);
}

/** `<uuid><ext>` — çakışmayan, istemci girdisinden tamamen bağımsız depolama adı. */
export function newStoredName(ext) {
  return `${randomUUID()}${ext}`;
}

/**
 * Depolama adından mutlak yolu YENİDEN KURAR ve UPLOAD_DIR sınırında kaldığını doğrular.
 * Veritabanındaki `path` sütununa asla doğrudan güvenilmez.
 */
export function storedPath(storedName) {
  const filePath = path.join(UPLOAD_DIR, path.basename(String(storedName)));
  if (path.dirname(path.resolve(filePath)) !== path.resolve(UPLOAD_DIR)) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Geçersiz dosya yolu');
  }
  return filePath;
}

/** Ek satırının diskteki dosyasını UPLOAD_DIR sınırından çıkmadan siler. */
export function removeStoredFile(storedName) {
  try {
    fs.rmSync(storedPath(storedName), { force: true });
  } catch {
    // Geçersiz yol → silinecek bir şey de yok. Sessiz geçilir.
  }
}

/** Dosyayı diske yazar; dizin yoksa oluşturur. Depolama adını döndürür. */
export function writeStoredFile(storedName, buffer) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  fs.writeFileSync(storedPath(storedName), buffer);
  return storedName;
}

export { UPLOAD_DIR };
