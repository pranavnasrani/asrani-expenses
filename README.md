# Asrani Expenses

A family expense tracker for Android (Flutter + Firebase). Each family member signs in with Google and tracks their own spending in Singapore dollars.

## Features
- Log expenses by hand or by scanning a receipt (Gemini fills in title, amount, place, category and date).
- Monthly budgets: overall, cash vs card/digital, or by category. Budgets repeat every month until changed.
- Rollover: unspent money compounds month after month from the month you choose. Overspending is forgiven, never carried.
- Search, category filters, edit, delete with Undo, CSV/PDF export.
- Insights: breakdown by category, place or payment method, six-month trend, weekly AI note, and an AI assistant for questions.
- Light and dark themes.

## Run
```bash
flutter pub get
flutter run --dart-define=GEMINI_API_KEY=your_key
```

Demo mode runs every screen on sample data with no sign-in (debug and profile builds only):
```bash
flutter run --dart-define=DEMO_MODE=true
```

## Test
```bash
flutter test
```
`test/budget_calculator_test.dart` covers the budget and rollover rules; `test/widget_test.dart` drives the screens against the in-memory demo repository.

## Layout
- `lib/logic/budget_calculator.dart`: pure budgeting and rollover rules.
- `lib/data/`: `ExpenseRepository` with Firestore and demo implementations.
- `lib/screens/`, `lib/widgets/`: UI. Design rules are in `DESIGN.md`; product context in `PRODUCT.md`.
