import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/refill_event.dart';
import '../../domain/repositories/refill_repository.dart';

final refillRepositoryProvider = Provider<RefillRepository>(
  (ref) =>
      throw UnimplementedError('RefillRepository must be provided by app DI.'),
);

final refillFailureProvider = StateProvider<Failure?>((ref) => null);

final refillEventsProvider =
    StateNotifierProvider<RefillViewModel, List<RefillEvent>>(
      (ref) => RefillViewModel(
        ref.watch(refillRepositoryProvider),
        onFailure: (failure) {
          Future<void>.microtask(() {
            ref.read(refillFailureProvider.notifier).state = failure;
          });
        },
      ),
    );

class RefillViewModel extends StateNotifier<List<RefillEvent>> {
  RefillViewModel(
    RefillRepository repository, {
    required void Function(Failure failure) onFailure,
  }) : _repository = repository,
       _onFailure = onFailure,
       super(_load(repository, onFailure));

  final RefillRepository _repository;
  final void Function(Failure failure) _onFailure;

  static List<RefillEvent> _load(
    RefillRepository repository,
    void Function(Failure failure) onFailure,
  ) {
    return repository.readAll().fold(
      onSuccess: (events) => List<RefillEvent>.unmodifiable(events),
      onFailure: (failure) {
        onFailure(failure);
        return const <RefillEvent>[];
      },
    );
  }

  Future<bool> append(RefillEvent event) async {
    final result = await _repository.append(event);
    return result.fold(
      onSuccess: (_) {
        final next = <RefillEvent>[
          ...state.where((item) => item.id != event.id),
          event,
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        state = List<RefillEvent>.unmodifiable(next);
        return true;
      },
      onFailure: (failure) {
        _onFailure(failure);
        return false;
      },
    );
  }

  List<RefillEvent> forMedication(String medicationId) => state
      .where((event) => event.medicationId == medicationId)
      .toList(growable: false);
}
