# AI Assistance & MCP Integration Architecture

## Purpose

Besyu may provide AI-assisted workflows without coupling core medication behavior to any single AI provider or allowing an AI model to become the source of truth for medication, reminder, appointment, or caregiver data.

The architecture should support future integration with:

- On-device / local AI
- Cloud AI providers
- MCP-capable AI hosts
- Future model providers without changing domain logic

AI is an assistive layer. Besyu domain use cases and persisted application data remain authoritative.

---

## Architecture Principles

1. **Domain-first** — medication, reminder, appointment, inventory, and caregiver rules live in domain/application use cases, not in AI tools.
2. **Provider-independent** — no core module depends directly on OpenAI, Anthropic, Google, or another model provider.
3. **Local-first** — local application data stays on-device by default. External transmission requires an explicit integration path and appropriate user consent.
4. **Least privilege** — AI tools expose only the minimum capability required for a task.
5. **No direct database access** — AI/MCP adapters must call approved use cases or repositories through an application-facing boundary. They must not query or mutate Hive/storage directly.
6. **Human confirmation for sensitive writes** — an AI suggestion must not silently change medication instructions, dosage, frequency, or other clinically sensitive records.
7. **Auditable actions** — tool invocation, confirmation state, and resulting mutation should be traceable without logging sensitive medication content to analytics.

---

## Target Architecture

```text
Besyu App
   |
   +-- Medication Domain
   +-- Reminder Domain
   +-- Appointment Domain
   +-- Inventory Domain
   +-- SOS / Caregiver Domain
   +-- Drug Knowledge
   |
   +-- AI Gateway
          |
          +-- Local AI Adapter
          +-- Cloud AI Adapter
          +-- MCP Adapter
                 |
                 +-- Besyu MCP Server / Tool Surface
                        |
                        +-- medication.*
                        +-- reminder.*
                        +-- appointment.*
                        +-- drug.*
                        +-- caregiver.*
```

The MCP layer is an adapter over existing application capabilities. It must not introduce a second implementation of business rules.

---

## Initial AI Tool Abstraction

The first implementation should establish an internal tool contract without implementing a production MCP server yet.

Conceptual Dart API:

```dart
abstract interface class AiTool {
  String get name;

  Future<AiToolResult> execute(
    AiToolContext context,
    Map<String, dynamic> arguments,
  );
}
```

Suggested registry:

```text
AiToolRegistry
   +-- ListCurrentMedicationTool
   +-- GetMedicationRemainingTool
   +-- ListTodayReminderTool
   +-- ListAppointmentsTool
   +-- LookupDrugTool
```

Adapters can later consume the same registry:

```text
AiToolRegistry
   |
   +-- InAppAiAdapter
   +-- LocalLlmAdapter
   +-- CloudLlmAdapter
   +-- McpAdapter
```

This follows the same dependency direction used by Besyu's Analytics and Crash abstractions: the application defines a stable contract and providers are replaceable implementations.

---

## Local AI / On-device LLM Strategy

Besyu should treat an on-device LLM as a **language-understanding and orchestration layer**, not as a medical knowledge source of truth.

High-value local AI responsibilities include:

- Natural-language intent classification
- Structured extraction from user-entered text
- OCR post-processing and normalization
- Semantic search/query interpretation
- Summarization of data already stored in Besyu
- Function/tool selection against the approved `AiToolRegistry`
- Future multimodal understanding when supported by the selected device/model stack

The LLM must not become authoritative for:

- Drug identity when a reference/database match is required
- Dosage correctness
- Drug interactions
- Contraindications
- Diagnosis
- Personalized treatment decisions

The application should prefer an "invisible AI" model where AI improves normal Besyu workflows rather than forcing users into a chatbot-first UI.

Example:

```text
"ยาตัวนี้กินเช้าเย็น เหลือประมาณ 20 เม็ด"
                 |
                 v
          Local AI extraction
                 |
                 v
{
  schedule: [morning, evening],
  inventory: 20
}
                 |
                 v
      Besyu validation/use case
                 |
                 v
        User confirmation UI
```

The model interprets language; Besyu validates and performs the action.

---

## Local AI Engine Abstraction

