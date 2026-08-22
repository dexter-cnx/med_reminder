# Cycle Tracking / Period Log — Product Proposal

## Status

**Awaiting product decision — not approved for implementation.**

This document captures a possible future Besyu feature for menstrual-cycle tracking. It is intentionally separated from the medication domain and must not be treated as committed roadmap scope until a later product decision explicitly promotes it.

---

## 1. Product rationale

Besyu is evolving from a medication reminder toward a broader **“Beside You”** personal companion while keeping medication as its current primary domain.

A lightweight **Cycle Tracking / Period Log** feature can fit that identity because it is recurring, personal, calendar-oriented daily-life information that may coexist naturally with medication, appointments, reminders, and the Daily Timeline.

The feature should begin as a **recording and estimation tool**, not as a fertility or medical-decision product.

---

## 2. Proposed first scope

The first version should focus on simple user-owned records:

- Record period start date.
- Record period end date.
- Record flow level when the user chooses to do so.
- Record optional symptoms, for example:
  - cramps / abdominal pain
  - headache
  - mood changes
  - acne
  - other user-entered symptom/note
- Record optional daily notes.
- Show cycle history in a simple calendar/history view.
- Estimate the next cycle from the user's historical records.
- Optionally notify the user before the estimated next period.

The estimation must be presented as an **estimate**, not a guaranteed date or medical conclusion.

---

## 3. Explicitly excluded from the initial scope

Do **not** automatically expand the first version into:

- fertility prediction
- ovulation prediction
- fertile-window prediction
- pregnancy prediction
- contraception advice
- diagnosis of irregular menstruation
- diagnosis or inference from symptom patterns
- medical recommendations based on cycle history

These capabilities materially increase medical, safety, privacy, and product-claim risk and require a separate product/regulatory decision.

---

## 4. Architecture boundary

Cycle tracking should be implemented as its own bounded feature, not as fields added to `Medication`, a medication profile, or a global user record.

Preferred conceptual structure:

```text
features/
  medication/
  reminders/
  appointments/
  cycle_tracking/
  emergency/
  ...

core/
  calendar/
  notifications/
  analytics/
  storage/
```

Likely domain concepts may include:

```text
CycleRecord
CycleDayLog
CycleSymptom
CycleEstimate
```

Exact naming is intentionally deferred until implementation design.

Architecture rules:

- `cycle_tracking` owns its domain entities, repository contracts, persistence mapping, and application services.
- Do not put period dates, cycle length, symptoms, or flow values into `Medication`.
- Shared calendar/timeline surfaces may read cycle data through the feature's public application/read-model boundary.
- The Timeline must not become the source of truth for cycle data.
- Notification scheduling should use the same domain-neutral notification port/adapter direction as other features.
- Storage implementation must remain behind repository/data-source abstractions.
- Keep the feature compatible with Besyu's offline-first baseline.

---

## 5. Daily Timeline and calendar integration

If approved later, cycle tracking may project selected information into the shared Besyu calendar or Daily Timeline.

Examples:

- recorded period start/end
- an upcoming estimated period
- an optional pre-period reminder

Important constraint:

The shared Timeline/calendar is a **composition/read surface**. It may display cycle-related items but must not own or duplicate cycle state.

Users should also be able to disable cycle-related projections/reminders without affecting the underlying history records.

---

## 6. Privacy and data handling

Menstrual-cycle records are **sensitive health data**. Privacy constraints are part of the feature's baseline product policy and must be designed before implementation rather than added afterward.

### Baseline privacy policy

- **Local-first:** cycle records remain on-device by default.
- **Opt-in:** the feature must not silently create or infer cycle records for users who have not enabled or used it.
- **Full deletion:** the user must be able to delete individual records and erase **all cycle-tracking data** owned by Besyu.
- **Exportable:** the user must be able to export their cycle data in a user-controlled manner. Export must never require uploading the data to a Besyu server.
- **No detailed cycle analytics by default:** analytics must not transmit reproductive-health details such as dates, cycle length, symptoms, flow, or notes.

Additional rules:

- Future cloud sync requires a separate privacy/security decision and must not be implied by the initial implementation.
- Do not expose detailed cycle data to unrelated features by default.
- Backup/export behavior must be explicit, user-initiated, and clearly identify when sensitive cycle data is included.
- AI/MCP access, if ever introduced, must use explicit bounded tools and permission-aware behavior rather than direct storage access.

If an application lock or protected local-storage capability is introduced in Besyu later, cycle records should be considered a high-priority candidate for that protection.

---

## 7. Analytics boundary

Analytics may measure **feature usage**, but must not measure or transmit the user's actual reproductive-health timeline by default.

Acceptable examples:

```text
cycle_feature_opened
cycle_record_flow_started
cycle_record_saved
cycle_reminder_enabled
```

For example, analytics may know that `cycle_feature_opened` occurred, but must **not** know information such as:

- “the user's period started on 2026-08-21”
- “the user's cycle length is 29 days”
- exact period start/end dates
- exact cycle length
- flow level
- symptom selections or symptom text
- free-text notes
- inferred fertility/ovulation information

Analytics event properties must not contain these values indirectly either, including timestamps or derived metrics that could reconstruct the reproductive-health timeline.

Event schemas should be reviewed against the observability/privacy policy before implementation.

---

## 8. Notification behavior

Potential notifications may include:

- estimated next-period reminder
- optional reminder a configurable number of days beforehand

Rules:

- Notifications are opt-in/configurable.
- Wording must state that the date is estimated where appropriate.
- Notifications must not imply diagnosis, pregnancy/fertility status, or medical certainty.
- The feature should reuse the app's domain-neutral notification scheduling abstraction rather than schedule directly from presentation code.

---

## 9. Future platform-health integration

A later version may evaluate integration with platform health stores such as:

- Apple Health / HealthKit
- Android Health Connect

This is **not part of the initial proposal**.

Before adding it, define:

- read vs write behavior
- permissions and revocation behavior
- conflict/source-of-truth policy
- data provenance
- duplicate handling
- privacy disclosure
- behavior when platform-health permissions are removed

Besyu's local domain model should remain usable without granting platform-health access.

---

## 10. AI / MCP boundary

If Besyu Assistant later gains access to cycle records, access must be explicit and bounded.

Potential safe read-oriented capabilities could include user-owned record retrieval such as:

- “When did I record my last period?”
- “Show my recorded cycle history.”
- “When does Besyu estimate the next period from my saved history?”

The assistant must not independently infer or claim:

- pregnancy
- ovulation
- fertility status
- disease/diagnosis
- contraception effectiveness
- medical treatment recommendations

The model should retrieve deterministic app-owned estimates through tools instead of recalculating reproductive-health conclusions from raw context.

---

## 11. Suggested acceptance criteria if approved

Before implementation can be considered complete:

- Cycle data is stored independently from medication models.
- User can create/edit/delete cycle records.
- User can erase all cycle-tracking data.
- User can export cycle data through an explicit user-controlled flow without requiring Besyu cloud storage.
- Estimated next period is clearly labeled as an estimate.
- Estimation logic is deterministic and unit-tested.
- Timeline/calendar integration does not duplicate source-of-truth state.
- Notification scheduling is opt-in and rebuildable from domain state.
- Analytics contain no exact cycle dates, cycle length, symptom values, flow values, or notes.
- Analytics contain no derived event properties capable of reconstructing the user's cycle timeline.
- Feature remains functional offline.
- Medication and reminder behavior is unchanged when cycle tracking is disabled or unused.

---

## 12. Product decision required

Before moving this feature from proposal to roadmap, decide at least:

1. Whether Cycle Tracking belongs in Besyu's near/mid-term product identity.
2. Whether the first release is strictly **Period Log + Cycle Estimate**.
3. Whether symptoms and flow levels belong in v1 or should be deferred.
4. Whether cycle items appear in the Daily Timeline by default or only when enabled.
5. Whether notifications are part of the first release.
6. Which export formats are provided and whether general Besyu backup requires explicit confirmation before including cycle data.
7. Whether platform HealthKit / Health Connect integration is worth pursuing later.
8. Whether any fertility/ovulation functionality should remain permanently out of scope or be evaluated as a separate product.

Until those decisions are made, this feature remains **documented but not committed**.
