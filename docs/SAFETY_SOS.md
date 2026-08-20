# Besyu — Safety & Emergency Assistance (SOS)

> **Besyu**  
> **Beside You.**  
> *อยู่ข้างกาย ในทุกวัน*

## Purpose

Besyu may provide a prominent **SOS / Quick Help** entry point to help the user contact a configured person or emergency service quickly.

This feature is an **Emergency Contact / Quick Help** convenience feature. It must not be presented as a guaranteed emergency-response service, medical monitoring service, or replacement for official emergency services.

## Primary UI

- Show an `SOS` action at the top-right of the Home screen.
- The action must be visually discoverable, but the entire app bar should not use emergency styling.
- Avoid accidental activation. Default interaction should be either:
  - tap → Emergency Sheet / confirmation, or
  - press-and-hold → Emergency Sheet / configured action.
- Do not start a call or send a message from a single accidental tap by default.

Example:

```text
SOS

Call
[ Emergency contact ]
[ Caregiver ]
[ Emergency service ]

Message
[ SMS caregiver ]
[ Open LINE ]

[ Cancel ]
```

## Configurable Emergency Contacts

Users may configure one or more emergency contacts with supported actions such as:

- Phone call
- SMS
- LINE chat/open LINE

Suggested settings model:

```text
EmergencyContact
- id
- name
- phoneNumber?
- lineTarget?
- preferredChannel
- enabledChannels
- priority
```

## Phone Call

Phone calling should be the primary and most reliable communication option where supported by the device.

Besyu should open the system calling flow for the configured number. Platform behavior and confirmation requirements must be respected.

## SMS

Besyu may open the system SMS composer with:

- configured recipient
- prefilled SOS text
- optional current-location link

Default behavior should allow the user to review the message before sending unless a platform-approved explicit emergency flow is implemented later.

Example message:

```text
ต้องการความช่วยเหลือ กรุณาติดต่อฉัน
ตำแหน่งปัจจุบัน: <location link>
```

## LINE

### Supported intent

Besyu may provide **Open LINE / LINE Chat** as an optional communication channel when LINE is available.

### Voice and video calls

Besyu must **not promise direct LINE Voice Call or LINE Video Call initiation**.

The public LINE integration surface should be treated as supporting navigation/opening LINE or supported chat/deep-link flows only. Unless LINE provides an official supported API/deep link for direct voice/video initiation in the future, Besyu must not label an action as if it can reliably start a LINE voice or video call to a configured contact.

Recommended labels:

- `Open LINE`
- `LINE Chat`

Avoid:

- `LINE Voice Call`
- `LINE Video Call`

unless an official supported integration becomes available and is verified for the target platforms.

## Channel Priority

Recommended default priority:

```text
SOS
├─ Call now          ← primary
├─ SMS + location    ← secondary
└─ Open LINE         ← optional
```

The user may configure a preferred contact/channel, but Besyu should maintain a reliable phone/SMS fallback where available.

## Emergency Services

Besyu may allow the user to configure or expose an official emergency-service number appropriate to the user's region.

The UI must distinguish official emergency services from personal emergency contacts.

No claim should be made that Besyu dispatches, monitors, or guarantees an emergency response.

## Location Sharing

Optional location sharing may be offered for SOS messages.

Requirements:

- request location permission only when the feature needs it
- do not require location permission for basic SOS functionality
- clearly indicate whether location will be included
- if location is unavailable, SOS contact actions must still work
- never show `location sent` unless the app can verify the relevant action/state

Suggested option:

```text
Include current location    ON/OFF
```

## Health Data in SOS

Medication information, adherence history, appointment information, doctor details, and other health data are sensitive.

Do **not** include medication or medical summaries in SOS messages by default.

If a future feature allows health-data sharing, it must require explicit user configuration and clear confirmation of what will be shared.

Suggested setting:

```text
Include medication summary  OFF
```

## Emergency Medical Card

A future **Emergency Medical Card** may expose user-confirmed emergency information such as:

- user's display name
- emergency contacts
- medication list selected by the user
- drug allergies entered/confirmed by the user
- important user-entered emergency notes

The app must not infer allergies or emergency medical facts using AI.

## Failure and Fallback Behavior

Besyu must handle communication failures explicitly.

Examples:

- no phone capability → disable call action and offer SMS/LINE if available
- no SIM/SMS capability → offer call/LINE where available
- LINE not installed → hide/disable LINE action and show an understandable fallback
- location denied/unavailable → continue without location
- invalid/unconfigured contact → require setup rather than pretending SOS was sent

Do not display success states such as `SOS sent` unless Besyu can actually verify that state.

## Privacy

SOS settings and emergency contacts should remain local-first by default.

Analytics must not capture:

- phone numbers
- LINE identifiers
- message content
- precise location
- emergency-contact names
- medication information attached to emergency flows

Technical analytics may record non-sensitive events such as:

```text
sos_opened
sos_call_intent_opened
sos_sms_composer_opened
sos_line_opened
sos_location_permission_denied
```

without sensitive payloads.

## Architecture Boundary

SOS communication must be abstracted from platform implementations.

Suggested domain-facing interfaces:

```dart
abstract interface class EmergencyContactRepository {}

abstract interface class EmergencyCommunicationGateway {
  Future<void> openPhoneCall(String phoneNumber);
  Future<void> openSms({required String phoneNumber, String? message});
  Future<void> openLine(...);
}

abstract interface class EmergencyLocationProvider {}
```

Platform-specific adapters may then implement Android/iOS calling, SMS, LINE deep links, and location services without coupling the domain layer to those APIs.

## Product Scope

Recommended delivery order:

### SOS v1

- SOS button on Home
- Emergency contact settings
- Phone call
- SMS composer
- Optional location link
- Safe confirmation / press-and-hold activation

### SOS v1.1

- Open LINE / LINE Chat
- channel preference
- fallback handling

### SOS Future

- Emergency Medical Card
- explicit user-selected emergency medical summary
- regional emergency-service configuration

Direct LINE voice/video call must remain out of scope unless LINE exposes an official, supported integration that can be verified on the target platforms.
