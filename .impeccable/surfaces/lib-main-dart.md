---
version: 1
slug: "lib-main-dart"
primary_target: "lib/main.dart"
related_targets: []
---

# Surface brief: Asrani Expenses app (all screens)

Scope: the whole Flutter app (Home, Expenses, Add/Edit, Budget, Insights, AI chat, Login, Onboarding, Settings). Mode: Operate. Platform: Android first (Material 3 structure).

Audience and job: Asrani family members logging spending one-handed in shops and hawker centres in Singapore daylight; month-end review of budgets.
Constraints: S$ currency; Material 3 navigation bar + one Add FAB; 48dp targets; follows system font scale; light theme default from the use scene (daylight, quick glances), dark theme first-class.

## Direction contract
THESIS: Budgets are tiers of a Peranakan enamel tingkat; unspent money settles in a jade Saved tier at the base and keeps compounding. Refuses the grey card + indigo accent budgeting dashboard.
OWN-WORLD: Full palette. Jade enamel shell (#1E6F66) owns the Home hero field and selected states; enamel coral pink, butter yellow, cobalt, and teal carry Cash, Card and categories; ground is pale glazed white tinted toward jade, never cream. Tiers are rounded 16dp enamel bands with a 4dp painted rim in their colour. Figtree, tabular numerals for money.
STORY: The visitor sees exactly how much is left, which tier is filling, and where saved money came from, then logs the next purchase in seconds.
FIRST VIEWPORT: Top: month title and view chip on the jade field; huge "S$ left to spend" figure (display, tabular) with budget and saved sub-line. Below: stacked tiers (fill bars), jade Saved tier last with month-by-month carry. Then recent expenses. Yellow Add FAB bottom-right above the navigation bar.
FORM: Tingkat Enamel, grounded candidate 7 of 7; seed:0bce212336c4d7e2
Signature move: the tier stack with the Saved tier, reused on Budget screen with carry history.
Raises kept: scale-contrast hierarchy (specimen); Undo and stamped closed months (ticket wallet); sticky month guide header with total (lexicon); one colour per category everywhere (Saville); tabular figures (timetable).
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
