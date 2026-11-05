# Design System Specifications & Style Guide
**Target Audience:** Solution Architects, Sales Engineers, IT Administrators  
**Design Philosophy:** Enterprise B2B SaaS — clean, technical, high-contrast, data-dense yet breathable. Inspired by the Elastic brand and modern cloud management platforms.

---

## 1. Color Palette & Design Tokens

The palette is engineered around Elastic's brand blues, teals, and dark navy, backed by a soft slate canvas that avoids the harshness of pure white while maintaining high contrast and readability.

### 1.1 Core Brand Tokens

| Token Name | Hex Code | RGB | Role / Usage |
| :--- | :--- | :--- | :--- |
| `primaryBlue` | `#0077CC` | `rgb(0, 119, 204)` | Primary actions, focused inputs, active sidebar links, primary branding. |
| `tealAccent` | `#00BFB3` | `rgb(0, 191, 179)` | Secondary brand accent, ERU hero gradient, verified/success highlights. |
| `navyDark` | `#1B1C3A` | `rgb(27, 28, 58)` | Primary text, high-emphasis headers, dark hero cards (ERU card). |
| `slateLight` | `#F8FAFC` | `rgb(248, 250, 252)` | Canvas / Scaffold background (Slate-50), reduces glare and eye fatigue. |
| `surfaceWhite` | `#FFFFFF` | `rgb(255, 255, 255)` | Card backgrounds, input fills, desktop sidebar background. |
| `borderLight` | `#E2E8F0` | `rgb(226, 232, 240)` | Card borders, dividers, inactive input borders (Slate-200). |
| `textMuted` | `#64748B` | `rgb(100, 116, 139)` | Subtitles, descriptions, timestamps, secondary labels (Slate-500). |
| `pinkHot` | `#F04E98` | `rgb(240, 78, 152)` | Hot storage tier indicator, critical metrics. |
| `yellowWarm` | `#FEC514` | `rgb(254, 197, 20)` | Warm storage tier indicator, quick preset badges. |

### 1.2 Semantic & Status Tokens

Use soft background tints paired with matching saturated text and subtle borders for clear status communication without visual clutter:

| Status | Background Tint | Border Color | Text / Icon Color | Example Component |
| :--- | :--- | :--- | :--- | :--- |
| **Admin / RBAC** | `#FAF5FF` (Purple-50) | `#E9D5FF` (Purple-200) | `#7E22CE` (Purple-700) | `ADMIN` badge, access control pill, header icon. |
| **Basic / Neutral** | `#F1F5F9` (Slate-100) | `#E2E8F0` (Slate-200) | `#334155` (Slate-700) | `BASIC` badge, read-only metadata tags. |
| **Success / Valid** | `#ECFDF5` (Emerald-50) | `#A7F3D0` (Emerald-200) | `#047857` (Emerald-700) | `YOU` badge, password change success, download toasts. |
| **Warning / Notice** | `#FFFBEB` (Amber-50) | `#FDE68A` (Amber-200) | `#B45309` (Amber-700) | Reset password icon container, preset highlight. |
| **Danger / Delete** | `#FEF2F2` (Red-50) | `#FECACA` (Red-200) | `#B91C1C` (Red-700) | Form errors, delete modal, sign-out icon (`#EF4444`). |
| **Creator-Only** | `#F3F4F6` (Gray-100) | `#D1D5DB` (Gray-300) | `#4B5563` (Gray-600) | Lock badge for unmodifiable user accounts. |

---

## 2. Typography System

### 2.1 Font Family
- **Primary Font:** **Inter** (`GoogleFonts.inter` in Flutter / `font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif` in Web).
- **Numbers / Metrics:** Inter with tabular figures (`tnum`) for consistent digit alignment in tables and cards.

### 2.2 Type Scale Hierarchy

