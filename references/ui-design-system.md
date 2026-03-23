# UI Design System — Reference

Design system là single source of truth cho UI: tokens, components, patterns, guidelines.
Khác với frontend architecture — đây là về ngôn ngữ thiết kế và governance, không phải code structure.

---

## 1. Anatomy of a Design System

```
Design System
├── Foundation (Design Tokens)
│   ├── Color           → brand, semantic, neutral, state palettes
│   ├── Typography      → scale, font families, weights, line-height
│   ├── Spacing         → 4px hoặc 8px base grid
│   ├── Elevation       → shadow levels (4–6 stops thường đủ)
│   ├── Border radius   → none / sm / md / lg / full
│   ├── Motion          → duration, easing curves
│   └── Z-index         → named layers (modal, tooltip, dropdown...)
│
├── Components
│   ├── Atoms           → Button, Input, Icon, Badge, Avatar, Spinner
│   ├── Molecules       → SearchBar, FormField, Card, Toast, Tooltip
│   └── Organisms       → Header, Sidebar, DataTable, Modal, CommandPalette
│
├── Patterns (UX behaviors)
│   ├── Navigation      → tabs, sidebar, breadcrumb, back behavior
│   ├── Forms           → validation timing, error states, async submit
│   ├── Data display    → empty states, loading skeletons, pagination
│   ├── Feedback        → toasts, banners, inline errors, progress
│   └── Overlays        → modal, drawer, popover, tooltip rules
│
└── Documentation
    ├── Usage guidelines (when to use / when NOT to use)
    ├── Accessibility notes per component
    ├── Do / Don't examples với screenshots
    ├── Changelog
    └── Migration guides
```

---

## 2. Design Tokens — 3 tầng bắt buộc

Token là named variables cho design decisions. **3 tầng giải quyết vấn đề khác nhau:**

```
Tầng 1: Primitive tokens (raw values — không dùng trực tiếp trong code)
  color.blue.500    = #3B82F6
  color.blue.600    = #2563EB
  spacing.4         = 16px
  font.size.lg      = 18px
  radius.md         = 8px

Tầng 2: Semantic tokens (intent-based — đây là cái dùng trong component)
  color.text.primary         = {color.gray.900}
  color.text.secondary       = {color.gray.600}
  color.bg.danger            = {color.red.50}
  color.border.interactive   = {color.blue.500}
  color.text.on-primary      = {color.white}
  space.component.padding-sm = {spacing.3}   ← 12px
  space.component.padding-md = {spacing.4}   ← 16px

Tầng 3: Component tokens (scoped — optional, dùng khi component cần override)
  button.primary.bg          = {color.bg.brand}
  button.primary.bg.hover    = {color.bg.brand-hover}
  button.border-radius       = {radius.md}
  input.border.color         = {color.border.default}
  input.border.color.focus   = {color.border.interactive}
```

### Tại sao cần đúng 3 tầng?

- **Đổi brand color** → chỉ đổi primitive, toàn bộ semantic/component tự cập nhật
- **Dark mode** → chỉ remap semantic layer, không đụng component
- **White-labeling** → đổi primitive per client/tenant
- **Thiếu semantic layer**: Component dùng `color.blue.500` trực tiếp → dark mode và theming phá vỡ hoàn toàn

### Edge cases với tokens

**Token circular reference**: `color.bg.primary = {color.bg.primary}` → Style Dictionary báo lỗi. Luôn resolve về primitive.

**Missing dark mode token**: Nếu semantic token chỉ define light mode mà quên dark → invisible text trên dark background. Enforce bằng CI lint.

**Alpha/transparent tokens**: Atlassian dùng approach này — `color.border.default = rgba(0,0,0,0.15)` thay vì hardcode hex. Lợi ích: tự blend với bất kỳ background nào. Cần thiết cho overlapping elements.

**Motion tokens và prefers-reduced-motion**:
```css
@media (prefers-reduced-motion: reduce) {
  --motion.duration.fast: 0ms;
  --motion.duration.normal: 0ms;
}
```
Nếu không handle → user có vestibular disorder bị ảnh hưởng.

### Token formats và tools

