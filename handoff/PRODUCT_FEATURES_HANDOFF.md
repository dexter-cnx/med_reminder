# Besyu Product Features Handoff

## Purpose

This handoff captures the agreed product direction for **Besyu** beyond the current medication-reminder baseline.

Product identity:

> **Besyu — Beside You.**
> 
> *อยู่ข้างกาย ในทุกวัน*

The product should evolve as a **personal medication companion**, not only a reminder app. The core experience should connect medication schedules, dose history, stock/refill awareness, doctor appointments, emergency information, and eventually a bounded AI assistant.

The current roadmap remains medication/health focused. However, the **Besyu / Beside You** identity is intentionally broader than medication, so architecture and shared product surfaces should not prevent future non-medical companion features from being added beside the medical features.

This does **not** commit Besyu to becoming a generic productivity/lifestyle app. Any future non-medical feature requires a separate product decision and must fit the “beside you in daily life” identity without weakening the primary medication experience.

This document is a product/architecture handoff only. Features listed here are **not implied to be implemented yet** unless another status document explicitly marks them complete.

---

## 1. Medication adherence history

Track dose outcomes as first-class history rather than only the current reminder state.

Required states should include at least:

- Taken
- Skipped
- Snoozed
- Missed / not completed when the scheduled window has passed

Product expectations:

- Show recent adherence history.
- Support useful windows such as 7 days and 30 days.
- Keep the presentation understandable; avoid turning the app into a clinical analytics dashboard.
- Allow future summaries such as adherence percentage, missed-dose count, and recurring patterns.
- Preserve the existing semantic dose identity (`medId + scheduledAt`) so multiple doses on the same day remain independent.

The history must remain factual. Besyu may summarize what the user recorded but must not infer medical compliance recommendations from the data.

---

## 2. Low-stock and refill workflow

Medication inventory should become an actionable refill workflow.

Baseline behavior:

- A successful `Taken` action consumes stock.
- Skipped and snoozed states do not consume stock.
- Remaining amount should continue to be derived from medication configuration and persisted dose history rather than maintained as a second mutable counter.
- Allow a configurable low-stock threshold.
- Notify when stock falls below the threshold.
- Estimate remaining days when the schedule permits a deterministic estimate.

Example:

> 6 tablets remaining — approximately 3 days left.

Future-compatible workflow:

- Refill reminder.
- Mark medication as refilled.
- Record refill quantity/date.
- Preserve historical refill events separately from dose logs.

The app must not infer that a prescription is medically appropriate to renew; it only reminds the user about inventory/refill logistics.

---

## 3. Medication course types

The domain must support medication usage patterns beyond indefinite daily medication.

Planned categories:

1. **Scheduled / ongoing**
   - Repeating medication with a stable schedule.

2. **Finite course**
   - Example: antibiotic for 7 days.
   - Existing finite-day scheduling behavior should remain the foundation.

3. **Taper / staged course**
   - A future course may have different dose/schedule stages over time.
   - Example: a medication whose quantity or frequency changes over multiple phases.
   - Do not implement this by mutating historical schedule meaning; model stages explicitly when this feature is implemented.

4. **PRN / as-needed**
   - Medication taken only when required rather than from a fixed recurring reminder.

Keep these concepts explicit in the domain rather than overloading one schedule enum until its meaning becomes ambiguous.

---

## 4. PRN / as-needed medication

Add support for medication that is not part of a fixed recurring schedule.

User flow should allow:

- Record that a PRN medication was taken.
- Record the timestamp.
- Optionally record a short reason/symptom note such as headache or pain.
- Show PRN usage history.
- Include PRN usage in doctor-visit summaries.

When medication metadata contains a user-entered minimum interval, Besyu may warn that a newly recorded dose is within that configured interval.

Safety boundary:

- Besyu must not invent dosage intervals or maximum doses.
- Any interval/dose constraint must come from trusted medication data, a prescription/label, or explicit user entry.
- A warning should be informational and must not replace pharmacist/doctor instructions.

---

## 5. Daily Timeline as the primary home concept

The preferred long-term Home experience is a **Today / Daily Timeline**, not a medication list alone.

The timeline may combine:

- Scheduled doses
- Taken/skipped/snoozed state
- PRN records when relevant
- Doctor appointments
- Refill/low-stock reminders
- Medication course milestones
- Other user-owned health logistics that fit the Besyu scope

Example:

