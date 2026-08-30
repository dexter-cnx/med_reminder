# Note, Checklist, and Generic Reminder Handoff

## Purpose

This handoff defines the approved product direction for adding **Notes**, **inline Checklists**, and **reminders for notes** to Besyu.

The intent is to expand the “Besyu — Beside You” product identity beyond medication without turning the application into a generic task manager. Notes should remain lightweight, local-first, and useful beside the user's existing medication, appointment, refill, timeline, and future companion workflows.

This document is a product/architecture handoff. It does not imply that the feature is implemented yet.

---

## 1. Product goals

The Notes feature should let the user capture information they want Besyu to keep beside them in daily life, for example:

- questions to ask a doctor
- things to bring to an appointment
- shopping or preparation lists
- medication-related notes
- personal reminders
- simple general-purpose notes

The feature should support both free-form text and checkable items without forcing the user to create a separate task entity for every checklist item.

Primary principle:

> A note is user-owned content. A checklist is a structured block inside a note. A reminder is a reusable capability that may target a note and, later, other feature-owned entities.

---

## 2. MVP scope

The first usable Notes release should include:

- create/edit/delete note
- text content
- inline checklist blocks
- pin/unpin
- archive/unarchive
- optional color/category metadata
- search by title and content
- local autosave
- undo after destructive actions where practical
- one optional reminder attached to a note
- notification tap opens the owning note
- local-first persistence

The MVP should **not** require:

- cloud synchronization
- collaboration
- shared notes
- rich-text document editing
- nested tasks/subtasks
- kanban/project-management behavior
- checklist-item reminders
- AI-generated content

---

## 3. Domain model

Do not store a checklist only as visual Unicode markers such as `☐` / `☑` inside one plain-text blob. That representation may be supported for import/export, but it should not be the source-of-truth domain model.

Recommended conceptual model:

```text
Note
├── id
├── title
├── blocks[]
├── category/color (optional)
├── pinned
├── archived
├── createdAt
├── updatedAt
└── reminderId (optional reference/read-model convenience only)

NoteBlock
├── TextBlock
└── ChecklistBlock
    └── ChecklistItem[]
        ├── id
        ├── text
        ├── completed
        └── position
```

A future implementation may use another serialization shape, but the following semantic guarantees should remain:

- note content is independently addressable from medication data
- checklist completion is structured state, not text parsing
- checklist items have stable IDs so reordering and future extensions remain possible
- archive is distinct from permanent deletion
- completion state survives editing/reordering

---

## 4. Feature boundary

Notes should be a sibling feature, not an extension of medication:

```text
lib/features/
├── medication/
├── appointment/
├── refill/
├── notes/
├── timeline/
└── ...
```

Recommended internal shape:

```text
lib/features/notes/
├── application/
├── data/
├── domain/
├── presentation/
└── notes_feature.dart
```

The Notes feature owns:

- note entities
- note blocks/checklist items
- note persistence
- note search/query behavior
- note editor state
- archive/pin semantics

It must not directly own platform notification scheduling.

---

## 5. Reminder architecture

### Current codebase context

The current application already has mature medication reminder infrastructure, including scheduling windows, reconciliation, trigger coordination, restore/rebuild behavior, platform notification delivery, and physical-validation handoffs.

Do **not** duplicate all of that inside `features/notes`.

At the same time, do not prematurely rewrite the existing medication reminder domain into a giant generic framework before Notes becomes a real second consumer.

Recommended evolution:

1. Implement Notes as an independent feature.
2. Identify the smallest shared notification/reminder contracts already proven by medication.
3. Extract domain-neutral scheduling/delivery abstractions only where Notes actually needs them.
4. Keep medication-specific reconciliation semantics in the medication feature.
5. Let Notes own note-reminder intent/state while shared infrastructure owns platform delivery.

Target conceptual model:

```text
Reminder
├── id
├── targetType
├── targetId
├── scheduledAt
├── recurrence (optional)
├── enabled
├── createdAt
└── updatedAt
```

Initial `targetType` may include:

```text
note
```

Future approved consumers may include:

```text
appointment
checklistItem
other feature-owned targets
```

Medication dose reminders may continue to use their specialized schedule/reconciliation model if that remains safer and clearer. A shared reminder abstraction must not erase medication-specific semantics such as dose identity, schedule windows, restore reconciliation, or reliability guarantees.

---

## 6. Note reminder behavior

MVP reminder options should include:

- no reminder
- selected date + time

Convenience presets may include:

- later today
- tomorrow
- custom date/time

Recurring reminders can be added after the one-shot flow is proven.

Notification behavior:

- title/body should be derived from user-owned note content with privacy-conscious defaults
- tapping the notification deep-links to the owning note
- deleting a note cancels its pending reminder
- archiving a note should not silently discard an active reminder; product behavior must be explicit
- editing reminder time reconciles the platform notification
- restore/import must rebuild pending note reminders using the same reliability principles already established for medication reminders

Future notification actions may include:

- Done
- Snooze
- Tomorrow

These actions are deferred until their state semantics are explicitly designed.

---

## 7. Checklist behavior

Checklist items live inside notes.

Expected UX:

```text
Prepare for tomorrow

☑ Bring documents
☐ Prepare medication
☐ Charge power bank
```

