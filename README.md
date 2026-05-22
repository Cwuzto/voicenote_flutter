# voicenote

A Flutter point-of-sale and voice-assisted order entry app.

## Current Status
- UI/UX polish now includes Sale, Order Detail, Main Shell navigation, shared app backgrounds, and dialog/bottom-sheet consistency updates.
- Recent progress also includes Orders sticky-header fixes, More-screen save UX improvements, and performance tuning across Sale, Orders, Dashboard, Product List, and Best Seller screens.
- Supabase MCP connectivity has been verified for the current project.
- Demo data now includes a restaurant-style Vietnamese seed set for `bao@gmail.com`, with seasonal order history from `2025-05-01` to `2026-05-22`.
- The orders repository has been updated to avoid `400 Bad Request` failures when loading large order histories.
- Progress details are tracked in [PROGRESS.md](./PROGRESS.md).

## Demo Data

- Main demo seed guide: [supabase/DEMO_SEED.md](./supabase/DEMO_SEED.md)
- Canonical reseed SQL: `supabase/sql/008_reseed_bao_grocery_demo.sql`

## Getting Started

This project is a starting point for a Flutter application.

Useful resources:
- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