Do not let feature code depend directly on `flutter_gemma` or a particular Gemma model.

Reserve a provider-independent boundary such as:

```dart
abstract interface class LocalAiEngine {
  Future<AiGenerationResult> generate(AiGenerationRequest request);

  Future<AiStructuredResult<T>> extractStructured<T>(
    AiStructuredRequest<T> request,
  );

  Future<AiIntentResult> classifyIntent(AiIntentRequest request);

  Future<AiEmbeddingResult> embed(AiEmbeddingRequest request);
}
```

Conceptual implementation layout:

```text
AI
|
+-- LocalAiEngine
|    +-- generate()
|    +-- extractStructured()
|    +-- classifyIntent()
|    +-- embed()
|
+-- LocalAiProvider
|    +-- FlutterGemmaLocalAiProvider   # candidate, not yet committed
|    +-- OsBuiltInLocalAiProvider      # future candidate
|    +-- OtherLocalModelProvider       # future candidate
|
+-- AiCapabilities
     +-- medicationParsing
     +-- reminderIntent
     +-- appointmentIntent
     +-- semanticSearch
     +-- summarization
```

This boundary allows the app to change runtime/model strategy without changing domain/application logic.

Potential future runtime selection:

```text
                 Besyu AI Layer
                      |
                LocalAiEngine
                      |
        +-------------+-------------+
        |             |             |
        v             v             v
 flutter_gemma    OS built-in    Cloud AI
 local model      local model    optional
```

Cloud AI remains optional and should not be required for sensitive core workflows.

---

## `flutter_gemma` Evaluation Direction

`flutter_gemma` is a **candidate implementation adapter**, not a committed production dependency at this stage.

If evaluated, the preferred starting point is a small current-generation on-device model rather than the older Gemma 2B line.

Recommended evaluation order:

### Baseline — Gemma 3 1B class

Candidate use cases:

- Intent classification
- Structured text extraction
- Reminder/appointment language parsing
- OCR cleanup/normalization
- Small summarization tasks
- Tool/function selection

Why it is the preferred baseline:

- Lower storage/RAM/runtime cost than larger multimodal models
- Sufficient target capability for text-first Besyu workflows
- Allows real-device latency, thermal, and memory testing before committing to a larger model

### Later — Gemma 3n E2B class or equivalent multimodal model

Evaluate only when Besyu needs capabilities that justify the additional runtime cost, for example:

- Image + text understanding
- Voice/audio-assisted workflows
- Direct multimodal medicine-package assistance
- More capable local reasoning where device performance remains acceptable

Do not adopt a larger model solely because it is more capable. The selected model must meet device performance, storage, memory, battery, privacy, and safety requirements.

Gemma 2B should therefore be treated as a historical/compatibility option, not the default target for a new Besyu implementation.

---

## OCR + Local AI Pipeline

Local AI can add significant value after OCR, especially with noisy medicine labels, packaging, or abbreviated instructions.

Target flow:

```text
Camera / Gallery
       |
       v
      OCR
       |
       v
   Raw OCR text
       |
       v
Local AI normalization
       |
       v
Structured medicine candidate
       |
       v
Fuzzy / deterministic matching
       |
       v
Local drug/reference database
       |
       v
User confirmation
```

Example raw OCR:

```text
AMOXlCILLlN
500 MG
CAP
1 CAP TID PC
```

Possible AI-normalized candidate:

```json
{
  "generic_name": "amoxicillin",
  "strength": "500 mg",
  "form": "capsule",
  "frequency": "3 times daily",
  "timing": "after meals"
}
```

Safety rule: the normalized result is a **candidate**. It must not overwrite reference-backed medication data or become a dosage instruction without deterministic matching, provenance, and appropriate user confirmation.

---

## Candidate Tool Surface

Read-oriented tools are the safest initial MCP surface.

```text
medication.list_current
medication.get
medication.search_history
medication.get_remaining

reminder.list_today
reminder.get

appointment.list
appointment.get

drug.lookup

drug.check_duplicate

caregiver.get_contact
```

Potential later write tools:

```text
reminder.snooze
reminder.mark_taken
reminder.mark_skipped
appointment.create
appointment.update
```

Clinically sensitive mutations should not initially be exposed as direct write tools.

