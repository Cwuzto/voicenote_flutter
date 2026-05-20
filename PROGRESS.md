# Project Progress

Last updated: 2026-05-21

## Completed UX/Animation Improvements

### Sale Screen (`lib/features/sale/presentation/sale_screen.dart`)
- Added smooth transition for empty cart <-> cart content with `AnimatedSwitcher` (fade + slide).
- Added animated search/input bar behavior:
  - Collapsed search chip expands into full input on tap.
  - Auto-collapses when unfocused and empty.
  - Focus state now has subtle animated border/shadow.
- Improved action button animation in quick bar (mic/send state transitions).
- Enhanced cart item visual design:
  - Gradient card background, softer border, and shadow.
  - Better hierarchy for name, unit price, line total, quantity, and note.
  - Inline edit action for faster access.
- Added tap feedback (`AnimatedScale`) on quantity +/- controls.
- Added animated quantity and line-total updates.
- Added entrance animation for cart rows (stagger-like fade + upward motion).

### Edit Item Dialog (`_openEditLineDialog`)
- Replaced basic `AlertDialog` with a custom styled `Dialog`.
- Added clearer structure (header, content groups, action row).
- Added quantity controls with stronger visual affordance.
- Added live subtotal preview (`Tam tinh`) while editing.

### Bottom Panel UX (Quick Grid / Listening)
- Improved panel open/close transition with smoother fade + slide.
- Added outside-tap-to-close behavior when panel is visible.
- Added subtle backdrop blur + tint over content area when panel is open.

### Order Detail Screen (`lib/features/orders/presentation/order_detail_screen.dart`)
- Added animated expand/collapse for order line preview (`AnimatedSize`).
- Added animated toggle text for "Xem tat ca" / "Thu gon".
- Added custom route transition to `SaleScreen` (fade + slight slide).
- Route transition respects reduced-motion setting (`MediaQuery.disableAnimations`).

## Quality Checks
- Ran `dart format` on changed files.
- Ran `flutter analyze` on touched screens with no issues.

## Notes
- Changes focus on UX polish and animation consistency.
- No data model or repository behavior changes were introduced.
