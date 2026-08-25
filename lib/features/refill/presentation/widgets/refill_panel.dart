import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../medication/domain/entities/medication.dart';
import '../../../medication/presentation/viewmodels/medication_view_model.dart';
import '../../domain/entities/refill_event.dart';
import '../providers/refill_providers.dart';

class RefillPanel extends ConsumerStatefulWidget {
  const RefillPanel({required this.medication, super.key});

  final Medication medication;

  @override
  ConsumerState<RefillPanel> createState() => _RefillPanelState();
}

class _RefillPanelState extends ConsumerState<RefillPanel> {
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events =
        ref
            .watch(refillEventsProvider)
            .where((event) => event.medicationId == widget.medication.id)
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final logs = ref.watch(logsProvider);
    final stockResolver = ref.watch(medicationStockResolverProvider);
    final remaining = stockResolver(widget.medication, logs);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'refill_title'.tr(namedArgs: {'name': widget.medication.name}),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'remaining'.tr(
                  namedArgs: {'count': remaining?.toString() ?? '-'},
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'refill_quantity'.tr(),
                  prefixIcon: const Icon(Icons.add_box_outlined),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'refill_note'.tr(),
                  prefixIcon: const Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text('refill_save'.tr()),
              ),
              const SizedBox(height: 24),
              Text(
                'refill_history'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('refill_history_empty'.tr()),
                )
              else
                ...events.map(
                  (event) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(
                      'refill_history_quantity'.tr(
                        namedArgs: {'count': event.quantity.toString()},
                      ),
                    ),
                    subtitle: Text(_historySubtitle(event)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('refill_quantity_invalid'.tr())));
      return;
    }

    setState(() => _saving = true);
    final note = _noteController.text.trim();
    final event = RefillEvent(
      id: const Uuid().v4(),
      medicationId: widget.medication.id,
      quantity: quantity,
      createdAt: DateTime.now(),
      note: note.isEmpty ? null : note,
    );

    // Capture app-scoped collaborators before awaiting. They remain valid even
    // if the modal sheet is dismissed while persistence is in flight.
    final container = ProviderScope.containerOf(context, listen: false);
    final refillViewModel = ref.read(refillEventsProvider.notifier);
    final medicationViewModel = ref.read(medsProvider.notifier);
    final logs = ref.read(logsProvider);

    final saved = await refillViewModel.append(event);
    if (!saved) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('refill_save_failed'.tr())));
      return;
    }

    container.invalidate(todayDosesProvider);
    await medicationViewModel.refreshAfterRefill(widget.medication.id, logs);
    if (!mounted) return;

    _quantityController.clear();
    _noteController.clear();
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('refill_saved'.tr())));
  }

  String _historySubtitle(RefillEvent event) {
    final date = event.createdAt;
    final timestamp =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    final note = event.note;
    return note == null || note.isEmpty ? timestamp : '$timestamp · $note';
  }
}