```text
07:00  ✓ Amlodipine
08:00  ✓ Metformin
13:00  ○ Vitamin D
18:30  🩺 Doctor appointment
21:00  ○ Metformin
```

Product goal:

> Opening Besyu should answer: **“What do I need to take care of today?”**

The timeline should remain operational and calm rather than becoming a generic health feed.

Architecturally, Timeline is allowed to become a cross-feature composition surface in the future. If Besyu later gains an approved non-medical companion feature, that feature may project appropriate items into Timeline without making Timeline own or duplicate the feature's source data.

---

## 6. Medication check-in / side-effect notes

Support lightweight check-ins after a new medication/course begins.

Potential check-in schedule can be configurable and may use simple defaults such as day 1, day 3, and day 7 when appropriate to the product flow.

A check-in may ask whether the user noticed anything unusual and allow entries such as:

- No issue
- Dizziness
- Nausea
- Rash
- Other / free text

Important constraints:

- These are **user-reported notes**, not diagnoses.
- Besyu must not determine causality (for example, it must not state that a medication caused a symptom).
- Besyu must not recommend discontinuing, substituting, or changing dosage based on these notes.
- Recorded check-ins should be available in the Doctor Visit Summary.

For potentially urgent symptoms, the product may provide a clear route to existing emergency/SOS mechanisms, but the safety behavior must be designed separately and conservatively.

---

## 7. Doctor Visit Summary

Add a dedicated view that prepares the user's medication information for a medical appointment.

The summary should be optimized for quick review and may include:

- Current medications
- Dose and schedule
- Course start/date information
- 7-day / 30-day adherence summary
- Missed or skipped dose history
- PRN medication usage
- User-reported medication check-ins / side-effect notes
- Low-stock/refill status
- Upcoming or current appointment information
- Questions/notes the user saved to ask the clinician

Future export/share:

- Printable/shareable PDF
- User-controlled sharing only
- Clear generation timestamp
- Clear distinction between user-entered data and app-derived summaries

The summary is a record/communication aid, not a clinical report or diagnosis.

---

## 8. Emergency Medical Card

Extend the safety concept beyond the SOS action itself with an optional Emergency Medical Card.

Potential user-controlled fields:

- Display name
- Emergency contact
- Current medications
- Medication allergies
- Important medical notes/conditions entered by the user
- Other emergency-relevant notes

Integration with SOS:

- SOS remains a fast action entry point.
- Depending on platform capability and user configuration, SOS may expose phone, SMS, LINE, or other supported contact actions.
- The Emergency Medical Card should be reachable from the safety flow without requiring the user to search through normal medication screens.

Future QR concept:

- Allow the user to expose a deliberately limited emergency subset through a QR code.
- Never encode the entire private local database by default.
- The user must control which fields are shared.
- The QR design must be evaluated for privacy, revocation, stale data, screenshots/copies, and offline behavior before implementation.

---

## 9. Besyu Assistant + MCP/tool layer

AI should be an assistant layer over Besyu's structured data, not the primary UI and not a medical decision engine.

Preferred architecture:

- Keep medication, appointment, stock, adherence, and safety data behind explicit application/domain services.
- Expose bounded tools through an MCP/tool abstraction.
- Keep the AI model independent from storage implementation.
- Require explicit permission/confirmation for write operations that materially change user data.
- Prefer deterministic app logic for calculations and safety rules; the model should call tools rather than reproduce domain logic from prompt context.

Candidate read capabilities:

- “What medication do I need to take today?”
- “Which medications are running low?”
- “How many doses did I miss this month?”
- “When is my next doctor appointment?”
- “What medication did I just record as taken?”
- “Summarize my last 30 days for my doctor.”

Candidate bounded write capabilities for later evaluation:

- Record a user-confirmed dose action.
- Add a user-confirmed note/question for the next doctor appointment.
- Create a user-confirmed refill reminder.

Safety boundary:

Besyu Assistant may retrieve, organize, summarize, and help the user operate their own records. It must not independently:

- Diagnose a disease.
- Tell the user to stop a prescribed medication.
- Substitute one medication for another.
- Change a dose or course.
- Invent contraindications, dosage limits, or interaction rules from model reasoning alone.

Medication facts shown through AI should come from a defined trusted-data layer whenever possible, with provenance retained by the application rather than relying solely on model memory.

The Assistant/tool architecture should remain capable of adding future non-medical tools without weakening these medical safety boundaries. A non-medical tool must still operate through its owning feature's application service rather than directly through storage or Flutter presentation state.