```
24px / Bold 800 (-0.5px tracking)  ── Page Header (Desktop)
20px / Bold 800 (-0.5px tracking)  ── Page Header (Mobile)
17px - 18px / Bold 700 - 800       ── Card Title / Modal Header
15px - 16px / SemiBold 700         ── Section / Table Group Header
14px / SemiBold 600                ── Primary Button Labels / Form Field Text
13px - 14px / Medium 500           ── Navigation Menu Items / Table Content
12.5px - 13px / Regular 400 - 500  ── Subtitles / Descriptive Paragraphs
12px / SemiBold 600 - 700          ── Form Field Floating Labels
11px / Medium 500                  ── Timestamps, Footers, Sub-captions
10px / Bold 700 - 800 (0.8px-1.1px) ── Category Eyebrows (UPPERCASE)
9px - 10px / ExtraBold 800         ── Pill Badges (ADMIN, BASIC, YOU)
```

---

## 3. Layout, Grid & Responsiveness

### 3.1 Breakpoints & Layout Modes
- **Desktop (`>= 850px`):** Fixed left sidebar (width `250px`), continuous scrollable canvas on the right.
- **Mobile / Tablet (`< 850px`):** Collapsed navigation via BottomNavigationBar or Drawer; content area expands to `100%` width with `16px` horizontal padding.

### 3.2 Content Max Width Containers
To maintain optimal readability and prevent forms/tables from stretching awkwardly on ultra-wide monitors:
- **Data Tables & User Lists:** `maxWidth: 1100px` (centered horizontally).
- **Form / Calculator Screens:** `maxWidth: 860px` (centered horizontally).
- **Authentication / Login Card:** `maxWidth: 420px` (centered vertically and horizontally).
- **Modals & Dialogs:** `maxWidth: 420px - 440px`.

---

## 4. Component Design Specifications

### 4.1 Navigation Sidebar (Desktop)
- **Width:** `250px`.
- **Background:** `#FFFFFF`.
- **Right Border:** `1px solid #E2E8F0`.
- **Header Section:**
  - Logo container: `40px x 40px`, rounded `10px`, border `1px solid #E2E8F0`, subtle shadow `0 2px 6px rgba(0,0,0,0.04)`.
  - App Name: `16px`, weight `800`, `#1B1C3A`, tracking `-0.4px`.
  - Sub-brand: `11px`, weight `500`, `#64748B`.
- **Category Overline:**
  - `padding: 20px 20px 10px 20px`.
  - Text: `MAIN NAVIGATION`, `10px`, weight `700`, uppercase, tracking `1.1px`, color `#64748B`.
- **Navigation Item:**
  - Height / Padding: `padding: 11px 14px`, border radius `8px`.
  - Inactive State: Transparent background, icon `#1B1C3A` at `70%` opacity, text `13.5px`, weight `500`, color `#1B1C3A`.
  - Active State: Background `rgba(0, 119, 204, 0.08)`, border `1px solid rgba(0, 119, 204, 0.20)`, icon `#0077CC`, text `13.5px`, weight `700`, color `#0077CC`.
- **Bottom User Card:**
  - Border top `1px solid #E2E8F0`.
  - User avatar: `34px x 34px` circle, background `rgba(0, 119, 204, 0.10)`, text initial `13px`, weight `800`, color `#0077CC`.
  - Username: `13px`, weight `700`, `#1B1C3A`, truncated.
  - Role Badge: `9px`, weight `700`, uppercase, rounded `4px`.
  - Quick action icon buttons: Change Password (`Icons.key_rounded`, `#0077CC`), Sign Out (`Icons.logout_rounded`, `#EF4444`).

---

### 4.2 Integrated Page Header (No Clunky AppBars)
Instead of standard colored toolbars, top-level pages use an integrated header directly inside the canvas:

```
[ EYEBROW CATEGORY PILL ]
Page Title (20-24px, Bold 800)                     [ Action Button ]
Descriptive subtitle explaining the purpose (13px, Slate-500)
```

- **Eyebrow Category Pill:**
  - Padding: `horizontal: 8px, vertical: 3px`.
  - Border Radius: `4px`.
  - Font: `10px`, weight `700`, letter spacing `0.8px`, uppercase.
  - Examples:
    - `ACCESS CONTROL & RBAC` (Purple theme)
    - `ELASTIC CLUSTER ARCHITECTURE` (Primary Blue theme)
    - `HISTORICAL ARCHIVES` (Teal theme)

