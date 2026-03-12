import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/gps_point.dart';

/// Exports GPS points to GPX format and shares via the system share sheet.
class GpxExporter {
  /// Generate a GPX file from a list of GPS points and share it.
  static Future<void> exportAndShare(
    List<GpsPoint> points,
    String sessionId,
  ) async {
    if (points.isEmpty) return;

    final gpxContent = _buildGpx(points, sessionId);

    // Write to temp file
    final dir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HHmm').format(points.first.timestamp);
    final file = File('${dir.path}/datacommons_gps_$timestamp.gpx');
    await file.writeAsString(gpxContent);

    // Share
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'DataCommons GPS Trace - $timestamp',
    );
  }

  static String _buildGpx(List<GpsPoint> points, String sessionId) {
    final isoFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<gpx version="1.1" creator="DataCommons" '
        'xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <trk>');
    buffer.writeln(
        '    <name>Session ${isoFormat.format(points.first.timestamp)}</name>');
    buffer.writeln('    <trkseg>');

    for (final p in points) {
      buffer.writeln(
          '      <trkpt lat="${p.latitude}" lon="${p.longitude}">');
      if (p.altitude != null) {
        buffer.writeln('        <ele>${p.altitude}</ele>');
      }
      buffer.writeln(
          '        <time>${isoFormat.format(p.timestamp)}</time>');
      if (p.speed != null) {
        buffer.writeln(
            '        <extensions><speed>${p.speed}</speed></extensions>');
      }
      buffer.writeln('      </trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }
}
