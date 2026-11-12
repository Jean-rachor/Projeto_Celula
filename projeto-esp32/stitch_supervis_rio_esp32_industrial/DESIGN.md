---
name: Industrial SCADA Core
colors:
  surface: '#faf8ff'
  surface-dim: '#d2d9f4'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f3ff'
  surface-container: '#eaedff'
  surface-container-high: '#e2e7ff'
  surface-container-highest: '#dae2fd'
  on-surface: '#131b2e'
  on-surface-variant: '#44474c'
  inverse-surface: '#283044'
  inverse-on-surface: '#eef0ff'
  outline: '#75777d'
  outline-variant: '#c5c6cd'
  surface-tint: '#525f75'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#0e1c2f'
  on-primary-container: '#77849c'
  inverse-primary: '#bac7e1'
  secondary: '#006398'
  on-secondary: '#ffffff'
  secondary-container: '#5bb8fe'
  on-secondary-container: '#00476e'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#001c38'
  on-tertiary-container: '#6886ae'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d6e3fe'
  primary-fixed-dim: '#bac7e1'
  on-primary-fixed: '#0e1c2f'
  on-primary-fixed-variant: '#3a475c'
  secondary-fixed: '#cce5ff'
  secondary-fixed-dim: '#93ccff'
  on-secondary-fixed: '#001d31'
  on-secondary-fixed-variant: '#004b73'
  tertiary-fixed: '#d3e4ff'
  tertiary-fixed-dim: '#aac9f4'
  on-tertiary-fixed: '#001c38'
  on-tertiary-fixed-variant: '#29486d'
  background: '#faf8ff'
  on-background: '#131b2e'
  surface-variant: '#dae2fd'
typography:
  display:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  metric-xl:
    fontFamily: JetBrains Mono
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.03em
  metric-lg:
    fontFamily: JetBrains Mono
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.02em
  metric-md:
    fontFamily: JetBrains Mono
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 22px
  label-code:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.04em
  label-caps:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.06em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-compact: 0.5rem
  margin: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1.25rem
  space-xl: 1.75rem
---

## Brand & Style

This design system targets mission-critical supervisory control and data acquisition (SCADA) interfaces running hardware control for industrial ESP32 architectures. The design tone is precise, dependable, unambiguous, and built for zero-latency cognitive processing under high-stress factory floor environments.

The design movement combines **Corporate Modern** rigor with **Tactile Industrial Precision**:
- High-contrast structured planes that favor crisp orientation and scan-speed over decorative flourish.
- Clear state segmentation that prevents misclicks and misreads in environments with ambient factory glare or low-light control rooms.
- Clean architectural geometry with calibrated panel separation to isolate live physical control loops, telemetry feeds, and emergency parameters.

## Colors

The palette establishes an authoritarian hierarchy where operational state takes visual precedence over passive UI structure:

- **Primary Structure (`#0B192C`, `#1E3E62`):** Grounded deep navy used for structural mastheads, machine identification bars, fixed navigation headers, and primary supervisory containers.
- **Active Indicators & Interaction (`#0284C7`, `#2563EB`):** Precision industrial blues for active state indicators, telemetry focus nodes, toggles, and primary physical action switches.
- **Base Surfaces (`#FFFFFF`, `#F8FAFC`):** Pure white for primary metric instrumentation and panel tiles; soft slate-gray for canvas background to mitigate eye fatigue across long shifts.
- **Structural Borders (`#E2E8F0`, `#CBD5E1`):** Low-bleed mechanical boundary definitions that separate distinct sensor clusters without adding visual noise.
- **Data & Text (`#0F172A`, `#334155`):** Near-black slate for maximum contrast ratio against white cards, ensuring complete compliance with industrial legibility standards.

### Operational State Tokens (Functional Exclusivity)
Operational status colors are strictly utilitarian and never used for aesthetic garnish:
- **Running / Operational (`#16A34A`):** Normal running states, active GPIO relays, heartbeat pulse, and acknowledged nominal states.
- **Standby / Warning (`#D97706`):** Approaching operating thresholds, non-critical sensor drift, calibration pending, or auto-throttle states.
- **Fault / Emergency STOP (`#DC2626`):** Hard faults, hardware interrupt halts, manual E-STOP trips, and network timeouts.

## Typography

