import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../../medication/presentation/viewmodels/medication_view_model.dart';
import '../../../refill/presentation/providers/refill_providers.dart';
import '../../application/build_emergency_medical_card.dart';
import '../../domain/entities/emergency_profile.dart';
import '../../domain/repositories/emergency_profile_repository.dart';

final emergencyProfileRepositoryProvider = Provider<EmergencyProfileRepository>(
  (ref) => throw UnimplementedError(
    'EmergencyProfileRepository must be provided by app DI.',
  ),
);

final emergencyProfileFailureProvider = StateProvider<Failure?>((ref) => null);

final emergencyProfileProvider =
    StateNotifierProvider<EmergencyProfileViewModel, EmergencyProfile?>(
      (ref) => EmergencyProfileViewModel(
        ref.watch(emergencyProfileRepositoryProvider),
        onFailure: (failure) {
          Future<void>.microtask(() {
            ref.read(emergencyProfileFailureProvider.notifier).state = failure;
          });
        },
      ),
    );

final emergencyMedicalCardProvider = Provider.autoDispose<EmergencyMedicalCard>(
  (ref) {
    const builder = BuildEmergencyMedicalCard();
    return builder(
      now: DateTime.now(),
      profile: ref.watch(emergencyProfileProvider),
      medications: ref.watch(medsProvider),
      doseLogs: ref.watch(logsProvider),
      refillEvents: ref.watch(refillEventsProvider),
    );
  },
);

class EmergencyProfileViewModel extends StateNotifier<EmergencyProfile?> {
  EmergencyProfileViewModel(
    EmergencyProfileRepository repository, {
    required void Function(Failure failure) onFailure,
  }) : _repository = repository,
       _onFailure = onFailure,
       super(_load(repository, onFailure));

  final EmergencyProfileRepository _repository;
  final void Function(Failure failure) _onFailure;

  static EmergencyProfile? _load(
    EmergencyProfileRepository repository,
    void Function(Failure failure) onFailure,
  ) => repository.read().fold(
    onSuccess: (profile) => profile,
    onFailure: (failure) {
      onFailure(failure);
      return null;
    },
  );

  Future<bool> save(EmergencyProfile profile) async {
    final normalized = profile.normalized();
    final result = await _repository.save(normalized);
    return result.fold(
      onSuccess: (_) {
        state = normalized;
        return true;
      },
      onFailure: (failure) {
        _onFailure(failure);
        return false;
      },
    );
  }

  Future<bool> clear() async {
    final result = await _repository.clear();
    return result.fold(
      onSuccess: (_) {
        state = null;
        return true;
      },
      onFailure: (failure) {
        _onFailure(failure);
        return false;
      },
    );
  }
}