Baseline interactions:

- add checklist item
- mark complete/incomplete
- edit text
- delete item
- reorder items
- optionally show progress such as `2 / 5`

MVP reminder scope is **note-level only**.

Checklist-item reminders are intentionally deferred because they introduce additional scheduling, completion, notification-action, and reconciliation semantics.

---

## 8. Search, archive, autosave, and delete semantics

Useful ideas from lightweight local note applications should be retained:

### Search

Search should match at least:

- title
- text blocks
- checklist item text

### Archive

Archive should remove a note from the normal active list without destroying it.

### Autosave

The editor should save locally without requiring an explicit save button for every edit. Implementation should debounce writes rather than persist every keystroke immediately.

### Delete

Prefer reversible UX where practical:

- soft/recoverable delete or undo window
- permanent deletion remains explicit

Do not use archive as a hidden substitute for permanent deletion; users must retain control over deleting their own data.

---

## 9. Local-first and privacy requirements

Notes may contain health information or unrelated private personal information, so they should follow a strict local-first policy.

Requirements:

- notes work fully offline
- user can permanently delete notes
- backup/export must remain user-controlled
- note body/checklist text must not be included in analytics payloads by default
- analytics may record coarse events such as `note_created` or `notes_feature_opened` only if the observability policy permits them
- crash reporting must avoid attaching note content or notification payload text

If encrypted local storage is introduced for Notes, encryption must be implemented as a reusable storage/security concern rather than one-off UI logic.

---

## 10. Backup / restore implications

The existing backup/restore system should eventually include Notes as a feature-owned data contributor rather than extending medication-specific DTOs.

Backup should preserve:

- note IDs
- title/content blocks
- checklist item IDs and completion state
- ordering
- pin/archive state
- category/color metadata
- reminder intent/state where applicable

Restore should:

- restore note data first
- reconcile pending note reminders after data commit succeeds
- avoid scheduling notifications for missing/deleted targets
- preserve idempotency when restore is retried

This is another reason to keep platform reminder delivery separate from feature data ownership.

---

## 11. Timeline integration

Notes should not automatically flood the Daily Timeline.

Only time-relevant note projections should appear, for example:

- a note with a reminder scheduled today
- a future explicitly approved checklist-item reminder

Timeline remains a cross-feature read/composition surface and must not become the source of truth for note content.

Example:

```text
08:00  ✓ Medication
18:30  🩺 Doctor appointment
20:00  📝 Prepare documents for tomorrow
```

---

## 12. Feature registry / settings integration

The current branch contains the feature registry/settings-composition foundation. Notes should integrate through that mechanism instead of adding another hard-coded settings/navigation switch.

When Notes is implemented:

- define a `notes` feature registration
- keep feature enablement separate from note data
- project settings/navigation metadata through the feature registry
- disabling the feature must not silently delete note data
- reminders belonging to a disabled feature need an explicit policy; default should be to preserve user data and avoid surprising destructive behavior

---

## 13. Future extensions

After MVP is stable, candidates include:

### Nearer-term

- recurring note reminders
- checklist progress
- richer categories/tags
- Markdown/plain-text export
- image attachment
- link note to medication
- link note to appointment
- quick-note entry from Home

### Later

- reminder per checklist item
- voice note
- OCR/image-to-note
- natural-language reminder parsing
- local-AI summary
- local-AI conversion from text to checklist

Example future command:

> “เตือนซื้อยาพรุ่งนี้หกโมงเย็น”

may become structured data such as:

```text
Note: ซื้อยา
Reminder: tomorrow 18:00
```

Any AI implementation must still operate through bounded application services and require confirmation before material write actions where appropriate.

---

## 14. Explicit non-goals

Do not turn this feature into:

- a full project-management suite
- team collaboration
- shared workspaces
- issue tracking
- calendar replacement
- autonomous AI task execution

Besyu Notes should remain a calm, lightweight companion feature.

---

## 15. Recommended implementation sequence

### Phase N1 — Foundation

- `notes` feature boundary
- Note / NoteBlock / ChecklistItem domain model
- repository contract
- local persistence
- CRUD tests
- backup-data contract planning

### Phase N2 — Runtime UI

- notes list
- editor
- inline checklist
- pin/archive
- search
- autosave
- undo/delete behavior
- responsive/accessibility checks

### Phase N3 — Note reminder

- define note reminder intent model
- extract/reuse minimal domain-neutral notification delivery contracts
- schedule/cancel/reconcile one-shot note reminders
- notification deep link to note
- restore reconciliation tests
- physical-device validation

### Phase N4 — Composition

- feature registry integration
- settings/navigation projection
- Today/Timeline projection for notes with reminders
- backup/restore integration

### Later

- recurrence
- checklist-item reminders
- export/import
- attachments
- AI/OCR/voice extensions

---

## 16. Architecture decision summary

The approved direction is:

> **Notes are an independent Besyu feature. Checklists are structured content inside Notes. Reminder delivery should become reusable only at the point where Notes provides a real second consumer, while medication-specific scheduling and reconciliation semantics remain specialized.**

This keeps the current architecture aligned with the existing guardrail in `handoff/ARCHITECTURE_EVOLUTION.md`: generalize shared abstractions when a real second consumer exists rather than building speculative infrastructure.
