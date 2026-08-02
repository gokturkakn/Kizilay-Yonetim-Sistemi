import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/strings_v2.dart';
import '../theme/tokens.dart';

/// Tek veri noktası (dilim / çubuk segmenti / nokta).
class ChartDatum {
  const ChartDatum({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData? icon;
}

/// Yığılmış çubuk satırı.
class ChartRow {
  const ChartRow({required this.label, required this.segments, this.onTap});

  final String label;
  final List<ChartDatum> segments;
  final VoidCallback? onTap;

  double get total => segments.fold(0, (a, b) => a + b.value);
}

/// §5.6/3 — her grafiğin zorunlu tablo görünümü verisi (E-13).
class ChartTableData {
  const ChartTableData({
    required this.title,
    required this.columns,
    required this.rows,
    this.totalRow,
  });

  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final List<String>? totalRow;
}

/// Grafik kartı ortak sözleşmesi — docs/UX-V2.md §5.6.
///
/// Her kart istisnasız: başlık · taşma menüsü (tablo görünümü / görseli kaydet
/// / Excel'e aktar) · boş durum · en az [kChartMinHeight] çizim alanı taşır.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    required this.tableData,
    this.subtitle,
    this.isEmpty = false,
    this.onClearFilters,
    this.trailing,
    this.onExportExcel,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final ChartTableData tableData;
  final bool isEmpty;
  final VoidCallback? onClearFilters;
  final Widget? trailing;
  final VoidCallback? onExportExcel;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: s4),
                        Text(subtitle!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: kTextSecondary)),
                      ],
                    ],
                  ),
                ),
                ?trailing,
                PopupMenuButton<String>(
                  tooltip: 'Grafik seçenekleri',
                  icon: const Icon(Icons.more_vert, color: kTextSecondary),
                  onSelected: (v) {
                    switch (v) {
                      case 'table':
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChartTableScreen(data: tableData),
                        ));
                      case 'excel':
                        onExportExcel?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'table', child: Text(S2.tabloGorunumu)),
                    if (onExportExcel != null)
                      const PopupMenuItem(
                          value: 'excel', child: Text(S2.excelAktar)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: s12),
            if (isEmpty)
              SizedBox(
                height: kChartMinHeight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bar_chart_outlined,
                          size: 48, color: kTextDisabled),
                      const SizedBox(height: s12),
                      Text(S2.dashVeriYok,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: kTextSecondary)),
                      if (onClearFilters != null)
                        TextButton(
                            onPressed: onClearFilters,
                            child: const Text(S2.filtreleriTemizle)),
                    ],
                  ),
                ),
              )
            else
              child,
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// E-13 · Grafik Tablo Görünümü.
class ChartTableScreen extends StatelessWidget {
  const ChartTableScreen({super.key, required this.data});

