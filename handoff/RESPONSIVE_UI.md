# Besyu Responsive UI Handoff

## Purpose

Besyu must treat responsive behavior as a product requirement, not as a later polish pass.

All current and future feature UI should support at least:

- phone / mobile layouts
- tablet layouts
- portrait
- landscape
- larger text without clipped primary actions

The responsive system should be **ratio-first**. Avoid designing one fixed phone canvas and scaling pixel values upward for tablets.

## Mobile vs Tablet shape ratio

Use the current available layout bounds rather than device model names.

A useful normalized shape ratio is:

```dart
final size = MediaQuery.sizeOf(context);
final shortSide = math.min(size.width, size.height);
final longSide = math.max(size.width, size.height);
final shapeRatio = shortSide / longSide;
```

Interpretation direction:

```text
more phone-shaped                         more tablet/square-shaped
0.40 -------- 0.50 -------- 0.60 -------- 0.70 -------- 1.00
```

Initial guideline:

- `shapeRatio < ~0.60` -> prefer **Mobile composition**
- `shapeRatio >= ~0.60` -> consider **Tablet composition** when the available space can actually support it

The ratio is a layout signal, not an inflexible device identity. Foldables, split-screen windows, desktop-sized Flutter windows, and unusual aspect ratios can cross these boundaries.

Therefore the implementation may use small min/max extent guards in addition to the ratio to prevent obviously unsuitable layouts, but **fixed pixel breakpoints must not be the primary sizing strategy**.

Do not scatter raw ratio thresholds throughout feature widgets. Put classification in one shared responsive policy/helper so the thresholds can be tuned consistently.

Conceptually:

```dart
enum BesyuLayoutClass {
  mobile,
  tablet,
}
```

A future helper may expose:

```dart
class BesyuLayoutInfo {
  final BesyuLayoutClass layoutClass;
  final Orientation orientation;
  final double shapeRatio;
  final Size availableSize;
}
```

## Ratio-based sizing

Once Mobile or Tablet composition is selected, size major regions as a proportion of the **available viewport**, not the physical screen and not a fixed design canvas.

Preferred approach:

```text
available width -> content/pane ratios -> min/max safety constraints
```

Examples:

### Mobile portrait

- primary content: approximately `92-100%` of safe available width
- usually one column
- cards/actions stack vertically when horizontal space becomes tight
- horizontal padding may use a small relative fraction with sensible min/max bounds

### Mobile landscape

Do not simply stretch the portrait column across the screen.

For flows that benefit from two regions:

```text
primary content   58-65%
secondary/actions 35-42%
```

Use a single region when a second pane adds no product value.

### Tablet portrait

Prefer a wider but bounded content canvas rather than full-width stretched phone cards.

Typical direction:

```text
main content width       72-88% of available width
optional master/detail   60-65% / 35-40%
```

Large empty margins are acceptable when they improve readability.

### Tablet landscape

This is the preferred environment for persistent multi-pane layouts where the feature benefits from them.

Typical direction:

```text
master/list/timeline     58-64%
detail/context panel     36-42%
```

A feature may choose a different ratio when its information hierarchy requires it, but it should be deliberate and documented.

## Composition must differ, not only dimensions

Mobile and Tablet should be allowed to use different composition.

Examples:

- Mobile medication list -> tap card -> detail/bottom sheet/full-screen detail
- Tablet medication list -> list + persistent detail pane when useful
- Mobile Daily Timeline -> one chronological column
- Tablet Daily Timeline -> timeline plus contextual detail/summary pane
- Mobile refill flow -> bottom sheet or full-screen compact flow
- Tablet refill flow -> centered/bounded sheet or side detail region rather than a phone-width sheet stretched across the display

Do not require every screen to become two-pane on tablets. Multi-pane is appropriate only when simultaneous context improves the task.

## Bottom sheets, dialogs, and forms

Modal surfaces must not blindly consume the full tablet width.

Rules:

- Mobile: modal width may approach full available width.
- Tablet: constrain form/modal content to a readable fraction of viewport width.
- Use viewport ratios first, then min/max width guards.
- Long forms must scroll and remain usable with the keyboard open.
- Primary actions must remain reachable in portrait and landscape.

## Typography and accessibility

Responsive behavior must survive text scaling.

At minimum validate common screens at:

- normal text scale
- `1.3x` text scale
- a larger accessibility scale where primary actions still remain usable

Do not shrink text merely to preserve a fixed layout. Let containers wrap/reflow first.

## Safe areas and system UI

All ratio calculations should use the layout space actually available to the feature after safe-area/system constraints are considered.

Avoid assumptions such as:

- fixed status-bar height
- fixed navigation-bar height
- identical Android/iOS insets
- portrait-only keyboard behavior

## Shared implementation direction

Responsive classification belongs in shared presentation infrastructure, for example:

```text
shared/
└── responsive/
    ├── besyu_layout_class.dart
    ├── besyu_layout_info.dart
    └── besyu_responsive.dart
```

Feature widgets may consume `BesyuLayoutInfo`, but should not each invent their own phone/tablet thresholds.

This remains presentation-only infrastructure. It must not leak into feature domain or persistence layers.

## Testing expectations

Feature UI work should include responsive validation when it changes a major screen.

Minimum matrix:

```text
Mobile portrait
Mobile landscape
Tablet portrait
Tablet landscape
```

For important screens also validate:

```text
Mobile + 1.3x text
Tablet + 1.3x text
keyboard-visible form state
empty state
long medication/description text
```

Golden tests are optional where they add value, but widget tests should at least detect overflow/exceptions for representative viewport shapes.

Use ratio-representative test viewports rather than testing only one canonical device resolution.

## Product rule

> Besyu should adapt its information hierarchy to the space available. Tablet UI is not a magnified phone UI, and landscape is not a stretched portrait UI.

The implementation should prefer **relative layout ratios + shared layout classification + min/max safety bounds** over hard-coded per-device pixel layouts.
