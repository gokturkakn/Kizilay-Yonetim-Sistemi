// TC kimlik numarası doğrulama ve (tohum veri için) geçerli sahte numara üretimi.
//
// Kurallar:
// - 11 hane, tamamı rakam, ilk hane 0 olamaz.
// - 10. hane = ((1,3,5,7,9. haneler toplamı) * 7 - (2,4,6,8. haneler toplamı)) mod 10
// - 11. hane = ilk 10 hanenin toplamı mod 10

export function isValidTcNo(value) {
  if (typeof value !== 'string') return false;
  if (!/^[1-9][0-9]{10}$/.test(value)) return false;
  const d = value.split('').map(Number);
  const odd = d[0] + d[2] + d[4] + d[6] + d[8];
  const even = d[1] + d[3] + d[5] + d[7];
  const d10 = ((odd * 7 - even) % 10 + 10) % 10;
  if (d[9] !== d10) return false;
  const d11 = d.slice(0, 10).reduce((a, b) => a + b, 0) % 10;
  return d[10] === d11;
}

// İlk 9 haneden geçerli bir TC numarası tamamlar (demo/tohum veri için).
export function completeTcNo(first9) {
  if (!/^[1-9][0-9]{8}$/.test(first9)) {
    throw new Error('completeTcNo: ilk 9 hane [1-9][0-9]{8} olmalı');
  }
  const d = first9.split('').map(Number);
  const odd = d[0] + d[2] + d[4] + d[6] + d[8];
  const even = d[1] + d[3] + d[5] + d[7];
  const d10 = ((odd * 7 - even) % 10 + 10) % 10;
  const d11 = (d.reduce((a, b) => a + b, 0) + d10) % 10;
  return first9 + String(d10) + String(d11);
}
