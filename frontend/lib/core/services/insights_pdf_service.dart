import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Color palette — mirrors the dark-themed app accent colors.
// ═══════════════════════════════════════════════════════════════════════════════

const _kTeal = PdfColor.fromInt(0xFF009688);
const _kTealLight = PdfColor.fromInt(0xFFE0F2F1);
const _kCyan = PdfColor.fromInt(0xFF00ACC1);
const _kCyanLight = PdfColor.fromInt(0xFFE0F7FA);
const _kOrange = PdfColor.fromInt(0xFFF57C00);
const _kOrangeLight = PdfColor.fromInt(0xFFFFF3E0);
const _kAmber = PdfColor.fromInt(0xFFFFA000);
const _kAmberLight = PdfColor.fromInt(0xFFFFF8E1);
const _kGreen = PdfColor.fromInt(0xFF2E7D32);
const _kGreenLight = PdfColor.fromInt(0xFFE8F5E9);
const _kRed = PdfColor.fromInt(0xFFC62828);
const _kRedLight = PdfColor.fromInt(0xFFFFEBEE);
const _kGrey50 = PdfColor.fromInt(0xFFFAFAFA);
const _kGrey100 = PdfColor.fromInt(0xFFF5F5F5);
const _kGrey200 = PdfColor.fromInt(0xFFEEEEEE);
const _kGrey600 = PdfColor.fromInt(0xFF757575);
const _kGrey800 = PdfColor.fromInt(0xFF424242);

/// Generates and downloads a polished PDF report from Gemini AI insights.
class InsightsPdfService {
  InsightsPdfService._();

  // ─── Public entry point ─────────────────────────────────────────────────

  static Future<void> downloadReport({
    Map<String, dynamic>? summary,
    Map<String, dynamic>? trends,
    Map<String, dynamic>? recommendations,
    Map<String, dynamic>? jurisdictions,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.nunitoRegular(),
        bold: await PdfGoogleFonts.nunitoBold(),
        italic: await PdfGoogleFonts.nunitoItalic(),
        boldItalic: await PdfGoogleFonts.nunitoBoldItalic(),
      ),
    );

