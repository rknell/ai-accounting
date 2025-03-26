import 'dart:io';

import 'package:ai_accounting/services/services.dart';
import 'package:path/path.dart' as p;

/// ReportWrapper class that provides a navigation frame for viewing different reports
/// The wrapper is designed to not be printed when using the browser's print function
class ReportWrapper {
  /// The services instance containing required services
  final Services services;

  /// Directory where reports are stored
  final String reportsDirectory = 'data';

  /// Creates a new report wrapper
  ///
  /// @param services The services instance containing required services
  ReportWrapper(this.services);

  /// Generates a wrapper HTML file that shows links to all available reports
  ///
  /// @return True if the wrapper was successfully generated, false otherwise
  bool generateWrapper() {
    try {
      final directory = Directory(reportsDirectory);

      // Check if directory exists
      if (!directory.existsSync()) {
        print('Reports directory not found: $reportsDirectory');
        return false;
      }

      // Get all HTML files in the reports directory
      final reportFiles = directory
          .listSync()
          .where((entity) =>
              entity is File &&
              p.extension(entity.path).toLowerCase() == '.html')
          .map((entity) => entity.path)
          .toList();

      // Filter out the report viewer itself to avoid circular reference
      reportFiles
          .removeWhere((path) => p.basename(path) == 'report_viewer.html');

      // Sort reports by modification date (newest first)
      reportFiles.sort((a, b) {
        final fileA = File(a);
        final fileB = File(b);
        return fileB.lastModifiedSync().compareTo(fileA.lastModifiedSync());
      });

      // Group reports by type
      final balanceSheetReports = <String>[];
      final profitAndLossReports = <String>[];
      final gstReports = <String>[];
      final otherReports = <String>[];

      for (final reportPath in reportFiles) {
        final fileName = p.basename(reportPath);

        if (fileName.startsWith('balance_sheet')) {
          balanceSheetReports.add(fileName);
        } else if (fileName.startsWith('profit_and_loss')) {
          profitAndLossReports.add(fileName);
        } else if (fileName.startsWith('gst')) {
          gstReports.add(fileName);
        } else {
          otherReports.add(fileName);
        }
      }

      // Generate HTML with navigation
      final html = _generateHtml(
          balanceSheetReports, profitAndLossReports, gstReports, otherReports);

      // Save the wrapper to file
      final wrapperFile = File(p.join(reportsDirectory, 'report_viewer.html'));
      wrapperFile.writeAsStringSync(html);

      return true;
    } catch (e) {
      print('Error generating report wrapper: $e');
      return false;
    }
  }

