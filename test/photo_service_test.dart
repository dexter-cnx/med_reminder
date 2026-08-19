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
}
