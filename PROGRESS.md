# Project Progress

Last updated: 2026-05-23

## Latest Backend / Data Progress

### Supabase MCP
- Confirmed Supabase MCP is connected and authenticated for the current project.
- Verified live access by reading project URL and listing database tables through MCP tools.

### Demo Data / Seed Refresh
- Reset and reseeded demo business data while keeping `auth.users` intact.
- Added a new canonical seed flow for Bao's grocery demo:
  - `supabase/sql/008_reseed_bao_grocery_demo.sql`
  - `supabase/scripts/reseed_demo.ps1`
  - `supabase/DEMO_SEED.md`
- Seed data now targets the owner account `bao@gmail.com`.
- Demo dataset now covers `2025-05-01` through `2026-05-22`.
- Expanded demo content to better fit the app's current POS / grocery scenario:
  - 1 store
  - 3 employees
  - 16 products
  - 3 bank accounts
  - 4 speaker templates
  - 1600+ orders with seasonal variation
- Demo content was updated from plain ASCII labels to Vietnamese display text with diacritics for store names, people, products, customers, notes, and speaker templates.

### Orders Data Loading Fix
- Investigated `PostgrestException` / `400 Bad Request` on the orders screen using Supabase API logs.
- Identified the root cause as an oversized `order_id=in.(...)` request when fetching `order_items` for many orders at once.
- Updated `lib/features/orders/data/order_repository.dart` to fetch `order_items` via nested relation selection inside the `orders` query instead of issuing a second oversized `inFilter` request.
- Ran `dart format` and `dart analyze` on the updated repository with no issues.

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
- Added outside-tap-to-close behavior for quick grid.
- Removed backdrop blur overlay based on UX feedback.
- Updated listening layout: quick bar is shown above the listening panel.
- Removed spacing gap between quick bar and listening panel.

### Order Detail Screen (`lib/features/orders/presentation/order_detail_screen.dart`)
- Added animated expand/collapse for order line preview (`AnimatedSize`).
- Added animated toggle text for "Xem tat ca" / "Thu gon".
- Added custom route transition to `SaleScreen` (fade + slight slide).
- Route transition respects reduced-motion setting (`MediaQuery.disableAnimations`).

## Quality Checks
- Ran `dart format` on changed files.
- Ran `flutter analyze` on touched screens with no issues.

## Main Shell / Navigation Polish

### Main Shell (`lib/features/main/presentation/main_shell_screen.dart`)
- Reworked bottom navigation into a custom floating shell-style navbar.
- Improved tab switching animation by moving from abrupt screen swaps to animated page transitions.
- Added safer `PageController` initialization to avoid hot-reload `LateInitializationError`.
- Added body background fallback behind page transitions to reduce flicker during tab changes.
- Moved navbar into an overlay inside the shell body so hidden state no longer reserves blank space.
- Added auto hide/show behavior for navbar:
  - Scroll up / reverse scroll hides navbar downward.
  - Scroll down / forward scroll reveals navbar again.
  - Hide/show uses `AnimatedSlide` + `AnimatedOpacity`.

### Navigation CTA / Sale Entry
- Refined the center `Ban hang` action styling to better match the rest of the navbar.
- Removed overly heavy blue emphasis based on visual feedback.
- Kept the sale action visually distinct without breaking overall balance.

## Shared Background System

### Shared Gradient Background (`lib/core/widgets/gradient_background.dart`)
- Consolidated the main app background into a reusable shared gradient widget.
- Updated gradient stops and decorative glow shapes for stronger visual depth.
- Applied shared background consistently across primary screens instead of maintaining separate per-screen gradients.
- Kept `MainShellScreen` itself neutral while individual app screens render the shared gradient.

### Theme Updates (`lib/core/theme/app_theme.dart`)
- Tuned scaffold base color so non-gradient surfaces feel less flat.
- Added shared theming for dialogs, bottom sheets, date pickers, and popup menus.

## Dialog / Bottom Sheet UX Refresh

### Shared Dialog Helpers (`lib/core/widgets/app_dialogs.dart`)
- Added reusable `showAppOptionSheet<T>()` for consistent action/filter selection sheets.
- Added reusable `showAppConfirmDialog()` for destructive and confirmation flows.
- Standardized sheet presentation with:
  - rounded surface
  - stronger spacing and hierarchy
  - selected-state styling
  - better destructive action treatment

### Updated Screens Using Shared Dialog Patterns
- Dashboard overview range picker now uses shared option sheet.
- Best seller sort/time filters now use shared option sheet.
- Orders status/time filters now use shared option sheet.
- Orders payment confirmation now uses shared confirm dialog.
- Product delete confirmation now uses shared confirm dialog.
- Bank account action sheet and delete confirmation now use shared shared dialog helpers.
- Employee delete confirmation now uses shared confirm dialog.
- Speaker template delete confirmation now uses shared confirm dialog.