| Format | Dùng trong | Tool |
|--------|-----------|------|
| CSS custom properties | Web | Style Dictionary, Theo |
| JS/TS object | React, Vue | Style Dictionary |
| Figma variables | Design | Figma native (2023+) |
| Swift/Kotlin | iOS/Android | Style Dictionary |
| JSON (W3C DTCG format) | Source of truth | Token Studio |

**Style Dictionary** transform 1 JSON source → tất cả platforms. Nên set up từ đầu dự án.

**Token Studio** plugin cho Figma: Sync Figma variables ↔ token JSON. Cầu nối design–dev.

---

## 3. Component Library Architecture

### Step-by-step: xây component đúng cách

**Bước 1: Research phase**
- Inventory existing UI: Screenshot tất cả buttons, inputs, cards hiện tại
- Tìm inconsistencies: có bao nhiêu border-radius khác nhau? Bao nhiêu shade of blue?
- Audit lại trước khi xây mới

**Bước 2: Define component API trước khi code**
```tsx
// Define props interface trước
interface ButtonProps {
  variant: 'primary' | 'secondary' | 'ghost' | 'danger'
  size: 'sm' | 'md' | 'lg'
  isLoading?: boolean
  isDisabled?: boolean
  leftIcon?: ReactNode
  rightIcon?: ReactNode
  // Polymorphic: render as <a> khi có href
  as?: 'button' | 'a'
  href?: string
  // Spread HTML attrs
  onClick?: MouseEventHandler
}
```

**Bước 3: Xác định states cần design**

Mỗi interactive component cần đủ states:
```
Default → Hover → Focus (keyboard) → Active (pressed) → Disabled → Loading
```
Nếu thiếu Focus state → fail WCAG. Nếu thiếu Loading → user spam-click.

**Bước 4: Implement với accessibility built-in**
- Dùng semantic HTML trước (`<button>`, `<a>`, `<input>`)
- Thêm ARIA chỉ khi semantic HTML không đủ
- Test với keyboard trước khi test với mouse

### Headless vs Styled vs Copy-paste

**Headless** (Radix UI, Ark UI, Headless UI):
- Logic + a11y + ARIA: đã có
- Visual: tự style 100%
- Phù hợp: muốn design system riêng, team design mạnh
- Edge case: Radix Popover trên iOS Safari có bug với virtual keyboard — cần patch

**Styled** (MUI, Ant Design, Chakra UI):
- Visual mặc định: có sẵn
- Override: `sx` prop, `styled()`, theme override — nhưng có friction và specificity wars
- Phù hợp: B2B internal tools, team muốn ship nhanh

**Copy-paste** (Shadcn/ui model):
- Copy source code vào repo — own hoàn toàn
- Không bị lock vào package version
- Dễ customize vì code trong repo
- Trade-off: Nhận upstream bug fixes phải merge thủ công

### Versioning & distribution

| Approach | Phù hợp | Edge case cần handle |
|----------|---------|----------------------|
| npm private package | Nhiều repo/team | Breaking changes → semver, migration guide |
| Git submodule | Ít team | Sync phức tạp, dễ out of sync |
| Copy-paste (Shadcn) | 1 repo hoặc monorepo | Không tự nhận upstream fixes |
| Monorepo (Turborepo/Nx) | App + DS cùng repo | Build cache, circular dependencies |

**Breaking change policy**: Nên theo semver. Major version = breaking. Luôn có deprecation period + migration codemod nếu có thể.

---

## 4. Theming

### Light / dark mode — approaches

**Approach 1: CSS class toggle (recommended)**
```css
:root           { --color-bg: #ffffff; --color-text: #111827; }
[data-theme="dark"] { --color-bg: #111827; --color-text: #f9fafb; }
```
JS: `document.documentElement.setAttribute('data-theme', 'dark')`

**Approach 2: prefers-color-scheme**
```css
@media (prefers-color-scheme: dark) { :root { ... } }
```
Hạn chế: Không thể override bằng user preference trong app.

**Approach 3: Kết hợp (best)**
```css
/* OS default */
@media (prefers-color-scheme: dark) {
  :root:not([data-theme]) { --color-bg: #111827; }
}
/* User override */
[data-theme="dark"] { --color-bg: #111827; }
[data-theme="light"] { --color-bg: #ffffff; }
```

### Flash of incorrect theme (FOIT)

