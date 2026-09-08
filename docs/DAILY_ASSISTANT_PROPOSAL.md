# Besyu Daily Assistant Proposal

Status: **Product direction / foundation proposal — not yet approved implementation scope**

## Why this belongs in Besyu

Besyu should not grow into a generic todo application. The useful product direction is broader and more coherent: help users remember important things in daily life without keeping everything in their head.

The interaction model should therefore unify medication, appointments, notes, checklists, expiring items, recurring maintenance, and future modules through shared reminder/scheduling capabilities while preserving each domain's own data model.

A useful product framing is:

> **Besyu — things in your life you shouldn't have to keep in your head.**

The main UX principle is that adding more features must not create isolated feature silos. New domains should be able to participate in a shared Today view, reminder engine, daily timeline, inbox, and quick-capture flow.

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

### 1.1 Unified Daily Timeline

`Today` should evolve beyond a flat summary into a unified daily timeline that can place heterogeneous items in chronological context without forcing them into one persistence model.

Examples of timeline participants:

- medication doses
- appointments
- scheduled tasks
- note reminders
- checklist deadlines
- recurring habits/routines if approved later
- expiring items that become relevant today
- user-created daily moments/attachments in a later phase

Conceptually:

```text
08:00  Medication dose
09:30  Task
10:00  Note reminder
14:30  Doctor appointment
18:00  Checklist due
All day  Passport expires in 7 days
```

The timeline is an aggregation projection. Medication remains medication, tasks remain tasks, notes remain notes, and so on.

This matters because Besyu should feel like one assistant with multiple capabilities, not several unrelated mini-apps sharing navigation.

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

### 2.1 Inbox for frictionless capture

Quick capture should not always require immediate classification.

When Besyu cannot confidently determine whether an entry is a task, note, reminder, checklist, appointment, or another domain item, it should be allowed to enter an `Inbox` state for later triage.

The purpose of Inbox is capture speed, not to create another permanent information silo.

Potential Inbox sources:

- typed quick capture
- voice capture
- share sheet / share-in from other apps
- pasted text or URLs
- imported snippets in future integrations

Inbox UX should support:

- quick review
- convert to a domain item
- attach date/time/reminder
- multi-select organization where useful
- delete/archive
- clear distinction between unprocessed items and committed domain records

The Inbox should remain lightweight and local-first.

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

### 3.1 Everything can be remindable

Reminder capability should not be artificially restricted to `Task`.

Where domain semantics allow it, Besyu should support reminders for:

- notes
- appointments
- checklists
- expirable items
- medication-related events through medication-specific scheduling rules
- future daily moments/attachments
- future habits/routines

This should be modeled through capabilities/contracts rather than by forcing every record into a Task inheritance hierarchy.

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

## 7. Carry-forward for unfinished items

Unfinished actionable items should not silently disappear because their original date has passed.

For eligible item types, Besyu should support a carry-forward rule that resurfaces incomplete items in Today until they are completed, rescheduled, dismissed, or intentionally archived.

Examples:

```text
Yesterday: Buy cat food — incomplete
Today: Carried forward
```

Carry-forward must be domain-aware:

- appropriate for tasks and some checklists
- optional/configurable for reminders
- not appropriate for already-missed medication doses unless medication-specific logic explicitly says so
- not appropriate for historical notes by default
- should never rewrite original timestamps/history

The projection should preserve provenance, for example `originalDueAt`, while Today shows that the item remains actionable.

## 8. Capability-based architecture

Besyu should avoid turning `Task` or `Medication` into a universal base model.

Prefer shared capabilities/services such as:

```text
Remindable
Schedulable
Repeatable
Completable
Expirable
CarryForwardEligible
```

while preserving domain-specific models.

Conceptually:

```text
Capture
  ↓
Inbox / Parsed Item
  ↓
Domain Item
  ├─ Medication
  ├─ Task
  ├─ Checklist
  ├─ Appointment
  ├─ Note
  ├─ Expirable
  ├─ Habit (future)
  └─ Future modules
        ↓
Shared capabilities
  Remindable
  Schedulable
  Repeatable
  Completable
  Expirable
  CarryForwardEligible
        ↓
Daily Timeline / Today Brief
        ↓
Widget / Live Activity / Future surfaces
```

`Life Items`/`Domain Item` above is a product/aggregation concept, not a requirement to persist all records in a single table/box.

## 9. Widgets / Live Activities should consume the same Today projection

