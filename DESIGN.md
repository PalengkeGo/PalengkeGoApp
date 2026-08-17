# Design

## Overview

PalengkeGo uses a clean utilitarian visual system shaped by local-market identity. The interface should feel practical first, with warmth and character carried through color, typography, and selective editorial energy rather than through decorative UI noise.

The design should support both customer shopping flows and vendor operations inside one coherent system. Shared structure and interaction patterns matter more than isolated visual cleverness.

## Visual Theme

- mobile-first
- bright surface-heavy layouts
- calm, deep-green brand identity
- restrained use of accent colors
- simple, trustworthy controls over decorative interfaces

The UI should feel usable in fast everyday contexts. It can be expressive in moments, but it should never become visually noisy or difficult to scan.

## Color Palette

### Core Colors

- Primary: `#0B372B`
- Accent Green: `#6D9773`
- Accent Yellow: `#FFB902`
- Surface Light: `#F6F8F7`
- Surface Container Low: `#F1F5F9`
- Surface Container: `#E2E8F0`
- Background: `#FFFFFF`
- On Surface: `#0B372B`
- On Surface Variant: `#64748B`

### Semantic Colors

- Success / Open: `#22C55E`
- Closed / Muted Status: `#94A3B8`
- Warning / Rating Accent: `#FFB902`
- Error / Delete: `#EF4444`
- Notification Badge: `#EF4444`

### Color Rules

- avoid pure black for primary text
- prefer emerald-tinted neutrals over cold default grays
- use yellow sparingly for ratings, promos, and select status moments
- use green to communicate positive action, availability, and completion
- use surface shifts and shadow before reaching for hard borders

## Typography

Primary family: `Plus Jakarta Sans`

### Type Scale

- Display: `24px`, `700`
- Headline: `20px`, `700`
- Subheadline: `16px`, `600`
- Body: `14px`, `400`
- Caption: `12px`, `500`
- Label: `12px`, `600`
- Micro: `9px` to `10px`, `600`

### Typography Rules

- use strong hierarchy through weight and size, not through many font families
- keep labels and metadata tight, but readable
- prioritize high legibility in shopping, checkout, and vendor management flows
- avoid typography that feels luxurious, editorial-first, or overly stylized

## Layout

- mobile-width constrained by default
- predictable scanning order
- restrained asymmetry when it adds energy, not confusion
- consistent section spacing with noticeable rhythm between groups
- avoid unnecessary nesting and card-within-card structures

### Radius Standards

- small: `8`
- medium: `12`
- large: `16`
- full: `50`

Use `16` as the dominant card/image radius unless there is a clear reason to go smaller.

## Elevation

### Shadow Guidance

- light interactive shadow for tappable surfaces
- medium card shadow for featured content or floating objects
- soft shadow over hard divider lines when possible

Shadows should feel gentle and functional, not dramatic.

## Components

### Buttons

- primary buttons use `#0B372B` with white text
- secondary actions use lighter surfaces or bordered treatments
- buttons should feel substantial and easy to tap on mobile

### Inputs

- search and text fields should sit on `Surface Light`
- rounded corners should typically use `12`
- focused inputs should use primary green emphasis

### Chips and Tabs

- selected state should be unmistakable through color and weight
- unselected states should remain quiet and legible
- avoid mixing too many chip/tab visual patterns across neighboring screens without reason

### Cards

- prefer single clean containers over nested card stacks
- use card treatments when grouping genuinely related content
- product and stall cards should stay easy to scan at small sizes

### Headers

- centered page titles are preferred where the flow expects a standard screen header
- back affordances should be consistent in shape, size, and padding
- avoid one-off header patterns unless the screen has a special role

## Motion

- use short, useful transitions
- avoid decorative motion that delays task completion
- page transitions and action feedback should feel smooth but quick
- reduced-motion-friendly behavior should be preserved wherever possible

## Content Style

- plain, direct labels
- helpful empty states
- concise status language
- avoid over-marketing copy inside operational screens

## Do

- keep the product easy to scan on mobile
- use consistent status colors and button roles
- prefer truthful dynamic data over plausible fake details
- maintain one shared product vocabulary across customer and vendor flows

## Do Not

- do not over-decorate operational screens
- do not rely on color alone for state meaning
- do not use random spacing, border radii, or shadow recipes
- do not let vendor flows drift into a different visual language from customer flows
