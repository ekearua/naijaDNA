# Design System Strategy: The Authoritative Editorial

## 1. Overview & Creative North Star
The **Creative North Star** for this design system is **"The Digital Curator."** In an era of information fatigue, this system is designed to feel like a high-end physical broadsheet reimagined for a glass screen. It rejects the frantic, cluttered layouts of traditional news aggregators in favor of a "Quiet Authority." 

The system breaks the "template" look by using intentional white space as a structural element, asymmetrical content clusters, and a sophisticated interplay between two distinct typographic worlds: the classic elegance of editorial serif and the functional clarity of a modern sans-serif. Every element is designed to feel "placed" rather than "pushed" into a grid.

## 2. Colors
Our palette is anchored in the heritage of Nigerian Green (#008751), but it is executed with tonal depth to avoid a flat, "corporate" appearance.

*   **Primary Palette:** `primary` (#006b3f) and `primary_container` (#008751). These are the pillars of the brand’s authority. Use them for high-intent actions and brand-defining moments.
*   **Surface & Background:** The foundation is `background` (#f9f9f8), a slightly off-white "paper" tone that reduces eye strain and feels more premium than pure white.
*   **The "No-Line" Rule:** Visual hierarchy is achieved through background color shifts, never 1px solid borders. For example, a card should be `surface_container_lowest` (#ffffff) sitting on a `surface_container` (#edeeed) background. 
*   **Surface Hierarchy & Nesting:** Use the tiers of `surface_container` to create depth. A `surface_container_high` should hold interactive elements, while `surface_container_low` defines secondary sectioning.
*   **The "Glass & Gradient" Rule:** Use `primary` to `primary_container` gradients on hero CTAs to add "soul." For floating overlays (like truth-score badges on top of images), use a backdrop-blur (12px-20px) with `surface_variant` at 80% opacity to create a frosted glass effect.

## 3. Typography
The system utilizes two distinct typefaces to create a professional contrast between "The Story" and "The Interface."

*   **Editorial Authority (Newsreader):** Used for all `display` and `headline` scales. This serif font communicates prestige and history. Large `display-lg` headings should be treated with generous leading (1.1) to feel like a premium magazine.
*   **Functional Clarity (Work Sans):** Used for `title`, `body`, and `label` scales. This provides a high-contrast, modern pairing that ensures legibility in dense article text and UI metadata.
*   **Visual Hierarchy:** Titles (`title-lg`) are bold and dense to grab attention, while `body-md` is optimized with a slightly wider line height (1.5) for long-form reading comfort.

## 4. Elevation & Depth
We eschew the standard "shadow-everything" approach for **Tonal Layering**.

*   **The Layering Principle:** Stack containers based on their surface tokens. A `surface_container_lowest` (white) element against a `surface` (#f9f9f8) background provides all the "lift" needed for a clean editorial look.
*   **Ambient Shadows:** Where floating is required (e.g., a "Live" news FAB), use an extra-diffused shadow: `box-shadow: 0 12px 32px rgba(25, 28, 28, 0.06)`. This mimics soft, natural gallery lighting.
*   **The "Ghost Border":** If containment is required for accessibility, use `outline_variant` (#bdcabe) at 20% opacity. High-contrast, 100% opaque borders are strictly forbidden.
*   **Glassmorphism:** Navigation bars and sticky headers must use `surface_container_lowest` with a 70% opacity and a `backdrop-filter: blur(20px)` to allow content to bleed through softly as the user scrolls.

## 5. Components

### News Cards
*   **Construction:** Large imagery with a `xl` (0.75rem) corner radius. Use `surface_container_lowest` for the card background.
*   **Spacing:** Use `spacing-4` (1rem) for internal padding.
*   **Constraint:** No borders. Use a soft `surface_dim` background for the card's parent container to create separation.

### Truth-Score Badge (Fact-Check)
*   **Styling:** Pill-shaped (`rounded-full`). 
*   **Color:** `primary_container` (#008751) background with `on_primary` (#ffffff) text.
*   **Overlay:** When placed over images, use the frosted glass rule (80% opacity + blur) to ensure the green feels integrated into the photo.

### Category Chips
*   **In-Active:** `secondary_container` (#e1e3e0) background with `on_secondary_container` text.
*   **Active:** `primary` (#006b3f) background with `on_primary` (#ffffff).
*   **Shape:** `rounded-md` (0.375rem) to maintain a modern, professional structure.

### Buttons & Inputs
*   **Primary Button:** `primary` background with `on_primary` text. Corners should be `DEFAULT` (0.25rem) for a sharper, more authoritative look than rounded "bubble" buttons.
*   **Input Fields:** Use `surface_container_low` backgrounds. Labels should be `label-md` using `on_surface_variant`. Avoid boxing inputs; use a bottom-weighted `outline_variant` (20% opacity).

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical spacing (e.g., `spacing-8` on the left and `spacing-6` on the right) to create a bespoke editorial feel.
*   **Do** prioritize the Nigerian Green (`primary`) for success states and authoritative markers (like Fact-Checking).
*   **Do** use `Newsreader` for quotes and pull-out text within articles to break the monotony of body text.

### Don't
*   **Don't** use solid black (#000000) for text; always use `on_background` (#191c1c) for a softer, more premium reading experience.
*   **Don't** use divider lines between news items in a list. Use `spacing-6` or `spacing-8` to let the white space act as the separator.
*   **Don't** use standard Material shadows. If it looks like a default Android app, it has failed the "Digital Curator" North Star.