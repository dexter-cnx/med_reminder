# Besyu — Product Specification

> **Besyu**  
> **Beside You.**  
> *อยู่ข้างกาย ในทุกวัน*

## 1. Product Identity

### Brand name

**Besyu**

### Brand label

**Beside You.**

### Thai brand line

**อยู่ข้างกาย ในทุกวัน**

### Product category label

**Personal Medication Companion**

### Store-facing descriptor

Recommended:

- **Besyu — Medication Reminder & Organizer**
- **Besyu — Medication Tracker & Reminder**

Avoid positioning such as:

- AI Doctor
- AI Pharmacist
- Medical Diagnosis AI
- AI Medication Advisor
- Smart Drug Dosage Calculator

### Brand intent

`Besyu` is derived from the idea of **Beside You**: a personal companion that stays with the user through medication routines, medication records, reminders, inventory, and doctor appointments.

The brand should feel supportive and personal without presenting itself as a doctor, pharmacist, diagnostic system, or autonomous medical decision system.

---

## 2. Product Overview

**Besyu** is a local-first medication companion focused on four core areas:

1. Identify and capture medication information from labels or packaging.
2. Manage personal medication records and remaining quantity.
3. Remind and record medication intake.
4. Manage doctor appointments and optionally synchronize them with the system calendar.

Besyu is a **Medication Organizer / Medication Reminder / Medication Information Tool**. It is not intended to diagnose disease or make autonomous medical decisions.

---

## 3. Core Principles

### 3.1 Local-first

Core data should be stored on-device by default, including:

- Medication list
- Medication inventory
- Medication schedules
- Intake history
- Doctor appointments
- Medication notes
- OCR results
- User corrections

Cloud/server connectivity must not be required for core functionality.

### 3.2 AI is assistive, not authoritative

AI may assist with:

- OCR post-processing
- Drug-name normalization
- Fuzzy matching
- Drug candidate ranking
- Label text extraction
- Structured instruction parsing
- Summarizing referenced information
- Detecting uncertain OCR fields

AI must not generate new medical advice or personalized treatment instructions on its own.

Allowed example:

> คำแนะนำที่อ่านได้จากฉลาก: รับประทานครั้งละ 1 เม็ด วันละ 2 ครั้ง หลังอาหาร

Not allowed:

> คุณควรรับประทานครั้งละ 1 เม็ด วันละ 2 ครั้ง

unless that instruction is clearly attributed to a label, prescription, clinician-provided instruction, or appropriate authoritative source.

---

## 4. Medication Capture

### 4.1 Scan medication

Supported capture sources:

- Medication label
- Medication bag
- Medication box
- Blister pack
- Bottle
- Prescription label

Pipeline:

```text
Camera
  ↓
Image preprocessing
  ↓
OCR
  ↓
Text normalization
  ↓
Drug-name candidate extraction
  ↓
Local drug database search
  ↓
Fuzzy matching
  ↓
User confirmation
```

### 4.2 OCR result

Potentially detected fields:

- Drug name
- Generic name
- Brand name
- Strength
- Dosage form
- Dosage instruction from label
- Quantity
- Dispensed date
- Hospital / clinic
- Doctor name
- Notes

Every detected field must be manually editable before final confirmation.

---

## 5. Medication Identification

Example candidate flow:

```text
OCR:
AMOXICILLIN 500 MG

Possible matches:

1. Amoxicillin 500 mg capsule
   Confidence: 97%

2. Amoxicillin 250 mg capsule
   Confidence: 71%
```

The user must confirm the medication before it is stored in the personal medication database.

Low-confidence results must not be auto-confirmed.

---

## 6. Medication Information

After identification, Besyu may show:

- Generic name
- Brand name
- Active ingredient
- Strength
- Dosage form
- Drug class
- Indications
- General usage information
- Common adverse effects
- Important warnings
- Storage information
- Manufacturer
- Registration information
- Reference source

Reference-backed information should include:

```text
Source
Last updated
```

---

## 7. Dosage Information — Safety Requirement

The requirement is:

> Read and structure medication-use instructions from labels, prescriptions, or user-entered information, and display general usage information from appropriate trusted references. The app must clearly distinguish source-derived instructions from general reference information.

### Label-derived example

```text
คำแนะนำบนฉลาก

ครั้งละ: 1 เม็ด
วันละ: 2 ครั้ง
เวลา: หลังอาหารเช้าและเย็น

Source:
Medication label
```

