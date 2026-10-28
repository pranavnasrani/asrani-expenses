# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users
Members of the Asrani family in Singapore. Each person signs in with their own Google account and tracks their own spending. Typical moment: standing at a till or walking out of a shop, phone in one hand, logging a purchase in a few seconds, or snapping a receipt to log later. Less often: sitting down at month end to see where the money went and whether the budget held.

## Product Purpose
A personal expense tracker that makes logging fast (manual entry or AI receipt scan) and makes monthly budgets honest. Success means each family member knows, at a glance, how much they have left to spend this month, including what they saved in earlier months.

## Positioning
Envelope-style monthly budgets with compounding surplus rollover: money left unspent stays yours and keeps accumulating month to month, while an overspent month is forgiven rather than punished. Budgets can be set overall, by payment method (cash vs card/digital), or by category.

## Operating Context
- One-handed phone use, frequently outdoors or in shops; quick entry matters more than dense analysis.
- Payment methods in use: Cash, Credit Card, Debit Card, PayNow, Other. "Card / Digital" groups every non-cash method.
- Currency is Singapore dollars (S$).
- Receipts are photographed and parsed by Gemini; images are stored inline as base64 in Firestore (no Firebase Storage).
- Month-end review: compare months, export CSV/PDF, ask the AI assistant questions about spending.

## Capabilities and Constraints
- Flutter app; Firebase Auth (Google sign-in) and Cloud Firestore, data under `users/{uid}`.
- Features: add/edit/delete expenses, receipt scan, place history autocomplete, custom categories, search, monthly budgets (overall / method / category) with rollover, analytics charts, AI chat over expenses, weekly AI insight, CSV/PDF export, light and dark themes, onboarding.
- Rollover rules (confirmed): compounding from the month rollover was switched on; only surplus carries forward (deficits are not carried); budgets repeat every month until changed.
- Gemini key is supplied at build time via `--dart-define=GEMINI_API_KEY`.
- iOS builds were previously abandoned; Android is the primary shipping target.

## Brand Commitments
- Name: "Asrani Expenses".

## Evidence on Hand
- No real testimonials, logos, or brand assets beyond the default launcher icons. Do not invent any.

## Product Principles
1. Logging an expense should take seconds and one thumb.
2. "What's left to spend" is the number that matters most; show it first and keep it truthful.
3. Rollover should be explainable: show where carried money came from.
4. Family-friendly, calm, never judgmental about spending.

## Accessibility & Inclusion
Inferred, not yet confirmed: family use likely includes older members, so keep comfortable text sizes that follow the system font scale, 48dp touch targets, sufficient contrast in both themes.