  /// Generates the HTML content for the report wrapper
  String _generateHtml(
    List<String> balanceSheetReports,
    List<String> profitAndLossReports,
    List<String> gstReports,
    List<String> otherReports,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Financial Reports</title>
    <style>
        body {
            font-family: 'Times New Roman', Times, serif;
            line-height: 1.5;
            margin: 0;
            padding: 0;
            display: flex;
            min-height: 100vh;
        }
        
        /* Navigation panel */
        .nav-panel {
            width: 250px;
            background-color: #f5f5f5;
            border-right: 1px solid #ddd;
            padding: 20px;
            overflow-y: auto;
        }
        
        /* Report viewing area */
        .report-view {
            flex-grow: 1;
            height: 100vh;
        }
        
        iframe {
            width: 100%;
            height: 100%;
            border: none;
        }
        
        h1 {
            font-size: 1.5rem;
            margin: 0 0 20px 0;
            padding-bottom: 10px;
            border-bottom: 2px solid #000;
        }
        
        h2 {
            font-size: 1.2rem;
            margin: 20px 0 10px 0;
            padding-bottom: 5px;
            border-bottom: 1px solid #ddd;
        }
        
        ul {
            list-style: none;
            padding: 0;
            margin: 0;
        }
        
        li {
            margin-bottom: 8px;
        }
        
        a {
            text-decoration: none;
            color: #0066cc;
            display: block;
            padding: 5px;
            border-radius: 4px;
        }
        
        a:hover {
            background-color: #e9f2ff;
        }
        
        .date {
            font-size: 0.8rem;
            color: #666;
            display: block;
        }
        
        /* Print styles - hide navigation when printing */
        @media print {
            .nav-panel {
                display: none;
            }
        }
    </style>
    <script>
        function loadReport(path) {
            document.getElementById('reportFrame').src = path;
            
            // For mobile: if screen is narrow, hide nav panel after selection
            if (window.innerWidth < 768) {
                document.querySelector('.nav-panel').style.display = 'none';
                document.querySelector('.report-view').style.width = '100%';
            }
        }
        
        function toggleNav() {
            const nav = document.querySelector('.nav-panel');
            nav.style.display = nav.style.display === 'none' ? 'block' : 'none';
        }
    </script>
</head>
<body>
    <!-- Navigation Panel (will not be printed) -->
    <div class="nav-panel no-print">
        <h1>Financial Reports</h1>
        
        <!-- Report type sections -->
''');

    // Balance Sheet Reports
    if (balanceSheetReports.isNotEmpty) {
      buffer.writeln('<h2>Balance Sheets</h2>');
      buffer.writeln('<ul>');
      for (final reportPath in balanceSheetReports) {
        final reportDate = _extractDateFromFileName(reportPath);
        buffer.writeln('''
          <li>
            <a href="javascript:void(0)" onclick="loadReport('$reportPath')">
              Balance Sheet
              <span class="date">$reportDate</span>
            </a>
          </li>
        ''');
      }
      buffer.writeln('</ul>');
    }

    // Profit and Loss Reports
    if (profitAndLossReports.isNotEmpty) {
      buffer.writeln('<h2>Profit &amp; Loss Statements</h2>');
      buffer.writeln('<ul>');
      for (final reportPath in profitAndLossReports) {
        final reportDate = _extractDateFromFileName(reportPath);
        buffer.writeln('''
          <li>
            <a href="javascript:void(0)" onclick="loadReport('$reportPath')">
              Profit &amp; Loss
              <span class="date">$reportDate</span>
            </a>
          </li>
        ''');
      }
      buffer.writeln('</ul>');
    }

    // GST Reports
    if (gstReports.isNotEmpty) {
      buffer.writeln('<h2>GST Reports</h2>');
      buffer.writeln('<ul>');
      for (final reportPath in gstReports) {
        final reportDate = _extractDateFromFileName(reportPath);
        buffer.writeln('''
          <li>
            <a href="javascript:void(0)" onclick="loadReport('$reportPath')">
              GST Report
              <span class="date">$reportDate</span>
            </a>
          </li>
        ''');
      }
      buffer.writeln('</ul>');
    }

    // Other Reports
    if (otherReports.isNotEmpty) {
      buffer.writeln('<h2>Other Reports</h2>');
      buffer.writeln('<ul>');
      for (final reportPath in otherReports) {
        buffer.writeln('''
          <li>
            <a href="javascript:void(0)" onclick="loadReport('$reportPath')">
              ${reportPath.replaceAll('_', ' ').replaceAll('.html', '')}
            </a>
          </li>
        ''');
      }
      buffer.writeln('</ul>');
    }

    // Complete the HTML
    buffer.writeln('''
    </div>
    
    <!-- Report Viewing Area -->
    <div class="report-view">
        <iframe id="reportFrame" name="reportFrame"></iframe>
    </div>
</body>
</html>
    ''');

    return buffer.toString();
  }

  /// Extracts a formatted date from a filename
  ///
  /// @param fileName The filename containing a date
  /// @return A formatted date string or the original filename if no date found
  String _extractDateFromFileName(String fileName) {
    // Look for date patterns like 20240331 (yyyymmdd)
    final datePattern = RegExp(r'(\d{4})(\d{2})(\d{2})');
    final match = datePattern.firstMatch(fileName);

    if (match != null) {
      final year = match.group(1);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);

      // Convert month number to name
      final monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];

      return '$day ${monthNames[month - 1]} $year';
    }

    return fileName.replaceAll('_', ' ').replaceAll('.html', '');
  }
}