### Reference-information example

```text
ข้อมูลทั่วไปของยา

รูปแบบการใช้ยานี้อาจแตกต่างกันตามข้อบ่งใช้ อายุ และภาวะของผู้ป่วย

Source:
Official drug information
```

### Besyu must not

- Calculate a personalized dose
- Increase or reduce a dose
- Change medication frequency
- Recommend stopping medication
- Recommend starting medication
- Select medication to treat symptoms
- Diagnose symptoms and prescribe medication
- Decide which dose is appropriate for a specific user

---

## 8. Medication Library

Medication can be added via:

- Scan
- Search
- Manual entry

Suggested model:

```text
Medication
- id
- drugReferenceId?
- genericName
- brandName?
- strength?
- dosageForm?
- imagePath?
- notes?
- createdAt
- updatedAt
```

---

## 9. Medication Inventory

Suggested model:

```text
MedicationInventory
- medicationId
- quantity
- unit
- openedAt?
- expiresAt?
- lowStockThreshold?
```

Supported units may include:

- tablet
- capsule
- sachet
- ml
- bottle
- tube
- dose

---

## 10. Automatic Stock Tracking

When an intake is recorded as `Taken`, Besyu may reduce inventory automatically.

Example:

```text
Before:
30 tablets

Taken:
1 tablet

Remaining:
29 tablets
```

---

## 11. Low Stock Reminder

Example:

```text
Amlodipine
เหลือ 4 เม็ด

ประมาณ 4 วันตามตารางที่บันทึกไว้
```

The wording must not imply that the user should obtain or continue medication without appropriate instruction.

---

## 12. Medication Schedule

Schedule should be modeled separately from Medication.

```text
MedicationSchedule
- id
- medicationId
- doseQuantity
- unit
- scheduledTimes
- startDate
- endDate?
- instructions?
- instructionSource
- enabled
```

Suggested `instructionSource` values:

```text
label
prescription
user
caregiver
reference
```

---

## 13. Medication Reminder

Supported patterns:

- Daily
- Multiple times per day
- Specific weekdays
- Start/end date
- Before meal
- After meal
- With meal
- Custom time

Example notification:

```text
08:00
Amoxicillin 500 mg

คำแนะนำบนฉลาก:
1 capsule after breakfast

[Taken]
[Snooze]
[Skip]
```

---

## 14. Snooze

Suggested presets:

- 5 min
- 10 min
- 15 min
- 30 min
- 1 hour
- Custom

Snoozed notifications must preserve their associated schedule and medication identity.

---

## 15. Medication Intake History

Suggested model:

```text
MedicationIntake
- id
- medicationId
- scheduleId
- scheduledAt
- takenAt?
- quantity
- status
- note?
```

Suggested status values:

```text
scheduled
taken
late
skipped
missed
```

---

## 16. Adherence

Besyu may show descriptive recorded adherence statistics.

```text
7 days

Scheduled: 14
Taken: 12
Skipped: 1
Missed: 1

Recorded adherence: 85.7%
```

Use neutral terminology such as **Recorded medication adherence** rather than converting the metric into autonomous medical judgments.

---

## 17. Doctor Appointments

Besyu includes an **Appointments** module for:

- Doctor
- Dentist
- Pharmacist
- Clinic
- Hospital
- Other healthcare provider

---

## 18. Appointment Model

```text
Appointment
- id
- title
- doctorName?
- clinicName?
- startAt
- endAt?
- location?
- phone?
- note?
- status
- calendarEventId?
- calendarId?
- syncToCalendar
- createdAt
- updatedAt
```

Suggested status values:

```text
scheduled
completed
cancelled
```

---

## 19. Appointment ↔ Medication

One appointment may relate to multiple medications.

```text
AppointmentMedication
- appointmentId
- medicationId
```

Example:

```text
นัดติดตามความดัน

Related medications:
- Amlodipine 5 mg
- Losartan 50 mg
```

---

## 20. System Calendar Integration

User actions:

```text
Add to Calendar
```

or

```text
Sync with Calendar
```

Example calendar event:

```text
Follow-up appointment

Dr. Somchai
ABC Hospital

Aug 28, 2026
10:00–10:30

Besyu
```

---

## 21. Calendar Sync Rules

Store:

```text
calendarId
calendarEventId
```

This supports:

- Updating existing calendar events
- Deleting linked calendar events
- Preventing duplicate events