Besyu already has native-companion direction. Future widget, lock-screen, ongoing-notification, and Live Activity surfaces should consume the same application-level Today/timeline projection where practical instead of independently rebuilding medication-only summaries.

This reduces duplicate business logic and keeps prioritization consistent across:

- main app Today
- home-screen widgets
- lock-screen surfaces
- iOS Live Activities / Dynamic Island where applicable
- Android ongoing notification surfaces
- future watch surfaces

Domain-specific surfaces may still exist when appropriate, but the shared Today projection should be the default aggregation source.

## 10. Future evidence-based completion

A later capability may allow Besyu to mark certain routines complete when a trusted local data source provides evidence.

Examples could include HealthKit / Health Connect-backed activity goals, but this is explicitly deferred until permissions, privacy, platform parity, and product value are separately approved.

Requirements if pursued later:

- opt-in only
- read-only where possible
- no silent medical inference
- clear source attribution for auto-completion
- reversible/manual override
- exact health data must not be sent to analytics by default

This concept must not be used to auto-confirm medication adherence without an explicit, reliable product design and safety review.

## 11. Future Daily Moments / attachments

A lightweight future extension may allow users to attach one or more contextual items to a day, such as a photo, short note, or voice memo.

This should not turn Besyu into a gallery or journaling app. The useful principle is that contextual content can participate in the daily timeline and reminder model when appropriate.

Possible examples:

- photo of a document to renew
- voice memo tied to a reminder
- one daily moment shown in Today/history
- attachment to an appointment/task/checklist

This remains future scope.

## 12. Privacy and local-first requirements

This direction must preserve Besyu's existing local-first principles.

- Natural-language capture should work locally for deterministic parsing.
- Optional AI interpretation should prefer on-device execution where practical.
- Reminder text should not be sent to analytics by default.
- Free-text notes should not be sent to analytics by default.
- Medical details, exact medication schedules, cycle data, and exact expiry dates must not be included in analytics payloads by default.
- Users must retain the ability to delete/export their own data according to the relevant feature policy.
- Inbox content should remain local unless the user explicitly chooses a sync/export path.
- Shared Today/timeline projections must not become a backdoor for broad sensitive-data analytics.

## 13. Workspace / sharing is explicitly deferred

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
6. Shared aggregation contract for Today / Daily Timeline.
7. Carry-forward eligibility semantics for actionable items.

### P1 — Product UX

8. Today / Daily Heads-up aggregation.
9. Unified Daily Timeline.
10. Universal Quick Add / Quick Capture.
11. Lightweight Inbox for unclassified captures.
12. Deterministic natural-language date/time parser.
13. Confirmation preview before persistence/scheduling.
14. Initial widget/native surfaces consuming the shared Today projection where practical.

### P2 — Optional intelligence

15. On-device intent parsing for complex text.
16. Suggested reminder offsets.
17. Suggested recurrence interpretation.
18. Daily Brief prioritization/ranking.
19. Smarter Inbox classification suggestions.

### Later

20. Share-in / richer capture channels.
21. Voice memo / Daily Moments attachments.
22. Health-backed evidence completion for approved non-medication routines.
23. Shared lists.
24. Workspace/collaboration.
25. Family/caregiver features.

## Highest-value first slice

If only three ideas are selected initially, prioritize:

1. **Today / Daily Timeline**
2. **Universal Quick Capture + lightweight Inbox**
3. **Multi-trigger + recurring Reminder Engine**

Together these change Besyu from a collection of reminder screens into a coherent daily assistant while remaining compatible with the existing medication-first foundation.

## Product quality gate

This direction should be judged by the 2026 product-development principle that implementation volume alone is not the bottleneck. The important test is whether a new user can understand Besyu's value quickly and whether the core loop is polished.

Before calling this direction complete:

- onboarding/first-use value should be understandable in roughly 30 seconds
- adding a common reminder should require minimal interaction
- capture should not force unnecessary classification before the user can save something
- reminder confirmation must be explicit and trustworthy
- non-happy paths around time zones, DST, invalid recurrence, past dates, and notification permission must be handled
- Today must degrade gracefully when one feature source is unavailable or empty
- carry-forward must never destroy historical due dates or medication history
- widget/native surfaces must remain consistent with app-level scheduling state
- performance must remain responsive with large local data sets
- features must not require cloud connectivity for their core behavior

## Decision status

This document records the product/architecture direction only. Individual milestones still require prioritization before implementation.
