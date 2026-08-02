// PDF tablo üreticisi.
//
// Kritik nokta: PDFKit'in gömülü Helvetica'sı WinAnsi kodlamasıyla sınırlıdır ve
// Türkçe karakterleri (ş ğ İ ı ö ü ç) bozar. Bu yüzden Unicode destekli DejaVu Sans
// TTF gömülür. Font bulunamazsa rapor sessizce bozuk çıkmaktansa hata verir.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import PDFDocument from 'pdfkit';

const require = createRequire(import.meta.url);

function fontPath(file) {
  const pkg = require.resolve('dejavu-fonts-ttf/package.json');
  return path.join(path.dirname(pkg), 'ttf', file);
}

const REGULAR = fontPath('DejaVuSansCondensed.ttf');
const BOLD = fontPath('DejaVuSansCondensed-Bold.ttf');

for (const f of [REGULAR, BOLD]) {
  if (!fs.existsSync(f)) {
    throw new Error(`PDF fontu bulunamadı: ${f} — Türkçe karakterler için gerekli.`);
  }
}

const PAGE_MARGIN = 28;
const HEADER_BG = '#E30613'; // Kızılay kırmızısı
const ROW_ALT_BG = '#F5F5F5';
const BORDER = '#DDDDDD';

/**
 * Sütunlu bir tabloyu PDF olarak response'a yazar (yatay A4).
 * @param {import('express').Response} res
 * @param {{filename:string,title:string,subtitle?:string,columns:Array,rows:Array}} spec
 */
export function sendPdfTable(res, { filename, title, subtitle, columns, rows }) {
  const doc = new PDFDocument({ size: 'A4', layout: 'landscape', margin: PAGE_MARGIN });
  doc.registerFont('tr', REGULAR);
  doc.registerFont('tr-bold', BOLD);

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  doc.pipe(res);

  const usableWidth = doc.page.width - PAGE_MARGIN * 2;
  // Excel sütun genişliklerini (karakter) sayfaya oranla
  const totalWeight = columns.reduce((s, c) => s + (c.width || 20), 0);
  const widths = columns.map((c) => ((c.width || 20) / totalWeight) * usableWidth);

  const drawTitle = () => {
    doc.font('tr-bold').fontSize(15).fillColor('#000')
      .text(title, PAGE_MARGIN, PAGE_MARGIN);
    doc.font('tr').fontSize(8).fillColor('#555')
      .text('Kızılay Kadın · Teşkilat Yönetim Sistemi', { continued: false });
    if (subtitle) doc.font('tr').fontSize(8).fillColor('#555').text(subtitle);
    doc.font('tr').fontSize(8).fillColor('#555')
      .text(`Toplam ${rows.length} kayıt · Oluşturma: ${new Date().toLocaleString('tr-TR')}`);
    doc.moveDown(0.4);
  };

  // Başlık bandı yüksekliği en uzun başlığa göre hesaplanır; aksi halde iki satıra
  // saran başlıklar ("Doğum Tarihi" gibi) kırmızı bandın dışına taşıp kesiliyor.
  const headerHeight = (() => {
    doc.font('tr-bold').fontSize(7.5);
    const tallest = Math.max(...columns.map((c, i) =>
      doc.heightOfString(String(c.header), { width: widths[i] - 6 })));
    return Math.max(18, tallest + 8);
  })();

  const drawHeader = () => {
    const y = doc.y;
    doc.rect(PAGE_MARGIN, y, usableWidth, headerHeight).fill(HEADER_BG);
    doc.font('tr-bold').fontSize(7.5).fillColor('#FFF');
    let x = PAGE_MARGIN;
    columns.forEach((c, i) => {
      doc.text(String(c.header), x + 3, y + 4, {
        width: widths[i] - 6,
        height: headerHeight - 6,
        ellipsis: true,
      });
      x += widths[i];
    });
    doc.y = y + headerHeight;
    doc.fillColor('#000');
  };

  drawTitle();
  drawHeader();

  const bottomLimit = doc.page.height - PAGE_MARGIN - 14;
  doc.font('tr').fontSize(7);

  rows.forEach((row, index) => {
    const cells = columns.map((c) => {
      const v = row[c.key];
      return v === null || v === undefined ? '' : String(v);
    });
    // Satır yüksekliği: en uzun hücreye göre (sarma dahil)
    const heights = cells.map((text, i) =>
      doc.heightOfString(text, { width: widths[i] - 6, align: 'left' }));
    const rowHeight = Math.max(12, Math.min(Math.max(...heights) + 5, 60));

    if (doc.y + rowHeight > bottomLimit) {
      doc.addPage();
      drawHeader();
      doc.font('tr').fontSize(7);
    }

    const y = doc.y;
    if (index % 2 === 1) doc.rect(PAGE_MARGIN, y, usableWidth, rowHeight).fill(ROW_ALT_BG);
    doc.fillColor('#000');

    let x = PAGE_MARGIN;
    cells.forEach((text, i) => {
      doc.text(text, x + 3, y + 3, {
        width: widths[i] - 6,
        height: rowHeight - 4,
        ellipsis: true,
      });
      x += widths[i];
    });
    doc.strokeColor(BORDER).lineWidth(0.3)
      .moveTo(PAGE_MARGIN, y + rowHeight).lineTo(PAGE_MARGIN + usableWidth, y + rowHeight).stroke();
    doc.y = y + rowHeight;
  });

  if (rows.length === 0) {
    doc.moveDown(1).font('tr').fontSize(9).fillColor('#777')
      .text('Seçilen filtrelere uygun kayıt bulunamadı.', PAGE_MARGIN, doc.y, { align: 'center', width: usableWidth });
  }

  // Sayfa numaraları
  const range = doc.bufferedPageRange();
  for (let i = 0; i < range.count; i += 1) {
    doc.switchToPage(range.start + i);
    doc.font('tr').fontSize(7).fillColor('#777').text(
      `${i + 1} / ${range.count}`,
      PAGE_MARGIN,
      doc.page.height - PAGE_MARGIN + 2,
      { width: usableWidth, align: 'right' }
    );
  }

  doc.end();
}
