---
name: Asrani Expenses
description: Tingkat Enamel. Budgets stack like a Peranakan tiffin carrier; unspent money settles in the jade Saved tier.
colors:
  jade-field: "#1E6F66"
  jade-field-dark: "#134A44"
  primary-container: "#BFE6DE"
  glazed-ground: "#F3F7F4"
  ground-dark: "#0F1715"
  enamel-white: "#FFFFFF"
  ink: "#16201E"
  ink-muted: "#46534F"
  track: "#E3EBE7"
  butter: "#F2C14E"
  on-butter: "#2A2005"
  cash-coral: "#D9607F"
  card-cobalt: "#2D4A8A"
  overall-ochre: "#B78516"
  over-red: "#B3261E"
  cat-food-tangerine: "#D9692A"
  cat-groceries-leaf: "#4F8A32"
  cat-bills-plum: "#7D4A93"
  cat-entertainment-teal: "#237F86"
  cat-health-rose: "#B8475A"
  cat-other-slate: "#5B6B7A"
typography:
  display:
    fontFamily: "Figtree, Roboto, sans-serif"
    fontSize: "45sp"
    fontWeight: 800
    letterSpacing: "-1.2px"
  title:
    fontFamily: "Figtree, Roboto, sans-serif"
    fontSize: "22sp"
    fontWeight: 700
  body:
    fontFamily: "Figtree, Roboto, sans-serif"
    fontSize: "14sp"
    fontWeight: 400
rounded:
  field: "14px"
  tier: "16px"
  sheet: "24px"
spacing:
  gutter: "16px"
  tier-gap: "8px"
  section: "28px"
components:
  tier-card:
    backgroundColor: "{colors.enamel-white}"
    rounded: "{rounded.tier}"
    padding: "12px 16px 14px"
  saved-tier:
    backgroundColor: "{colors.jade-field}"
    textColor: "{colors.enamel-white}"
    rounded: "{rounded.tier}"
  fab-add:
    backgroundColor: "{colors.butter}"
    textColor: "{colors.on-butter}"
    rounded: "{rounded.tier}"
  button-primary:
    backgroundColor: "{colors.jade-field}"
    textColor: "{colors.enamel-white}"
    rounded: "{rounded.field}"
    height: "52px"
---

# Asrani Expenses design

Source of truth for tokens is `lib/theme/app_theme.dart` (`AppTheme` color schemes plus the `Enamel` theme extension). This file describes the built world.

## Overview
An Operate-mode Android app built on Material 3 structure (navigation bar, one FAB, bottom sheets, snackbars). The world enters through palette, type, density and one signature move: budgets drawn as stacked enamel tiers, with compounded rollover held in a jade Saved tier at the base. Light theme is the default for daylight use in shops and hawker centres; dark is a first-class scheme.

## Colors
### Primary
Jade enamel (`jade-field`) owns the Home hero field, the Saved tier, primary buttons and selected states. In dark mode the field deepens and the Saved tier lightens to `#6CC3B6` with dark text.
### Secondary
Butter yellow is reserved for the Add FAB, the single primary action.
### Neutral
A glazed white ground tinted toward jade (never cream), enamel-white cards, and a jade-grey ink. Muted text stays at least 4.5:1 on the ground.
### Named Rules
- **One colour per category, everywhere.** `CategoryUtils.colorFor` decides it: the same colour in tiers, list badges and charts. Unknown categories hash into the enamel cycle.
- **Cash is coral, Card / Digital is cobalt, Overall is ochre.**
- **Red only means overspent.**

## Typography
Figtree for everything, mapped to Material roles; it follows the system font scale. Money always uses tabular figures (`tabular` in `app_theme.dart`).
### Hierarchy
The left-to-spend figure (display, 800) is the largest thing on any screen, and every label around it stays small and quiet. Screen titles use titleLarge, section headers titleLarge, list titles titleMedium.

## Layout
16dp gutters. Tiers are stacked 8dp apart. Sections get 28dp above and 4–8dp below. The FAB clearance is 96dp at the end of scroll views.

## Elevation & Depth
Flat enamel. Separation comes from tonal surfaces (ground vs enamel white vs surface containers), not shadows. Only the FAB and popovers carry Material elevation.

## Shapes
Fields and buttons 14dp, tier cards 16dp, sheets 24dp top corners, chips 10dp.

## Components
### Buttons
Filled jade for a screen's main action, outlined for secondary, text buttons for inline actions. Minimum height 52dp.
### Chips
ChoiceChips for category, payment method and date in the expense form; selected uses the jade container.
### Navigation
Material NavigationBar with four destinations: Home, Expenses, Budget, Insights. System Back returns to Home before leaving the app.
### Tier card (signature)
`TierCard` in `lib/widgets/tier.dart`: a 4dp painted rim in the bucket colour, label with a status ("S$ x left" or "S$ x over") at the right, a 12dp fill bar that animates with ease-out (instant when animations are disabled), then "spent of available" and "incl. S$ y saved".
### Saved tier (signature)
`SavedTier`: a jade band showing the compounded surplus and the net amount each earlier month added.

## Do's and Don'ts
### Do:
- Lead with what is left to spend.
- Explain carried money: tapping a tier opens its month-by-month history.
- Offer Undo instead of a confirm dialog for deletes.
### Don't:
- Use gradients, gradient text, glass or blur.
- Use red for anything but overspending or errors.
- Add a second FAB or move Add out of the FAB.
