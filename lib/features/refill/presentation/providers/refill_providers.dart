import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/refill_repository.dart';

final refillRepositoryProvider = Provider<RefillRepository>(
  (ref) => throw UnimplementedError(
    'RefillRepository must be provided by app DI.',
  ),
);