    final generatedAt = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        header: (ctx) => _header(ctx, generatedAt),
        footer: _footer,
        build: (ctx) => [
          _coverBlock(generatedAt, summary),
          pw.SizedBox(height: 10),
          if (summary != null) ..._buildSummary(summary),
          if (trends != null) ..._buildTrends(trends),
          if (recommendations != null)
            ..._buildRecommendations(recommendations),
          if (jurisdictions != null) ..._buildJurisdictions(jurisdictions),
        ],
      ),
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: _filename(generatedAt));
    } else {
      await Printing.layoutPdf(onLayout: (_) => bytes);
    }
  }

  static String _filename(DateTime dt) =>
      'insights_report_${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}.pdf';

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── PAGE HEADER / FOOTER ─────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _header(pw.Context ctx, DateTime date) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                width: 28,
                height: 28,
                decoration: pw.BoxDecoration(
                  color: _kTeal,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'AI',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Gemini AI Insights Report',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _kTeal,
                      ),
                    ),
                    pw.Text(
                      'Pothole Infrastructure Analytics',
                      style: const pw.TextStyle(fontSize: 8, color: _kGrey600),
                    ),
                  ],
                ),
              ),
              pw.Text(
                _formatDate(date),
                style: const pw.TextStyle(fontSize: 9, color: _kGrey600),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 2, color: _kTeal),
          pw.Container(height: 0.5, color: _kGrey200),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        children: [
          pw.Container(height: 0.5, color: _kGrey200),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by Gemini AI  \u2022  Confidential',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: _kGrey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: _kGrey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── COVER BLOCK ──────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _coverBlock(DateTime dt, Map<String, dynamic>? summary) {
    final title = summary?['title']?.toString() ?? 'AI Infrastructure Insights';
    final dateRange = summary?['date_range']?.toString() ?? '';
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_kTealLight, PdfColors.white],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _kTeal, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: _kGrey800,
            ),
          ),
          if (dateRange.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              dateRange,
              style: const pw.TextStyle(fontSize: 10, color: _kGrey600),
            ),
          ],
          pw.SizedBox(height: 6),
          pw.Text(
            'Report generated on ${_formatDate(dt)} at '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}',
            style: pw.TextStyle(
              fontSize: 8,
              color: _kGrey600,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── SECTION: EXECUTIVE SUMMARY ───────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  static List<pw.Widget> _buildSummary(Map<String, dynamic> data) {
    final widgets = <pw.Widget>[
      _sectionBanner('Executive Summary', _kCyan, _kCyanLight),
    ];

    // Overview paragraph
    if (data['overview'] is String) {
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _kGrey50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _kGrey200),
          ),
          child: pw.Text(
            data['overview'] as String,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),
        ),
      );
    }

    // Key stats — 2×2 colored card grid
    if (data['key_stats'] is List) {
      final stats = (data['key_stats'] as List).whereType<Map>().toList();
      if (stats.isNotEmpty) {
        widgets.add(_subLabel('Key Performance Metrics'));
        for (int i = 0; i < stats.length; i += 2) {
          final left = stats[i];
          final right = i + 1 < stats.length ? stats[i + 1] : null;
          widgets.add(
            pw.Row(
              children: [
                pw.Expanded(child: _statCard(left)),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: right != null ? _statCard(right) : pw.SizedBox(),
                ),
              ],
            ),
          );
          widgets.add(pw.SizedBox(height: 8));
        }
      }
    }

    // Highlights
    if (data['highlights'] is List) {
      final items = (data['highlights'] as List)
          .map((e) => e.toString())
          .toList();
      if (items.isNotEmpty) {
        widgets.add(_subLabel('Key Highlights'));
        widgets.add(_bulletList(items, PdfColors.cyan800));
      }
    }

    // Summary recommendations
    if (data['recommendations'] is List) {
      final items = (data['recommendations'] as List)
          .map((e) => e.toString())
          .toList();
      if (items.isNotEmpty) {
        widgets.add(_subLabel('Quick Recommendations'));
        widgets.add(_bulletList(items, _kTeal));
      }
    }

    widgets.add(pw.SizedBox(height: 6));
    return widgets;
  }

  static pw.Widget _statCard(Map stat) {
    final label = stat['label']?.toString() ?? '';
    final value = stat['value']?.toString() ?? '';
    final trend = stat['trend']?.toString() ?? '';
    final trendColor = trend == 'up'
        ? _kGreen
        : trend == 'down'
        ? _kRed
        : _kGrey600;
    final trendIcon = trend == 'up'
        ? '\u25B2'
        : trend == 'down'
        ? '\u25BC'
        : '\u25CF';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _kGrey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _kGrey600,
              letterSpacing: 0.6,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _kGrey800,
                ),
              ),
              if (trend.isNotEmpty) ...[
                pw.SizedBox(width: 6),
                pw.Text(
                  trendIcon,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: trendColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── SECTION: TREND ANALYSIS ──────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  static List<pw.Widget> _buildTrends(Map<String, dynamic> data) {
    final widgets = <pw.Widget>[
      _sectionBanner('Trend Analysis', _kOrange, _kOrangeLight),
    ];

    // Direction badge + summary
    final direction = data['overall_direction']?.toString() ?? '';
    final summaryText = data['summary']?.toString() ?? '';
    if (direction.isNotEmpty || summaryText.isNotEmpty) {
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _kGrey50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _kGrey200),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (direction.isNotEmpty) ...[
                _directionChip(direction),
                pw.SizedBox(width: 10),
              ],
              pw.Expanded(
                child: pw.Text(
                  summaryText,
                  style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Daily pattern
    if (data['daily_pattern'] is String) {
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _kOrangeLight,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                'Pattern  ',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _kOrange,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  data['daily_pattern'] as String,
                  style: const pw.TextStyle(fontSize: 9, color: _kGrey800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Emerging hotspots table
    if (data['emerging_hotspots'] is List) {
      final spots = (data['emerging_hotspots'] as List)
          .whereType<Map>()
          .toList();
      if (spots.isNotEmpty) {
        widgets.add(_subLabel('Emerging Hotspots'));
        widgets.add(
          _styledTable(
            headers: ['Jurisdiction', 'Count', 'Severity', 'Reason'],
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(3),
            },
            rows: spots.map((h) {
              return [
                h['jurisdiction']?.toString() ?? '',
                h['report_count']?.toString() ?? '',
                h['severity']?.toString() ?? '',
                h['reason']?.toString() ?? '',
              ];
            }).toList(),
            accentColor: _kOrange,
          ),
        );
        widgets.add(pw.SizedBox(height: 8));
      }
    }

    // Worsening areas
    if (data['worsening_areas'] is List) {
      final areas = (data['worsening_areas'] as List).whereType<Map>().toList();
      if (areas.isNotEmpty) {
        widgets.add(_subLabel('Worsening Areas'));
        for (final a in areas) {
          widgets.add(
            _infoCard(
              title: a['jurisdiction']?.toString() ?? 'Unknown',
              subtitle: a['issue']?.toString() ?? '',
              trailing: a['metric']?.toString() ?? '',
              color: _kRed,
            ),
          );
        }
        widgets.add(pw.SizedBox(height: 4));
      }
    }

    // Positive trends
    if (data['positive_trends'] is List) {
      final pos = (data['positive_trends'] as List).whereType<Map>().toList();
      if (pos.isNotEmpty) {
        widgets.add(_subLabel('Positive Trends'));
        for (final p in pos) {
          widgets.add(
            _infoCard(
              title: p['description']?.toString() ?? '',
              trailing: p['metric']?.toString() ?? '',
              color: _kGreen,
            ),
          );
        }
        widgets.add(pw.SizedBox(height: 4));
      }
    }

    widgets.add(pw.SizedBox(height: 6));
    return widgets;
  }

  static pw.Widget _directionChip(String direction) {
    final isImproving = direction == 'improving';
    final isDeclining = direction == 'declining';
    final color = isImproving
        ? _kGreen
        : isDeclining
        ? _kRed
        : _kOrange;
    final bg = isImproving
        ? _kGreenLight
        : isDeclining
        ? _kRedLight
        : _kOrangeLight;
    final arrow = isImproving
        ? '\u25B2'
        : isDeclining
        ? '\u25BC'
        : '\u25CF';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: color, width: 0.5),
      ),
      child: pw.Text(
        '$arrow ${direction.toUpperCase()}',
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── SECTION: PRIORITY RECOMMENDATIONS ────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  static List<pw.Widget> _buildRecommendations(Map<String, dynamic> data) {
    final widgets = <pw.Widget>[
      _sectionBanner('Priority Recommendations', _kAmber, _kAmberLight),
    ];

    if (data['priority_queue'] is List) {
      final queue = (data['priority_queue'] as List).whereType<Map>().toList();
      for (final item in queue) {
        final rank = item['rank']?.toString() ?? '';
        final priority = item['priority']?.toString() ?? '';
        final jurisdiction = item['jurisdiction']?.toString() ?? '';
        final reason = item['reason']?.toString() ?? '';
        final urgency = item['urgency']?.toString() ?? '';
        final size = item['size']?.toString() ?? '';
        final ageHours = item['age_hours'];
        final estimatedImpact = item['estimated_impact']?.toString() ?? '';

        final priorityColor = _priorityPdfColor(priority);
        final priorityBg = _priorityPdfBgColor(priority);

        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border(
                left: pw.BorderSide(color: priorityColor, width: 3),
                top: pw.BorderSide(color: _kGrey200, width: 0.5),
                right: pw.BorderSide(color: _kGrey200, width: 0.5),
                bottom: pw.BorderSide(color: _kGrey200, width: 0.5),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top row: rank + priority badge + urgency + metadata
                pw.Row(
                  children: [
                    pw.Container(
                      width: 22,
                      height: 22,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        color: _kGrey800,
                        borderRadius: pw.BorderRadius.circular(11),
                      ),
                      child: pw.Text(
                        rank.isNotEmpty ? '#$rank' : '',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    _badge(priority, priorityColor, priorityBg),
                    pw.SizedBox(width: 6),
                    if (urgency.isNotEmpty)
                      _badge(
                        urgency.toUpperCase(),
                        _urgencyColor(urgency),
                        _urgencyBgColor(urgency),
                      ),
                    pw.Spacer(),
                    if (size.isNotEmpty)
                      pw.Text(
                        size,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: _kGrey600,
                        ),
                      ),
                    if (ageHours != null) ...[
                      pw.SizedBox(width: 8),
                      pw.Text(
                        '${_num(ageHours)}h open',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: _kGrey600,
                        ),
                      ),
                    ],
                  ],
                ),
                pw.SizedBox(height: 6),

                // Jurisdiction
                if (jurisdiction.isNotEmpty)
                  pw.Text(
                    jurisdiction,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _kGrey800,
                    ),
                  ),

                // Reason
                if (reason.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    reason,
                    style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
                  ),
                ],

                // Impact
                if (estimatedImpact.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _kRedLight,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Text(
                      'Impact: $estimatedImpact',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: _kRed,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    // Clustering insights
    if (data['clustering_insights'] is String) {
      widgets.add(
        _calloutBox(
          label: 'Clustering Insight',
          text: data['clustering_insights'] as String,
          color: _kAmber,
          bg: _kAmberLight,
        ),
      );
    }

    // Resource suggestion
    if (data['resource_suggestion'] is String) {
      widgets.add(
        _calloutBox(
          label: 'Resource Suggestion',
          text: data['resource_suggestion'] as String,
          color: _kTeal,
          bg: _kTealLight,
        ),
      );
    }

    widgets.add(pw.SizedBox(height: 6));
    return widgets;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── SECTION: JURISDICTION SCORECARDS ─────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  static List<pw.Widget> _buildJurisdictions(Map<String, dynamic> data) {
    final widgets = <pw.Widget>[
      _sectionBanner('Jurisdiction Scorecards', _kGreen, _kGreenLight),
    ];

    // Overall assessment
    if (data['overall_assessment'] is String) {
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _kGrey50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _kGrey200),
          ),
          child: pw.Text(
            data['overall_assessment'] as String,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),
        ),
      );
    }

    // Best performer / needs attention callouts
    final best = data['best_performer']?.toString() ?? '';
    final worst = data['needs_attention']?.toString() ?? '';
    if (best.isNotEmpty || worst.isNotEmpty) {
      widgets.add(
        pw.Row(
          children: [
            if (best.isNotEmpty)
              pw.Expanded(
                child: _miniCallout('\u2605 Best Performer', best, _kGreen),
              ),
            if (best.isNotEmpty && worst.isNotEmpty) pw.SizedBox(width: 8),
            if (worst.isNotEmpty)
              pw.Expanded(
                child: _miniCallout('\u26A0 Needs Attention', worst, _kRed),
              ),
          ],
        ),
      );
      widgets.add(pw.SizedBox(height: 10));
    }

    // Scorecards table
    if (data['scorecards'] is List) {
      final cards = (data['scorecards'] as List).whereType<Map>().toList();
      if (cards.isNotEmpty) {
        widgets.add(_jurisdictionTable(cards));
      }
    }

    widgets.add(pw.SizedBox(height: 6));
    return widgets;
  }

  /// Rich jurisdiction table with colored grade badges and alternating rows.
  static pw.Widget _jurisdictionTable(List<Map> cards) {
    const headerStyle = pw.TextStyle(fontSize: 8, color: PdfColors.white);

    return pw.Table(
      border: pw.TableBorder.all(color: _kGrey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.4),
        1: const pw.FlexColumnWidth(0.7),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(0.9),
        5: const pw.FlexColumnWidth(0.8),
        6: const pw.FlexColumnWidth(3.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kGreen),
          children: [
            _headerCell('Jurisdiction', headerStyle),
            _headerCell('Grade', headerStyle),
            _headerCell('Resolution', headerStyle),
            _headerCell('Avg Resp (h)', headerStyle),
            _headerCell('Overdue', headerStyle),
            _headerCell('Red', headerStyle),
            _headerCell('Notes', headerStyle),
          ],
        ),
        ...cards.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          final rowBg = i.isEven ? PdfColors.white : _kGrey100;
          final grade = c['grade']?.toString() ?? '';
          final resRate = c['resolution_rate'];
          final avgResp = c['avg_response_hours'];

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            children: [
              _dataCell(c['jurisdiction']?.toString() ?? '', bold: true),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 5,
                ),
                child: pw.Center(child: _gradeBadge(grade)),
              ),
              _dataCell(resRate != null ? '${_num(resRate)}%' : '-'),
              _dataCell(avgResp != null ? _num(avgResp) : '-'),
              _dataCell(c['overdue']?.toString() ?? '-'),
              _dataCell(c['red_count']?.toString() ?? '-'),
              _dataCell(
                c['summary']?.toString() ?? c['suggestion']?.toString() ?? '',
                maxLines: 3,
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Colored circular grade badge.
  static pw.Widget _gradeBadge(String grade) {
    final color = _gradeColor(grade);
    final bg = _gradeBgColor(grade);
    return pw.Container(
      width: 20,
      height: 20,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: bg,
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Text(
        grade,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── SHARED BUILDING BLOCKS ───────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// Full-width colored section banner with side accent bar.
  static pw.Widget _sectionBanner(String text, PdfColor accent, PdfColor bg) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border(
          left: pw.BorderSide(color: accent, width: 4),
          top: pw.BorderSide(color: accent, width: 0.5),
          right: pw.BorderSide(color: accent, width: 0.5),
          bottom: pw.BorderSide(color: accent, width: 0.5),
        ),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: accent,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static pw.Widget _subLabel(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: _kGrey600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// Styled table with accent-colored header and alternating rows.
  static pw.Widget _styledTable({
    required List<String> headers,
    required List<List<String>> rows,
    required PdfColor accentColor,
    Map<int, pw.TableColumnWidth>? columnWidths,
  }) {
    const headerStyle = pw.TextStyle(fontSize: 8, color: PdfColors.white);

    return pw.Table(
      border: pw.TableBorder.all(color: _kGrey200, width: 0.5),
      columnWidths: columnWidths,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: accentColor),
          children: headers.map((h) => _headerCell(h, headerStyle)).toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final i = entry.key;
          final cells = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : _kGrey100,
            ),
            children: cells.map((c) => _dataCell(c)).toList(),
          );
        }),
      ],
    );
  }

  /// Small info card for worsening areas / positive trends.
  static pw.Widget _infoCard({
    required String title,
    String? subtitle,
    String? trailing,
    required PdfColor color,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border(
          left: pw.BorderSide(color: color, width: 3),
          top: pw.BorderSide(color: _kGrey200, width: 0.5),
          right: pw.BorderSide(color: _kGrey200, width: 0.5),
          bottom: pw.BorderSide(color: _kGrey200, width: 0.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _kGrey800,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    subtitle,
                    style: const pw.TextStyle(fontSize: 8, color: _kGrey600),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null && trailing.isNotEmpty) ...[
            pw.SizedBox(width: 8),
            pw.Text(
              trailing,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Rounded callout box for clustering insights / resource suggestions.
  static pw.Widget _calloutBox({
    required String label,
    required String text,
    required PdfColor color,
    required PdfColor bg,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(text, style: const pw.TextStyle(fontSize: 9, lineSpacing: 2)),
        ],
      ),
    );
  }

  /// Mini callout used side-by-side (best performer / needs attention).
  static pw.Widget _miniCallout(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border(
          left: pw.BorderSide(color: color, width: 3),
          top: pw.BorderSide(color: _kGrey200, width: 0.5),
          right: pw.BorderSide(color: _kGrey200, width: 0.5),
          bottom: pw.BorderSide(color: _kGrey200, width: 0.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _kGrey800,
            ),
          ),
        ],
      ),
    );
  }

  /// Colored inline badge.
  static pw.Widget _badge(String text, PdfColor color, PdfColor bg) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: color, width: 0.5),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Bullet list with colored circle bullets.
  static pw.Widget _bulletList(List<String> items, PdfColor bulletColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.map((text) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(left: 6, bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 5,
                height: 5,
                margin: const pw.EdgeInsets.only(top: 3, right: 8),
                decoration: pw.BoxDecoration(
                  color: bulletColor,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  text,
                  style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Table cell helpers ─────────────────────────────────────────────────

  static pw.Widget _headerCell(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        style: style.copyWith(fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _dataCell(
    String text, {
    bool bold = false,
    int maxLines = 2,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        maxLines: maxLines,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _kGrey800,
        ),
      ),
    );
  }

  // ─── Color lookup helpers ───────────────────────────────────────────────

  static PdfColor _gradeColor(String grade) {
    switch (grade) {
      case 'A':
        return _kGreen;
      case 'B':
        return _kTeal;
      case 'C':
        return _kCyan;
      case 'D':
        return _kOrange;
      case 'F':
        return _kRed;
      default:
        return _kGrey600;
    }
  }

  static PdfColor _gradeBgColor(String grade) {
    switch (grade) {
      case 'A':
        return _kGreenLight;
      case 'B':
        return _kTealLight;
      case 'C':
        return _kCyanLight;
      case 'D':
        return _kOrangeLight;
      case 'F':
        return _kRedLight;
      default:
        return _kGrey100;
    }
  }

  static PdfColor _priorityPdfColor(String p) {
    switch (p) {
      case 'Red':
        return _kRed;
      case 'Yellow':
        return _kAmber;
      case 'Green':
        return _kGreen;
      default:
        return _kGrey600;
    }
  }

  static PdfColor _priorityPdfBgColor(String p) {
    switch (p) {
      case 'Red':
        return _kRedLight;
      case 'Yellow':
        return _kAmberLight;
      case 'Green':
        return _kGreenLight;
      default:
        return _kGrey100;
    }
  }

  static PdfColor _urgencyColor(String u) {
    switch (u) {
      case 'critical':
        return _kRed;
      case 'high':
        return _kOrange;
      case 'medium':
        return _kAmber;
      default:
        return _kGrey600;
    }
  }

  static PdfColor _urgencyBgColor(String u) {
    switch (u) {
      case 'critical':
        return _kRedLight;
      case 'high':
        return _kOrangeLight;
      case 'medium':
        return _kAmberLight;
      default:
        return _kGrey100;
    }
  }

  // ─── Misc helpers ───────────────────────────────────────────────────────

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  /// Format a numeric value (int or double).
  static String _num(dynamic v) {
    if (v is int) return v.toString();
    if (v is double) {
      return v == v.roundToDouble()
          ? v.toInt().toString()
          : v.toStringAsFixed(1);
    }
    return v?.toString() ?? '-';
  }
}
