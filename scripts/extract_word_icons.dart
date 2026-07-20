// ignore_for_file: unnecessary_cast

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  final rootDir = Directory('C:\\MyDartProjects\\docx_rendering');
  final sourceDir =
      Directory(p.join(rootDir.path, 'resources', 'word.example'));
  final targetDir =
      Directory(p.join(rootDir.path, 'resources', 'extracted_icons'));

  if (!sourceDir.existsSync()) {
    print('Source directory does not exist: ${sourceDir.path}');
    exit(1);
  }

  if (targetDir.existsSync()) {
    targetDir.deleteSync(recursive: true);
  }
  targetDir.createSync(recursive: true);

  print('Extracting icons and assets to: ${targetDir.path}');

  int copiedCount = 0;
  int decodedCount = 0;

  // 1. Traverse and copy binary images and font files
  final allFiles = sourceDir.listSync(recursive: true, followLinks: false);
  for (final entity in allFiles) {
    if (entity is! File) continue;

    final file = entity as File;
    final relPath = p.relative(file.path, from: sourceDir.path);
    final ext = p.extension(file.path).toLowerCase();

    // Check if it's already an image or font file
    const targetExtensions = {
      '.png',
      '.svg',
      '.ico',
      '.jpg',
      '.jpeg',
      '.gif',
      '.woff',
      '.woff2',
      '.ttf'
    };

    if (targetExtensions.contains(ext)) {
      // Create a flat name to avoid subdirectories and collisions
      final pathParts = p.split(p.dirname(relPath));
      final cleanParts = pathParts
          .where((part) => part != '.' && part.isNotEmpty)
          .map((part) => part.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_'))
          .toList();

      final prefix = cleanParts.isNotEmpty ? '${cleanParts.join('_')}_' : '';
      final newName = 'copied_$prefix${p.basename(file.path)}';
      final destPath = p.join(targetDir.path, newName);

      file.copySync(destPath);
      copiedCount++;
    }
  }

  // 2. Decode DataURIs from the _DataURI folder
  final dataUriDir = Directory(p.join(sourceDir.path, '_DataURI'));
  if (dataUriDir.existsSync()) {
    final dataFiles = dataUriDir.listSync();
    for (final entity in dataFiles) {
      if (entity is! File) continue;
      final file = entity as File;
      if (!p.basename(file.path).endsWith('.txt')) continue;

      try {
        final content = file.readAsStringSync().trim();
        if (!content.startsWith('data:')) {
          print(
              'Warning: File ${p.basename(file.path)} does not start with data: scheme');
          continue;
        }

        // Parse the data URI scheme
        final commaIndex = content.indexOf(',');
        if (commaIndex == -1) {
          print('Warning: Invalid data URI in ${p.basename(file.path)}');
          continue;
        }

        final header = content.substring(0, commaIndex);
        final data = content.substring(commaIndex + 1);

        // Extract media type
        final mimeTypeMatch = RegExp(r'data:([^;]+)').firstMatch(header);
        if (mimeTypeMatch == null) {
          print(
              'Warning: Could not parse mime type in ${p.basename(file.path)}');
          continue;
        }

        final mimeType = mimeTypeMatch.group(1)!;
        final isBase64 = header.contains(';base64');

        // Determine extension
        String extension;
        if (mimeType == 'image/svg+xml') {
          extension = '.svg';
        } else if (mimeType == 'image/png') {
          extension = '.png';
        } else if (mimeType == 'image/jpeg' || mimeType == 'image/jpg') {
          extension = '.jpg';
        } else if (mimeType == 'image/gif') {
          extension = '.gif';
        } else if (mimeType == 'image/x-icon' ||
            mimeType == 'image/vnd.microsoft.icon') {
          extension = '.ico';
        } else if (mimeType.contains('woff2')) {
          extension = '.woff2';
        } else if (mimeType.contains('woff')) {
          extension = '.woff';
        } else if (mimeType.contains('ttf')) {
          extension = '.ttf';
        } else {
          // Fallback based on text file name hints
          final name = p.basename(file.path);
          if (name.contains('.svg')) {
            extension = '.svg';
          } else if (name.contains('.png')) {
            extension = '.png';
          } else if (name.contains('.woff')) {
            extension = '.woff';
          } else if (name.contains('.jpeg') || name.contains('.jpg')) {
            extension = '.jpg';
          } else if (name.contains('.gif')) {
            extension = '.gif';
          } else {
            extension = '.bin';
          }
        }

        List<int> bytes;
        if (isBase64) {
          // Normalize and decode base64
          final normalizedData = data.replaceAll(RegExp(r'\s+'), '');
          bytes = base64.decode(normalizedData);
        } else {
          // Decode URL-encoded string
          bytes = utf8.encode(Uri.decodeComponent(data));
        }

        final sourceBaseName = p.basenameWithoutExtension(file.path);
        final newName = 'decoded_$sourceBaseName$extension';
        final destPath = p.join(targetDir.path, newName);

        final destFile = File(destPath);
        destFile.writeAsBytesSync(bytes);
        decodedCount++;
      } catch (e) {
        print('Error decoding data URI from file ${p.basename(file.path)}: $e');
      }
    }
  }

  print('\nExtraction complete!');
  print('Total copied files (images/fonts): $copiedCount');
  print('Total decoded Data URI files: $decodedCount');
  print('All files saved in: ${targetDir.path}');
}
