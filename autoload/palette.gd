class_name Palette
extends RefCounted
## Palette: the shared warm cartoon colours. Use these instead of ad-hoc hex codes so the
## clinic, the AudiOtron 3000 and the story screens look like one game.
## Clinical convention is fixed: RIGHT = red O, LEFT = blue X (ASHA). Never swap them.

const CREAM := Color("#fff3dc")       ## page background
const PAPER := Color("#fffbf2")       ## cards, panels
const INK := Color("#2e2442")         ## outlines and text
const INK_SOFT := Color("#6b5e7e")    ## secondary text
const SHADOW := Color("#2e244233")    ## soft drop shadow

const RIGHT_RED := Color("#e5383b")   ## right ear: red, symbol O
const RIGHT_TINT := Color("#ffe3e0")  ## right audiogram card tint
const LEFT_BLUE := Color("#2d6cdf")   ## left ear: blue, symbol X
const LEFT_TINT := Color("#dfeaff")   ## left audiogram card tint
const BOTH_INK := Color("#2e2442")    ## binaural / sound field

const TONE_CYAN := Color("#36d6e7")   ## "tone is ON" glow
const PRESS_LIME := Color("#9ee34b")  ## "patient pressed" flash
const SELECT_ORANGE := Color("#ff9f1c")  ## selected state, LCD chips
const SUNNY := Color("#ffd23f")       ## primary buttons, combo flame core
const CORAL := Color("#ff6f59")       ## accent buttons, warnings that are friendly
const MINT := Color("#5bc8a3")        ## success, "Textbook!"
const PLUM := Color("#8e5cc4")        ## impossible / special
const SKY := Color("#bfe6ff")         ## outdoor sky, booth glass

const LCD_BG := Color("#1d1a2b")
const LCD_TEXT := Color("#fff8e8")
const LCD_DIM := Color("#5d5672")

const HOOT_BROWN := Color("#c98b4f")
const HOOT_FACE := Color("#fff1de")
const SKIN := Color("#ffcf9e")
const SKIN_SHADE := Color("#e09a6c")
const WOOD := Color("#c8874b")
const WALL := Color("#f7d9b0")
const FLOOR := Color("#8fcfb3")

const GRADE_COLORS: Dictionary[String, Color] = {
	"S": Color("#ff9f1c"), "A": Color("#5bc8a3"), "B": Color("#2d6cdf"), "C": Color("#8e5cc4"), "Do-over": Color("#e5383b"),
}


static func ear_color(ear: String) -> Color:
	match ear:
		"right":
			return RIGHT_RED
		"left":
			return LEFT_BLUE
	return BOTH_INK


static func ear_tint(ear: String) -> Color:
	match ear:
		"right":
			return RIGHT_TINT
		"left":
			return LEFT_TINT
	return PAPER


static func grade_color(grade: String) -> Color:
	return GRADE_COLORS.get(grade, INK)
