import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class PhotoService {
  static const photoDirectoryName = 'med_photos';

  static String destinationPath(
    String documentsPath,
    String sourcePath, {
    required String fileId,
  }) {
    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    return p.join(documentsPath, photoDirectoryName, '$fileId$extension');
  }

  static Future<String> persistPhoto(String sourcePath) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, photoDirectoryName));
    await directory.create(recursive: true);

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException(
        'Selected medication photo does not exist',
        sourcePath,
      );
    }

    final destination = destinationPath(
      documents.path,
      sourcePath,
      fileId: const Uuid().v4(),
    );
    return (await source.copy(destination)).path;
  }

  static Future<void> deletePhoto(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static Future<int> pruneOrphaned(Iterable<String> referencedPaths) async {
    final documents = await getApplicationDocumentsDirectory();
    return pruneOrphanedInDirectory(
      Directory(p.join(documents.path, photoDirectoryName)),
      referencedPaths,
    );
  }

  static Future<int> pruneOrphanedInDirectory(
    Directory directory,
    Iterable<String> referencedPaths,
  ) async {
    if (!await directory.exists()) return 0;

    final referenced = referencedPaths
        .where((path) => path.isNotEmpty)
        .map((path) => p.normalize(File(path).absolute.path))
        .toSet();

    var deleted = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final normalized = p.normalize(entity.absolute.path);
      if (referenced.contains(normalized)) continue;
      await entity.delete();
      deleted++;
    }
    return deleted;
  }
}