---

### 4.3 Cards & Containers

#### Standard Card (White / Outline)
- **Background:** `#FFFFFF`.
- **Elevation:** `0` (avoid heavy drop shadows for clean enterprise feel).
- **Border:** `1px solid #E2E8F0`.
- **Border Radius:** `12px` (outer cards) / `10px` (list items).
- **Internal Padding:** `18px - 24px`.

#### Hero / High-Emphasis Card (Dark Navy)
Used for key summary anchors (e.g., ERU License Banner):
- **Background:** `#1B1C3A` (`navyDark`).
- **Border Radius:** `16px`.
- **Border:** None (or subtle `1px solid rgba(255, 255, 255, 0.1)`).
- **Gradient Accent Element:** Linear gradient `[#0077CC, #00BFB3]` with box-shadow `0 4px 10px rgba(0, 191, 179, 0.3)`.

---

### 4.4 Form Inputs & Controls

- **Text Inputs:**
  - Background Fill: `#FFFFFF`.
  - Height / Padding: `isDense: true`, content padding `14px 16px`.
  - Inactive Border: `1px solid #E2E8F0`, border radius `8px`.
  - Focused Border: `1.5px solid #0077CC`, border radius `8px`.
  - Error Border: `1px solid #EF4444`.
  - Label Placement: Outside input, positioned `5px` above field. Font `12px`, weight `600 - 700`, color `#1B1C3A`.
  - Hint Text: Color `#94A3B8`, font size `13px`.
- **Dropdowns / Select Fields:**
  - Matching rounded `8px`, same border states as text inputs.
- **Interactive Role Selectors (Pills):**
  - Clickable status pill with dropdown arrow: `[ BASIC ▾ ]`.
  - Mouse cursor: `SystemMouseCursors.click`.
  - Padding: `horizontal: 8px, vertical: 4px`.
  - Border Radius: `5px`.
  - Font: `10px`, weight `800`, uppercase.

---

### 4.5 Buttons

| Button Type | Background | Border | Text / Icon Color | Height / Padding | Corner Radius |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Primary** | `#0077CC` | None | `#FFFFFF` | `11px - 14px` V, `16px - 20px` H | `8px` |
| **Secondary / Outlined** | Transparent | `1px solid #E2E8F0` or `#0077CC` | `#0077CC` or `#64748B` | `10px - 12px` V, `14px - 16px` H | `8px` |
| **Danger / Delete** | `#DC2626` | None | `#FFFFFF` | `10px` V, `16px` H | `8px` |
| **Action Icon Button** | Transparent | None | `#0077CC` / `#EF4444` | Flat, `splashRadius: 18` | Circle |

---

### 4.6 Dialogs & Modals

- **Border Radius:** `14px`.
- **Shape:** Rounded rectangle, background `#FFFFFF`, elevation `8` or `16`.
- **Header Structure:**
  - Left icon badge: `36px x 36px`, rounded `8px`, with semantic color background (e.g. amber for password reset, purple for role change, red for delete).
  - Title: `17px`, weight `800`, color `#1B1C3A`.
- **Body:**
  - Max width constraint: `420px - 440px`.
  - Explanatory prompt: `12.5px`, color `#64748B`, line-height `1.35`.
  - Form controls with `12px - 14px` spacing.
- **Footer Actions:**
  - Aligned to bottom-right.
  - Left: `Cancel` text button (`#64748B`).
  - Right: Filled action button (`#0077CC` or `#DC2626`), with integrated loading indicator (`CircularProgressIndicator(strokeWidth: 2, color: Colors.white)`).

---

### 4.7 Badges & Status Indicators

```
┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────────┐
│   ADMIN   │  │   BASIC   │  │    YOU    │  │  Creator only │
└───────────┘  └───────────┘  └───────────┘  └───────────────┘
 Purple Tint    Slate Tint     Emerald Tint     Neutral Lock
```