Problem: Page load với light mode, sau đó JS set dark mode → flash.  
Solution: Inline script trong `<head>` trước render:
```html
<script>
  const theme = localStorage.getItem('theme') ||
    (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
  document.documentElement.setAttribute('data-theme', theme)
</script>
```
Với Next.js: dùng `next-themes` library.

### Multi-theme / White-label

```
themes/
  base.css       → shared tokens
  default.css    → --color-primary: #3B82F6
  enterprise.css → --color-primary: #1D4ED8
  partner-a.css  → --color-primary: #7C3AED
```

**Edge cases white-label**:
- Logo, favicon, brand name → cần CMS hoặc config per tenant
- Email templates → cần generate per tenant
- Font → client có thể muốn font riêng, cần preload đúng

### Elevation trong dark mode

Light mode: dùng shadow để tạo depth  
Dark mode: shadow không hiệu quả trên dark background → **dùng màu sáng hơn** để tạo elevation

```css
/* Light mode */
--elevation-1: 0 1px 3px rgba(0,0,0,0.12);

/* Dark mode */
--elevation-1-bg: rgba(255,255,255,0.05);  /* overlay nhẹ */
```
Atlassian dùng approach này — check Carbon Design System của IBM cho reference.

---

## 5. Accessibility (A11y) Chi Tiết

### WCAG 2.1 AA — requirements thực tế

**Color contrast**:
- Text < 18pt: 4.5:1 minimum
- Text ≥ 18pt hoặc bold ≥ 14pt: 3:1
- UI components (border, icon): 3:1 với background
- Placeholder text: 4.5:1 (hay bị bỏ quên)
- Disabled elements: exempt khỏi contrast requirement

**Focus management — hay bị bỏ quên**:
```
- Modal open → focus trap bên trong modal
- Modal close → focus return về trigger button
- Route change → focus về main content (h1 hoặc main)
- Toast/notification → không steal focus, nhưng accessible qua screen reader
- Infinite scroll → không làm mất keyboard position
```

**Keyboard navigation pattern**:
```
Tab / Shift+Tab   → move between interactive elements
Enter / Space     → activate button
Escape            → close modal, dropdown, tooltip
Arrow keys        → navigate inside composite widget (menu, tabs, radio group)
Home / End        → first/last item in list
```

**ARIA anti-patterns hay gặp**:
- `role="button"` trên `<div>` khi có thể dùng `<button>` — sai
- `aria-label` trùng với visible text — thừa (nhưng không sai)
- `aria-hidden="true"` trên icon trong button mà không có text label — screen reader đọc trống
- `aria-live` region quá nhiều → screen reader nói không ngừng

**Correct icon button pattern**:
```html
<!-- Option 1: visually hidden text -->
<button>
  <svg aria-hidden="true">...</svg>
  <span class="sr-only">Close</span>
</button>

<!-- Option 2: aria-label -->
<button aria-label="Close dialog">
  <svg aria-hidden="true">...</svg>
</button>
```

### Testing accessibility

1. **Keyboard only**: Tháo chuột, navigate toàn bộ flow
2. **Screen reader**: VoiceOver (Mac/iOS), NVDA (Windows), TalkBack (Android)
3. **Automated**: axe-core (trong Storybook, Playwright, CI)
4. **Contrast checker**: Figma Plugin: Contrast, browser DevTools

---

## 6. Design-to-Code Workflow

### Step-by-step

```
Bước 1: Token setup
  Figma Variables → export JSON → Style Dictionary → CSS/JS/Swift/Kotlin

Bước 2: Component design
  Figma: design component với tất cả states, variants, responsive breakpoints
  Annotate: spacing (px), radius (px), state behaviors, interaction notes

Bước 3: Component code
  Implement component, consume tokens qua CSS vars
  Unit test với Testing Library

Bước 4: Storybook
  Story cho: default, variants, states, edge cases (long text, empty, error)
  Controls panel để test props interactively
  A11y addon để auto-check

Bước 5: Visual regression
  Chromatic: catch visual diffs trên mọi PR
  Review threshold: pixel diff > 0.1% → require approval

Bước 6: Release
  Bump version theo semver
  Update changelog
  Announce trong Slack/Notion với migration notes nếu breaking
```

### Storybook edge case stories — hay bị thiếu

