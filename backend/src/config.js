import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const ROOT_DIR = path.resolve(__dirname, '..');
export const DATA_DIR = path.join(ROOT_DIR, 'data');
// K5 — dosya ekleri. Yerel disk; üretimde nesne depolamaya taşınabilir (tek yerden değişir).
export const UPLOAD_DIR = process.env.KK_UPLOAD_DIR || path.join(ROOT_DIR, 'uploads');
export const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;

export const PORT = Number(process.env.PORT || 4141);
export const DB_PATH = process.env.KK_DB_PATH || path.join(DATA_DIR, 'app.db');
export const JWT_EXPIRES_IN = '12h';

/**
 * ---------------------------------------------------------------------------
 * "ÜRETİM BENZERİ" ORTAM TESPİTİ  (tek tanım — tüm güvenlik kararları buna bakar)
 * ---------------------------------------------------------------------------
 *
 * Bir ortam şu üç koşuldan HERHANGİ BİRİ sağlanıyorsa üretim benzeri sayılır:
 *
 *   1) NODE_ENV = production          → standart Node sözleşmesi
 *   2) RENDER    (herhangi bir değer) → Render.com barındırması (`RENDER=true` verir)
 *   3) KK_ENV    = production         → başka bir platformda elle işaretleme
 *
 * Kaçış kapısı: `KK_ENV=development` HER ZAMAN kazanır ve ortamı geliştirme sayar.
 * Üretim davranışını yerelde denemek için: `KK_ENV=production npm start`.
 *
 * Neden isim listesi değil de "herhangi biri": Render `NODE_ENV=production` ve
 * `RENDER=true` değişkenlerinin ikisini de verir; biri elle silinse bile diğeri
 * korumayı ayakta tutar. Güvenlik kontrolünün tek bir değişkene bağlı olmaması
 * bilinçli bir karardır.
 */
export function isProductionLike(env = process.env) {
  if (env.KK_ENV === 'development') return false;
  return env.NODE_ENV === 'production'
    || Boolean(env.RENDER)
    || env.KK_ENV === 'production';
}

/** Yalnızca YEREL GELİŞTİRME içindir. Üretim benzeri ortamda kullanılması engellenir. */
export const DEV_JWT_SECRET = 'kizilay-kadin-mvp-dev-secret';
export const MIN_JWT_SECRET_LENGTH = 32;

/**
 * Üretim benzeri ortamda JWT gizli anahtarının kabul edilebilir olup olmadığını döndürür.
 * @returns {string|null} Sorun varsa Türkçe açıklama, yoksa null.
 *
 * Denetim BLOKE-5: `config.js` sabit kodlanmış varsayılana sessizce düşüyordu ve bu değer
 * herkese açık depoda yayımlanmış durumdaydı — yani herkes kendi `genel_merkez` token'ını
 * imzalayabilirdi. Artık üretim benzeri ortamda sunucu AÇILMAZ.
 */
export function jwtSecretProblem(env = process.env) {
  if (!isProductionLike(env)) return null;
  const secret = String(env.KK_JWT_SECRET || '').trim();
  if (!secret) {
    return 'KK_JWT_SECRET ortam değişkeni tanımlı değil.';
  }
  if (secret === DEV_JWT_SECRET) {
    return 'KK_JWT_SECRET geliştirme varsayılanına eşit; bu değer herkese açık depoda yayımlanmıştır.';
  }
  if (secret.length < MIN_JWT_SECRET_LENGTH) {
    return `KK_JWT_SECRET çok kısa (${secret.length} karakter); en az ${MIN_JWT_SECRET_LENGTH} karakter olmalı.`;
  }
  return null;
}

/**
 * Açılış öncesi güvenlik kontrolü. Sorun varsa çok satırlı Türkçe bir mesaj döndürür;
 * sorun yoksa null. `src/server.js` bunu ilk iş olarak çağırır ve mesaj varsa
 * hiçbir şeye dokunmadan (veritabanı bile açılmadan) çıkar — fail-fast.
 */
export function startupConfigError(env = process.env) {
  const problem = jwtSecretProblem(env);
  if (!problem) return null;
  return [
    '',
    '═══════════════════════════════════════════════════════════════════════',
    '  SUNUCU BAŞLATILAMADI — ÜRETİM GÜVENLİK KONTROLÜ',
    '═══════════════════════════════════════════════════════════════════════',
    `  ${problem}`,
    '',
    '  Üretim benzeri bir ortam algılandı (NODE_ENV=production, RENDER veya',
    '  KK_ENV=production). Bu ortamda JWT imza anahtarı ZORUNLUDUR: anahtar',
    '  bilinirse herkes kendi genel merkez oturumunu imzalayabilir.',
    '',
    '  Çözüm — rastgele bir anahtar üretip ortam değişkeni olarak tanımlayın:',
    '',
    '    node -e "console.log(require(\'crypto\').randomBytes(48).toString(\'base64url\'))"',
    `    KK_JWT_SECRET=<üretilen değer>   (en az ${MIN_JWT_SECRET_LENGTH} karakter)`,
    '',
    '  Anahtar değiştiğinde mevcut tüm oturumlar geçersiz olur; kullanıcılar',
    '  yeniden giriş yapar. Beklenen ve istenen davranış budur.',
    '',
    '  Yerel geliştirmede bu kontrol çalışmaz (KK_ENV=development ile zorlanabilir).',
    '═══════════════════════════════════════════════════════════════════════',
    '',
  ].join('\n');
}

export const IS_PRODUCTION_LIKE = isProductionLike();

// Üretim benzeri ortamda buraya gelinmeden önce `startupConfigError()` süreci
// durdurur; bu yüzden varsayılana düşmek yalnızca geliştirmede mümkündür.
export const JWT_SECRET = String(process.env.KK_JWT_SECRET || '').trim() || DEV_JWT_SECRET;