1. **`ADMIN`:** Background `#FAF5FF`, Border `#E9D5FF`, Text `#7E22CE` (`9.5px - 10px`, Bold 800).
2. **`BASIC`:** Background `#F1F5F9`, Border `#E2E8F0`, Text `#334155` (`9.5px - 10px`, Bold 800).
3. **`YOU` (Current User Identifier):** Background `#ECFDF5`, Border `#A7F3D0`, Text `#047857` (`9.5px`, Bold 800).
4. **`Creator only` (Permission Safeguard):** Background `#F3F4F6`, Border `#D1D5DB`, Text `#4B5563`, prefixed with lock icon (`12px`).

---

## 5. Ready-to-Use Code Snippets

### 5.1 Flutter Theme Class (`theme.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Palette
  static const Color primaryBlue = Color(0xFF0077CC);
  static const Color tealAccent = Color(0xFF00BFB3);
  static const Color navyDark = Color(0xFF1B1C3A);
  static const Color slateLight = Color(0xFFF8FAFC);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get lightTheme {
    final interFont = GoogleFonts.inter().fontFamily;

    return ThemeData(
      useMaterial3: true,
      fontFamily: interFont,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: tealAccent,
        surface: Colors.white,
        onSurface: navyDark,
      ),
      scaffoldBackgroundColor: slateLight,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
    );
  }
}
```

---

### 5.2 CSS / Tailwind Design Tokens (`tailwind.config.js`)

If replicating this design system in web applications (React, Vue, Next.js, or HTML):

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: {
          blue: '#0077CC',
          teal: '#00BFB3',
          navy: '#1B1C3A',
          pink: '#F04E98',
          yellow: '#FEC514',
        },
        slate: {
          canvas: '#F8FAFC',
          card: '#FFFFFF',
          border: '#E2E8F0',
          muted: '#64748B',
        },
      },
      fontFamily: {
        sans: ['Inter', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
      },
      borderRadius: {
        card: '12px',
        dialog: '14px',
        input: '8px',
        badge: '4px',
      },
    },
  },
};
```

---

### 5.3 Raw CSS Custom Properties (`tokens.css`)

```css
:root {
  /* Brand Tokens */
  --color-primary-blue: #0077CC;
  --color-teal-accent: #00BFB3;
  --color-navy-dark: #1B1C3A;
  --color-pink-hot: #F04E98;
  --color-yellow-warm: #FEC514;

  /* Surfaces & Canvas */
  --color-canvas: #F8FAFC;
  --color-card: #FFFFFF;
  --color-border: #E2E8F0;
  --color-text-main: #1B1C3A;
  --color-text-muted: #64748B;

  /* Status Colors */
  --badge-admin-bg: #FAF5FF;
  --badge-admin-border: #E9D5FF;
  --badge-admin-text: #7E22CE;

  --badge-basic-bg: #F1F5F9;
  --badge-basic-border: #E2E8F0;
  --badge-basic-text: #334155;

  --badge-success-bg: #ECFDF5;
  --badge-success-border: #A7F3D0;
  --badge-success-text: #047857;

  /* Typography */
  --font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  
  /* Radii */
  --radius-input: 8px;
  --radius-card: 12px;
  --radius-dialog: 14px;
}
```

---

## 6. Golden Rules for Consistency

1. **Borders Over Shadows:** Never use heavy drop shadows (`box-shadow: 0 10px 25px ...`) for regular content cards. Use crisp `1px solid #E2E8F0` borders on pure white cards over the `#F8FAFC` slate canvas.
2. **Dense & Scannable:** Keep form controls compact (`isDense: true` or `padding: 10px - 12px`). Technical users prefer scannable interfaces over excessive whitespace.
3. **Eyebrow Category Pills:** Every major screen should feature an uppercase category pill (`10px`, weight `700`, letter spacing `0.8px`) above the main header to provide instant contextual hierarchy.
4. **Color-Coded Status Pills:** Never show plain text for roles or states. Always enclose statuses (`ADMIN`, `BASIC`, `YOU`) in rounded tinted pill boxes with a matching 1px border.
5. **No Clunky Full-Width AppBars:** Avoid full-width colored header bars. Let the canvas flow cleanly, integrating titles directly into the scrollable body alongside desktop sidebars.