```tsx
// Luôn viết story cho edge cases
export const LongText = { args: { label: 'Đây là một cái button có text rất dài không ngờ' } }
export const EmptyState = { args: { items: [] } }
export const Loading = { args: { isLoading: true } }
export const Disabled = { args: { isDisabled: true } }
export const RTL = { decorators: [(Story) => <div dir="rtl"><Story /></div>] }
export const SmallContainer = { decorators: [(Story) => <div style={{width: 200}}><Story /></div>] }
```

---

## 7. Governance — Hay Bị Bỏ Qua

### Contribution model

**Centralized**: 1 team owns DS, others submit requests  
Phù hợp: nhỏ, chất lượng cao, nhưng bottleneck  

**Federated**: Product teams contribute, DS team reviews  
Phù hợp: lớn, scale tốt hơn  

**Hybrid** (recommended cho >5 teams):
- DS team: foundation tokens, core atoms
- Product teams: contribute molecules, organisms
- Review process: RFC → design review → code review → merge

### Decision log

Mỗi "tại sao chọn X thay Y" nên được document:
```markdown
## ADR-003: Dùng Radix UI thay tự build

Date: 2024-03
Status: Accepted

Context: Cần accessible dropdown/select/tooltip...
Decision: Dùng Radix UI headless primitives
Consequences: +a11y tốt, +maintain thấp; -bundle size tăng 15kb
```

---

## 8. Khi nào xây vs mua

| Tình huống | Recommendation | Lý do |
|-----------|----------------|-------|
| Internal tool, team < 5 devs | Shadcn/ui hoặc MUI | ROI không đủ để xây từ đầu |
| Product với brand mạnh | Headless + custom tokens | Cần full control visual |
| SaaS nhiều tenant | Token-based theming từ đầu | White-label sau này đỡ đau |
| B2B dashboard | MUI hoặc Ant Design | Nhanh, table/chart components tốt |
| Mobile + Web | Design tokens shared, components riêng | Khác nhau quá nhiều về interaction |
| 3+ apps dùng chung | Monorepo với shared package | Dưới 3 app: overhead không xứng |

**Anti-pattern hay gặp**: Xây design system khi chưa có product thực — token và component thay đổi liên tục khi product chưa stable. Nên:
1. Build product trước với loose consistency
2. Extract patterns sau khi ổn định
3. Xây design system từ patterns đã có

---

## Checklist trước khi ship component mới

> 🔴 MUST = block ship | 🟠 SHOULD = fix trước prod | 🟡 NICE = tech debt

🔴 MUST:
- [ ] Keyboard accessible: Tab focus vào được, Enter/Space activate, Escape dismiss
- [ ] Color contrast ≥ 4.5:1 (text), ≥ 3:1 (UI elements, icons)
- [ ] Không dùng màu đơn thuần để convey information (phải có text/icon kèm)
- [ ] Focus indicator visible (không bị `outline: none` ẩn)

🟠 SHOULD:
- [ ] Tất cả states được design: default, hover, focus, active, disabled, loading, error
- [ ] ARIA roles và labels đúng (không thừa, không thiếu)
- [ ] Dark mode tested (không chỉ light mode)
- [ ] Responsive tại mobile breakpoint (320px minimum)
- [ ] Story viết đủ edge cases (long text, empty, error, loading)
- [ ] axe-core A11y check pass trong Storybook

🟡 NICE:
- [ ] RTL-ready (nếu app có plan hỗ trợ Arabic/Hebrew)
- [ ] Visual regression Chromatic approved
- [ ] Animation: `prefers-reduced-motion` respected
- [ ] Changelog updated với semantic version
- [ ] Migration guide nếu breaking change API

---

## 8. Animation & Motion Tokens

### Motion as a design system layer