---

## Tool Risk Levels

### Level 1 — Read-only

Examples:

- List today's reminders
- Show current medication records
- Read remaining inventory
- Show upcoming appointments
- Look up reference-backed drug information

Policy:

- May execute when the user's intent is clear.
- Must still respect privacy and integration permissions.

### Level 2 — Low-risk operational write

Examples:

- Snooze a reminder
- Mark a recorded dose as Taken / Skip
- Create a doctor appointment from explicit user-provided details

Policy:

- The user request must clearly indicate the intended action.
- The tool must validate through normal Besyu use cases.
- A result should be surfaced back to the user.

### Level 3 — Sensitive medication mutation

Examples:

- Change dosage quantity
- Change medication frequency
- Start or stop medication
- Replace label/prescription-derived instructions
- Delete clinically relevant medication history

Policy:

- AI must not execute an autonomous change.
- AI may prepare a proposed change only when appropriate.
- Besyu must present the proposed change in app UI with source/provenance and explicit confirmation.
- The final mutation must go through the normal medication use case.

Conceptual flow:

```text
AI
  |
  v
Propose medication change
  |
  v
Besyu confirmation UI
  |
  +-- Confirm
  |      |
  |      v
  |   Medication Use Case
  |
  +-- Cancel
```

---

## Medical Safety Boundary

MCP does not change Besyu's existing medical-safety policy.

AI/MCP must not:

- Diagnose symptoms
- Select a medication to treat symptoms
- Calculate a personalized dose
- Increase or reduce a prescribed/label-derived dose on its own
- Recommend starting or stopping medication as an autonomous decision
- Fabricate missing medication instructions
- Present model-generated information as if it came from a clinician, prescription, label, or authoritative drug source

For medication information, provenance must remain visible whenever applicable.

---

## Permission Model

Tool execution should be capability-scoped rather than exposing the entire application state.

Suggested capability groups:

```text
medication.read
medication.write_operational
medication.propose_sensitive_change
reminder.read
reminder.write
appointment.read
appointment.write
caregiver.read
drug_reference.read
```

Future external MCP connections should allow the user to enable or disable capability groups independently where practical.

Sensitive capabilities should default to disabled for external clients until the permission and confirmation UX is implemented.

---

## Data Privacy

AI/MCP integration must follow the application's local-first privacy model.

Do not automatically send the following to an external model or MCP host:

- Complete medication list
- Medication history
- Dosage instructions
- OCR text
- Appointment notes
- Doctor information
- Healthcare-facility information
- Caregiver details

External transmission must be limited to the data required for the requested operation and should occur only through an explicitly enabled integration.

Analytics and crash-reporting adapters must not log MCP arguments or results containing health data.

For on-device inference, prompts/results that include health data must remain outside analytics and crash payloads by default. Model input/output logging must be disabled unless a specific diagnostic mode is explicitly designed with appropriate privacy controls.

---

## Audit Trail

AI-triggered actions should have a local audit model independent from analytics.

Suggested fields:

```text
AiActionAudit
- id
- toolName
- riskLevel
- requestedAt
- completedAt?
- resultStatus
- confirmationRequired
- confirmationStatus?
- actorType
- integrationType?
```

Avoid storing full prompts, medication names, OCR text, or tool payloads unless a specific product requirement justifies it and privacy handling is defined.

---

## Example AI Workflows

### "วันนี้ต้องกินยาอะไรบ้าง"

```text
AI
  -> reminder.list_today
  -> summarize existing Besyu schedule
```

### "ยา Amoxicillin เหลือกี่เม็ด"

```text
AI
  -> medication.get_remaining
  -> report persisted inventory result
```

### "นัดหมอครั้งหน้าวันไหน"

```text
AI
  -> appointment.list
  -> select next upcoming appointment
```

### Natural-language appointment creation

```text
"พรุ่งนี้ผมต้องไปหาหมอตอนบ่ายสอง"
        |
        v
 Local AI intent extraction
        |
        v
 appointment.create proposal
        |
        v
 Besyu validation/confirmation
```

The model extracts the requested date/time. Calendar/domain integration remains responsible for validation and persistence.

### Drug interaction question

A future implementation may compose multiple read tools:

