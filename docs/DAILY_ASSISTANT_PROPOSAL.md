# Besyu Daily Assistant Proposal

Status: **Product direction / foundation proposal — not yet approved implementation scope**

## Why this belongs in Besyu

Besyu should not grow into a generic todo application. The useful product direction is broader and more coherent: help users remember important things in daily life without keeping everything in their head.

The interaction model should therefore unify medication, appointments, notes, checklists, expiring items, recurring maintenance, and future modules through shared reminder/scheduling capabilities while preserving each domain's own data model.

A useful product framing is:

> **Besyu — things in your life you shouldn't have to keep in your head.**

The main UX principle is that adding more features must not create isolated feature silos. New domains should be able to participate in a shared Today view, reminder engine, and quick-capture flow.

## Product pillars

### 1. Today / Daily Heads-up

Introduce a `Today` or `Daily Brief` aggregation surface that answers one question quickly: **what should I know or do today?**

Potential sources:

- medication doses
- appointments
- tasks
- note reminders
- checklist due items
- expiring documents/items
- recurring maintenance
- cycle reminders, if that feature is separately approved
- future Besyu modules

Illustrative content:

```text
Today

08:00  Metformin
After breakfast  Vitamin D
14:30  Doctor appointment
13 days left  Driver license expiry
Today  Buy cat food
Today  Change water filter
```

`Today` should be an aggregation/read model, not the source of truth for any domain.

Conceptually:

```text
Medication ─────┐
Appointments ───┤
Tasks ──────────┤
Notes ──────────┼──► Today
Documents ──────┤
Cycle ──────────┤
Future modules ─┘
```

This is the preferred way to keep Besyu understandable as feature count grows.

## 2. Universal Quick Capture — "Tell once"

Besyu should eventually support a single quick-entry surface where users can express intent naturally instead of navigating a long form.

Examples:

- "กินวิตามินดีทุกวันหลังอาหารเช้า"
- "เตือนต่อพาสปอร์ต 3 เดือนก่อนหมดอายุ"
- "ซื้อยาสีฟันพรุ่งนี้เย็น"
- "นัดหมอวันศุกร์ 10 โมง เตือนก่อน 1 วัน"
- "Remind me to change the water filter every 3 months"

The result must be converted into explicit structured data and shown to the user for confirmation before saving.

Example confirmation:

```text
Doctor appointment
Friday 10:00
Reminder: 1 day before

[Cancel]  [Save]
```

### Parsing architecture

Do not make an LLM mandatory for basic reminder creation.

Preferred pipeline:

```text
User text
   ↓
Deterministic parser
   ↓
Structured intent
   ↓
Optional on-device LLM for ambiguous/complex language
   ↓
Intent validator
   ↓
Confirmation preview
   ↓
Save through domain/application contracts
```

Simple date/time expressions should remain deterministic and fast. On-device AI such as Gemma may be evaluated later as an optional interpretation layer, not as the persistence or scheduling source of truth.

Any parser output must be validated before mutating domain data.

## 3. Unified multi-trigger reminder model

Avoid designing future domains around a single nullable field such as:

```dart
DateTime? reminderAt;
```

The reminder model should support multiple independent triggers for one item, for example:

```dart
List<ReminderTrigger> reminders;
```

Example:

```text
Passport renewal
Friday 10:00

3 days before
1 day before
1 hour before
At time
```

Or:

```text
Passport expires
1 Dec 2026

90 days before
30 days before
7 days before
On expiry date
```

This shared capability is useful for medication, appointments, tasks, notes, expirable items, and future modules.

Reminder scheduling must remain a dedicated application/domain service rather than presentation-layer logic.

## 4. Recurrence rules

Recurring reminders should be represented as rules rather than a small set of UI booleans.

Minimum future rule set:

- every day
- every N days
- every week
- selected weekdays
- every month
- every N months
- every year

The model must distinguish two recurrence semantics:

### Fixed schedule

```text
Jan 1 → Apr 1 → Jul 1
```

Suitable for calendar-defined schedules.

### Relative to completion

```text
Due Jan 1
Completed Jan 10
Next due Apr 10
```

Suitable for maintenance, replacement cycles, refills, and routines where the next due date depends on when the previous occurrence was actually completed.

These two modes must not be conflated.

## 5. Checklist as structured data

Checklist notes should not be persisted only as markdown/free-text markers. Checklist items should be first-class structured records so Besyu can support progress, completion timestamps, ordering, and future item-level behavior.

Illustrative model:

