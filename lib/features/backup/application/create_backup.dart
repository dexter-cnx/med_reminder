import 'dart:typed_data';

import '../../../core/result/result.dart';
import 'backup_archive_codec.dart';
import 'backup_data_port.dart';

class CreateBackup {
  const CreateBackup({required this.dataPort, required this.codec});

  final BackupDataPort dataPort;
  final BackupArchiveCodec codec;

  Future<Result<Uint8List>> call() async {
    final captured = await dataPort.capture();
    return captured.fold(
      onSuccess: codec.encode,
      onFailure: (failure) async => Failed<Uint8List>(failure),
    );
  }
}