```text
medication.list_current
        |
        v
drug interaction reference lookup
        |
        v
reference-backed explanation
```

The response must distinguish authoritative reference information from model-generated explanation and must not convert the result into a personalized prescription decision.

---

## MCP Direction

Besyu may later expose its approved AI tool surface through an MCP server so an MCP-capable AI host can perform user-authorized operations without direct access to Besyu storage.

Conceptual external flow:

```text
MCP-capable AI Host
        |
        v
Besyu MCP Adapter / Server
        |
        v
Permission + Confirmation Policy
        |
        v
Besyu Application Use Cases
        |
        v
Local Repositories / Storage
```

The MCP adapter must remain replaceable. MCP protocol details must not leak into domain entities or use cases.

---

## Phase Plan

### Phase AI-0 — Architecture only

Implement or reserve interfaces for:

- `AiTool`
- `AiToolContext`
- `AiToolResult`
- `AiToolRegistry`
- `LocalAiEngine`
- Provider-neutral local AI request/result contracts
- AI capability declarations
- Tool risk classification
- Capability/permission policy
- Confirmation policy
- Local AI-action audit abstraction
- `McpAdapter` boundary

No production AI provider, model bundle, or production MCP SDK is required in this phase.

### Phase AI-0.5 — Local AI feasibility spike

Before committing a model/runtime to production:

- Evaluate `flutter_gemma` behind `LocalAiEngine`
- Use a Gemma 3 1B-class model as the initial text baseline
- Test Thai + English intent classification and structured extraction
- Test OCR normalization against realistic medicine-label samples
- Benchmark startup/load time, first-token latency, sustained latency, RAM, model size, battery/thermal behavior, and failure handling on representative Android/iOS devices
- Verify that model download/storage lifecycle can be managed without blocking normal medication/reminder functionality
- Verify that core Besyu features work when the local model is missing, unsupported, unloaded, or fails
- Do not ship AI-0.5 results as authoritative medical behavior

A larger Gemma 3n E2B-class model should be evaluated only if multimodal/voice requirements justify it.

### Phase AI-1 — Read-only in-app assistant

Candidate scope:

- Current medication queries
- Today's reminder queries
- Remaining inventory queries
- Appointment queries
- Reference-backed drug lookup
- Natural-language query interpretation

Prefer local execution where possible.

### Phase AI-1.5 — Assisted structured input

Candidate scope:

- OCR medicine-text normalization
- User-text-to-reminder proposal
- User-text-to-appointment proposal
- Semantic search over local records/reference indexes

All clinically meaningful extracted fields remain proposals until validated by deterministic application logic and required confirmation.

### Phase AI-2 — Low-risk actions

Candidate scope:

- Reminder snooze
- Taken / Skip recording
- Appointment creation/update

Require clear user intent and normal domain validation.

### Phase AI-3 — Multimodal/local capability expansion

Only if product value and real-device evidence justify the runtime cost:

- Gemma 3n E2B-class or equivalent multimodal local model
- Image-assisted medicine/package understanding
- Voice/audio-assisted workflows
- Capability-based model selection by device

The text baseline should remain available when multimodal capability is unavailable.

### Phase AI-4 — External MCP integration

Only after permissions, privacy controls, confirmation UX, and audit behavior are validated:

- Production MCP adapter/server
- External MCP host connection
- Capability-scoped authorization
- Sensitive-write restrictions
- Integration settings / disconnect controls

---

## Non-goals for Current Development

Do not currently:

- Select an AI vendor as a hard dependency
- Add `flutter_gemma` as a production dependency solely because it is the current evaluation candidate
- Bundle or download a production Gemma model yet
- Treat Gemma 2B as the default new implementation target
- Add OpenAI / Anthropic / Gemini SDKs to core packages
- Implement an MCP SDK directly inside domain or data layers
- Expose Hive boxes or repository internals to AI
- Upload the local medication database to a model provider
- Implement autonomous medication decisions
- Allow external AI clients unrestricted write access
- Treat LLM output as authoritative drug, dose, interaction, contraindication, or diagnostic data

The current objective is to establish a stable integration seam so future local AI/MCP functionality can be added without restructuring Besyu's core architecture.