```dart
class Checklist {
  String id;
  String title;
  List<ChecklistItem> items;
  List<ReminderTrigger> reminders;
}

class ChecklistItem {
  String id;
  String text;
  bool completed;
  DateTime? completedAt;
  int order;
}
```

Potential use cases:

- travel packing
- hospital preparation
- medications to bring
- shopping
- before-leaving-home checklist
- recurring household routines

Possible later enhancement: reusable checklist templates. This is not required for the initial checklist milestone.

## 6. Expiry tracking

Introduce an `Expirable` capability/domain concept for things users should know about before they become a problem.

Potential examples:

- medication expiration
- national ID
- driver license
- passport
- insurance
- vehicle registration / compulsory insurance
- certificates
- contracts
- other user-defined items

Illustrative fields:

```text
id
title
expiryDate
reminderRules
category
note?
attachment?
```

Do not force all expirable objects into a generic Task entity. Domains may own their own records while participating through shared capabilities.

## 7. Capability-based architecture

Besyu should avoid turning `Task` or `Medication` into a universal base model.

Prefer shared capabilities/services such as:

```text
Remindable
Schedulable
Repeatable
Completable
Expirable
```

while preserving domain-specific models.

Conceptually:

```text
                    Besyu
                      │
             ┌────────┴────────┐
             │   Life Items    │
             └────────┬────────┘
                      │
       ┌──────────────┼───────────────┐
       │              │               │
     Task           Note          Medication
       │              │               │
   Checklist      Reminder           Dose
       │
 Appointment
       │
  Expirable
       │
  Future modules

             ↓

        Reminder Engine
             ↓
     Notification Scheduler

             ↓

          Today Feed
```

`Life Items` above is a product/aggregation concept, not a requirement to persist all records in a single table/box.

## 8. Privacy and local-first requirements

This direction must preserve Besyu's existing local-first principles.

- Natural-language capture should work locally for deterministic parsing.
- Optional AI interpretation should prefer on-device execution where practical.
- Reminder text should not be sent to analytics by default.
- Free-text notes should not be sent to analytics by default.
- Medical details, exact medication schedules, cycle data, and exact expiry dates must not be included in analytics payloads by default.
- Users must retain the ability to delete/export their own data according to the relevant feature policy.

## 9. Workspace / sharing is explicitly deferred

Shared workspaces, shared lists, household collaboration, caregiver access, and family accounts should **not** be added to the current scope.

They introduce additional requirements for:

- accounts
- synchronization
- invitations
- roles/permissions
- conflict resolution
- shared notification semantics
- backend ownership
- sensitive-data privacy boundaries

Architecture may avoid blocking these use cases, but implementation belongs to a later caregiver/family/collaboration milestone.

## Proposed roadmap order

### P0 — Foundation

1. Unified reminder rule model.
2. Multiple reminder offsets/triggers.
3. Recurrence rule model with fixed-vs-after-completion semantics.
4. Structured checklist model.
5. Expiry capability/model boundary.

### P1 — Product UX

6. Today / Daily Heads-up aggregation.
7. Universal Quick Add / Quick Capture.
8. Deterministic natural-language date/time parser.
9. Confirmation preview before persistence/scheduling.

### P2 — Optional intelligence

10. On-device intent parsing for complex text.
11. Suggested reminder offsets.
12. Suggested recurrence interpretation.
13. Daily Brief prioritization/ranking.

### Later

14. Shared lists.
15. Workspace/collaboration.
16. Family/caregiver features.

## Highest-value first slice

If only three ideas are selected initially, prioritize:

1. **Today / Daily Heads-up**
2. **Universal Quick Capture**
3. **Multi-trigger + recurring Reminder Engine**

Together these change Besyu from a collection of reminder screens into a coherent daily assistant while remaining compatible with the existing medication-first foundation.

## Product quality gate

This direction should be judged by the 2026 product-development principle that implementation volume alone is not the bottleneck. The important test is whether a new user can understand Besyu's value quickly and whether the core loop is polished.

Before calling this direction complete:

- onboarding/first-use value should be understandable in roughly 30 seconds
- adding a common reminder should require minimal interaction
- reminder confirmation must be explicit and trustworthy
- non-happy paths around time zones, DST, invalid recurrence, past dates, and notification permission must be handled
- Today must degrade gracefully when one feature source is unavailable or empty
- performance must remain responsive with large local data sets
- features must not require cloud connectivity for their core behavior

## Decision status

This document records the product/architecture direction only. Individual milestones still require prioritization before implementation.