When an appointment changes in Besyu:

```text
Appointment updated
      ↓
Update calendar event
```

When cancelling an appointment:

```text
Cancel appointment

○ Cancel only in Besyu
○ Cancel and remove calendar event
```

---

## 22. Calendar Permission

Do not request Calendar permission at app launch.

Request it only when the user first performs an action that requires Calendar integration.

If permission is denied, appointments inside Besyu must continue to work normally.

---

## 23. Appointment Reminders

Besyu may provide reminders independently from the system calendar, for example:

```text
1 day before
2 hours before
30 minutes before
```

Appointment reminders may support snooze.

---

## 24. Appointment Preparation

Before an appointment, Besyu may provide a **Prepare for Appointment** view showing:

- Current medication list
- Current recorded schedules
- Recent medication history
- Medication notes
- Questions to ask the doctor

Example:

```text
Appointment tomorrow
10:00

Current medications

Amlodipine
5 mg
08:00 daily

Losartan
50 mg
20:00 daily
```

---

## 25. Questions for Doctor

Users may keep personal notes such as:

```text
Questions for doctor

- ยานี้ทำให้ง่วงหรือไม่
- ต้องกินต่ออีกนานไหม
- มีผลตรวจอะไรที่ต้องติดตามหรือไม่
```

AI may help structure or rewrite the user's notes but must not silently answer them as if it were the treating clinician.

---

## 26. Medication Changes After Appointment

Changes should be historically traceable rather than silently overwriting the previous schedule.

```text
Medication change

Previous schedule:
1 tablet morning

New schedule:
1 tablet morning + evening

Source:
Doctor / prescription

Changed:
28 Aug 2026
```

---

## 27. Medication Timeline

Potential timeline:

```text
Aug 20
Medication added

Aug 21
Started medication

Aug 28
Doctor appointment

Aug 28
Schedule changed

Sep 10
Medication completed
```

---

## 28. Drug Database

Reference drug data must be separate from user medication records.

```text
Bundled Drug Database
        +
Periodic Drug Data Update
        ↓
Local Drug Reference DB
        ↓
Search / Fuzzy Search
        ↓
User Medication Records
```

Reference data updates must not corrupt or overwrite user-entered medication history.

---

## 29. Drug Data Sources

Potential sources should be authoritative and appropriately licensed, such as:

- Thai FDA / อย.
- Official product information
- Manufacturer information
- Government/open drug datasets
- Other authoritative drug databases with appropriate licensing

Recommended provenance fields:

```text
source
sourceId
sourceUpdatedAt
importedAt
```

---

## 30. Search

Suggested search pipeline:

```text
Exact match
↓
Normalized match
↓
Prefix match
↓
Fuzzy match
↓
Alias / brand / generic match
```

Thai and English should both be supported.

---

## 31. Offline / Local AI

Local AI may be used for OCR normalization, candidate ranking, and instruction parsing.

Example OCR normalization:

```text
อะมอกซิซิลิน
→
Amoxicillin
```

Example candidate ranking inputs:

```text
OCR text
+
strength
+
dosage form
+
manufacturer
↓
Candidate score
```

Example instruction parsing:

```text
รับประทานครั้งละ 1 เม็ด
วันละ 3 ครั้ง
หลังอาหาร
```

may become:

```json
{
  "quantity": 1,
  "unit": "tablet",
  "frequencyPerDay": 3,
  "relationToMeal": "after_meal"
}
```

The structured result must be reviewable before being persisted.

---

## 32. AI Confidence

Uncertain AI/OCR-derived fields should carry confidence where practical.

```text
Drug name
Amoxicillin
98%

Strength
500 mg
96%

Instruction
1 capsule twice daily
64%
```

Low-confidence fields should require explicit confirmation.

---

## 33. Do Not Guess

If Besyu cannot reliably read an instruction:

```text
ไม่สามารถอ่านวิธีใช้ยาได้อย่างมั่นใจ

กรุณาตรวจสอบฉลาก
หรือกรอกข้อมูลด้วยตนเอง
```

The app must not fabricate missing medication details merely to complete a record.

---

## 34. Privacy

Sensitive health data includes:

- Medication list
- Medication history
- Appointment data
- Doctor information
- Healthcare facility
- Medication notes
- Adherence history

Principles:

```text
Local by default
Minimal permissions
Minimal external transmission
Explicit user action
```

---

## 35. Analytics

If analytics are used, do not transmit:

