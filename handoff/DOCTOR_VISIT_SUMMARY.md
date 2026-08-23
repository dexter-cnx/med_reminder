# Doctor Visit Summary

## Status

This slice adds the first user-visible Doctor Visit Summary as a derived read model.

The summary does **not** own or persist a second copy of medication, dose, refill,
appointment, or medication check-in data.

## Source data

The summary is composed from the existing feature states:

- Medication
- DoseLog
- RefillEvent
- MedicationCheckIn
- DoctorAppointment

`BuildDoctorVisitSummary` is a pure application query that receives those source
records and produces a `DoctorVisitSummary` snapshot.

## Default period

Recent medication facts use a rolling 30-day window ending at generation time.
The window currently applies to:

- taken dose count
- skipped dose count
- refill quantity
- medication check-ins

Upcoming appointments are future appointments at or after generation time and
are not restricted to the 30-day history window.

## Safety semantics

The first summary intentionally contains factual records only.

It may show:

- medication name and generic/medical name
- taken and skipped counts
- refill quantity
- user-reported medication observations
- upcoming appointments

It must not infer:

- adherence quality or an adherence score
- diagnosis
- medication causality for a reported observation
- whether medication should be stopped, substituted, or dose-adjusted
- urgency classification from a reported observation

The UI explicitly states that check-ins are factual user-entered observations
and that Besyu does not determine causality.

## Ownership

Doctor Visit Summary is a composition/read-model feature. Source features remain
the source of truth.

Do not add a `doctor_visit_summary` Hive box merely to cache the current
snapshot. If export/share is added later, generate the export from a fresh
summary query.

## UI

The summary is reachable from the Appointments tab through a dedicated
"Doctor visit summary" action. It remains reachable even when no appointment is
currently saved.

The first screen is responsive using the existing `ResponsiveLayoutInfo`
policy and shows a maximum of five recent check-ins per medication and three
upcoming appointments for readability. The underlying read model retains all
matching records.

## Follow-up

Recommended next slices:

1. Add explicit date-range selection (for example 7 / 30 / 90 days) without
   changing source ownership.
2. Add share/export adapters (plain text / PDF) generated on demand.
3. Add medication stock/current quantity if useful, using the existing
   event-derived inventory boundary rather than legacy arithmetic.
4. Add appointment-specific summary launch/context only if it remains a read
   concern and does not duplicate appointment data.
5. Reuse this query boundary from the future Assistant/MCP application facade.
