import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/task.dart';
import '../utils/date_utils.dart';

/// Builds CSV and PDF files from the task list and shares them.
class ExportService {
  // ---------- Helpers ----------

  String _status(Task t) {
    if (t.isCompleted) return 'Completed';
    if (t.isOverdue) return 'Overdue';
    return 'Pending';
  }

  String _due(Task t) =>
      '${AppDateUtils.formatDate(t.dueDate)} '
          '${AppDateUtils.formatTime(t.dueTime.hour, t.dueTime.minute)}';

  String _stamp() {
    final n = DateTime.now();
    return '${AppDateUtils.formatDate(n)}_'
        '${n.hour.toString().padLeft(2, '0')}'
        '${n.minute.toString().padLeft(2, '0')}';
  }

  Future<File> _newFile(String name) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$name');
  }

  // ---------- CSV ----------

  /// Wraps a value in quotes when it contains a comma, quote or newline.
  String _cell(String v) {
    final needsQuotes = v.contains(',') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r');
    final escaped = v.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  Future<File> exportCsv(List<Task> tasks) async {
    final rows = <List<String>>[
      [
        'Title',
        'Description',
        'Due date',
        'Due time',
        'Status',
        'Completed at',
        'Repeat',
        'Subtasks done',
        'Subtasks total',
        'Progress %',
      ],
      for (final t in tasks)
        [
          t.title,
          t.description,
          AppDateUtils.formatDate(t.dueDate),
          AppDateUtils.formatTime(t.dueTime.hour, t.dueTime.minute),
          _status(t),
          t.completedAt?.toIso8601String() ?? '',
          t.recurrence?.label ?? '',
          t.subtasks
              .where((s) => s.isCompleted)
              .length
              .toString(),
          t.subtasks.length.toString(),
          t.progressPercent.toString(),
        ],
    ];

    final text = rows.map((r) => r.map(_cell).join(',')).join('\r\n');
    final file = await _newFile('tasks_${_stamp()}.csv');
    // The BOM (\uFEFF) lets Excel read non-English characters correctly.
    await file.writeAsString('\uFEFF$text', encoding: utf8);
    return file;
  }

  // ---------- PDF ----------

  pw.Widget _pdfCell(String text, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  Future<File> exportPdf(List<Task> tasks) async {
    final doc = pw.Document();
    final done = tasks
        .where((t) => t.isCompleted)
        .length;
    final overdue = tasks
        .where((t) => t.isOverdue)
        .length;
    final pending = tasks.length - done;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) =>
        [
          pw.Text(
            'Task Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated ${AppDateUtils.formatDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Total: ${tasks.length}   Pending: $pending   '
                'Completed: $done   Overdue: $overdue',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(3.2),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.6),
              4: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfCell('Title', bold: true),
                  _pdfCell('Due', bold: true),
                  _pdfCell('Status', bold: true),
                  _pdfCell('Progress', bold: true),
                  _pdfCell('Repeat', bold: true),
                ],
              ),
              for (final t in tasks)
                pw.TableRow(
                  children: [
                    _pdfCell(t.title),
                    _pdfCell(_due(t)),
                    _pdfCell(_status(t)),
                    _pdfCell(
                      t.subtasks.isEmpty
                          ? '-'
                          : '${t.subtasks
                          .where((s) => s.isCompleted)
                          .length}'
                          '/${t.subtasks.length} (${t.progressPercent}%)',
                    ),
                    _pdfCell(t.recurrence?.label ?? '-'),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    final file = await _newFile('tasks_${_stamp()}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  // ---------- Sharing ----------

  /// Opens the Android share sheet (Gmail, Drive, Files, WhatsApp, ...).
  Future<void> shareFile(File file, {
    String? subject,
    String? text,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
        text: text,
      ),
    );
  }
}