```
Motion tokens define timing and easing — same as color and spacing:
  Not: "button transition 0.3s ease" hardcoded everywhere
  But: button uses --motion-duration-fast + --motion-easing-standard

Token structure:
  Duration tokens:
    motion.duration.instant:     50ms  — micro-interactions (checkbox)
    motion.duration.fast:       150ms  — small UI transitions (tooltip)
    motion.duration.normal:     250ms  — page transitions (drawer open)
    motion.duration.slow:       400ms  — complex animations (expansion)
    motion.duration.deliberate: 600ms  — onboarding, celebration

  Easing tokens:
    motion.easing.standard:     cubic-bezier(0.2, 0, 0, 1)    — enter/exit
    motion.easing.decelerate:   cubic-bezier(0, 0, 0.2, 1)    — entering view
    motion.easing.accelerate:   cubic-bezier(0.3, 0, 1, 0.8)  — leaving view
    motion.easing.emphasized:   cubic-bezier(0.2, 0, 0, 1)    — emphasized motion
    motion.easing.spring:       cubic-bezier(0.34, 1.56, 0.64, 1) — overshoot

CSS variables:
  :root {
    --motion-duration-fast: 150ms;
    --motion-duration-normal: 250ms;
    --motion-easing-standard: cubic-bezier(0.2, 0, 0, 1);
  }
  @media (prefers-reduced-motion: reduce) {
    :root {
      --motion-duration-fast: 0ms;
      --motion-duration-normal: 0ms;
      --motion-duration-slow: 0ms;
    }
  }

  .button { transition: background-color var(--motion-duration-fast) var(--motion-easing-standard); }
  .drawer { transition: transform var(--motion-duration-normal) var(--motion-easing-decelerate); }
```

### Motion design principles

```
1. Purpose: Every animation should communicate something
   Enter: element appearing → use decelerate easing (fast start, slow end = "landing")
   Exit: element leaving → use accelerate easing (slow start, fast end = "taking off")
   State change: stay in place, use standard easing

2. Appropriate duration:
   Small elements (icon, checkbox): 50-100ms
   Medium elements (tooltip, badge): 150-200ms
   Large elements (modal, drawer): 250-400ms
   Full-page transitions: 300-500ms
   Rule: Duration should feel proportional to element size

3. prefers-reduced-motion is non-negotiable:
   Some users have vestibular disorders — animation causes nausea/dizziness
   WCAG 2.1 AA: Provide option to disable
   Implementation: @media (prefers-reduced-motion) { duration = 0ms or instant }
   Test: Enable in OS settings, verify all animations disabled

4. No animation for its own sake:
   Avoid: Spinning logos, decorative particle effects
   Use: Only when it guides attention or communicates state change
```

---

## 9. Style Dictionary v4

### What changed in v4 (2024)

```
Style Dictionary v4 (September 2024): Complete rewrite
  ESM-first: No more CommonJS compatibility issues
  Async API: All transforms and format hooks are now async
  New config format: config.json → .tokens.json (DTCG format native)
  Composites: Design tokens can reference other tokens natively
  Better TypeScript: First-class TS support, typed config

Migration from v3:
  npm install style-dictionary@4
  Main breaking change: Config is now ESM module, not CommonJS
```

### v4 setup (current standard)

```javascript
// style-dictionary.config.mjs (ESM, not .js)
import StyleDictionary from 'style-dictionary'
import { register } from '@tokens-studio/sd-transforms'

// Register Token Studio transforms
register(StyleDictionary)

const sd = new StyleDictionary({
  source: ['tokens/**/*.json'],    // DTCG-format token files
  platforms: {
    css: {
      transformGroup: 'tokens-studio',
      prefix: 'app',
      buildPath: 'src/styles/tokens/',
      files: [{
        destination: 'variables.css',
        format: 'css/variables',
        options: { outputReferences: true },  // Use CSS var() references
      }],
    },
    js: {
      transformGroup: 'tokens-studio',
      buildPath: 'src/styles/tokens/',
      files: [{
        destination: 'tokens.ts',
        format: 'javascript/es6',
      }],
    },
    ios: {
      transformGroup: 'ios-swift',
      buildPath: 'ios/Styles/',
      files: [{ destination: 'StyleTokens.swift', format: 'ios-swift/class.swift' }],
    },
  },
})

await sd.buildAllPlatforms()

// tokens/color.json (W3C DTCG format)
{
  "color": {
    "blue": {
      "500": { "$type": "color", "$value": "#3B82F6" },
      "600": { "$type": "color", "$value": "#2563EB" }
    },
    "primary": {
      "$type": "color",
      "$value": "{color.blue.500}",   // References another token
      "$description": "Main brand color"
    }
  }
}

// npm run build-tokens → generates CSS vars, TS, Swift from single source
```