The type system separates general UI cognition from critical telemetry consumption:
- **Inter** provides high-legibility, neutral typographic clarity for supervisory navigation, form controls, statuses, and alarms.
- **JetBrains Mono** serves as the strict instrumentation face. All numerical telemetry (analog reads, register addresses, PWM frequencies, packet timing, voltages, temperatures) must render in monospaced tabular figures to eliminate visual jitter during real-time screen re-renders.

## Layout & Spacing

The layout follows a deterministic, dense multi-column SCADA grid engineered for fixed operator dashboards, wall monitors, and rugged tablet displays.

- **Grid System:** 12-column modular grid with standard `1rem` gutters for administrative screens, switching to `gutter-compact` (`0.5rem`) within high-density telemetry walls.
- **Screen Adaptation:** 
  - **Desktop / Wall Console (1280px+):** Fixed full-height operational dashboard; split pane with fixed left-hand device/bus navigation and right-hand telemetry and actuator workspace.
  - **Rugged Tablet (768px - 1024px):** 2-to-4 column modular flow. Action buttons expand to hit targets no smaller than 48px to accommodate gloved operation.
  - **Mobile Diagnostics (<768px):** Single-column stacked telemetry stack with pinned emergency stop and critical node status headers.

## Elevation & Depth

This system avoids heavy, atmospheric shadows to maintain crisp visibility under varying ambient lighting conditions. Visual hierarchy relies on **crisp structural outlines and flat surface tinting**:

- **Floor Surface:** Flat light canvas (`#F8FAFC`).
- **Surface Level 1 (Panels & Cards):** Pure white (`#FFFFFF`) framed with a 1px border (`#E2E8F0`). Zero drop shadow.
- **Surface Level 2 (Active/Selected Panels):** White surface framed with a 1px border (`#CBD5E1`) and a discrete 2px solid boundary line on the leading edge (colored by functional state or `#0284C7`).
- **Surface Level 3 (Modals & Overlays):** `#FFFFFF` with a thin keyline border (`#0F172A` at 12% opacity) and a clinical drop shadow: `0 4px 12px rgba(15, 23, 42, 0.08)`.
- **System Masthead:** Flat `#0B192C` with border-bottom of 1px solid `#1E3E62`.

## Shapes

The interface embraces a functional, mechanical geometry. Roundedness level `1` (0.25rem standard radius) gives UI elements disciplined, technical boundaries that reflect industrial sheet metal and panel-mount hardware.

- Standard buttons, metric cards, inputs, and tabs use `rounded-sm` (4px).
- Status pills, LEDs, and hardware pin indicators maintain distinct circular geometries (50% radius) solely to signal their role as physical state indicators.

## Components

### Buttons & Actuators
- **Primary Industrial Button:** Dark Navy (`#0B192C`) background, white text, 4px border radius, 40px height for desktop / 48px for touch panels. Focus state adds a 2px outer offset ring in `#0284C7`.
- **Active State Toggle:** Slate border (`#CBD5E1`), white background. When toggled ON, fills with `#0284C7` and white label.
- **E-STOP / Emergency Button:** High-visibility Ruby Red (`#DC2626`) fill, white bold sans-serif text, uppercase, min-width 120px. On hover/active, darkens to `#B91C1C`. Never uses soft transitions; state changes are immediate (0ms transition).

### Telemetry Cards
- Encased in 1px `#E2E8F0` solid borders.
- Top section contains uppercase `label-caps` in `#64748B`, hardware channel ID in `label-code`, and operational status dot (8px).
- Center displays `metric-xl` values in JetBrains Mono (`#0F172A`) paired with standard engineering unit symbols (e.g., `mA`, `V`, `°C`, `RPM`, `bar`).

### Status Badges & Chips
- Compact height (20px - 24px) with 2px corner radius.
- Backgrounds use 10% tint of the operational color with solid 1px border of the parent hue:
  - Nominal: `#DCFCE7` background, `#16A34A` border and text.
  - Alert: `#FEF3C7` background, `#D97706` border and text.
  - Fault: `#FEE2E2` background, `#DC2626` border and text.

### Form Inputs & Setpoint Steppers
- Clean rectangular fields with 1px `#CBD5E1` borders, pure white background, and JetBrains Mono input values for numerical accuracy.
- Stepper buttons (+ / -) feature tactile active down-press feedback (`#E2E8F0` background on active click).

### Hardware Pin & Bus Matrices
- Dedicated visual layout for ESP32 GPIO status: compact tabular grid listing pin numbers, logical assignments (ADC, DAC, I2C, SPI), and real-time HIGH/LOW logic states with green/slate digital indicators.