---

## 10. Explicitly deferred: Caregiver / Family mode

**Caregiver / Family mode is NOT part of the near-term roadmap.**

Keep it as a future product possibility only.

Possible future scope:

- Multiple person profiles
- Parent/child/partner medication management
- Caregiver overview
- Cross-device/cloud synchronization
- Permission and consent model
- Remote adherence notifications

Reason for deferral:

This substantially increases complexity around identity, authorization, privacy, data ownership, notifications, synchronization, and medical-context mistakes. The current Besyu product should first become excellent for a single primary user's medication workflow.

Do not introduce multi-profile assumptions into current UI unless required for future-safe domain modeling.

---

## 11. Features intentionally outside the near-term scope

Do not expand Besyu into these areas without a separate product/regulatory decision:

- Social/community feed
- Pharmacy marketplace
- Telemedicine platform
- AI diagnosis
- AI-generated medication recommendation/substitution
- Autonomous dose changes
- Broad cloud sync platform

Also do not pre-build generic productivity domains such as tasks, routines, personal notes, household workflows, or similar companion features merely because the architecture can support them. They remain **future possibilities, not current roadmap commitments**.

These may dramatically increase privacy, operational, and regulatory scope or dilute the current product identity if introduced without a clear product rationale.

---

## 12. Recommended roadmap

### MVP / foundation

- Medication scan/import flow
- Medication records
- Inventory
- Local reminders
- Taken / Snooze / Skip
- Low-stock + refill warning
- Doctor appointments
- SOS
- Daily Timeline foundation

### v1.1

- Medication adherence history
- Finite/structured medication courses
- PRN/as-needed medication
- Medication check-ins / side-effect notes
- Doctor Visit Summary

### v1.2

- Emergency Medical Card
- Refill event/history improvements
- Doctor-summary export/share
- Timeline refinement across medication, refill, and appointment events

### v1.3

- Besyu Assistant
- MCP/tool abstraction
- Read-oriented personal medication queries
- Bounded, confirmation-based assistant write actions

### Future / not committed

- Caregiver / Family mode
- Multi-profile support
- Cloud synchronization required by multi-person workflows
- Non-medical companion features that fit the Besyu identity, subject to a separate product decision

---

## 13. Architecture implications

These product additions should preserve the existing Clean Architecture + MVVM + Riverpod direction.

Likely future domain concepts include:

```text
Medication
MedicationCourse / MedicationCourseStage
DoseLog
PrnDoseLog
RefillEvent
MedicationCheckIn
DoctorAppointment
DoctorVisitQuestion
EmergencyProfile
TimelineItem (presentation/read-model concept)
```

Guidelines:

- Treat medication as a bounded feature/domain rather than the application-wide root model.
- Do not make `Medication` a giant mutable object containing every future feature.
- Prefer separate aggregates/events where lifecycle and history differ.
- Keep derived values (remaining stock, adherence summaries, estimated days left) deterministic and testable.
- Keep persistence abstract behind repository/data-source contracts.
- New features should own their data/repositories rather than adding fields into a global Besyu or Medication record.
- Home, Timeline, Search, and Assistant may compose cross-feature read models but must not become the source of truth.
- Keep shared infrastructure such as storage, notification delivery, time, permissions, calendar access, observability, and results domain-neutral where practical.
- Keep notification scheduling behind ports/adapters.
- Keep AI/MCP above the domain/application services rather than directly exposing Hive or another storage engine.
- Preserve offline-first behavior as the baseline unless a future feature explicitly requires network/cloud capability.
- Generalize shared abstractions only when a real second consumer exists; avoid speculative architecture for hypothetical features.

See `handoff/ARCHITECTURE_EVOLUTION.md` for the concrete feature/core/composition guardrails.

---

## 14. Product principle

The current working product principle is:

> **Besyu should help the user remember, understand, record, and communicate their medication routine — while staying clearly on the user-assistance side of the boundary rather than making medical decisions.**

The combination of **Daily Timeline + refill awareness + Doctor Visit Summary + Emergency Medical Card** should become a central differentiator from a generic medication reminder.

Longer-term identity principle:

> **Besyu means “Beside You.” Medication is the current primary domain, but future features may support other parts of daily life when they clearly belong beside the user, integrate cleanly through independent feature boundaries, and do not compromise the medication experience.**
