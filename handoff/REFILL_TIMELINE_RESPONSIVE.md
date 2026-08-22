# Refill Timeline + Responsive Home Handoff

## Scope

This increment projects persisted medication refill events into Besyu's Daily Timeline and applies the shared ratio-first responsive policy to the Today surface.

## Timeline composition

Timeline remains a read model, never a source of truth.

```text
Medication / DoseLog ---------\
                              > buildDailyTimeline() -> TimelineItem[] -> Home
RefillEvent -----------------/
```

`RefillTimelineItem` contains:

- the immutable `RefillEvent`
- a presentation-friendly medication name supplied by the app composition layer
- `at = RefillEvent.createdAt`

The pure builder filters refill events to the requested day and sorts refill and dose items together chronologically.

The app-level `dailyTimelineProvider` performs the cross-feature join between Medication, Today doses, and Refill state. Timeline feature internals do not import medication/refill presentation providers.

## Home behavior

The Today tab consumes `dailyTimelineProvider` instead of rendering only scheduled doses.

Medication dose timeline cards retain Taken / Skip / Snooze actions.

Refill timeline cards show:

- refill time
- refill quantity
- medication name when available
- optional refill note

A refill recorded today appears reactively in the Today timeline because `refillEventsProvider` is part of `dailyTimelineProvider`.

## Responsive policy implementation

`ResponsiveLayoutInfo` implements the shared ratio-first policy from `handoff/RESPONSIVE_UI.md`.

Primary signal:

```text
shapeRatio = shortestSide / longestSide
```

Current classification:

```text
shapeRatio >= 0.60 AND shortestSide >= 600 -> tablet-shaped\anotherwise                                  -> mobile-shaped
```

The 600 logical-pixel value is a safety guard, not the primary sizing model. It prevents compact square windows/phones from being treated as tablets.

### Mobile

- single timeline flow
- works in portrait and landscape
- major horizontal padding is derived from viewport width and clamped for safety

### Tablet portrait

- single timeline flow for now
- avoids forcing split-pane composition where vertical reading remains clearer

### Tablet landscape

- two-pane composition
- primary timeline: about 62%
- secondary overview: about 38%
- pane ratio comes from `ResponsiveLayoutInfo`, not hard-coded widget widths

This matches the handoff target range of approximately 58-64% / 36-42%.

## Tests

Regression coverage includes:

- same-day refill events appear in Daily Timeline
- refill events from another day are excluded
- dose/refill items are ordered by timestamp
- medication name projection survives the app composition boundary
- representative phone portrait/landscape classify as Mobile
- representative tablet portrait/landscape classify as Tablet
- tablet landscape exposes 62/38 pane fractions
- compact square viewport remains Mobile through the safety guard

## Non-goals

- persisting Timeline items
- moving refill ownership into Timeline
- appointment/check-in timeline items in this increment
- editing refill history from Timeline
- tablet-specific medication editor redesign
- desktop/windowed layout beyond the current safety classification

## Next step

After this increment is stable, the next composition candidate is `AppointmentTimelineItem` once the Appointment feature has a real persisted/application boundary. Timeline should continue to accept new feature projections rather than querying storage directly.