### Dialog Layout Improvements
- Large form dialogs were updated to use `scrollable: true` where appropriate to reduce overflow risk on smaller screens.
- Product add/edit dialog was redesigned from a basic `AlertDialog` into a more structured custom `Dialog` with:
  - icon-led header
  - clearer section labels
  - improved price control layout
  - cleaner action row

## Product Screen Updates

### Product List Screen (`lib/features/products/presentation/product_list_screen.dart`)
- Connected FAB position to navbar visibility using a `ValueListenable`.
- FAB behavior now animates smoothly:
  - navbar visible -> product FAB sits at bottom `65 + safe area`
  - navbar hidden -> product FAB slides down to bottom `0 + safe area`
- Simplified product FAB to icon-only `+` based on UX feedback.
- Updated product add/edit dialog visual design and removed extra hint/misc copy that made the dialog feel noisy.

## Latest Interaction UX Updates
- Keyboard dismissal: tap outside input now hides keyboard.
- Keyboard positioning: quick bar moves up to sit right above keyboard when opened.
- Voice UX:
  - While listening, the mic button in quick bar becomes a cancel button.
  - Removed redundant cancel button from listening panel UI.

## Latest UI / UX Progress

### Orders Screen (`lib/features/orders/presentation/order_list_screen.dart`)
- Fixed sticky date header behavior so day sections no longer stack vertically while scrolling.
- Grouped each sticky date header with its own order sliver content using `SliverMainAxisGroup`.
- Restored sticky header layout after experimenting with transparent backgrounds:
  - header remains a separate row between filters and order cards
  - pinned geometry is stable again
  - current visual state uses scaffold-colored background, divider, and light shadow when overlapping content
- Fixed a regression where the optimized order list could appear empty:
  - invalidated visible-order cache correctly when store data, filters, or search state change
  - added safer cache reuse checks beyond simple list reference identity

### Main Navigation Labels
- Updated bottom navbar labels to proper Vietnamese with diacritics:
  - `Tổng quan`
  - `Sản phẩm`
  - `Bán hàng`
  - `Hóa đơn`
  - `Nhiều hơn`

### More Screen UX

#### Personal Info (`lib/features/more/presentation/profile_screen.dart`)
- Improved save experience for profile editing:
  - save button is disabled until there is a meaningful change
  - inline success and error status cards were added above the form
  - added unsaved-change / synced-state helper text
  - keyboard now dismisses before save
  - baseline field values are refreshed after save so the form visibly returns to a clean state

#### Store Info (`lib/features/more/presentation/store_info_screen.dart`)
- Applied the same UX improvements as personal info:
  - save only becomes active when data changes
  - inline success / error feedback
  - unsaved-change indicator
  - save resets the clean baseline after success

#### More Home (`lib/features/more/presentation/more_screen.dart`)
- Returning from child screens now triggers a fresh data reload so updated profile/store state is reflected immediately on the main More screen.

### Sale Voice UI
- Removed the redundant `Thêm` button from the listening panel.
- Listening flow now auto-submits recognized content when parsing succeeds.
- If parsing is incomplete, recognized text remains editable in the input bar for fast correction.
- Refreshed the listening panel visual design with clearer transcript preview and lighter guidance copy.

## Latest Performance Work

### Sale Screen (`lib/features/sale/presentation/sale_screen.dart`)
- Reduced rebuild pressure during voice entry:
  - sound level animation now uses `ValueNotifier<double>` instead of `setState` on the whole screen
  - transcript preview in the listening panel now listens directly to the text controller
  - quick bar now listens to input/focus changes via `AnimatedBuilder` instead of forcing full-screen rebuilds on each keystroke
  - repeated voice-hint updates are now guarded so unchanged strings do not trigger extra rebuilds

### Orders Screen (`lib/features/orders/presentation/order_list_screen.dart`)
- Search results are now driven through `ValueListenableBuilder<TextEditingValue>` instead of broad `setState` calls on every typed character.
- Added lightweight caching for filtered/grouped visible orders so unrelated UI updates do not repeatedly re-filter and regroup the full order list.

### Dashboard Overview (`lib/features/dashboard/presentation/overview_screen.dart`)
- Added cached overview snapshot computation for:
  - revenue amount
  - order count
  - chart render data
  - best-seller aggregation
- Dashboard now avoids rebuilding all statistics from raw paid orders on every widget build when filters and source data have not changed.

### Product List (`lib/features/products/presentation/product_list_screen.dart`)
- Removed per-character `setState` for search.
- Added grouped-product caching based on current query and product source data.

### Best Seller Screen (`lib/features/dashboard/presentation/best_seller_screen.dart`)
- Removed per-character `setState` for search.
- Added cached row aggregation keyed by search query, time filter, sort mode, and custom range.

## Notes
- Changes focus on UX polish, animation consistency, and reducing unnecessary rebuild work on high-traffic screens.
- Recent work now also includes sticky-header stability fixes, More-screen save UX polish, and several list/dashboard performance optimizations.
- Current optimization work has focused on Sale voice interactions, Orders list filtering/grouping, Dashboard stat aggregation, Product list search/grouping, and Best Seller search/aggregation.
