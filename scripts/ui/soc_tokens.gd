class_name SocTokens
extends RefCounted
## Design tokens for the SOC interface (M8): colours, spacing, radii, borders,
## type sizes, focus outline and motion timing. Every SOC screen reads these and
## nothing else, so the design system screen is a faithful QA reference.
##
## Decision note: the M8 brief specifies this palette. The menus still use the
## 05 §2 `Palette`. Both coexist until the art bible and the brief are
## reconciled (see docs/architecture/M8_UI_SYSTEM.md, open item OI-1).

# --- colour ---------------------------------------------------------------
const BACKGROUND: Color = Color8(0x10, 0x12, 0x1B)
const SURFACE: Color = Color8(0x19, 0x1D, 0x2B)
const ELEVATED: Color = Color8(0x23, 0x2A, 0x3B)
const CYAN: Color = Color8(0x42, 0xD9, 0xF5)
const ULTRAVIOLET: Color = Color8(0x92, 0x75, 0xFF)
const AMBER: Color = Color8(0xF5, 0xB8, 0x4B)
const RED: Color = Color8(0xF0, 0x64, 0x72)
const GREEN: Color = Color8(0x63, 0xD6, 0x9B)
const TEXT: Color = Color8(0xF2, 0xF4, 0xFA)
const TEXT_MUTED: Color = Color8(0xA4, 0xAE, 0xC3)
## Component outline: 3.8:1 against SURFACE, so boundaries pass the 3:1 rule.
const BORDER: Color = Color8(0x6C, 0x7A, 0x99)
## Decorative dividers only. Never the sole indicator of anything.
const DIVIDER: Color = Color8(0x2E, 0x37, 0x50)

# High-contrast variant: pure black, white text, yellow focus.
const HC_BACKGROUND: Color = Color(0, 0, 0)
const HC_SURFACE: Color = Color(0.05, 0.05, 0.05)
const HC_ELEVATED: Color = Color(0.12, 0.12, 0.12)
const HC_TEXT: Color = Color(1, 1, 1)
const HC_ACCENT: Color = Color(1.0, 0.9, 0.0)
const HC_BORDER: Color = Color(1, 1, 1)

# --- severity -------------------------------------------------------------
## Severity is always shown as colour + text label + ASCII marker, never colour alone.
const SEVERITIES: Array[String] = ["critical", "high", "medium", "low", "info"]
const SEVERITY_LABELS: Dictionary = {
	"critical": "CRITICAL", "high": "HIGH", "medium": "MEDIUM", "low": "LOW", "info": "INFO",
}
const SEVERITY_MARKERS: Dictionary = {
	"critical": "!!!", "high": "!!", "medium": "!", "low": "-", "info": "i",
}
const SEVERITY_COLORS: Dictionary = {
	"critical": RED, "high": AMBER, "medium": ULTRAVIOLET, "low": CYAN, "info": TEXT_MUTED,
}

# --- spacing and shape ----------------------------------------------------
const SPACE_XS: int = 4
const SPACE_S: int = 8
const SPACE_M: int = 12
const SPACE_L: int = 16
const SPACE_XL: int = 24
const SHELL_MARGIN: int = 12
const PANEL_PADDING: int = 12
const RADIUS: int = 4
const BORDER_WIDTH: int = 1
const FOCUS_WIDTH: int = 3
## Pointer and controller target floor at the 1280x800 reference.
const MIN_TARGET: float = 40.0
const NAV_WIDTH: float = 216.0
const REFERENCE_SIZE: Vector2i = Vector2i(1280, 800)

# --- type (pixels at 100% text scale) -------------------------------------
const FONT_BODY: int = 18
const FONT_SMALL: int = 16
const FONT_MONO: int = 16
const FONT_HEADING: int = 22
const FONT_TITLE: int = 30
const FONT_DISPLAY: int = 34
## Smallest text anywhere in the SOC UI. Anything below this is a bug.
const FONT_FLOOR: int = 14

# --- motion (seconds; run through AccessibilitySettings.motion_duration) --
const MOTION_FAST: float = 0.12
const MOTION_BASE: float = 0.2
const TOAST_SECONDS: float = 4.0


## Colour for a severity id; unknown ids read as "info".
static func severity_color(severity: String) -> Color:
	return SEVERITY_COLORS.get(severity, TEXT_MUTED)


## "!! HIGH": marker plus label, the non-colour signal.
static func severity_text(severity: String) -> String:
	var known: String = severity if SEVERITY_LABELS.has(severity) else "info"
	return "%s %s" % [SEVERITY_MARKERS[known], SEVERITY_LABELS[known]]


## Position in SEVERITIES (0 is most severe); unknown ids sort last.
static func severity_rank(severity: String) -> int:
	var index: int = SEVERITIES.find(severity)
	return index if index >= 0 else SEVERITIES.size()