- Medication names
- Doctor names
- Hospital / clinic names
- Dosage instructions
- OCR text
- Appointment notes
- Medication history

Technical telemetry may include events such as:

```text
scan_started
scan_completed
ocr_failed
calendar_permission_denied
```

without sensitive health payloads.

---

## 36. Backup / Export

Future options may include:

- Local encrypted backup
- Medication list export
- Medication history export
- Appointment history export

Potential explicit export formats:

```text
PDF
CSV
JSON
```

Exports must require explicit user action.

---

## 37. Architecture

Recommended high-level structure:

```text
Flutter
│
├── Presentation
│   ├── Medication
│   ├── Scanner
│   ├── Reminder
│   ├── Inventory
│   ├── Appointment
│   └── Settings
│
├── Domain
│   ├── Medication
│   ├── Schedule
│   ├── Intake
│   ├── Inventory
│   ├── Appointment
│   └── DrugReference
│
├── Data
│   ├── Repositories
│   ├── Local Storage
│   ├── Drug Reference DB
│   └── Calendar
│
└── Infrastructure
    ├── OCR
    ├── Local AI
    ├── Notifications
    └── System Calendar
```

---

## 38. Storage Abstraction

Domain code must not depend directly on a storage engine.

```dart
abstract interface class MedicationRepository {}

abstract interface class AppointmentRepository {}

abstract interface class MedicationHistoryRepository {}

abstract interface class DrugReferenceRepository {}
```

Implementations may include:

```text
DxtrBoxMedicationRepository
HiveMedicationRepository
SQLiteMedicationRepository
```

This allows the local persistence engine to change without affecting domain logic.

---

## 39. MVP Scope

### MVP 1 — Medication + Reminder + Inventory

Medication:

- Add medication manually
- Medication local DB
- Search medication
- Medication details

Reminder:

- Schedule
- Notification
- Taken
- Skip
- Snooze
- History

Inventory:

- Quantity
- Automatic decrement
- Low-stock warning

### MVP 2 — Scanner

- Camera
- OCR
- Medication-name extraction
- Fuzzy matching
- User confirmation
- Label instruction extraction
- Structured parsing
- Source indication

### MVP 3 — Appointment

- Add/edit/delete appointment
- Appointment reminder
- Related medications
- Calendar integration
- Calendar update/delete synchronization

### MVP 4 — Medication Companion

- Appointment preparation
- Medication timeline
- Adherence summary
- Medication changes/history
- Export medication summary
- Questions for doctor

---

## 40. Explicit Non-Goals for Initial Releases

Do not implement as autonomous product behavior:

- Disease diagnosis
- Symptom diagnosis
- Drug recommendation
- Personalized drug selection
- Personalized dosage calculation
- Drug-dose adjustment
- Prescription generation
- Replacement for doctor/pharmacist consultation
- Autonomous medical decision making

---

## 41. Safety UI

Medication information should visually distinguish:

```text
[ข้อมูลจากฉลาก]

[ข้อมูลที่ผู้ใช้กรอก]

[ข้อมูลอ้างอิงยา]
```

These sources should not be blended into generated text in a way that obscures provenance.

---

## 42. Source Provenance

Important medication instructions should be traceable.

Example:

```text
Dosage instruction

1 tablet twice daily

Source:
Medication label

Captured:
20 Aug 2026

Confidence:
94%

Verified by user:
Yes
```

Source provenance is a core Besyu product principle.

---

## 43. Product Flow

```text
Scan / Search / Enter Medication
             ↓
       Confirm Medication
             ↓
      Add to Medication List
             ↓
       Configure Schedule
             ↓
      Medication Reminder
             ↓
         Take / Skip
             ↓
       Medication History
             ↓
        Stock Tracking
             ↓
       Doctor Appointment
             ↓
     Prepare for Appointment
             ↓
      Medication Changed?
             ↓
      Update Schedule
             ↓
         Continue Cycle
```

---

## 44. Long-term Product Identity

Besyu should evolve as a:

> **Personal Medication Companion**

not an:

> **AI Medical Decision System**

Primary strengths should remain:

- Offline-first
- Privacy-first
- Reliable medication reminders
- Medication inventory
- Fast medication capture
- Traceable medication information
- Doctor appointment integration
- Complete medication history
- Clear source provenance
- User-confirmed AI assistance

The product goal is to help users manage their medication-related information and routines more reliably while avoiding autonomous medical decision-making.
