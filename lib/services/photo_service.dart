import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class PhotoService {
  static Future<String> persistPhoto(String sourcePath) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'med_photos'));
    await directory.create(recursive: true);

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Selected medication photo does not exist', sourcePath);
    }

    final extension = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final destination = p.join(directory.path, '${const Uuid().v4()}$extension');
    return (await source.copy(destination)).path;
  }

  static Future<void> deletePhoto(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
