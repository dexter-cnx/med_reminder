import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/services/photo_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('photo destination stays under med_photos and preserves extension', () {
    final path = PhotoService.destinationPath(
      p.join('tmp', 'documents'),
      p.join('camera', 'package.png'),
      fileId: 'photo-1',
    );

    expect(path, p.join('tmp', 'documents', 'med_photos', 'photo-1.png'));
  });

  test('pruneOrphaned removes only unreferenced files', () async {
    final root = await Directory.systemTemp.createTemp('med-photo-test-');
    addTearDown(() => root.delete(recursive: true));

    final kept = File(p.join(root.path, 'kept.jpg'));
    final orphan = File(p.join(root.path, 'orphan.jpg'));
    await kept.writeAsString('keep');
    await orphan.writeAsString('delete');

    final deleted = await PhotoService.pruneOrphanedInDirectory(
      root,
      <String>[kept.path],
    );

    expect(deleted, 1);
    expect(await kept.exists(), isTrue);
    expect(await orphan.exists(), isFalse);
  });
}
