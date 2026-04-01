# Design System Document: High-End Editorial Admin

## 1. Overview & Creative North Star
**The Creative North Star: "The Digital Curator"**

This design system moves beyond the utility of a standard CMS to embody the authority of a prestigious newsroom. We are not building a generic "dashboard"; we are crafting a sophisticated operational environment that feels as structured as a broadsheet newspaper and as fluid as a modern digital experience. 

By utilizing intentional asymmetry, high-contrast typography scales, and a departure from traditional "boxed" UI, we create a sense of **Editorial Trust**. The interface should feel "composed" rather than "assembled." We break the template look by prioritizing white space as a structural element and using tonal layering to guide the editor’s eye through complex workflows without visual clutter.

---

## 2. Colors & Surface Philosophy

The palette is rooted in a heritage green (`primary: #005137`) and a warm, paper-like foundation (`background: #fff8f3`).

### The "No-Line" Rule
To achieve a premium editorial feel, **1px solid borders are prohibited for sectioning.** We do not "box" content. Instead, boundaries must be defined through:
*   **Background Shifts:** Transitioning from `surface` to `surface-container-low` to define a new functional area.
*   **Vertical Rhythm:** Using the Spacing Scale (specifically `8` and `12` tokens) to create clear, breathable separation.

### Surface Hierarchy & Nesting
Treat the UI as a series of stacked, fine paper sheets. Importance is signaled by "lifting" or "recessing" surfaces using the following tiers:
*   **Surface (Base):** The primary canvas for page content.
*   **Surface-Container-Low:** For secondary sidebars or global navigation.
*   **Surface-Container-Highest:** For active utility panels or focused editing zones.
*   **Nesting Rule:** An inner container must always be at least one tier higher or lower than its parent to create organic depth.

### The "Glass & Gradient" Rule
For floating elements (modals, dropdowns, or "Live Preview" snackbars), use **Glassmorphism**. Apply `surface` at 80% opacity with a `backdrop-filter: blur(12px)`. 

### Signature Textures
Main CTAs and high-level headers should utilize a subtle linear gradient: `primary (#005137)` to `primary-container (#0f6b4b)`. This prevents the "flat-and-cheap" look of digital-only platforms and adds a tactile, ink-like depth.

---

## 3. Typography

Typography is our primary tool for establishing authority. We pair the intellectual weight of a serif with the operational precision of a sans-serif.

*   **Display & Headlines (Newsreader/Merriweather):** Used for Page Titles (`2.25rem` to `3.5rem`) and App Titles. The serif font acts as the "Editorial Voice"—it is authoritative, trustworthy, and traditional.
*   **UI & Titles (Inter):** Used for section headers and functional labels. The high x-height of Inter ensures legibility in dense operational environments like article grids or audit logs.
*   **Body (Inter):** Fixed at `15px` (approx. `0.9375rem`) for editorial text entry. This ensures that what the editor sees in the admin closely mimics the reading experience on the front-end.
*   **Meta & Labels (Inter):** Small, high-contrast caps or medium weights (`0.6875rem` to `0.75rem`) are used for timestamps, word counts, and status indicators.

---

## 4. Elevation & Depth

We reject traditional drop shadows in favor of **Tonal Layering**.

*   **Layering Principle:** To "lift" a card (e.g., a story card in a list), place a `surface-container-lowest` card on top of a `surface-container-low` background. This creates a soft, natural edge.
*   **Ambient Shadows:** If a floating element is required, use a "Newsroom Shadow":
    *   `box-shadow: 0 12px 32px -4px rgba(29, 27, 24, 0.06);`
    *   The shadow color is derived from `on-surface` (#1d1b18), never pure black, to simulate natural ambient light on paper.
*   **The "Ghost Border" Fallback:** For accessibility in input fields or search bars, use the `outline-variant` token at **20% opacity**. This creates a "suggestion" of a boundary without breaking the airy, editorial aesthetic.

---

## 5. Components

### Buttons
*   **Primary:** Gradient fill (`primary` to `primary-container`), white text, `12px` radius. High-intent actions only (e.g., "Publish").
*   **Secondary:** `surface-container-highest` background with `on-surface` text. For navigational actions.
*   **Tertiary:** No background. `primary` text weight 600. For "Cancel" or "Go Back."

### Input Fields
*   **Style:** `14px` radius, `surface-container-lowest` fill. 
*   **Focus State:** A 2px "Ghost Border" using `primary` at 40% opacity. Avoid heavy glow effects.

### Editorial Cards & Lists
*   **Rule:** **Forbid divider lines.** 
*   **Implementation:** Separate list items using a `spacing-4` (1rem) gap. Use a `surface-variant` background on hover to indicate interactivity.
*   **Content:** Lead with the Serif Headline (`headline-sm`) to prioritize the story over the metadata.

### Relevant Custom Components
*   **The "Status Quill":** A specialized Chip for workflow states (Draft, Review, Published). Use `secondary-container` (Amber) for "Review" and `primary-fixed` (Light Green) for "Published," always with `0.5` spacing for internal padding.
*   **The Audit Rail:** A thin, `surface-container-low` vertical strip on the right-side of the editor for metadata, preventing it from cluttering the main writing space.

---

## 6. Do’s and Don’ts

### Do
*   **Do** prioritize "Reading Gravity." Align text-heavy components to a clear vertical axis.
*   **Do** use asymmetrical layouts. For example, a 12-column grid where the main content occupies 7 columns and the metadata 3, leaving 2 columns of "white space" for visual breathing room.
*   **Do** use `primary` (Deep Green) sparingly to highlight "Truth" and "Action" (Verified badges, Publish buttons).

### Don't
*   **Don't** use 100% black text. Always use `on-surface` (#1d1b18) for a softer, premium ink-on-paper feel.
*   **Don't** use standard "Material Design" shadows. They feel too "app-like" and degrade the editorial sophistication.
*   **Don't** use dividers between cards. If the layout feels messy, increase your spacing tokens rather than adding lines.
*   **Don't** use fully opaque borders on inputs. They create visual "noise" that distracts from the content.