  final ChartTableData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.title),
            Text('Tablo Görünümü',
                style: theme.textTheme.bodySmall?.copyWith(color: kOnPrimary)),
          ],
        ),
      ),
      body: data.rows.isEmpty
          ? Center(
              child: Text(S2.bosTablo,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: kTextSecondary)))
          : SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStatePropertyAll(kBackground),
                  columns: [
                    for (final c in data.columns)
                      DataColumn(
                          label: Text(c, style: theme.textTheme.titleSmall)),
                  ],
                  rows: [
                    for (final r in data.rows)
                      DataRow(cells: [
                        for (var i = 0; i < r.length; i++)
                          DataCell(Text(r[i],
                              style: TextStyle(
                                fontFeatures: i == 0
                                    ? null
                                    : const [FontFeature.tabularFigures()],
                              ))),
                      ]),
                    if (data.totalRow != null)
                      DataRow(
                        color: const WidgetStatePropertyAll(kBackground),
                        cells: [
                          for (final c in data.totalRow!)
                            DataCell(Text(c,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Halka (donut) grafik — §5.2
// ---------------------------------------------------------------------------

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.data,
    required this.centerLabel,
    this.onSliceTap,
  });

  final List<ChartDatum> data;
  final String centerLabel;
  final ValueChanged<int>? onSliceTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.fold<double>(0, (a, b) => a + b.value);
    return Column(
      children: [
        SizedBox(
          height: kChartMinHeight,
          child: CustomPaint(
            size: const Size.fromHeight(kChartMinHeight),
            painter: _DonutPainter(
              data: data,
              total: total,
              centerValue: Formats.number(total.round()),
              centerLabel: centerLabel,
              textDirection: Directionality.of(context),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: s12),
        // Legend: her satırda ikon + renk noktası + etiket + sayı (§5.2).
        for (var i = 0; i < data.length; i++)
          InkWell(
            onTap: onSliceTap == null ? null : () => onSliceTap!(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: s4),
              child: Row(
                children: [
                  if (data[i].icon != null) ...[
                    Icon(data[i].icon, size: 16, color: data[i].color),
                    const SizedBox(width: s8),
                  ],
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: data[i].color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: s8),
                  Expanded(
                    child: Text(data[i].label,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: kTextPrimary)),
                  ),
                  Text(Formats.number(data[i].value.round()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: kTextPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(width: s8),
                  Text(
                    total == 0
                        ? '%0'
                        : '%${((data[i].value / total) * 100).round()}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kTextSecondary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.data,
    required this.total,
    required this.centerValue,
    required this.centerLabel,
    required this.textDirection,
  });

  final List<ChartDatum> data;
  final double total;
  final String centerValue;
  final String centerLabel;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final ringWidth = radius * 0.34;
    if (radius <= 0) return;

    if (total <= 0) {
      final paint = Paint()
        ..color = kInactiveContainer
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth;
      canvas.drawCircle(center, radius - ringWidth / 2, paint);
    } else {
      var start = -math.pi / 2;
      // Dilimler arası 2 px kSurface boşluk (kenarlık çizilmez).
      final gap = 2 / radius;
      for (final d in data) {
        if (d.value <= 0) continue;
        final sweep = (d.value / total) * math.pi * 2;
        final paint = Paint()
          ..color = d.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - ringWidth / 2),
          start + gap / 2,
          math.max(sweep - gap, 0.001),
          false,
          paint,
        );
        start += sweep;
      }
    }

    // Ortada toplam.
    _text(canvas, centerValue, center.translate(0, -14),
        const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w600, color: kTextPrimary));
    _text(canvas, centerLabel, center.translate(0, 10),
        const TextStyle(fontSize: 12, color: kTextSecondary));
  }

  void _text(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total || old.data.length != data.length;
}

// ---------------------------------------------------------------------------
// Yatay (yığılmış) çubuk — §5.3
// ---------------------------------------------------------------------------

/// Yatay yığılmış çubuk grafik. Bölge adları uzun olduğu için **yatay**
/// seçilmiştir; eksen etiketi döndürmek yasaktır (§5.3).
class HorizontalStackedBarChart extends StatelessWidget {
  const HorizontalStackedBarChart({super.key, required this.rows});

  final List<ChartRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxTotal =
        rows.fold<double>(0, (a, r) => math.max(a, r.total));
    return Column(
      children: [
        for (final row in rows)
          InkWell(
            onTap: row.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(row.label,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(Formats.number(row.total.round()),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kTextSecondary)),
                    ],
                  ),
                  const SizedBox(height: s4),
                  LayoutBuilder(builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final scale = maxTotal <= 0 ? 0.0 : width / maxTotal;
                    return SizedBox(
                      height: 24, // çubuk kalınlığı <= 24 px
                      child: Row(
                        children: [
                          for (final seg in row.segments)
                            if (seg.value > 0) ...[
                              Tooltip(
                                message:
                                    '${row.label} · ${seg.label}: ${Formats.number(seg.value.round())}',
                                child: Container(
                                  width: math.max(seg.value * scale, 2),
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: seg.color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.center,
                                  // Segment içi etiket yalnız sığıyorsa.
                                  child: seg.value * scale >= 28
                                      ? Text(
                                          Formats.number(seg.value.round()),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 2),
                            ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Tek seri yatay sıralı çubuk — §5.3B / §5.4.
///
/// Değerler çubuk ucunda **doğrudan etiketlenir**; çubukları büyüklüğe göre
/// koyulaştırmak yasaktır (hepsi tek renk).
class HorizontalBarChart extends StatelessWidget {
  const HorizontalBarChart({
    super.key,
    required this.data,
    this.onTap,
  });

  final List<ChartDatum> data;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = data.fold<double>(0, (a, d) => math.max(a, d.value));
    return Column(
      children: [
        for (var i = 0; i < data.length; i++)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: s4),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(data[i].label,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: s8),
                  Expanded(
                    child: LayoutBuilder(builder: (context, constraints) {
                      final scale = maxValue <= 0
                          ? 0.0
                          : (constraints.maxWidth - 48) / maxValue;
                      return Row(
                        children: [
                          Container(
                            width: math.max(data[i].value * scale, 2),
                            height: 20,
                            decoration: BoxDecoration(
                              color: data[i].color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: s8),
                          Text(Formats.number(data[i].value.round()),
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: kTextPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Çizgi grafik — §5.4 Aylık Faaliyet Trendi
// ---------------------------------------------------------------------------

/// Tek seri çizgi grafik. Çift eksen **yasaktır**; ızgara çizgileri düz
/// (kesikli yasak). Yalnız son nokta doğrudan etiketlenir.
class LineChart extends StatelessWidget {
  const LineChart({super.key, required this.points, required this.labels});

  final List<double> points;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kChartMinHeight + 28, // çizim + eksen bandı
      child: CustomPaint(
        painter: _LinePainter(
          points: points,
          labels: labels,
          textDirection: Directionality.of(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.labels,
    required this.textDirection,
  });

  final List<double> points;
  final List<String> labels;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const axisBand = 24.0;
    const leftPad = 44.0;
    final plotHeight = size.height - axisBand;
    final plotWidth = size.width - leftPad - 24;
    final maxValue = points.reduce(math.max);
    final niceMax = _niceMax(maxValue);

    // Yatay ızgara (1 px, DÜZ) + y ekseni etiketleri.
    final grid = Paint()
      ..color = kGridLine
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plotHeight - (plotHeight * i / 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - 24, y), grid);
      final label = Formats.number((niceMax * i / 4).round());
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        textDirection: textDirection,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
    }

    final axis = Paint()
      ..color = kAxisLine
      ..strokeWidth = 1;
    canvas.drawLine(Offset(leftPad, plotHeight),
        Offset(size.width - 24, plotHeight), axis);

    Offset at(int i) {
      final x = points.length == 1
          ? leftPad + plotWidth / 2
          : leftPad + plotWidth * i / (points.length - 1);
      final y = niceMax <= 0
          ? plotHeight
          : plotHeight - (points[i] / niceMax) * plotHeight;
      return Offset(x, y);
    }

    // Çizgi: 2 px, yuvarlak uç/birleşim, tek renk kChart1.
    final line = Paint()
      ..color = kChart1
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(path, line);

    // Noktalar: yarıçap >= 4, 2 px kSurface halka.
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(at(i), 5, Paint()..color = kSurface);
      canvas.drawCircle(at(i), 4, Paint()..color = kChart1);
    }

    // Eksen etiketleri (ay kısaltmaları) — döndürülmez, sığmazsa atlanır.
    final step = (labels.length / 8).ceil().clamp(1, labels.length);
    for (var i = 0; i < labels.length; i += step) {
      final tp = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        textDirection: textDirection,
      )..layout();
      tp.paint(canvas, Offset(at(i).dx - tp.width / 2, plotHeight + 6));
    }

    // Yalnız son nokta doğrudan etiketlenir.
    final last = points.length - 1;
    final tp = TextPainter(
      text: TextSpan(
        text: Formats.number(points[last].round()),
        style: const TextStyle(
            fontSize: 12, color: kTextPrimary, fontWeight: FontWeight.w600),
      ),
      textDirection: textDirection,
    )..layout();
    tp.paint(canvas, at(last) + Offset(-tp.width / 2, -tp.height - 10));
  }

  double _niceMax(double v) {
    if (v <= 0) return 4;
    final magnitude = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final normalized = v / magnitude;
    final step = normalized <= 1
        ? 1.0
        : normalized <= 2
            ? 2.0
            : normalized <= 5
                ? 5.0
                : 10.0;
    return step * magnitude;
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.points != points || old.labels != labels;
}
