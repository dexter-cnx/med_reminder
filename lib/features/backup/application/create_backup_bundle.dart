import 'dart:typed_data';

import '../../../core/result/result.dart';
import 'backup_bundle_archive_codec.dart';
import 'backup_data_port.dart';
import 'medication_photo_attachment_collector.dart';

final class CreateBackupBundle {
  const CreateBackupBundle({
    required this.dataPort,
    required this.attachmentCollector,
    required this.codec,
  });

  final BackupDataPort dataPort;
  final MedicationPhotoAttachmentCollector attachmentCollector;
  final BackupBundleArchiveCodec codec;

  Future<Result<Uint8List>> call() async {
    final captured = await dataPort.capture();
    if (captured case Failed(:final failure)) {
      return Failed<Uint8List>(failure);
    }

    final bundle = await attachmentCollector.collect(
      (captured as Success).value,
    );
    if (bundle case Failed(:final failure)) {
      return Failed<Uint8List>(failure);
    }

    return codec.encodeBundle((bundle as Success).value);
  }
}
