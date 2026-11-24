--!nocheck
--[[
	fihOS · v5.1
	A premium dark interface for Roblox with a Dynamic Island launcher.

	The island sits at the top of the screen: hover it for live stats, click it
	(or press the menu key) and it morphs into the window.

	No CanvasGroups (they can render blank on low-memory devices). Images are two
	uploads: the fihOS icon and one icon sprite sheet.
	Icons: Lucide (ISC licence, https://lucide.dev).

	local fihOS   = require(ReplicatedStorage.fihOS)
	local Window  = fihOS:CreateWindow()   -- the fihOS name and logo are fixed
	local General = Window:AddTab({ Title = "General", Icon = "house" })
	local Group   = General:AddSection("Behaviour")
	Group:AddToggle({ Title = "Enabled", Default = true, Flag = "Enabled" })
	Window:AddConfigTab()            -- optional: save and load configurations

	The look is set from code (there is no in-game settings panel):
	fihOS:CreateWindow({ Theme = "Midnight", Accent = Color3.fromRGB(255, 95, 150) })
	fihOS:CreateWindow({ Colors = { Window = Color3.fromRGB(16, 16, 18) } })   -- override any colour
	fihOS:AddTheme("Mine", { Window = ..., Group = ..., Accent = ... }, "Onyx")
	Window:SetTheme("Rose")   Window:SetAccent(color)   Window:SetUserScale(1.1)
	Window:SetToggleKey(Enum.KeyCode.K)
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

-- fihOS branding. Fixed on purpose: scripts that use the library can't rename,
-- re-logo or re-label it (there are no options for it, and the UI never reads
-- these from anywhere a caller can reach).
local BRAND = table.freeze({
	Name = "fihOS",
	Logo = "rbxassetid://140358159572499", -- 512px
	LogoSmall = "rbxassetid://75289628303587", -- 64px, for the island, banners and footer
	LogoMedium = "rbxassetid://136872781856598", -- 128px, for the morph
})

local Library = {
	Name = BRAND.Name,
	Version = "5.1.0",
	Flags = {},
	Windows = {},
	Assets = {
		Logo = BRAND.Logo,
		LogoSmall = BRAND.LogoSmall,
		LogoMedium = BRAND.LogoMedium,
		Icons = "rbxassetid://86952919489503", -- 48px icons
		Icons32 = "rbxassetid://123429938630653",
		Icons28 = "rbxassetid://87889325028358",
		Icons24 = "rbxassetid://81188702555568",
		Icons16 = "rbxassetid://71271963009029",
	},
	MemoryConfigs = {},
}

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section

local SIDEBAR = 220
local TOOLBAR = 52
local MARGIN = 40 -- transparent room around the window for its shadow
local RADIUS = 12
local NAV_HEIGHT = 30
local ROW = 42
local ROW_TALL = 56
local ISLAND_HEIGHT = 36
local ISLAND_CARD = Vector2.new(344, 228)
local MENU_ITEM = 28
local MENU_PAD = 5

local SANS = "rbxasset://fonts/families/BuilderSans.json"
local MONO = "rbxasset://fonts/families/BuilderMono.json"
local Fonts = {
	Regular = Font.new(SANS, Enum.FontWeight.Regular),
	Medium = Font.new(SANS, Enum.FontWeight.Medium),
	SemiBold = Font.new(SANS, Enum.FontWeight.SemiBold),
	Bold = Font.new(SANS, Enum.FontWeight.Bold),
	Mono = Font.new(MONO, Enum.FontWeight.Regular),
}

-- Lucide icons packed into one sprite sheet: name -> top-left of a 48px cell
local ICON_SIZE = 48
local ICONS = {
	["activity"] = { 2, 2 }, ["app-window"] = { 54, 2 }, ["bell"] = { 106, 2 }, ["box"] = { 158, 2 },
	["check"] = { 210, 2 }, ["chevron-down"] = { 262, 2 }, ["chevron-left"] = { 314, 2 }, ["chevron-right"] = { 366, 2 },
	["chevron-up"] = { 2, 54 }, ["chevrons-up-down"] = { 54, 54 }, ["circle"] = { 106, 54 }, ["circle-help"] = { 158, 54 },
	["circle-user"] = { 210, 54 }, ["clock"] = { 262, 54 }, ["code"] = { 314, 54 }, ["command"] = { 366, 54 },
	["copy"] = { 2, 106 }, ["cpu"] = { 54, 106 }, ["crosshair"] = { 106, 106 }, ["download"] = { 158, 106 },
	["ellipsis"] = { 210, 106 }, ["external-link"] = { 262, 106 }, ["eye"] = { 314, 106 }, ["eye-off"] = { 366, 106 },
	["file-text"] = { 2, 158 }, ["fish"] = { 54, 158 }, ["flame"] = { 106, 158 }, ["folder"] = { 158, 158 },
	["gamepad-2"] = { 210, 158 }, ["gauge"] = { 262, 158 }, ["gift"] = { 314, 158 }, ["globe"] = { 366, 158 },
	["heart"] = { 2, 210 }, ["house"] = { 54, 210 }, ["info"] = { 106, 210 }, ["keyboard"] = { 158, 210 },
	["layers"] = { 210, 210 }, ["link"] = { 262, 210 }, ["list"] = { 314, 210 }, ["lock"] = { 366, 210 },
	["log-out"] = { 2, 262 }, ["map"] = { 54, 262 }, ["maximize-2"] = { 106, 262 }, ["minimize-2"] = { 158, 262 },
	["minus"] = { 210, 262 }, ["monitor"] = { 262, 262 }, ["moon"] = { 314, 262 }, ["mouse-pointer-2"] = { 366, 262 },
	["package"] = { 2, 314 }, ["palette"] = { 54, 314 }, ["pencil"] = { 106, 314 }, ["plus"] = { 158, 314 },
	["power"] = { 210, 314 }, ["refresh-cw"] = { 262, 314 }, ["rotate-ccw"] = { 314, 314 }, ["save"] = { 366, 314 },
	["search"] = { 2, 366 }, ["settings"] = { 54, 366 }, ["shield"] = { 106, 366 }, ["sliders-horizontal"] = { 158, 366 },
	["snowflake"] = { 210, 366 }, ["sparkles"] = { 262, 366 }, ["star"] = { 314, 366 }, ["sun"] = { 366, 366 },
	["swords"] = { 2, 418 }, ["target"] = { 54, 418 }, ["terminal"] = { 106, 418 }, ["timer"] = { 158, 418 },
	["trash-2"] = { 210, 418 }, ["trending-up"] = { 262, 418 }, ["upload"] = { 314, 418 }, ["user"] = { 366, 418 },
	["users"] = { 2, 470 }, ["webhook"] = { 54, 470 }, ["wifi"] = { 106, 470 }, ["x"] = { 158, 470 },
	["zap"] = { 210, 470 },
}
Library.Icons = ICONS

-- accent colours: AddSwatches' default palette (the first seven also make up the
-- rainbow "theme default" swatch)
local ACCENTS = {
	Color3.fromRGB(122, 118, 255), -- indigo
	Color3.fromRGB(10, 132, 255), -- blue
	Color3.fromRGB(50, 190, 230), -- cyan
	Color3.fromRGB(60, 200, 120), -- green
	Color3.fromRGB(245, 195, 60), -- yellow
	Color3.fromRGB(255, 140, 50), -- orange
	Color3.fromRGB(255, 95, 150), -- pink
	Color3.fromRGB(236, 236, 240), -- white
}
Library.Accents = ACCENTS

-- sidebar icon tiles cycle through these unless a tab sets Color
local TILE_COLORS = {
	Color3.fromRGB(10, 132, 255),
	Color3.fromRGB(175, 82, 222),
	Color3.fromRGB(255, 149, 0),
	Color3.fromRGB(52, 199, 89),
	Color3.fromRGB(255, 45, 85),
	Color3.fromRGB(48, 176, 199),
	Color3.fromRGB(94, 92, 230),
	Color3.fromRGB(142, 142, 147),
}

-- themes ----------------------------------------------------------------------
-- Every surface (window, island, notifications, menus) takes its colours from the
-- theme, so they always match: the island's tokens follow the window's unless a
-- theme overrides them. A theme may also list Tiles to recolour the sidebar icons.

local function palette(values, island)
	values.IslandBg = values.Window
	values.IslandChip = values.Control
	values.IslandTrack = values.Track
	values.IslandText = values.Text
	values.IslandText2 = values.Text:Lerp(values.SubText, 0.35)
	values.IslandSub = values.SubText
	values.IslandMuted = values.Muted
	values.IslandLine = values.Line
	values.IslandLineT = values.BorderT
	for key, value in pairs(island or {}) do
		values[key] = value
	end
	return values
end

local Themes = {
	-- premium dark, neutral (the default)
	Onyx = palette({
		Window = Color3.fromRGB(20, 20, 23),
		Sidebar = Color3.fromRGB(24, 24, 27),
		Group = Color3.fromRGB(29, 29, 33),
		Control = Color3.fromRGB(40, 40, 46),
		ControlHover = Color3.fromRGB(48, 48, 55),
		ControlPress = Color3.fromRGB(58, 58, 66),
		Field = Color3.fromRGB(22, 22, 25),
		Track = Color3.fromRGB(54, 54, 62),
		Menu = Color3.fromRGB(31, 31, 36),
		Segment = Color3.fromRGB(66, 66, 75),
		Line = Color3.fromRGB(255, 255, 255),
		BorderT = 0.92,
		SeparatorT = 0.94,
		HoverT = 0.95,
		HighlightT = 0.94,
		Text = Color3.fromRGB(238, 238, 242),
		SubText = Color3.fromRGB(146, 146, 156),
		Muted = Color3.fromRGB(96, 96, 106),
		Knob = Color3.fromRGB(246, 246, 248),
		Shadow = Color3.fromRGB(0, 0, 0),
		ShadowT = 0.68,
		Good = Color3.fromRGB(70, 206, 130),
		Warn = Color3.fromRGB(245, 190, 70),
		Bad = Color3.fromRGB(255, 95, 95),
		Accent = Color3.fromRGB(122, 118, 255),
	}),
	-- premium dark with a blue night tint
	Midnight = palette({
		Window = Color3.fromRGB(15, 18, 28),
		Sidebar = Color3.fromRGB(19, 23, 35),
		Group = Color3.fromRGB(23, 28, 42),
		Control = Color3.fromRGB(34, 41, 60),
		ControlHover = Color3.fromRGB(42, 50, 72),
		ControlPress = Color3.fromRGB(51, 60, 85),
		Field = Color3.fromRGB(16, 20, 31),
		Track = Color3.fromRGB(46, 55, 80),
		Menu = Color3.fromRGB(25, 30, 45),
		Segment = Color3.fromRGB(58, 68, 96),
		Line = Color3.fromRGB(255, 255, 255),
		BorderT = 0.92,
		SeparatorT = 0.94,
		HoverT = 0.95,
		HighlightT = 0.94,
		Text = Color3.fromRGB(232, 236, 246),
		SubText = Color3.fromRGB(140, 150, 174),
		Muted = Color3.fromRGB(88, 98, 124),
		Knob = Color3.fromRGB(244, 246, 250),
		Shadow = Color3.fromRGB(0, 0, 0),
		ShadowT = 0.66,
		Good = Color3.fromRGB(60, 205, 140),
		Warn = Color3.fromRGB(250, 200, 70),
		Bad = Color3.fromRGB(255, 90, 100),
		Accent = Color3.fromRGB(96, 165, 255),
	}),
	-- the macOS dark grey
	Graphite = palette({
		Window = Color3.fromRGB(30, 30, 32),
		Sidebar = Color3.fromRGB(43, 43, 46),
		Group = Color3.fromRGB(40, 40, 43),
		Control = Color3.fromRGB(72, 72, 76),
		ControlHover = Color3.fromRGB(84, 84, 88),
		ControlPress = Color3.fromRGB(98, 98, 103),
		Field = Color3.fromRGB(28, 28, 30),
		Track = Color3.fromRGB(70, 70, 75),
		Menu = Color3.fromRGB(46, 46, 50),
		Segment = Color3.fromRGB(102, 102, 107),
		Line = Color3.fromRGB(255, 255, 255),
		BorderT = 0.9,
		SeparatorT = 0.92,
		HoverT = 0.94,
		HighlightT = 0.88,
		Text = Color3.fromRGB(236, 236, 238),
		SubText = Color3.fromRGB(155, 155, 161),
		Muted = Color3.fromRGB(105, 105, 112),
		Knob = Color3.fromRGB(246, 246, 248),
		Shadow = Color3.fromRGB(0, 0, 0),
		ShadowT = 0.75,
		Good = Color3.fromRGB(48, 209, 88),
		Warn = Color3.fromRGB(255, 214, 10),
		Bad = Color3.fromRGB(255, 69, 58),
		Accent = Color3.fromRGB(10, 132, 255),
	}),
	-- warm dark with a rose accent
	Rose = palette({
		Window = Color3.fromRGB(24, 18, 21),
		Sidebar = Color3.fromRGB(29, 22, 26),
		Group = Color3.fromRGB(35, 26, 31),
		Control = Color3.fromRGB(50, 38, 45),
		ControlHover = Color3.fromRGB(60, 46, 54),
		ControlPress = Color3.fromRGB(71, 54, 64),
		Field = Color3.fromRGB(26, 19, 23),
		Track = Color3.fromRGB(64, 48, 57),
		Menu = Color3.fromRGB(37, 28, 33),
		Segment = Color3.fromRGB(78, 59, 70),
		Line = Color3.fromRGB(255, 255, 255),
		BorderT = 0.92,
		SeparatorT = 0.94,
		HoverT = 0.95,
		HighlightT = 0.94,
		Text = Color3.fromRGB(246, 236, 240),
		SubText = Color3.fromRGB(174, 152, 162),
		Muted = Color3.fromRGB(114, 96, 105),
		Knob = Color3.fromRGB(250, 244, 246),
		Shadow = Color3.fromRGB(0, 0, 0),
		ShadowT = 0.66,
		Good = Color3.fromRGB(90, 210, 140),
		Warn = Color3.fromRGB(250, 196, 80),
		Bad = Color3.fromRGB(255, 90, 100),
		Accent = Color3.fromRGB(255, 122, 162),
	}),
	-- deep purple night with a pumpkin-orange accent
	Halloween = palette({
		Window = Color3.fromRGB(22, 14, 28),
		Sidebar = Color3.fromRGB(32, 20, 40),
		Group = Color3.fromRGB(36, 23, 44),
		Control = Color3.fromRGB(64, 42, 74),
		ControlHover = Color3.fromRGB(76, 50, 88),
		ControlPress = Color3.fromRGB(90, 60, 104),
		Field = Color3.fromRGB(20, 12, 26),
		Track = Color3.fromRGB(70, 46, 80),
		Menu = Color3.fromRGB(40, 26, 48),
		Segment = Color3.fromRGB(98, 66, 112),
		Line = Color3.fromRGB(255, 255, 255),
		BorderT = 0.9,
		SeparatorT = 0.92,
		HoverT = 0.94,
		HighlightT = 0.88,
		Text = Color3.fromRGB(246, 236, 226),
		SubText = Color3.fromRGB(178, 158, 170),
		Muted = Color3.fromRGB(122, 100, 118),
		Knob = Color3.fromRGB(255, 246, 236),
		Shadow = Color3.fromRGB(0, 0, 0),
		ShadowT = 0.72,
		Good = Color3.fromRGB(124, 214, 80),
		Warn = Color3.fromRGB(255, 190, 40),
		Bad = Color3.fromRGB(230, 60, 60),
		Accent = Color3.fromRGB(255, 117, 24),
		Tiles = {
			Color3.fromRGB(255, 117, 24), -- pumpkin
			Color3.fromRGB(142, 68, 173), -- witch purple
			Color3.fromRGB(106, 190, 48), -- slime
			Color3.fromRGB(200, 40, 40), -- blood
			Color3.fromRGB(255, 190, 40), -- candle
			Color3.fromRGB(110, 60, 200), -- violet
			Color3.fromRGB(40, 150, 120), -- moss
			Color3.fromRGB(150, 140, 160), -- ghost
		},
	}, {
		IslandLine = Color3.fromRGB(255, 117, 24),
		IslandLineT = 0.7,
	}),
	Light = palette({
		Window = Color3.fromRGB(244, 244, 246),
		Sidebar = Color3.fromRGB(229, 229, 233),
		Group = Color3.fromRGB(255, 255, 255),
		Control = Color3.fromRGB(255, 255, 255),
		ControlHover = Color3.fromRGB(246, 246, 248),
		ControlPress = Color3.fromRGB(228, 228, 232),
		Field = Color3.fromRGB(255, 255, 255),
		Track = Color3.fromRGB(220, 220, 225),
		Menu = Color3.fromRGB(250, 250, 252),
		Segment = Color3.fromRGB(255, 255, 255),
		Line = Color3.fromRGB(0, 0, 0),
		BorderT = 0.86,
		SeparatorT = 0.91,
		HoverT = 0.95,
		HighlightT = 1,
		Text = Color3.fromRGB(29, 29, 31),
		SubText = Color3.fromRGB(108, 108, 114),
		Muted = Color3.fromRGB(158, 158, 165),
		Knob = Color3.fromRGB(255, 255, 255),
		Shadow = Color3.fromRGB(0, 0, 0),
		ShadowT = 0.86,
		Good = Color3.fromRGB(40, 175, 70),
		Warn = Color3.fromRGB(220, 160, 0),
		Bad = Color3.fromRGB(225, 55, 45),
		Accent = Color3.fromRGB(0, 122, 255),
	}, {
		IslandChip = Color3.fromRGB(232, 232, 236),
		IslandTrack = Color3.fromRGB(220, 220, 226),
	}),
}
Themes.Dark = Themes.Onyx -- the old default's name
Library.Themes = Themes
Library.ThemeOrder = { "Onyx", "Midnight", "Graphite", "Rose", "Halloween", "Light" }
Library.ThemeLabels = { Rose = "Rosé" }

-- add (or replace) a theme: start from another one and change what you like.
-- Switch to it with Window:SetTheme(name).
function Library:AddTheme(name, colors, base)
	local values = table.clone(Themes[base or "Onyx"] or Themes.Onyx)
	local island = {}
	for key, value in pairs(colors or {}) do
		values[key] = value
		if string.sub(key, 1, 6) == "Island" then
			island[key] = value
		end
	end
	Themes[name] = palette(values, island)
	if not table.find(self.ThemeOrder, name) then
		table.insert(self.ThemeOrder, name)
	end
	return Themes[name]
end

local KEY_NAMES = {
	LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl",
	LeftAlt = "LAlt", RightAlt = "RAlt", Return = "Return", Backspace = "Delete", CapsLock = "Caps",
	Insert = "Ins", Delete = "Del", PageUp = "PgUp", PageDown = "PgDn", Escape = "Esc",
	One = "1", Two = "2", Three = "3", Four = "4", Five = "5",
	Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
}

-- utilities -------------------------------------------------------------------

local function create(className, props, children)
	local inst = Instance.new(className)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(radius)
	return create("UICorner", { CornerRadius = radius == "full" and UDim.new(1, 0) or UDim.new(0, radius) })
end

local function pad(left, right, top, bottom)
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right or left),
		PaddingTop = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or top or 0),
	})
end

local function list(spacing, props)
	local layout = create("UIListLayout", { Padding = UDim.new(0, spacing or 0), SortOrder = Enum.SortOrder.LayoutOrder })
	for key, value in pairs(props or {}) do
		layout[key] = value
	end
	return layout
end

-- 1px border drawn inside the element's bounds, so clipping never eats it
local function stroke(parent, props)
	local line = Instance.new("UIStroke")
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Thickness = 1
	pcall(function()
		line.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	end)
	for key, value in pairs(props or {}) do
		line[key] = value
	end
	line.Parent = parent
	return line
end

local function tween(inst, goal, duration, style, direction)
	local info = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
	local ok, t = pcall(TweenService.Create, TweenService, inst, info, goal)
	if ok then
		t:Play()
		return t
	end
	for key, value in pairs(goal) do
		pcall(function()
			inst[key] = value
		end)
	end
end

local textWidths = {}
local function measure(text, font, size)
	text = tostring(text)
	local key = text .. "\0" .. font.Family .. "\0" .. font.Weight.Name .. "\0" .. size
	if textWidths[key] then
		return textWidths[key]
	end
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = font
	params.Size = size
	params.Width = 10000
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	local width = ok and math.ceil(bounds.X) or math.ceil(#text * size * 0.6)
	textWidths[key] = width
	return width
end

-- The icons are rendered at 16, 24, 28, 32 and 48px (same grid order; the small
-- ones with slightly heavier strokes). Each icon is drawn from the sheet exactly
-- twice its size, and every icon in this file has an even size centred in an
-- even box, so it lands on whole pixels and the GPU averages clean 2x2 blocks:
-- sharp at 100% scale instead of smeared. Other sizes use the nearest larger sheet.
local ICON_SHEETS = {
	{ Size = 16, Asset = "Icons16" },
	{ Size = 24, Asset = "Icons24" },
	{ Size = 28, Asset = "Icons28" },
	{ Size = 32, Asset = "Icons32" },
	{ Size = ICON_SIZE, Asset = "Icons" },
}

local function iconRect(name, size)
	local cell = ICONS[name] or ICONS.box
	local index = math.floor((cell[2] - 2) / 52 + 0.5) * 8 + math.floor((cell[1] - 2) / 52 + 0.5)
	local sheet
	for _, candidate in ipairs(ICON_SHEETS) do
		if candidate.Size == size * 2 then
			sheet = candidate
			break
		end
	end
	if not sheet then
		sheet = ICON_SHEETS[#ICON_SHEETS]
		for _, candidate in ipairs(ICON_SHEETS) do
			if candidate.Size >= size * 1.7 then
				sheet = candidate
				break
			end
		end
	end
	local step = sheet.Size + 4
	return Library.Assets[sheet.Asset],
		Vector2.new(2 + index % 8 * step, 2 + math.floor(index / 8) * step),
		Vector2.new(sheet.Size, sheet.Size)
end

-- icon from the sprite sheets by name, or any image id passed straight through
local function icon(name, size, props)
	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromOffset(size, size)
	image.ScaleType = Enum.ScaleType.Fit
	if type(name) == "string" and (name:find("^rbxasset") or name:find("^rbxthumb") or name:find("^http")) then
		image.Image = name
	else
		image.Image, image.ImageRectOffset, image.ImageRectSize = iconRect(name, size)
	end
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			image[key] = value
		end
	end
	image.Parent = parent
	return image
end

local function setIcon(image, name)
	if ICONS[name] then
		image.Image, image.ImageRectOffset, image.ImageRectSize = iconRect(name, image.Size.X.Offset)
	else
		image.Image = name or ""
		image.ImageRectSize = Vector2.zero
	end
end

local function isClick(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function keyName(key)
	if not key then
		return "None"
	end
	return KEY_NAMES[key.Name] or key.Name
end

-- a KeyCode, the name of one, or nothing: anything else (a bad name, "None") is nil
local function resolveKey(key)
	if typeof(key) == "EnumItem" then
		return key.EnumType == Enum.KeyCode and key or nil
	elseif type(key) == "string" then
		local ok, found = pcall(function()
			return Enum.KeyCode[key]
		end)
		return ok and found or nil
	end
	return nil
end

local function isTouchOnly()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function defaultParent()
	if typeof(gethui) == "function" then
		local ok, container = pcall(gethui)
		if ok and container then
			return container
		end
	end
	local player = Players.LocalPlayer
	return player and player:WaitForChild("PlayerGui")
end

local function register(window, options, object)
	local flag = options.Flag
	if flag then
		object.Flag = flag
		window.Flags[flag] = object
		Library.Flags[flag] = object
	end
	return object
end

local function formatTime(seconds)
	seconds = math.floor(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	if hours > 0 then
		return ("%dh %02dm"):format(hours, minutes)
	end
	return ("%dm %02ds"):format(minutes, seconds % 60)
end

-- transparency fades for groups of instances (no CanvasGroup needed)
local FADE_PROPS = {
	TextLabel = { "TextTransparency" },
	TextButton = { "TextTransparency" },
	TextBox = { "TextTransparency" },
	ImageLabel = { "ImageTransparency", "BackgroundTransparency" },
	Frame = { "BackgroundTransparency" },
	UIStroke = { "Transparency" },
}

local function fadeable(group, inst)
	local base = {}
	for _, prop in ipairs(FADE_PROPS[inst.ClassName] or {}) do
		base[prop] = inst[prop]
	end
	table.insert(group, { Instance = inst, Base = base })
	return inst
end

local function fade(group, visible, duration)
	for _, entry in ipairs(group) do
		local goal = {}
		for prop, value in pairs(entry.Base) do
			goal[prop] = visible and value or 1
		end
		if duration == 0 then
			for prop, value in pairs(goal) do
				entry.Instance[prop] = value
			end
		else
			tween(entry.Instance, goal, duration or 0.2)
		end
	end
end

-- theme -----------------------------------------------------------------------
-- Themed properties are bound to a token (or a function of the palette), so an
-- appearance or accent change re-tweens the whole interface in place.
-- Sequences can't be tweened, so those are assigned directly.

local SNAP_TYPES = { ColorSequence = true, NumberSequence = true, boolean = true, string = true, EnumItem = true }

local Theme = {}
Theme.__index = Theme

-- overrides: colours that replace the theme's own, whichever theme is chosen
function Theme.new(name, accent, overrides)
	-- strong keys: Roblox can collect an Instance's Lua wrapper while the
	-- Instance is alive, so a weak-keyed table would silently drop bindings
	local self = setmetatable({ Bindings = {}, CustomAccent = accent, Overrides = overrides, Listeners = {} }, Theme)
	self:Set(name, true)
	return self
end

function Theme:_derive()
	local values = self.Values
	local accent = values.Accent
	values.AccentHover = accent:Lerp(Color3.new(1, 1, 1), 0.12)
	values.AccentPress = accent:Lerp(Color3.new(0, 0, 0), 0.15)
	local luminance = 0.2126 * accent.R + 0.7152 * accent.G + 0.0722 * accent.B
	values.OnAccent = luminance > 0.62 and Color3.fromRGB(24, 24, 26) or Color3.new(1, 1, 1)
	-- a switch knob stays visible on a very light accent
	values.KnobOn = luminance > 0.62 and Color3.fromRGB(30, 30, 34) or values.Knob
end

function Theme:Set(name, instant)
	if name == "Dark" then
		name = "Onyx"
	end
	self.Name = Themes[name] and name or "Onyx"
	self.Values = table.clone(Themes[self.Name])
	for key, value in pairs(self.Overrides or {}) do
		self.Values[key] = value
	end
	if self.CustomAccent then
		self.Values.Accent = self.CustomAccent
	end
	self:_derive()
	self:Refresh(instant)
end

-- nil goes back to the theme's own accent
function Theme:SetAccent(color, instant)
	self.CustomAccent = color
	self.Values.Accent = color or (self.Overrides and self.Overrides.Accent) or Themes[self.Name].Accent
	self:_derive()
	self:Refresh(instant)
end

function Theme:Resolve(value)
	if type(value) == "function" then
		return value(self.Values)
	elseif type(value) == "string" then
		return self.Values[value]
	end
	return value
end

function Theme:Bind(inst, props)
	local existing = self.Bindings[inst]
	if existing then
		for key, value in pairs(props) do
			existing[key] = value
		end
	else
		self.Bindings[inst] = props
		inst.Destroying:Connect(function()
			self.Bindings[inst] = nil
		end)
	end
	self:Apply(inst, true)
	return inst
end

function Theme:Apply(inst, instant)
	local props = self.Bindings[inst]
	if not props then
		return
	end
	local goal = {}
	for prop, value in pairs(props) do
		local resolved = self:Resolve(value)
		if instant or SNAP_TYPES[typeof(resolved)] then
			inst[prop] = resolved
		else
			goal[prop] = resolved
		end
	end
	if next(goal) then
		tween(inst, goal, 0.2)
	end
end

function Theme:Refresh(instant)
	for inst in pairs(self.Bindings) do
		if inst.Parent then
			self:Apply(inst, instant)
		end
	end
	for _, listener in ipairs(self.Listeners) do
		task.spawn(listener)
	end
end

-- shared visuals ----------------------------------------------------------------

-- soft drop shadow from a few stacked rounded frames (kept short: every
-- translucent layer is overdraw)
local function dropShadow(theme, parent, radius, layers, offsetY)
	local holder = create("Frame", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, offsetY or 6),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = parent,
	})
	for i = 1, layers do
		local spread = i * 4
		local strength = (1 - i / (layers + 1)) / layers * 1.6
		local layer = create("Frame", {
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, spread * 2 - 6, 1, spread * 2 - 6),
			ZIndex = 0,
			Parent = holder,
		}, { corner(radius + spread) })
		theme:Bind(layer, { BackgroundColor3 = "Shadow", BackgroundTransparency = function(c)
			return 1 - (1 - c.ShadowT) * strength
		end })
	end
	return holder
end

-- the faint light edge along the top of macOS dark-mode controls
local function topHighlight(theme, parent, radius)
	local line = create("Frame", {
		Name = "Highlight",
		BorderSizePixel = 0,
		Position = UDim2.new(0, radius, 0, 1),
		Size = UDim2.new(1, -radius * 2, 0, 1),
		ZIndex = 2,
		Parent = parent,
	})
	theme:Bind(line, { BackgroundColor3 = "Line", BackgroundTransparency = "HighlightT" })
	return line
end

-- macOS focus ring: a soft accent outline just outside a control
local function focusRing(theme, parent, radius)
	local ring = create("Frame", {
		Name = "FocusRing",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 6, 1, 6),
		Visible = false,
		ZIndex = 0,
		Parent = parent,
	}, { corner(radius + 3) })
	local line = Instance.new("UIStroke")
	line.Thickness = 3
	line.Parent = ring
	theme:Bind(line, { Color = "Accent", Transparency = 0.55 })
	return ring
end

-- shortcut recorder (also used beside toggles); returns its state table
local function shortcutField(window, parent, initial, onChanged)
	local theme = window.Theme
	local state = { Key = initial, Listening = false, Hovered = false }
	local field = create("TextButton", {
		Name = "Shortcut",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(64, 24),
		Parent = parent,
	}, { corner(6) })
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Fonts.Medium,
		TextSize = 13,
		Parent = field,
	})
	local border = stroke(field)
	local ring = focusRing(theme, field, 6)
	theme:Bind(field, { BackgroundColor3 = function(c)
		return state.Hovered and c.ControlHover or c.Field
	end })
	theme:Bind(label, { TextColor3 = function(c)
		return state.Listening and c.SubText or c.Text
	end })
	theme:Bind(border, {
		Color = function(c)
			return state.Listening and c.Accent or c.Line
		end,
		Transparency = function(c)
			return state.Listening and 0 or c.BorderT
		end,
	})

	local function render()
		local text = state.Listening and "Type Shortcut" or keyName(state.Key)
		label.Text = text
		ring.Visible = state.Listening
		tween(field, { Size = UDim2.fromOffset(math.max(measure(text, Fonts.Medium, 13) + 24, 56), 24) }, 0.15)
		theme:Apply(field)
		theme:Apply(label)
		theme:Apply(border)
	end

	field.MouseEnter:Connect(function()
		state.Hovered = true
		theme:Apply(field)
	end)
	field.MouseLeave:Connect(function()
		state.Hovered = false
		theme:Apply(field)
	end)
	field.Activated:Connect(function()
		state.Listening = true
		window.ListeningForKey = true
		render()
	end)
	window:_connect(UserInputService.InputBegan:Connect(function(input)
		if not state.Listening then
			return
		end
		if isClick(input) then
			-- a click anywhere cancels recording, so shortcuts never stay blocked
			state.Listening = false
			task.defer(function()
				window.ListeningForKey = false
			end)
			render()
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode == Enum.KeyCode.Unknown then
			return
		end
		if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
			state.Key = nil
		elseif input.KeyCode ~= Enum.KeyCode.Escape then
			state.Key = input.KeyCode
		end
		state.Listening = false
		task.defer(function()
			window.ListeningForKey = false
		end)
		render()
		if onChanged then
			task.spawn(onChanged, state.Key)
		end
	end))

	function state:Set(key)
		state.Key = resolveKey(key)
		render()
	end

	render()
	return state, field
end

-- push button visual shared by AddButton and AddButtons
local function pushButton(theme, parent, options, size)
	local style = string.lower(options.Style or (options.Primary and "primary" or "default"))
	local hovered, pressed = false, false
	local button = create("TextButton", {
		Name = options.ButtonText or options.Title or "Button",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Size = size or UDim2.fromScale(1, 1),
		Parent = parent,
	}, { corner(6) })
	local border = stroke(button)
	topHighlight(theme, button, 6)
	local inner = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = button,
	}, {
		list(6, {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	local glyph
	if options.Icon then
		glyph = icon(options.Icon, 16, { LayoutOrder = 1, Parent = inner })
	end
	local text = create("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		Text = options.ButtonText or options.Title or "Button",
		FontFace = Fonts.Medium,
		TextSize = 13,
		LayoutOrder = 2,
		Parent = inner,
	})

	local function background(c)
		if style == "primary" then
			return pressed and c.AccentPress or hovered and c.AccentHover or c.Accent
		end
		return pressed and c.ControlPress or hovered and c.ControlHover or c.Control
	end
	local function textColor(c)
		if style == "primary" then
			return c.OnAccent
		elseif style == "danger" then
			return c.Bad
		end
		return c.Text
	end
	theme:Bind(button, { BackgroundColor3 = background })
	theme:Bind(border, { Color = "Line", Transparency = function(c)
		return (style == "primary" or c.Line == Color3.new(1, 1, 1)) and 1 or c.BorderT
	end })
	theme:Bind(text, { TextColor3 = textColor })
	if glyph then
		theme:Bind(glyph, { ImageColor3 = textColor })
	end

	local function paint()
		theme:Apply(button)
	end
	button.MouseEnter:Connect(function()
		hovered = true
		paint()
	end)
	button.MouseLeave:Connect(function()
		hovered, pressed = false, false
		paint()
	end)
	button.MouseButton1Down:Connect(function()
		pressed = true
		paint()
	end)
	button.MouseButton1Up:Connect(function()
		pressed = false
		paint()
	end)
	button.Activated:Connect(function()
		if options.Callback then
			task.spawn(options.Callback)
		end
	end)
	return button, text
end

-- window ------------------------------------------------------------------------

function Library:CreateWindow(options)
	options = options or {}
	local size = options.Size
	if typeof(size) == "UDim2" then
		size = Vector2.new(size.X.Offset, size.Y.Offset)
	end
	size = size or Vector2.new(780, 540)

	local self = setmetatable({
		Options = options,
		Title = BRAND.Name, -- not configurable
		Theme = Theme.new(options.Theme or options.Appearance or "Onyx", options.Accent, options.Colors),
		Tabs = {},
		Connections = {},
		Toggles = {},
		Flags = {},
		BaseSize = size,
		Size = size,
		ToggleKey = options.ToggleKey or Enum.KeyCode.RightControl,
		IsOpen = false,
		Alive = true,
		Zoomed = false,
		Transparent = false,
		Dim = false,
		UserScale = 1,
		FitScale = 1,
		BaseScale = 1,
		IslandMode = "Hover",
		IslandExpanded = false,
		RunningCount = 0,
		Fps = 60,
		StartTime = os.clock(),
		ToastOrder = 0,
		History = {},
		HistoryIndex = 0,
		RestPosition = UDim2.fromScale(0.5, 0.5),
		NotificationsEnabled = true,
	}, Window)
	local theme = self.Theme
	local player = Players.LocalPlayer
	self.Configs = self:_configStore()

	local parent = options.Parent or defaultParent()
	local name = options.Name or "fihOS"
	if not parent then
		error("fihOS: nowhere to put the interface (pass options.Parent, or create the window from a LocalScript)", 2)
	end
	-- a window with this name already there (the script ran twice): shut it down
	-- properly, so its loops and input connections go with it
	for _, other in ipairs(table.clone(Library.Windows)) do
		if other.Gui and other.Gui.Name == name and other.Gui.Parent == parent then
			other:Destroy()
		end
	end
	local previous = parent:FindFirstChild(name)
	if previous then
		previous:Destroy()
	end

	local gui = create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	})
	self.Gui = gui

	self.DimFrame = create("Frame", {
		Name = "Dim",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 0,
		Parent = gui,
	})

	-- root: transparent frame with room for the shadow
	local root = create("Frame", {
		Name = "Window",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = self.RestPosition,
		Size = UDim2.fromOffset(size.X + MARGIN * 2, size.Y + MARGIN * 2),
		Visible = false,
		ZIndex = 1,
		Parent = gui,
	})
	self.Root = root
	self.Scale = create("UIScale", { Parent = root })

	local shadowArea = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(MARGIN, MARGIN),
		Size = UDim2.new(1, -MARGIN * 2, 1, -MARGIN * 2),
		Parent = root,
	})
	dropShadow(theme, shadowArea, RADIUS, 6, 16)

	local main = create("Frame", {
		Name = "Main",
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(MARGIN, MARGIN),
		Size = UDim2.new(1, -MARGIN * 2, 1, -MARGIN * 2),
		ZIndex = 2,
		Parent = root,
	}, { corner(RADIUS) })
	theme:Bind(main, {
		BackgroundColor3 = "Window",
		BackgroundTransparency = function()
			return self.Transparent and 0.08 or 0
		end,
	})
	theme:Bind(stroke(main), { Color = "Line", Transparency = function(c)
		return c.BorderT - 0.02
	end })
	self.Main = main

	self:_buildSidebar(main, player)
	self:_buildContent(main)

	-- dragging by the top strip (traffic-light row and toolbar)
	local dragRegion = create("Frame", {
		Name = "DragRegion",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TOOLBAR),
		ZIndex = 1,
		Parent = main,
	})
	local dragging, dragInput, dragStart, startPosition = false, nil, nil, nil
	dragRegion.InputBegan:Connect(function(input)
		if isClick(input) then
			dragging, dragInput, dragStart, startPosition = true, input, input.Position, root.Position
			self:ClosePopover()
		end
	end)
	self:_connect(UserInputService.InputChanged:Connect(function(input)
		-- the mouse, or the same finger that started the drag (not a second touch)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == dragInput) then
			local delta = input.Position - dragStart
			self.RestPosition = self:_clampRest(UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			))
			tween(root, { Position = self.RestPosition }, 0.08, Enum.EasingStyle.Sine)
		end
	end))
	self:_connect(UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging, dragInput = false, nil
		end
	end))

	-- toggle key (Escape closes an open menu first)
	self:_connect(UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape and self.Popover then
			self:ClosePopover()
			return
		end
		if processed or self.ListeningForKey then
			return
		end
		if self.ToggleKey and input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end))

	-- notification banners, stacked in the bottom-right corner
	self.Toasts = create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 340, 1, -80),
		ZIndex = 30,
		Parent = gui,
	}, { list(10, { VerticalAlignment = Enum.VerticalAlignment.Bottom }) })
	self.ToastScale = create("UIScale", { Parent = self.Toasts })

	self:_buildIsland(player)
	self:_buildMorph()
	self:_connect(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_rescale()
	end))
	-- removed from outside (the ScreenGui destroyed): stop the loops and connections too
	gui.Destroying:Connect(function()
		self:Destroy()
	end)

	gui.Parent = parent
	self:_rescale()
	self:_startLoops()

	table.insert(Library.Windows, self)
	if options.StartOpen then
		self:Open()
	else
		self:_islandShow(true)
	end
	return self
end

function Window:_connect(connection)
	table.insert(self.Connections, connection)
	return connection
end

-- fit to the screen, using the ScreenGui's own size (the camera can be swapped
-- out and reports a tiny viewport while loading)
function Window:_rescale()
	local viewport = self.Gui.AbsoluteSize
	if viewport.X < 200 or viewport.Y < 200 then
		local camera = Workspace.CurrentCamera
		viewport = camera and camera.ViewportSize or viewport
	end
	if viewport.X < 200 or viewport.Y < 200 then
		return
	end
	self.FitScale = math.clamp(math.min(viewport.X / (self.Size.X + 80), viewport.Y / (self.Size.Y + 80)), 0.45, 1)
	self:_applyScale()
	local rest = self:_clampRest(self.RestPosition)
	if rest ~= self.RestPosition then
		self.RestPosition = rest
		self.Root.Position = rest
	end
end

-- keep the window reachable: its title strip stays on screen, and so does a
-- good piece of its width
function Window:_clampRest(position)
	local viewport = self.Gui.AbsoluteSize
	if viewport.X < 200 or viewport.Y < 200 then
		return position
	end
	local half = self.Size * self.BaseScale / 2
	local x = viewport.X * position.X.Scale + position.X.Offset
	local y = viewport.Y * position.Y.Scale + position.Y.Offset
	local clampedX = math.clamp(x, 120 - half.X, viewport.X - 120 + half.X)
	local clampedY = math.clamp(y, half.Y, math.max(viewport.Y - 60 + half.Y, half.Y))
	return UDim2.new(position.X.Scale, position.X.Offset + (clampedX - x), position.Y.Scale, position.Y.Offset + (clampedY - y))
end

function Window:_applyScale()
	self:ClosePopover() -- it was placed for the old scale
	self.BaseScale = self.FitScale * self.UserScale
	if self.IsOpen then
		self.Scale.Scale = self.BaseScale
	end
	self.ToastScale.Scale = self.BaseScale
	if self.IslandScale then
		self.IslandScale.Scale = math.clamp(self.BaseScale, 0.7, 1.25)
	end
end

-- sidebar -------------------------------------------------------------------------

function Window:_buildSidebar(main, player)
	local theme = self.Theme
	local options = self.Options
	local sidebar = create("Frame", {
		Name = "Sidebar",
		BorderSizePixel = 0,
		Size = UDim2.new(0, SIDEBAR, 1, 0),
		ZIndex = 2,
		Parent = main,
	}, { corner(RADIUS) })
	local fill = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, RADIUS, 1, 0),
		Parent = sidebar,
	})
	local divider = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		ZIndex = 3,
		Parent = sidebar,
	})
	local function sidebarAlpha()
		return self.Transparent and 0.12 or 0
	end
	theme:Bind(sidebar, { BackgroundColor3 = "Sidebar", BackgroundTransparency = sidebarAlpha })
	theme:Bind(fill, { BackgroundColor3 = "Sidebar", BackgroundTransparency = sidebarAlpha })
	theme:Bind(divider, { BackgroundColor3 = "Line", BackgroundTransparency = "SeparatorT" })

	-- traffic lights: close and minimise both go to the island, zoom enlarges
	local lights = create("Frame", {
		Name = "TrafficLights",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(60, 12),
		ZIndex = 5,
		Parent = sidebar,
	}, { list(8, { FillDirection = Enum.FillDirection.Horizontal }) })
	local glyphs = {}
	local function light(order, color, glyphName, action)
		local button = create("TextButton", {
			Name = ({ "Close", "Minimize", "Zoom" })[order],
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
			BackgroundColor3 = color,
			Size = UDim2.fromOffset(12, 12),
			LayoutOrder = order,
			ZIndex = 5,
			Parent = lights,
		}, { corner("full") })
		stroke(button, { Color = Color3.new(0, 0, 0), Transparency = 0.82 })
		local glyph = icon(glyphName, 8, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageColor3 = Color3.fromRGB(60, 20, 10):Lerp(color, 0.15),
			ImageTransparency = 1,
			ZIndex = 6,
			Parent = button,
		})
		table.insert(glyphs, glyph)
		button.Activated:Connect(action)
	end
	light(1, Color3.fromRGB(255, 95, 87), "x", function()
		self:Close()
	end)
	light(2, Color3.fromRGB(254, 188, 46), "minus", function()
		self:Close()
	end)
	light(3, Color3.fromRGB(40, 200, 64), "maximize-2", function()
		self:SetZoomed(not self.Zoomed)
	end)
	lights.MouseEnter:Connect(function()
		for _, glyph in ipairs(glyphs) do
			tween(glyph, { ImageTransparency = 0.25 }, 0.12)
		end
	end)
	lights.MouseLeave:Connect(function()
		for _, glyph in ipairs(glyphs) do
			tween(glyph, { ImageTransparency = 1 }, 0.12)
		end
	end)

	-- search field
	local focused = false
	local search = create("Frame", {
		Name = "Search",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 0, 28),
		ZIndex = 3,
		Parent = sidebar,
	}, { corner(7) })
	local searchBorder = stroke(search)
	local searchRing = focusRing(theme, search, 7)
	theme:Bind(search, { BackgroundColor3 = "Line", BackgroundTransparency = function(c)
		return c.Line == Color3.new(1, 1, 1) and 0.94 or 0.95
	end })
	theme:Bind(searchBorder, {
		Color = function(c)
			return focused and c.Accent or c.Line
		end,
		Transparency = function(c)
			return focused and 0 or c.SeparatorT
		end,
	})
	local lens = icon("search", 14, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 9, 0.5, 0),
		Parent = search,
	})
	theme:Bind(lens, { ImageColor3 = "SubText" })
	local searchBox = create("TextBox", {
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -38, 1, 0),
		Text = "",
		PlaceholderText = "Search",
		FontFace = Fonts.Regular,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = search,
	})
	theme:Bind(searchBox, { TextColor3 = "Text", PlaceholderColor3 = "SubText" })
	searchBox.Focused:Connect(function()
		focused = true
		searchRing.Visible = true
		theme:Apply(searchBorder)
	end)
	searchBox.FocusLost:Connect(function()
		focused = false
		searchRing.Visible = false
		theme:Apply(searchBorder)
	end)
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self:_filter(searchBox.Text)
	end)
	self.SearchBox = searchBox

	-- navigation
	local navTop = 84
	local nav = create("ScrollingFrame", {
		Name = "Navigation",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, navTop),
		Size = UDim2.new(1, -20, 1, -navTop - 40),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
		Parent = sidebar,
	}, { list(2) })
	self.NavItems = nav

	-- footer: the fihOS mark
	local footer = create("Frame", {
		Name = "Footer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -12),
		Size = UDim2.new(1, -32, 0, 18),
		ZIndex = 3,
		Parent = sidebar,
	})
	create("ImageLabel", {
		BackgroundTransparency = 1,
		Image = BRAND.LogoSmall,
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(16, 16),
		Parent = footer,
	})
	local footerText = create("TextLabel", {
		BackgroundTransparency = 1,
		RichText = true,
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -22, 1, 0),
		Text = BRAND.Name,
		FontFace = Fonts.SemiBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footer,
	})
	local function paintFooter()
		footerText.Text = BRAND.Name .. (theme.Name == "Halloween" and "  \u{1F383}" or "")
	end
	theme:Bind(footerText, { TextColor3 = "SubText" })
	paintFooter()
	table.insert(theme.Listeners, paintFooter)
end

-- content -------------------------------------------------------------------------

function Window:_buildContent(main)
	local theme = self.Theme
	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(SIDEBAR, 0),
		Size = UDim2.new(1, -SIDEBAR, 1, 0),
		ZIndex = 2,
		Parent = main,
	})

	local toolbar = create("Frame", {
		Name = "Toolbar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TOOLBAR),
		ZIndex = 3,
		Parent = content,
	})
	-- back / forward through the tab history
	local function navButton(name, glyphName, x, step)
		local hovered = false
		local button = create("TextButton", {
			Name = name,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, x, 0.5, 0),
			Size = UDim2.fromOffset(28, 26),
			Parent = toolbar,
		}, { corner(6) })
		local glyph = icon(glyphName, 16, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = button,
		})
		local function enabled()
			local index = self.HistoryIndex + step
			return index >= 1 and index <= #self.History
		end
		theme:Bind(button, { BackgroundColor3 = "Line", BackgroundTransparency = function(c)
			return (hovered and enabled()) and c.HoverT or 1
		end })
		theme:Bind(glyph, { ImageColor3 = function(c)
			return enabled() and c.Text or c.Muted
		end })
		button.MouseEnter:Connect(function()
			hovered = true
			theme:Apply(button)
		end)
		button.MouseLeave:Connect(function()
			hovered = false
			theme:Apply(button)
		end)
		button.Activated:Connect(function()
			if enabled() then
				self.HistoryIndex += step
				self:SelectTab(self.History[self.HistoryIndex], false, true)
			end
		end)
		return function()
			theme:Apply(button)
			theme:Apply(glyph)
		end
	end
	local paintBack = navButton("Back", "chevron-left", 14, -1)
	local paintForward = navButton("Forward", "chevron-right", 44, 1)
	self.PaintHistory = function()
		paintBack()
		paintForward()
	end

	self.TitleLabel = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(84, 0),
		Size = UDim2.new(1, -98, 1, 0),
		Text = "",
		FontFace = Fonts.SemiBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = toolbar,
	})
	theme:Bind(self.TitleLabel, { TextColor3 = "Text" })
	-- hairline under the toolbar that appears once the page scrolls (as on macOS)
	self.ToolbarLine = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 1,
		Parent = toolbar,
	})
	theme:Bind(self.ToolbarLine, { BackgroundColor3 = "Line" })

	self.Pages = create("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, TOOLBAR),
		Size = UDim2.new(1, -2, 1, -TOOLBAR - 2),
		ZIndex = 2,
		Parent = content,
	})
	self.NoResults = create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(240, 20),
		Text = "No Results",
		FontFace = Fonts.SemiBold,
		TextSize = 15,
		Visible = false,
		ZIndex = 3,
		Parent = self.Pages,
	})
	theme:Bind(self.NoResults, { TextColor3 = "SubText" })
end

function Window:_scrollLine(page)
	local scrolled = page.CanvasPosition.Y > 2
	tween(self.ToolbarLine, { BackgroundTransparency = scrolled and self.Theme.Values.SeparatorT or 1 }, 0.15)
end

-- dynamic island ------------------------------------------------------------------

function Window:_buildIsland(player)
	local theme = self.Theme
	local options = self.Options

	local holder = create("Frame", {
		Name = "Island",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -60),
		Size = UDim2.fromOffset(200, ISLAND_HEIGHT),
		Visible = false,
		ZIndex = 20,
		Parent = self.Gui,
	})
	self.IslandScale = create("UIScale", { Parent = holder })
	dropShadow(theme, holder, 18, 4, 6)
	local body = create("TextButton", {
		Name = "Body",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = holder,
	}, { corner(18) })
	theme:Bind(body, { BackgroundColor3 = "IslandBg" })
	theme:Bind(stroke(body), { Color = "IslandLine", Transparency = "IslandLineT" })
	self.IslandHolder = holder

	-- compact pill ------------------------------------------------------------
	local compact = {}
	local pill = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ISLAND_HEIGHT), Parent = body })
	fadeable(compact, create("ImageLabel", {
		BackgroundTransparency = 1,
		Image = BRAND.LogoSmall,
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 11, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		Parent = pill,
	}))
	local titleWidth = measure(BRAND.Name, Fonts.SemiBold, 13)
	local pillTitle = fadeable(compact, create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(0, titleWidth + 4, 1, 0),
		Text = BRAND.Name,
		FontFace = Fonts.SemiBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pill,
	}))
	theme:Bind(pillTitle, { TextColor3 = "IslandText" })
	local bars = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -38, 0.5, 0),
		Size = UDim2.fromOffset(18, 16),
		Parent = pill,
	})
	-- four 3px bars with 2px gaps, on whole pixels. Heights are set as a fraction of
	-- the 16px box (offsets are whole numbers in Roblox, scales aren't), so they
	-- can move by less than a pixel per frame.
	self.IslandBars = {}
	for i = 1, 4 do
		local bar = fadeable(compact, create("Frame", {
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, (i - 1) * 5, 0.5, 0),
			Size = UDim2.new(0, 3, 0.25, 0),
			Parent = bars,
		}, { corner("full") }))
		theme:Bind(bar, { BackgroundColor3 = function(c)
			return self.RunningCount > 0 and c.Accent or c.IslandMuted
		end })
		table.insert(self.IslandBars, bar)
	end
	self.IslandCount = fadeable(compact, create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -13, 0.5, 0),
		Size = UDim2.fromOffset(22, 16),
		Text = "0",
		FontFace = Fonts.SemiBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = pill,
	}))
	theme:Bind(self.IslandCount, { TextColor3 = "IslandText" })
	self.IslandCompactWidth = 40 + titleWidth + 14 + 18 + 8 + 22 + 13
	holder.Size = UDim2.fromOffset(self.IslandCompactWidth, ISLAND_HEIGHT)

	-- expanded card -----------------------------------------------------------
	local card = {}
	local panel = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(ISLAND_CARD.X, ISLAND_CARD.Y),
		Parent = body,
	})
	local function text(props, token)
		local label = create("TextLabel", props)
		label.BackgroundTransparency = 1
		label.Parent = panel
		theme:Bind(label, { TextColor3 = token })
		return fadeable(card, label)
	end
	-- the experience you're in: its icon, its name and its creator. Groups and
	-- users with Roblox's verified badge get the blue check after their name.
	local gameIcon = fadeable(card, create("ImageLabel", {
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(44, 44),
		Image = game.GameId ~= 0 and ("rbxthumb://type=GameIcon&id=%d&w=150&h=150"):format(game.GameId) or BRAND.LogoSmall,
		ScaleType = Enum.ScaleType.Crop,
		Parent = panel,
	}, { corner(10) }))
	theme:Bind(gameIcon, { BackgroundColor3 = "IslandChip" })
	local gameName = text({
		Position = UDim2.fromOffset(72, 19),
		Size = UDim2.fromOffset(150, 18),
		Text = game.PlaceId ~= 0 and "Loading..." or "Roblox Studio",
		FontFace = Fonts.SemiBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, "IslandText")
	local CREATOR_MAX = 150
	local creatorName = text({
		Position = UDim2.fromOffset(72, 40),
		Size = UDim2.fromOffset(CREATOR_MAX, 14),
		Text = game.PlaceId ~= 0 and "" or "UNPUBLISHED PLACE",
		FontFace = Fonts.Medium,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, "IslandSub")
	local verified = fadeable(card, create("Frame", {
		Name = "Verified",
		Visible = false,
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(0, 132, 255),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(72, 47),
		Size = UDim2.fromOffset(12, 12),
		Parent = panel,
	}, { corner("full") }))
	fadeable(card, icon("check", 8, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ImageColor3 = Color3.new(1, 1, 1),
		Parent = verified,
	}))
	if game.PlaceId ~= 0 then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, game.PlaceId, Enum.InfoType.Asset)
			if not gameName.Parent then
				return
			end
			if not ok or type(info) ~= "table" then
				gameName.Text = game.Name
				return
			end
			gameName.Text = info.Name or game.Name
			local creator = type(info.Creator) == "table" and info.Creator or {}
			local label = string.upper(creator.Name or "")
			local isVerified = creator.HasVerifiedBadge == true
			local width = math.min(measure(label, Fonts.Medium, 11), CREATOR_MAX - (isVerified and 16 or 0))
			creatorName.Text = label
			creatorName.Size = UDim2.fromOffset(width + 2, 14)
			verified.Position = UDim2.fromOffset(72 + width + 5, 47)
			verified.Visible = isVerified
		end)
	end
	self.IslandTimer = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(110, 22),
		Text = "0m 00s",
		FontFace = Fonts.SemiBold,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, "IslandText")
	text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 41),
		Size = UDim2.fromOffset(110, 14),
		Text = "session",
		FontFace = Fonts.Regular,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, "IslandMuted")

	local function statTile(x, labelText)
		local tile = {}
		tile.Value = text({
			RichText = true,
			Position = UDim2.fromOffset(x, 76),
			Size = UDim2.fromOffset(148, 24),
			Text = "-",
			FontFace = Fonts.SemiBold,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, "IslandText")
		text({
			Position = UDim2.fromOffset(x, 80),
			Size = UDim2.fromOffset(148, 14),
			Text = labelText,
			FontFace = Fonts.Medium,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, "IslandMuted")
		local track = fadeable(card, create("Frame", {
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, 108),
			Size = UDim2.fromOffset(148, 3),
			Parent = panel,
		}, { corner("full") }))
		theme:Bind(track, { BackgroundColor3 = "IslandTrack" })
		tile.Bar = fadeable(card, create("Frame", {
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = track,
		}, { corner("full") }))
		tile.Bar.BackgroundColor3 = theme.Values.Good
		return tile
	end
	self.IslandFps = statTile(16, "FRAME RATE")
	self.IslandPing = statTile(180, "PING")

	local chips = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 126),
		Size = UDim2.new(1, -32, 0, 28),
		Parent = panel,
	}, { list(8, { FillDirection = Enum.FillDirection.Horizontal }) })
	local function chip(order, labelText, accentValue)
		local frame = fadeable(card, create("Frame", {
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28),
			LayoutOrder = order,
			Parent = chips,
		}, {
			corner("full"),
			pad(12, 12, 0, 0),
			list(6, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center }),
		}))
		theme:Bind(frame, { BackgroundColor3 = "IslandChip" })
		local label = fadeable(card, create("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			Text = labelText,
			FontFace = Fonts.Medium,
			TextSize = 12,
			LayoutOrder = 1,
			Parent = frame,
		}))
		theme:Bind(label, { TextColor3 = "IslandSub" })
		local value = fadeable(card, create("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			Text = "-",
			FontFace = Fonts.SemiBold,
			TextSize = 12,
			LayoutOrder = 2,
			Parent = frame,
		}))
		theme:Bind(value, { TextColor3 = accentValue and "Accent" or "IslandText" })
		return value
	end
	self.IslandPlayers = chip(1, "Players", false)
	self.IslandRunning = chip(2, "Running", true)
	self.IslandTab = chip(3, "Tab", false)

	self.IslandRunningList = text({
		RichText = true,
		Position = UDim2.fromOffset(16, 168),
		Size = UDim2.new(1, -32, 0, 16),
		Text = "",
		FontFace = Fonts.Regular,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, "IslandSub")
	self.IslandHint = text({
		Position = UDim2.fromOffset(16, 196),
		Size = UDim2.new(1, -32, 0, 14),
		Text = "",
		FontFace = Fonts.Regular,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, "IslandMuted")

	self.CompactFade = compact
	self.CardFade = card
	fade(card, false, 0)
	self:_updateHint()

	local hovering = false
	body.MouseEnter:Connect(function()
		hovering = true
		self:_islandExpand(true)
	end)
	body.MouseLeave:Connect(function()
		hovering = false
		task.delay(0.12, function()
			if not hovering then
				self:_islandExpand(false)
			end
		end)
	end)
	body.Activated:Connect(function()
		self:Open()
	end)
end

function Window:_updateHint()
	if self.IslandHint then
		local key = self.ToggleKey and (" or press " .. keyName(self.ToggleKey)) or ""
		self.IslandHint.Text = (isTouchOnly() and "Tap" or "Click") .. key .. " to open"
	end
end

function Window:_islandExpand(expand)
	if self.IslandExpanded == expand then
		return
	end
	self.IslandExpanded = expand
	if expand then
		self:_islandRefresh()
	end
	local target = expand and UDim2.fromOffset(ISLAND_CARD.X, ISLAND_CARD.Y)
		or UDim2.fromOffset(self.IslandCompactWidth, ISLAND_HEIGHT)
	tween(self.IslandHolder, { Size = target }, expand and 0.45 or 0.35)
	fade(self.CompactFade, not expand, expand and 0.12 or 0.3)
	fade(self.CardFade, expand, expand and 0.35 or 0.12)
end

function Window:_islandShow(show)
	local holder = self.IslandHolder
	local token = {}
	self.IslandToken = token
	if show then
		holder.Visible = true
		tween(holder, { Position = UDim2.new(0.5, 0, 0, 10) }, 0.5)
		self:_islandExpand(false)
	else
		self:_islandExpand(false)
		tween(holder, { Position = UDim2.new(0.5, 0, 0, -60 - (self.IslandExpanded and ISLAND_CARD.Y or 0)) }, 0.3)
		task.delay(0.3, function()
			if self.IslandToken == token then
				holder.Visible = false
			end
		end)
	end
end

function Window:SetIslandMode(_mode)
	self.IslandMode = "Hover"
	if not self.IsOpen then
		self:_islandShow(true)
		self:_islandExpand(false)
	end
end

function Window:_runningToggles()
	local names = {}
	for _, toggle in ipairs(self.Toggles) do
		if toggle.Value then
			table.insert(names, toggle.Title)
		end
	end
	return names
end

function Window:_islandRefresh()
	local values = self.Theme.Values
	local running = self:_runningToggles()

	self.IslandTimer.Text = formatTime(os.clock() - self.StartTime)
	local fps = math.floor(self.Fps + 0.5)
	local unit = values.IslandSub:ToHex()
	self.IslandFps.Value.Text = ('%d <font size="12" color="#%s">fps</font>'):format(fps, unit)
	self.IslandFps.Bar.BackgroundColor3 = fps >= 50 and values.Good or fps >= 30 and values.Warn or values.Bad
	tween(self.IslandFps.Bar, { Size = UDim2.fromScale(math.clamp(fps / 60, 0.05, 1), 1) }, 0.4)

	local ping = 0
	local player = Players.LocalPlayer
	if player then
		pcall(function()
			ping = math.floor(player:GetNetworkPing() * 1000 + 0.5)
		end)
	end
	self.IslandPing.Value.Text = ('%d <font size="12" color="#%s">ms</font>'):format(ping, unit)
	self.IslandPing.Bar.BackgroundColor3 = ping <= 90 and values.Good or ping <= 180 and values.Warn or values.Bad
	tween(self.IslandPing.Bar, { Size = UDim2.fromScale(math.clamp(1 - ping / 300, 0.05, 1), 1) }, 0.4)

	self.IslandPlayers.Text = ("%d/%d"):format(#Players:GetPlayers(), math.max(Players.MaxPlayers, 1))
	self.IslandRunning.Text = tostring(#running)
	self.IslandTab.Text = self.CurrentTab and self.CurrentTab.Title or "-"

	if #running == 0 then
		self.IslandRunningList.Text = "Nothing running"
	else
		local shown = {}
		for i = 1, math.min(#running, 3) do
			shown[i] = running[i]
		end
		local extra = #running > 3 and ("  +" .. (#running - 3)) or ""
		self.IslandRunningList.Text = ('Running  <font color="#%s">%s</font>%s'):format(
			values.IslandText2:ToHex(),
			table.concat(shown, " · "),
			extra
		)
	end
end

function Window:_startLoops()
	local frames = 0
	self:_connect(RunService.Heartbeat:Connect(function()
		frames += 1
	end))
	task.spawn(function()
		local last = os.clock()
		while self.Alive do
			task.wait(0.5)
			if not self.Alive then
				break
			end
			local now = os.clock()
			self.Fps = frames / math.max(now - last, 0.001)
			frames, last = 0, now

			local running = #self:_runningToggles()
			if running ~= self.RunningCount then
				self.RunningCount = running
				for _, bar in ipairs(self.IslandBars) do
					self.Theme:Apply(bar)
				end
			end
			self.IslandCount.Text = tostring(running)
			if self.IslandExpanded and self.IslandHolder.Visible then
				self:_islandRefresh()
			end
		end
	end)

	-- the island's activity bars: a soft waveform redrawn every frame from two sine
	-- waves per bar (each with its own speed and phase), so they glide instead of
	-- jumping between random heights. With nothing running they ease down to dots.
	local bars = self.IslandBars
	local speeds = { 4.4, 5.6, 3.8, 5.0 }
	local phases = { 0, 2.1, 4.2, 1.3 }
	local level, clock = 0, 0
	local stepped = RunService:IsClient() and RunService.RenderStepped or RunService.Heartbeat
	self:_connect(stepped:Connect(function(dt)
		level += ((self.RunningCount > 0 and 1 or 0) - level) * math.min(dt * 5, 1)
		if not self.IslandHolder.Visible or self.IslandExpanded then
			return
		end
		clock += dt
		for i, bar in ipairs(bars) do
			local wave = 0.6 * math.sin(clock * speeds[i] + phases[i])
				+ 0.4 * math.sin(clock * speeds[i] * 1.9 + phases[i] * 1.7)
			bar.Size = UDim2.new(0, 3, (4 + level * (6 + 6 * wave)) / 16, 0)
		end
	end))
end

-- morph: one panel that turns into the window and back into the island ------------
-- The real window and island swap in underneath it, so opening and minimising
-- read as a single shape changing (no CanvasGroup needed).

function Window:_buildMorph()
	local theme = self.Theme
	local morph = create("Frame", {
		Name = "Morph",
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 25,
		Parent = self.Gui,
	})
	self.MorphCorner = create("UICorner", { CornerRadius = UDim.new(0, RADIUS), Parent = morph })
	self.MorphStroke = stroke(morph)
	self.MorphShadow = dropShadow(theme, morph, 16, 3, 8)
	self.MorphLogo = create("ImageLabel", {
		Name = "Logo",
		BackgroundTransparency = 1,
		Image = BRAND.LogoMedium,
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		ImageTransparency = 1,
		ZIndex = 2,
		Parent = morph,
	})
	self.Morph = morph
end

-- what the morph looks like as the island and as the window
function Window:_morphLook(look)
	local values = self.Theme.Values
	if look == "island" then
		return values.IslandBg, values.IslandLine, values.IslandLineT
	end
	return values.Window, values.Line, values.BorderT - 0.02
end

function Window:_islandRestRect()
	local scale = self.IslandScale.Scale
	local size = Vector2.new(self.IslandCompactWidth, ISLAND_HEIGHT) * scale
	return Vector2.new(self.Gui.AbsoluteSize.X / 2 - size.X / 2, 10), size, 18 * scale
end

function Window:_windowRestRect()
	local viewport = self.Gui.AbsoluteSize
	local rest = self.RestPosition
	local center = Vector2.new(viewport.X * rest.X.Scale + rest.X.Offset, viewport.Y * rest.Y.Scale + rest.Y.Offset)
	local size = self.Size * self.BaseScale
	return center - size / 2, size, RADIUS * self.BaseScale
end

function Window:_placeMorph(position, size, radius, look, opaque)
	local morph = self.Morph
	local color, lineColor, lineAlpha = self:_morphLook(look)
	morph.Position = UDim2.fromOffset(position.X, position.Y)
	morph.Size = UDim2.fromOffset(size.X, size.Y)
	morph.BackgroundColor3 = color
	self.MorphCorner.CornerRadius = UDim.new(0, radius)
	self.MorphStroke.Color = lineColor
	morph.BackgroundTransparency = opaque and 0 or 1
	self.MorphStroke.Transparency = opaque and lineAlpha or 1
	self.MorphShadow.Visible = opaque
	self.MorphLogo.ImageTransparency = 1
	self.MorphLogo.Size = UDim2.fromOffset(24, 24)
	self.MorphLook = look
	morph.Visible = true
end

function Window:_flyMorph(position, size, radius, look, duration)
	local style, direction = Enum.EasingStyle.Quint, Enum.EasingDirection.InOut
	local color, lineColor, lineAlpha = self:_morphLook(look)
	self.MorphLook = look
	tween(self.Morph, {
		Position = UDim2.fromOffset(position.X, position.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = color,
	}, duration, style, direction)
	tween(self.MorphCorner, { CornerRadius = UDim.new(0, radius) }, duration, style, direction)
	tween(self.MorphStroke, { Color = lineColor, Transparency = lineAlpha }, duration, style, direction)
end

function Window:_fadeMorph(visible, duration)
	local _, _, lineAlpha = self:_morphLook(self.MorphLook or "window")
	tween(self.Morph, { BackgroundTransparency = visible and 0 or 1 }, duration)
	tween(self.MorphStroke, { Transparency = visible and lineAlpha or 1 }, duration)
	self.MorphShadow.Visible = visible
end

-- put the island back at rest without its slide-in (it takes over from the morph)
function Window:_islandPlace()
	local holder = self.IslandHolder
	self.IslandToken = {}
	self.IslandExpanded = false
	holder.Position = UDim2.new(0.5, 0, 0, 10)
	holder.Size = UDim2.fromOffset(self.IslandCompactWidth, ISLAND_HEIGHT)
	fade(self.CardFade, false, 0)
	fade(self.CompactFade, false, 0)
	holder.Visible = true
	fade(self.CompactFade, true, 0.25)
end

function Window:_bumpIsland()
	local islandScale = self.IslandScale
	local base = math.clamp(self.BaseScale, 0.7, 1.25)
	tween(islandScale, { Scale = base * 1.08 }, 0.12, Enum.EasingStyle.Quad)
	task.delay(0.12, function()
		tween(islandScale, { Scale = base }, 0.35, Enum.EasingStyle.Back)
	end)
end

function Window:Open()
	if self.IsOpen or not self.Alive then
		return
	end
	self.IsOpen = true
	local token = {}
	self.VisibilityToken = token
	self:ClosePopover()
	local morphTime = 0.46

	-- the morph starts as the island (compact or expanded, wherever it is now)
	local holder = self.IslandHolder
	local fromIsland = holder.Visible
	local fromPosition, fromSize, fromRadius
	local fromLook = "island"
	if self.Morph.Visible then
		-- minimise still running: reverse from the morph's current shape
		fromPosition = self.Morph.AbsolutePosition - self.Gui.AbsolutePosition
		fromSize = self.Morph.AbsoluteSize
		fromRadius = self.MorphCorner.CornerRadius.Offset
		fromIsland = true
	elseif fromIsland then
		fromPosition = holder.AbsolutePosition - self.Gui.AbsolutePosition
		fromSize = holder.AbsoluteSize
		fromRadius = 18 * self.IslandScale.Scale
		fade(self.CompactFade, false, 0.08)
		fade(self.CardFade, false, 0.08)
	else
		fromPosition, fromSize, fromRadius = self:_islandRestRect()
	end

	-- the real window waits underneath, already at its final size and place
	local root = self.Root
	root.Visible = false
	root.Size = UDim2.fromOffset(self.Size.X + MARGIN * 2, self.Size.Y + MARGIN * 2)
	root.Position = self.RestPosition
	self.Scale.Scale = self.BaseScale

	task.delay(fromIsland and 0.08 or 0, function()
		if self.VisibilityToken ~= token then
			return
		end
		self.IslandToken = {}
		holder.Visible = false
		self.IslandExpanded = false
		if self.Morph.Visible then
			self.MorphShadow.Visible = true
		else
			self:_placeMorph(fromPosition, fromSize, fromRadius, fromLook, fromIsland)
			if not fromIsland then
				self:_fadeMorph(true, 0.12)
			end
		end
		local toPosition, toSize, toRadius = self:_windowRestRect()
		self:_flyMorph(toPosition, toSize, toRadius, "window", morphTime)
		tween(self.MorphLogo, { ImageTransparency = 0, Size = UDim2.fromOffset(48, 48) }, 0.32)
		if self.Dim then
			self.DimFrame.Visible = true
			tween(self.DimFrame, { BackgroundTransparency = 0.45 }, 0.4)
		end

		-- once the panel has the window's shape, fade it away to reveal the window
		task.delay(morphTime, function()
			if self.VisibilityToken ~= token then
				return
			end
			root.Visible = true
			self:_fadeMorph(false, 0.2)
			tween(self.MorphLogo, { ImageTransparency = 1 }, 0.12)
			task.delay(0.21, function()
				if self.VisibilityToken == token then
					self.Morph.Visible = false
				end
			end)
		end)
	end)
end

-- minimise: the window becomes the morph panel and shrinks into the island
function Window:Close()
	if not self.IsOpen then
		return
	end
	self.IsOpen = false
	local token = {}
	self.VisibilityToken = token
	self:ClosePopover()
	local morphTime = 0.46
	local toIsland = true

	if not self.Root.Visible and not self.Morph.Visible then
		-- toggled back before the open animation began: just restore the island
		if toIsland then
			self:_islandPlace()
		end
		return
	elseif self.Root.Visible then
		-- cover the window with an identical panel, fading its content out
		local main = self.Main
		self:_placeMorph(main.AbsolutePosition - self.Gui.AbsolutePosition, main.AbsoluteSize, RADIUS * self.Scale.Scale, "window", false)
		self:_fadeMorph(true, 0.14)
	else
		-- open still running: carry on from the morph's current shape
		self:_fadeMorph(true, 0.08)
	end
	tween(self.DimFrame, { BackgroundTransparency = 1 }, 0.3)

	task.delay(0.13, function()
		if self.VisibilityToken ~= token then
			return
		end
		self.Root.Visible = false
		self.DimFrame.Visible = false
		local toPosition, toSize, toRadius = self:_islandRestRect()
		self:_flyMorph(toPosition, toSize, toRadius, "island", morphTime)
		tween(self.MorphLogo, { ImageTransparency = 0 }, 0.15)
		task.delay(morphTime * 0.55, function()
			if self.VisibilityToken == token then
				tween(self.MorphLogo, { ImageTransparency = 1, Size = UDim2.fromOffset(18, 18) }, 0.16)
			end
		end)

		task.delay(morphTime, function()
			if self.VisibilityToken ~= token then
				return
			end
			if toIsland then
				self.Morph.Visible = false
				self:_islandPlace()
				self:_bumpIsland()
			else
				self:_fadeMorph(false, 0.2)
				task.delay(0.21, function()
					if self.VisibilityToken == token then
						self.Morph.Visible = false
					end
				end)
			end
		end)
	end)
end

function Window:Minimize()
	self:Close()
end

function Window:Toggle()
	if self.IsOpen then
		self:Close()
	else
		self:Open()
	end
end

-- green light: enlarge the window around its centre
function Window:SetZoomed(zoomed)
	self.Zoomed = zoomed
	local base = self.BaseSize
	self.Size = zoomed and Vector2.new(math.floor(base.X * 1.15), math.floor(base.Y * 1.15)) or base
	self:_rescale() -- a zoomed window still has to fit the screen
	tween(self.Root, { Size = UDim2.fromOffset(self.Size.X + MARGIN * 2, self.Size.Y + MARGIN * 2) }, 0.4)
end

-- any name in Library.ThemeOrder (or one added with fihOS:AddTheme). Halloween
-- brings its own accent, so a picked accent is dropped going into or out of it.
function Window:SetTheme(name)
	local theme = self.Theme
	if (name == "Halloween") ~= (theme.Name == "Halloween") then
		theme.CustomAccent = nil
	end
	theme:Set(name)
end
Window.SetAppearance = Window.SetTheme -- older name

-- nil goes back to the theme's own accent
function Window:SetAccent(color)
	self.Theme:SetAccent(color)
end

function Window:SetToggleKey(key)
	self.ToggleKey = resolveKey(key)
	self:_updateHint()
end

function Window:SetTransparent(enabled)
	self.Transparent = enabled
	self.Theme:Refresh()
end

function Window:SetDim(enabled)
	self.Dim = enabled
	if self.IsOpen then
		self.DimFrame.Visible = true
		tween(self.DimFrame, { BackgroundTransparency = enabled and 0.45 or 1 }, 0.3)
	end
end

function Window:SetUserScale(scale)
	self.UserScale = math.clamp(scale, 0.5, 1.5)
	self:_applyScale()
end

function Window:Destroy()
	if not self.Alive then
		return
	end
	self.Alive = false
	self.IsOpen = false
	self.VisibilityToken = {}
	self:ClosePopover()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	for flag, object in pairs(self.Flags) do
		if Library.Flags[flag] == object then
			Library.Flags[flag] = nil
		end
	end
	self.Gui:Destroy()
	table.clear(self.Theme.Bindings)
	table.clear(self.Theme.Listeners)
	local index = table.find(Library.Windows, self)
	if index then
		table.remove(Library.Windows, index)
	end
end

-- search: filters the sidebar and the rows of every tab ---------------------------

function Window:_filter(query)
	query = string.lower(query or "")
	local firstMatch
	for _, tab in ipairs(self.Tabs) do
		local tabMatch = query == "" or string.find(string.lower(tab.Title), query, 1, true) ~= nil
		local anyRow = false
		for _, section in ipairs(tab.Sections) do
			local sectionMatch = query ~= "" and string.find(string.lower(section.Title or ""), query, 1, true) ~= nil
			local sectionAny = false
			for _, element in ipairs(section.Elements) do
				local visible = query == "" or tabMatch or sectionMatch or string.find(element.Search, query, 1, true) ~= nil
				element.Row.Visible = visible
				sectionAny = sectionAny or visible
			end
			section.Outer.Visible = query == "" or sectionMatch or sectionAny
			anyRow = anyRow or sectionAny
			section:_refreshSeparators()
		end
		if tab.Hero then
			tab.Hero.Visible = query == "" or tabMatch
		end
		local visible = query == "" or tabMatch or anyRow
		tab.Button.Visible = visible
		if visible and not firstMatch then
			firstMatch = tab
		end
	end
	self.NoResults.Visible = query ~= "" and firstMatch == nil
	if self.CurrentTab then
		self.CurrentTab.Page.Visible = not self.NoResults.Visible
	end
	if query ~= "" and firstMatch and self.CurrentTab and not self.CurrentTab.Button.Visible then
		self:SelectTab(firstMatch, true)
	end
end

-- popovers ----------------------------------------------------------------------------
-- One floating panel at a time: dropdown menus, or a popover of your own. Like
-- macOS, they appear at once (no animation) under their button, or above it when
-- there's no room below. Menus line up with the button's left edge and have the
-- dark outline and light inner edge of NSMenu; a popover opened with Arrow = true is centred
-- on its button with an arrow pointing at it, like NSPopover. A click anywhere
-- else, Escape, dragging or closing the window shuts it.

local ARROW = 8 -- how far a popover's arrow pokes out

function Window:_openPopover(anchor, width, height, options)
	options = options or {}
	self:ClosePopover()
	local theme = self.Theme
	local gui = self.Gui
	local scale = self.Scale.Scale
	local screen = gui.AbsoluteSize
	local position = anchor.AbsolutePosition - gui.AbsolutePosition
	local size = anchor.AbsoluteSize
	local arrow = options.Arrow == true
	local outer = height + (arrow and ARROW or 0)
	local pixelWidth, pixelHeight = width * scale, outer * scale
	local gap = (arrow and 2 or 4) * scale
	local below = position.Y + size.Y + gap
	local up = below + pixelHeight > screen.Y - 8 and position.Y - gap - pixelHeight >= 8
	local x
	if arrow then
		x = position.X + size.X / 2 - pixelWidth / 2
	elseif options.Align == "Right" then
		x = position.X + size.X - pixelWidth
	else
		x = position.X
	end
	x = math.clamp(x, 8, math.max(screen.X - 8 - pixelWidth, 8))
	local y = up and position.Y - gap or math.min(below, math.max(screen.Y - 8 - pixelHeight, 8))
	local edge = up and 1 or 0
	local anchorX = options.Align == "Right" and 1 or 0
	local dark = theme.Values.Line == Color3.new(1, 1, 1)

	local backdrop = create("TextButton", {
		Name = "PopoverBackdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
		Parent = gui,
	})
	local holder = create("Frame", {
		Name = "Popover",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(anchorX, edge),
		Position = UDim2.fromOffset(x + anchorX * pixelWidth, y),
		Size = UDim2.fromOffset(width, outer),
		ZIndex = 41,
		Parent = gui,
	}, { create("UIScale", { Scale = scale }) })
	-- the panel itself sits below (or above) the arrow
	local body = create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, (arrow and not up) and ARROW or 0),
		Size = UDim2.new(1, 0, 0, height),
		Parent = holder,
	})
	local radius = arrow and 12 or 8
	dropShadow(theme, body, radius, 4, 8)
	if not arrow then
		-- menus: a fine dark outline just outside the panel
		local outline = create("Frame", {
			Name = "Outline",
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 2, 1, 2),
			ZIndex = 1,
			Parent = body,
		}, { corner(radius + 1) })
		theme:Bind(outline, { BackgroundColor3 = "Shadow", BackgroundTransparency = function(c)
			return c.Line == Color3.new(1, 1, 1) and 0.4 or 0.86
		end })
	end
	local panel = create("Frame", {
		Name = "Panel",
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = body,
	}, { corner(radius) })
	theme:Bind(panel, { BackgroundColor3 = "Menu" })
	-- the light inner edge of dark-mode menus (light mode: a hairline border instead)
	local edgeLine = stroke(panel)
	local function edgeAlpha(c)
		if c.Line == Color3.new(1, 1, 1) then
			return 0.88
		end
		return arrow and c.BorderT or 1
	end
	theme:Bind(edgeLine, { Color = "Line", Transparency = edgeAlpha })

	if arrow then
		-- a rotated square half-tucked under the panel, centred on the button
		local tip = (position.X + size.X / 2 - x) / scale
		tip = math.clamp(tip, radius + 10, width - radius - 10)
		local point = create("Frame", {
			Name = "Arrow",
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(tip, up and height or 0),
			Size = UDim2.fromOffset(15, 15),
			Rotation = 45,
			ZIndex = 2, -- above the shadow, under the panel
			Parent = body,
		}, { corner(2) })
		theme:Bind(point, { BackgroundColor3 = "Menu" })
		theme:Bind(stroke(point), { Color = "Line", Transparency = edgeAlpha })
		-- hide the panel's edge where the arrow joins it
		local join = create("Frame", {
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, up and 1 or 0),
			Position = UDim2.new(0, tip, up and 1 or 0, 0),
			Size = UDim2.fromOffset(19, 1),
			ZIndex = 10,
			Parent = panel,
		})
		theme:Bind(join, { BackgroundColor3 = "Menu" })
	end

	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = panel,
	})

	local popover = { Backdrop = backdrop, Holder = holder, Body = body, Owner = anchor, Width = width, Cleanup = {}, Dark = dark }
	self.Popover = popover
	backdrop.Activated:Connect(function()
		if self.Popover == popover then
			self:ClosePopover()
		end
	end)
	return popover, content
end

function Window:ClosePopover()
	local popover = self.Popover
	if not popover then
		return
	end
	self.Popover = nil
	for _, connection in ipairs(popover.Cleanup) do
		connection:Disconnect()
	end
	popover.Backdrop:Destroy()
	popover.Holder:Destroy()
	task.defer(function()
		if not self.Popover then
			self.ListeningForKey = false
		end
	end)
	if popover.OnClose then
		popover.OnClose()
	end
end

-- dropdown menus (NSMenu) -------------------------------------------------------------
-- Drops below its button, at least as wide as the button.
-- Chosen items carry a check in the left column (multi-select too); the row under
-- the mouse is filled with the accent. Picking closes the menu at once;
-- multi-select menus stay open. Lists longer than eight get a
-- search field. Keyboard: Up/Down, Return, and typing jumps to a match.

local TYPE_KEYS = {
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
	Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Space = " ",
}

function Window:OpenMenu(anchor, menu)
	local theme = self.Theme
	local items = menu.Items or {}
	local count = #items
	local multi = menu.Multi == true
	local searchable = menu.Searchable
	if searchable == nil then
		searchable = count > 8
	end
	-- multi-select menus get a footer: how many are chosen, plus Clear and All
	local hasFooter = multi and count >= 3 and type(menu.OnSetAll) == "function"
	local scale = math.max(self.Scale.Scale, 0.01)
	local widest = 0
	for _, item in ipairs(items) do
		widest = math.max(widest, measure(tostring(item), Fonts.Regular, 13))
	end
	local width = math.floor(math.max(anchor.AbsoluteSize.X / scale, widest + MENU_PAD * 2 + 26 + 16, hasFooter and 180 or 0) + 0.5)
	local maxRows = math.max(menu.MaxRows or 8, 1)
	local searchHeight = searchable and 38 or 0
	local footerHeight = hasFooter and 34 or 0
	-- prefer opening downward: show fewer rows (the list scrolls) rather than flip
	-- above the button. It only flips when fewer than four rows fit below.
	do
		local gui = self.Gui
		local below = anchor.AbsolutePosition.Y - gui.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 4 * scale
		local room = (gui.AbsoluteSize.Y - 8 - below) / scale - searchHeight - footerHeight - MENU_PAD * 2
		local fits = math.floor(room / MENU_ITEM)
		if fits >= 4 and fits < math.min(count, maxRows) then
			maxRows = fits
		end
	end
	local listHeight = MENU_PAD * 2 + math.clamp(count, 1, maxRows) * MENU_ITEM
	local popover, content = self:_openPopover(anchor, width, searchHeight + listHeight + footerHeight, { Align = menu.Align })
	local function alive()
		return self.Popover == popover
	end

	-- a quick pop out of the button
	local pop = popover.Holder:FindFirstChildOfClass("UIScale")
	if pop then
		pop.Scale = scale * 0.95
		tween(pop, { Scale = scale }, 0.18)
	end

	local searchBox
	if searchable then
		local field = create("Frame", {
			Name = "Search",
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(MENU_PAD + 1, MENU_PAD + 1),
			Size = UDim2.new(1, -(MENU_PAD + 1) * 2, 0, 26),
			Parent = content,
		}, { corner(6) })
		theme:Bind(field, { BackgroundColor3 = "Field" })
		theme:Bind(stroke(field), { Color = "Line", Transparency = "BorderT" })
		local lens = icon("search", 12, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Parent = field,
		})
		theme:Bind(lens, { ImageColor3 = "SubText" })
		searchBox = create("TextBox", {
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(26, 0),
			Size = UDim2.new(1, -32, 1, 0),
			Text = "",
			PlaceholderText = "Search",
			FontFace = Fonts.Regular,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = field,
		})
		theme:Bind(searchBox, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })
		local divider = create("Frame", {
			BorderSizePixel = 0,
			Position = UDim2.new(0, MENU_PAD + 5, 0, searchHeight - 1),
			Size = UDim2.new(1, -(MENU_PAD + 5) * 2, 0, 1),
			Parent = content,
		})
		theme:Bind(divider, { BackgroundColor3 = "Line", BackgroundTransparency = "SeparatorT" })
	end

	local scroller = create("ScrollingFrame", {
		Name = "Items",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, searchHeight),
		Size = UDim2.new(1, 0, 0, listHeight),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageTransparency = 0.4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = content,
	}, { pad(MENU_PAD, MENU_PAD, MENU_PAD, MENU_PAD), list(0) })
	theme:Bind(scroller, { ScrollBarImageColor3 = "Muted" })
	local empty = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, searchHeight),
		Size = UDim2.new(1, 0, 0, listHeight),
		Text = count == 0 and "No Options" or "No Results",
		FontFace = Fonts.Regular,
		TextSize = 13,
		Visible = count == 0,
		Parent = content,
	})
	theme:Bind(empty, { TextColor3 = "SubText" })

	local entries = {}
	local highlighted
	local picking = false
	local paintFooter = function() end
	local function setHighlight(index)
		if highlighted == index then
			return
		end
		local previous = entries[highlighted]
		highlighted = index
		if previous then
			previous.Paint()
		end
		if entries[index] then
			entries[index].Paint()
		end
	end
	local function shownEntries()
		local shown = {}
		for index, entry in ipairs(entries) do
			if entry.Button.Visible then
				table.insert(shown, index)
			end
		end
		return shown
	end
	-- keep a row in view (or centred, when the menu opens)
	local function scrollTo(index, center)
		local shown = shownEntries()
		local position = table.find(shown, index)
		if not position then
			return
		end
		local top = MENU_PAD + (position - 1) * MENU_ITEM
		local current = scroller.CanvasPosition.Y
		local target = current
		if center then
			target = top - (listHeight - MENU_ITEM) / 2
		elseif top < current + MENU_PAD then
			target = top - MENU_PAD
		elseif top + MENU_ITEM > current + listHeight - MENU_PAD then
			target = top + MENU_ITEM - listHeight + MENU_PAD
		end
		local limit = math.max(MENU_PAD * 2 + #shown * MENU_ITEM - listHeight, 0)
		scroller.CanvasPosition = Vector2.new(0, math.clamp(target, 0, limit))
	end
	local function pick(index)
		local entry = entries[index]
		if not entry or not alive() or picking then
			return
		end
		menu.OnPick(entry.Item)
		if multi then
			entry.Paint()
			paintFooter()
			return
		end
		-- single choice: the menu closes straight away
		picking = true
		self:ClosePopover()
	end

	for index, item in ipairs(items) do
		local text = tostring(item)
		local function chosen()
			return menu.IsSelected(item)
		end
		local function lit()
			return highlighted == index
		end
		local button = create("TextButton", {
			Name = text,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
			Size = UDim2.new(1, 0, 0, MENU_ITEM),
			LayoutOrder = index,
			Parent = scroller,
		}, { corner(6) })
		local tick = icon("check", 12, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Parent = button,
		})
		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(26, 0),
			Size = UDim2.new(1, -34, 1, 0),
			Text = text,
			FontFace = Fonts.Regular,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = button,
		})
		theme:Bind(button, { BackgroundColor3 = "Accent", BackgroundTransparency = function()
			return lit() and 0 or 1
		end })
		theme:Bind(label, { TextColor3 = function(c)
			return lit() and c.OnAccent or c.Text
		end })
		theme:Bind(tick, {
			ImageColor3 = function(c)
				return lit() and c.OnAccent or c.Accent
			end,
			ImageTransparency = function()
				return chosen() and 0 or 1
			end,
		})

		local entry = { Item = item, Key = string.lower(text), Button = button }
		function entry.Paint()
			theme:Apply(button, true)
			theme:Apply(label, true)
			theme:Apply(tick, true)
		end
		entries[index] = entry
		button.MouseEnter:Connect(function()
			if not picking then
				setHighlight(index)
			end
		end)
		button.MouseLeave:Connect(function()
			if highlighted == index and not picking then
				setHighlight(nil)
			end
		end)
		button.Activated:Connect(function()
			pick(index)
		end)
	end

	if hasFooter then
		local footer = create("Frame", {
			Name = "Footer",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, footerHeight),
			Parent = content,
		})
		local line = create("Frame", {
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(MENU_PAD + 5, 0),
			Size = UDim2.new(1, -(MENU_PAD + 5) * 2, 0, 1),
			Parent = footer,
		})
		theme:Bind(line, { BackgroundColor3 = "Line", BackgroundTransparency = "SeparatorT" })
		local summary = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(MENU_PAD + 8, 1),
			Size = UDim2.new(1, -112, 1, -1),
			Text = "",
			FontFace = Fonts.Regular,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = footer,
		})
		theme:Bind(summary, { TextColor3 = "SubText" })
		local function action(text, right, on)
			local buttonWidth = measure(text, Fonts.Medium, 12) + 16
			local hovered = false
			local button = create("TextButton", {
				Name = text,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -right, 0.5, 0),
				Size = UDim2.fromOffset(buttonWidth, 22),
				Text = text,
				FontFace = Fonts.Medium,
				TextSize = 12,
				Parent = footer,
			}, { corner(5) })
			theme:Bind(button, {
				BackgroundColor3 = "Line",
				BackgroundTransparency = function(c)
					return hovered and c.HoverT - 0.04 or 1
				end,
				TextColor3 = function(c)
					return hovered and c.Text or c.SubText
				end,
			})
			button.MouseEnter:Connect(function()
				hovered = true
				theme:Apply(button, true)
			end)
			button.MouseLeave:Connect(function()
				hovered = false
				theme:Apply(button, true)
			end)
			button.Activated:Connect(function()
				if not alive() then
					return
				end
				menu.OnSetAll(on)
				for _, entry in ipairs(entries) do
					entry.Paint()
				end
				paintFooter()
			end)
			return buttonWidth
		end
		local allWidth = action("All", MENU_PAD + 3, true)
		action("Clear", MENU_PAD + 3 + allWidth + 2, false)
		paintFooter = function()
			local selected = 0
			for _, item in ipairs(items) do
				if menu.IsSelected(item) then
					selected += 1
				end
			end
			summary.Text = selected == 0 and "None selected" or ("%d selected"):format(selected)
		end
		paintFooter()
	end

	if searchBox then
		-- the menu grows and shrinks with the matches
		local function fit(shown)
			listHeight = MENU_PAD * 2 + math.clamp(shown, 1, maxRows) * MENU_ITEM
			local total = searchHeight + listHeight + footerHeight
			scroller.Size = UDim2.new(1, 0, 0, listHeight)
			empty.Size = UDim2.new(1, 0, 0, listHeight)
			popover.Holder.Size = UDim2.fromOffset(width, total)
			popover.Body.Size = UDim2.new(1, 0, 0, total)
		end
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			local query = string.lower(searchBox.Text)
			for _, entry in ipairs(entries) do
				entry.Button.Visible = query == "" or string.find(entry.Key, query, 1, true) ~= nil
			end
			local shown = shownEntries()
			fit(#shown)
			empty.Visible = #shown == 0
			-- the best match is highlighted so Return picks it
			setHighlight(query ~= "" and shown[1] or nil)
			scroller.CanvasPosition = Vector2.zero
		end)
		if not isTouchOnly() then
			task.defer(function()
				if alive() then
					searchBox:CaptureFocus()
				end
			end)
		end
	end
	task.defer(function()
		if alive() and menu.Selected then
			scrollTo(menu.Selected, true)
		end
	end)

	-- the menu takes the keyboard while it's open (shortcuts wait)
	self.ListeningForKey = true
	local typed, typedAt = "", 0
	table.insert(popover.Cleanup, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard or not alive() or picking then
			return
		end
		local key = input.KeyCode
		local shown = shownEntries()
		if #shown == 0 then
			return
		end
		if key == Enum.KeyCode.Down or key == Enum.KeyCode.Up then
			local step = key == Enum.KeyCode.Down and 1 or -1
			local position = highlighted and table.find(shown, highlighted)
				or table.find(shown, menu.Selected or 0)
				or (step == 1 and 0 or #shown + 1)
			position = math.clamp(position + step, 1, #shown)
			setHighlight(shown[position])
			scrollTo(shown[position])
		elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter then
			if highlighted then
				pick(highlighted)
			end
		elseif searchable then
			return -- the search field has the keyboard
		elseif key == Enum.KeyCode.Home or key == Enum.KeyCode.End then
			local index = shown[key == Enum.KeyCode.Home and 1 or #shown]
			setHighlight(index)
			scrollTo(index)
		else
			local character = TYPE_KEYS[key.Name] or (#key.Name == 1 and string.lower(key.Name)) or nil
			if character then
				if os.clock() - typedAt > 1 then
					typed = ""
				end
				typed ..= character
				typedAt = os.clock()
				for _, index in ipairs(shown) do
					if string.sub(entries[index].Key, 1, #typed) == typed then
						setHighlight(index)
						scrollTo(index)
						break
					end
				end
			end
		end
	end))
	return popover
end

-- notifications: banners stacked in the bottom-right corner ---------------------------------
-- The newest sits at the bottom; at most four show at once. Same surface as the
-- window, with a soft shadow. Click one (or its close button) to dismiss it.

local TOAST_WIDTH = 340
local MAX_TOASTS = 4

function Window:Notify(options)
	if type(options) == "string" then
		options = { Title = options }
	end
	options = options or {}
	if not self.Alive or self.NotificationsEnabled == false then
		return { Dismiss = function() end }
	end
	local theme = self.Theme
	local duration = options.Duration or 5
	self.ToastOrder += 1

	local holder = create("Frame", {
		Name = "Banner",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(TOAST_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self.ToastOrder,
		Parent = self.Toasts,
	})
	-- the shadow is a sibling sized to the card (a child would draw over it)
	local shade = create("Frame", {
		Name = "Shade",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(TOAST_WIDTH + 40, 0),
		Size = UDim2.fromOffset(TOAST_WIDTH, 60),
		Parent = holder,
	})
	dropShadow(theme, shade, 14, 3, 6)
	local card = create("TextButton", {
		Name = "Card",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Position = UDim2.fromOffset(TOAST_WIDTH + 40, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
		Parent = holder,
	}, { corner(14) })
	theme:Bind(card, { BackgroundColor3 = "Window" })
	theme:Bind(stroke(card), { Color = "Line", Transparency = function(c)
		return c.BorderT - 0.03
	end })
	local function fitShade()
		shade.Size = UDim2.fromOffset(TOAST_WIDTH, card.AbsoluteSize.Y / math.max(self.ToastScale.Scale, 0.01))
	end
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitShade)

	create("ImageLabel", {
		BackgroundTransparency = 1,
		Image = options.Icon or BRAND.LogoSmall,
		ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromOffset(13, 13),
		Size = UDim2.fromOffset(28, 28),
		Parent = card,
	})
	local body = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(1, -52, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = card,
	}, { pad(0, 14, 12, 13), list(3) })
	local top = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 17), LayoutOrder = 1, Parent = body })
	local title = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 1, 0),
		Text = options.Title or BRAND.Name,
		FontFace = Fonts.SemiBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = top,
	})
	local stamp = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "now",
		FontFace = Fonts.Regular,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = top,
	})
	theme:Bind(title, { TextColor3 = "Text" })
	theme:Bind(stamp, { TextColor3 = "Muted" })
	if options.Content and options.Content ~= "" then
		local text = create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = options.Content,
			FontFace = Fonts.Regular,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Parent = body,
		})
		theme:Bind(text, { TextColor3 = "SubText" })
	end

	-- the close button appears on hover, top-left
	local close = create("TextButton", {
		Name = "Close",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(18, 18),
		Visible = false,
		ZIndex = 3,
		Parent = card,
	}, { corner("full") })
	theme:Bind(close, { BackgroundColor3 = "Control" })
	theme:Bind(stroke(close), { Color = "Line", Transparency = "BorderT" })
	local closeGlyph = icon("x", 8, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 4,
		Parent = close,
	})
	theme:Bind(closeGlyph, { ImageColor3 = "SubText" })

	task.defer(fitShade)
	tween(card, { Position = UDim2.new() }, 0.5)
	tween(shade, { Position = UDim2.new() }, 0.5)

	self.ActiveToasts = self.ActiveToasts or {}
	local closed = false
	local function dismiss()
		if closed then
			return
		end
		closed = true
		local index = table.find(self.ActiveToasts, dismiss)
		if index then
			table.remove(self.ActiveToasts, index)
		end
		local away = UDim2.fromOffset(TOAST_WIDTH + 40, 0)
		tween(card, { Position = away }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(shade, { Position = away }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.3, function()
			-- then the gap closes so the others settle
			local height = holder.AbsoluteSize.Y / math.max(self.ToastScale.Scale, 0.01)
			holder.AutomaticSize = Enum.AutomaticSize.None
			holder.Size = UDim2.fromOffset(TOAST_WIDTH, height)
			tween(holder, { Size = UDim2.fromOffset(TOAST_WIDTH, 0) }, 0.25)
			task.delay(0.26, function()
				holder:Destroy()
			end)
		end)
	end
	table.insert(self.ActiveToasts, dismiss)
	if #self.ActiveToasts > MAX_TOASTS then
		self.ActiveToasts[1]()
	end
	card.MouseEnter:Connect(function()
		close.Visible = true
	end)
	card.MouseLeave:Connect(function()
		close.Visible = false
	end)
	close.Activated:Connect(dismiss)
	card.Activated:Connect(dismiss)
	if duration > 0 and duration < math.huge then
		task.delay(duration, dismiss)
	end
	return { Dismiss = dismiss }
end

function Library:Notify(options)
	local window = self.Windows[#self.Windows]
	return window and window:Notify(options)
end

-- tabs ----------------------------------------------------------------------------

function Window:AddTab(options)
	if type(options) == "string" then
		options = { Title = options }
	end
	options = options or {}
	local theme = self.Theme
	local index = #self.Tabs + 1
	local tab = setmetatable({
		Window = self,
		Title = options.Title or "Tab",
		IconName = options.Icon or "box",
		Color = options.Color or TILE_COLORS[(index - 1) % #TILE_COLORS + 1],
		Columns = options.Columns == 2 and 2 or 1,
		Index = index,
		Sections = {},
		Selected = false,
		Hovered = false,
	}, Tab)

	-- sidebar item: coloured icon tile + label; the selection is an accent fill
	local button = create("TextButton", {
		Name = tab.Title,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		Size = UDim2.new(1, 0, 0, NAV_HEIGHT),
		LayoutOrder = index,
		Parent = self.NavItems,
	}, { corner(6) })
	-- themes with their own tile colours (Halloween) recolour every tile
	local function tileColor(c)
		return c.Tiles and c.Tiles[(index - 1) % #c.Tiles + 1] or tab.Color
	end
	local tile = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		Parent = button,
	}, { corner(5) })
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
		Parent = tile,
	})
	icon(tab.IconName, 14, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ImageColor3 = Color3.new(1, 1, 1),
		Parent = tile,
	})
	theme:Bind(tile, { BackgroundColor3 = tileColor })
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Text = tab.Title,
		FontFace = Fonts.Regular,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	})
	theme:Bind(button, {
		BackgroundColor3 = function(c)
			return tab.Selected and c.Accent or c.Line
		end,
		BackgroundTransparency = function(c)
			if tab.Selected then
				return 0
			end
			return tab.Hovered and c.HoverT or 1
		end,
	})
	theme:Bind(label, { TextColor3 = function(c)
		return tab.Selected and c.OnAccent or c.Text
	end })
	tab.Button, tab.Label = button, label

	button.MouseEnter:Connect(function()
		tab.Hovered = true
		tab:_paint()
	end)
	button.MouseLeave:Connect(function()
		tab.Hovered = false
		tab:_paint()
	end)
	button.Activated:Connect(function()
		self:SelectTab(tab)
	end)

	-- page
	tab.Page = create("ScrollingFrame", {
		Name = tab.Title,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageTransparency = 0.5,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = self.Pages,
	}, { pad(24, 24, 4, 24), list(18) })
	theme:Bind(tab.Page, { ScrollBarImageColor3 = "Muted" })
	tab.Page:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if self.CurrentTab == tab then
			self:_scrollLine(tab.Page)
		end
	end)

	-- optional pane header: big icon tile, title and description
	if options.Description then
		local hero = create("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 50),
			LayoutOrder = 0,
			Parent = tab.Page,
		})
		local bigTile = create("Frame", {
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(44, 44),
			Parent = hero,
		}, { corner(10) })
		create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
			Parent = bigTile,
		})
		icon(tab.IconName, 24, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageColor3 = Color3.new(1, 1, 1),
			Parent = bigTile,
		})
		theme:Bind(bigTile, { BackgroundColor3 = tileColor })
		local heroTitle = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(58, 5),
			Size = UDim2.new(1, -58, 0, 22),
			Text = tab.Title,
			FontFace = Fonts.SemiBold,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = hero,
		})
		local heroText = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(58, 28),
			Size = UDim2.new(1, -58, 0, 16),
			Text = options.Description,
			FontFace = Fonts.Regular,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = hero,
		})
		theme:Bind(heroTitle, { TextColor3 = "Text" })
		theme:Bind(heroText, { TextColor3 = "SubText" })
		tab.Hero = hero
	end

	-- sections live in one column, or two with Columns = 2. (With a list layout
	-- in the ScrollingFrame, its padding already narrows children, so no
	-- manual subtraction here.)
	local columns = create("Frame", {
		Name = "Columns",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = tab.Page,
	}, { list(14, { FillDirection = Enum.FillDirection.Horizontal }) })
	local function column(order)
		return create("Frame", {
			Name = order == 1 and "Left" or "Right",
			BackgroundTransparency = 1,
			Size = tab.Columns == 2 and UDim2.new(0.5, -7, 0, 0) or UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = columns,
		}, { list(18) })
	end
	tab.Left = column(1)
	tab.Right = tab.Columns == 2 and column(2) or tab.Left

	table.insert(self.Tabs, tab)
	if index == 1 then
		self:SelectTab(tab, true)
	end
	return tab
end

function Tab:_paint(instant)
	local theme = self.Window.Theme
	theme:Apply(self.Button, instant)
	theme:Apply(self.Label, instant)
end

function Tab:Select()
	self.Window:SelectTab(self)
end

function Window:SelectTab(tab, instant, fromHistory)
	if not tab or self.CurrentTab == tab then
		return
	end
	local previous = self.CurrentTab
	self.CurrentTab = tab
	self:ClosePopover()
	if not fromHistory then
		for i = #self.History, self.HistoryIndex + 1, -1 do
			table.remove(self.History, i)
		end
		table.insert(self.History, tab)
		self.HistoryIndex = #self.History
	end
	if self.PaintHistory then
		self.PaintHistory()
	end
	for _, other in ipairs(self.Tabs) do
		other.Selected = other == tab
		other:_paint(instant)
	end
	if previous then
		previous.Page.Visible = false
	end
	tab.Page.Visible = not self.NoResults.Visible
	self:_scrollLine(tab.Page)
	self.TitleLabel.Text = tab.Title
	if not instant then
		tab.Page.Position = UDim2.fromOffset(0, 8)
		tween(tab.Page, { Position = UDim2.new() }, 0.35)
		self.TitleLabel.TextTransparency = 1
		tween(self.TitleLabel, { TextTransparency = 0 }, 0.25)
	end
end

-- sections: a title above a rounded group of rows -----------------------------------

function Tab:AddSection(title, side)
	local options = type(title) == "table" and title or { Title = title, Side = side }
	local theme = self.Window.Theme
	local column
	if options.Side == "Right" then
		column = self.Right
	elseif options.Side == "Left" then
		column = self.Left
	else
		column = #self.Sections % 2 == 0 and self.Left or self.Right
	end

	local outer = create("Frame", {
		Name = options.Title or "Section",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #self.Sections + 1,
		Parent = column,
	}, { list(7) })
	if options.Title and options.Title ~= "" then
		local header = create("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 17),
			Text = options.Title,
			FontFace = Fonts.SemiBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
			Parent = outer,
		}, { pad(2, 0, 0, 0) })
		theme:Bind(header, { TextColor3 = "Text" })
	end
	local box = create("Frame", {
		Name = "Group",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = outer,
	}, { corner(10), list(0) })
	theme:Bind(box, { BackgroundColor3 = "Group" })
	theme:Bind(stroke(box), { Color = "Line", Transparency = "BorderT" })
	if options.Footer then
		local footer = create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = options.Footer,
			FontFace = Fonts.Regular,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Parent = outer,
		}, { pad(2, 2, 0, 0) })
		theme:Bind(footer, { TextColor3 = "SubText" })
	end

	local section = setmetatable({
		Window = self.Window,
		Tab = self,
		Title = options.Title,
		Outer = outer,
		Holder = box,
		Elements = {},
		Order = 0,
		Narrow = self.Columns == 2,
	}, Section)
	table.insert(self.Sections, section)
	return section
end

-- one row inside the group; rows after the first get an inset hairline on top
function Section:_row(options, height, search)
	local theme = self.Window.Theme
	self.Order += 1
	local row = create("Frame", {
		Name = options.Title or options.Placeholder or "Row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = self.Order,
		Parent = self.Holder,
	})
	local separator = create("Frame", {
		Name = "Separator",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 0, 1),
		Visible = #self.Elements > 0,
		Parent = row,
	})
	theme:Bind(separator, { BackgroundColor3 = "Line", BackgroundTransparency = "SeparatorT" })
	table.insert(self.Elements, {
		Row = row,
		Separator = separator,
		Search = string.lower(search or ((options.Title or "") .. " " .. (options.Description or ""))),
	})
	return row
end

function Section:_refreshSeparators()
	local first = true
	for _, element in ipairs(self.Elements) do
		if element.Row.Visible then
			element.Separator.Visible = not first
			first = false
		end
	end
end

-- title (and optional description) on the left of a row
function Section:_text(row, options, reserve, x)
	local theme = self.Window.Theme
	x = x or 12
	local hasDescription = options.Description and options.Description ~= ""
	local width = -(x + 12 + (reserve > 0 and reserve + 12 or 0))
	local title = create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = hasDescription and UDim2.fromOffset(x, 10) or UDim2.new(0, x, 0.5, -9),
		Size = UDim2.new(1, width, 0, 18),
		Text = options.Title or "",
		FontFace = Fonts.Regular,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	theme:Bind(title, { TextColor3 = "Text" })
	if hasDescription then
		local description = create("TextLabel", {
			Name = "Description",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, 29),
			Size = UDim2.new(1, width, 0, 15),
			Text = options.Description,
			FontFace = Fonts.Regular,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		theme:Bind(description, { TextColor3 = "SubText" })
	end
	return title
end

local function rowHeight(options)
	return (options.Description and options.Description ~= "") and ROW_TALL or ROW
end

-- switch (NSSwitch) -----------------------------------------------------------------

function Section:AddToggle(options)
	local window, theme = self.Window, self.Window.Theme
	local toggle = { Type = "Toggle", Title = options.Title or "", Value = options.Default == true, Default = options.Default == true }
	local hasKey = options.Keybind ~= nil
	local row = self:_row(options, rowHeight(options))
	local hit = create("TextButton", { Name = "Hit", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = row })
	self:_text(row, options, hasKey and 120 or 40)

	local track = create("Frame", {
		Name = "Switch",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(38, 22),
		Parent = row,
	}, { corner("full") })
	local trackBorder = stroke(track)
	-- the knob is a container so its little shadow travels with it
	local knob = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), ZIndex = 2, Parent = track })
	local knobShadow = create("Frame", {
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.78,
		Parent = knob,
	}, { corner("full") })
	local knobFace = create("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = knob }, { corner("full") })
	theme:Bind(track, { BackgroundColor3 = function(c)
		return toggle.Value and c.Accent or c.Track
	end })
	theme:Bind(trackBorder, { Color = "Line", Transparency = function(c)
		return toggle.Value and 1 or c.BorderT
	end })
	theme:Bind(knobFace, { BackgroundColor3 = function(c)
		return toggle.Value and c.KnobOn or c.Knob
	end })

	local pressed = false
	local function render(instant)
		theme:Apply(track, instant)
		theme:Apply(trackBorder, instant)
		theme:Apply(knobFace, instant)
		local goal = {
			AnchorPoint = Vector2.new(toggle.Value and 1 or 0, 0.5),
			Position = toggle.Value and UDim2.new(1, -2, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
			Size = UDim2.fromOffset(pressed and 23 or 18, 18),
		}
		if instant then
			for key, value in pairs(goal) do
				knob[key] = value
			end
		else
			tween(knob, goal, 0.25)
		end
	end

	function toggle:Set(value, silent)
		toggle.Value = value == true
		render()
		if not silent and options.Callback then
			task.spawn(options.Callback, toggle.Value)
		end
	end

	hit.MouseButton1Down:Connect(function()
		pressed = true
		render()
	end)
	hit.MouseLeave:Connect(function()
		if pressed then
			pressed = false
			render()
		end
	end)
	hit.Activated:Connect(function()
		pressed = false
		toggle:Set(not toggle.Value)
	end)
	knobShadow.Visible = true

	if hasKey then
		local holder = create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -60, 0.5, 0),
			Size = UDim2.fromOffset(70, 24),
			ZIndex = 2,
			Parent = row,
		})
		local keyState = shortcutField(window, holder, resolveKey(options.Keybind))
		toggle.KeyState = keyState
		window:_connect(UserInputService.InputBegan:Connect(function(input, processed)
			if processed or window.ListeningForKey or keyState.Listening then
				return
			end
			if keyState.Key and input.KeyCode == keyState.Key then
				toggle:Set(not toggle.Value)
			end
		end))
	end

	if options.Track ~= false then
		table.insert(window.Toggles, toggle)
	end
	render(true)
	return register(self.Window, options, toggle)
end

-- checkbox ------------------------------------------------------------------------

function Section:AddCheckbox(options)
	local window, theme = self.Window, self.Window.Theme
	local checkbox = { Type = "Checkbox", Title = options.Title or "", Value = options.Default == true, Default = options.Default == true }
	local row = self:_row(options, rowHeight(options))
	local hit = create("TextButton", { Name = "Hit", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = row })
	self:_text(row, options, 0, 40)

	local box = create("Frame", {
		Name = "Box",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = (options.Description and options.Description ~= "") and UDim2.new(0, 14, 0, 19) or UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		Parent = row,
	}, { corner(4) })
	local border = stroke(box)
	topHighlight(theme, box, 4)
	local mark = icon("check", 12, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 3,
		Parent = box,
	})
	local markScale = create("UIScale", { Parent = mark })
	theme:Bind(box, { BackgroundColor3 = function(c)
		return checkbox.Value and c.Accent or c.Field
	end })
	theme:Bind(border, { Color = "Line", Transparency = function(c)
		return checkbox.Value and 1 or c.BorderT - 0.06
	end })
	theme:Bind(mark, { ImageColor3 = "OnAccent" })

	local function render(instant)
		theme:Apply(box, instant)
		theme:Apply(border, instant)
		mark.ImageTransparency = checkbox.Value and 0 or 1
		if checkbox.Value and not instant then
			markScale.Scale = 0.5
			tween(markScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
		end
	end

	function checkbox:Set(value, silent)
		checkbox.Value = value == true
		render()
		if not silent and options.Callback then
			task.spawn(options.Callback, checkbox.Value)
		end
	end
	hit.Activated:Connect(function()
		checkbox:Set(not checkbox.Value)
	end)

	if options.Track ~= false then
		table.insert(window.Toggles, checkbox)
	end
	render(true)
	return register(self.Window, options, checkbox)
end

-- slider (NSSlider) -----------------------------------------------------------------

function Section:AddSlider(options)
	local window, theme = self.Window, self.Window.Theme
	local min, max = options.Min or 0, options.Max or 100
	local step = options.Step or options.Increment or 1
	if min > max then
		min, max = max, min
	end
	if step <= 0 then
		step = 1
	end
	local suffix = options.Suffix or ""
	local default = math.clamp(options.Default or min, min, max)
	local slider = { Type = "Slider", Value = default, Default = default }
	local stacked = self.Narrow or options.Stacked == true
	local hasDescription = options.Description and options.Description ~= ""
	local height = stacked and (hasDescription and 76 or 62) or rowHeight(options)
	local row = self:_row(options, height)

	local decimals = 0
	local stepText = tostring(step)
	local dot = stepText:find("%.")
	if dot then
		decimals = #stepText - dot
	end
	local function format(value)
		if decimals > 0 then
			return string.format("%." .. decimals .. "f", value)
		end
		return tostring(math.floor(value + 0.5))
	end

	-- inline: title left, slider + value field right. stacked: track below.
	local area
	if stacked then
		self:_text(row, { Title = options.Title, Description = options.Description }, 64)
		local top = hasDescription and 52 or 38
		area = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, top),
			Size = UDim2.new(1, -24, 0, 20),
			Parent = row,
		})
	else
		self:_text(row, options, 250)
		area = create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -72, 0.5, 0),
			Size = UDim2.fromOffset(186, 20),
			Parent = row,
		})
	end

	-- value field: shows the number, click to type one
	local fieldFocused = false
	local field = create("TextBox", {
		Name = "Value",
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = stacked and UDim2.new(1, -12, 0, hasDescription and 19 or 21) or UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(52, 22),
		FontFace = Fonts.Regular,
		TextSize = 13,
		Parent = row,
	}, { corner(5) })
	local fieldBorder = stroke(field)
	local fieldRing = focusRing(theme, field, 5)
	theme:Bind(field, { BackgroundColor3 = "Field", TextColor3 = "Text" })
	theme:Bind(fieldBorder, {
		Color = function(c)
			return fieldFocused and c.Accent or c.Line
		end,
		Transparency = function(c)
			return fieldFocused and 0 or c.BorderT
		end,
	})

	local track = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 9, 0.5, 0),
		Size = UDim2.new(1, -18, 0, 4),
		Parent = area,
	}, { corner("full") })
	local fill = create("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = track }, { corner("full") })
	theme:Bind(track, { BackgroundColor3 = "Track" })
	theme:Bind(fill, { BackgroundColor3 = "Accent" })

	-- tick marks under the track (optional)
	if options.Ticks and options.Ticks > 1 then
		for i = 0, options.Ticks - 1 do
			local tick = create("Frame", {
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(i / (options.Ticks - 1), 0, 1, 5),
				Size = UDim2.fromOffset(2, 5),
				Parent = track,
			}, { corner(1) })
			theme:Bind(tick, { BackgroundColor3 = "Muted" })
		end
	end

	-- round white knob with a soft shadow
	local knob = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		ZIndex = 2,
		Parent = track,
	})
	create("Frame", {
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.75,
		Parent = knob,
	}, { corner("full") })
	local knobFace = create("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = knob }, {
		corner("full"),
		create("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.85, Thickness = 1 }),
	})
	local dragging = false
	theme:Bind(knobFace, { BackgroundColor3 = function(c)
		return dragging and c.Knob:Lerp(Color3.new(0.8, 0.8, 0.82), 0.4) or c.Knob
	end })

	local hit = create("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 3,
		Parent = area,
	})

	local function render(instant)
		local alpha = max == min and 0 or (slider.Value - min) / (max - min)
		if not fieldFocused then
			field.Text = format(slider.Value) .. suffix
		end
		field.Size = UDim2.fromOffset(math.max(measure(format(slider.Value) .. suffix, Fonts.Regular, 13) + 16, 44), 22)
		if instant then
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
		else
			tween(fill, { Size = UDim2.fromScale(alpha, 1) }, 0.12)
			tween(knob, { Position = UDim2.fromScale(alpha, 0.5) }, 0.12)
		end
	end

	function slider:Set(value, silent)
		value = tonumber(value) or slider.Value
		value = math.clamp(value, min, max)
		value = math.clamp(min + math.floor((value - min) / step + 0.5) * step, min, max)
		value = tonumber(string.format("%." .. decimals .. "f", value))
		if value == slider.Value then
			render()
			return
		end
		slider.Value = value
		render()
		if not silent and options.Callback then
			task.spawn(options.Callback, value)
		end
	end

	field.Focused:Connect(function()
		fieldFocused = true
		fieldRing.Visible = true
		field.Text = format(slider.Value)
		theme:Apply(fieldBorder)
	end)
	field.FocusLost:Connect(function()
		fieldFocused = false
		fieldRing.Visible = false
		theme:Apply(fieldBorder)
		slider:Set(tonumber((field.Text:gsub("[^%d%.%-]", ""))))
	end)

	local function fromX(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		slider:Set(min + alpha * (max - min))
	end
	hit.InputBegan:Connect(function(input)
		if isClick(input) then
			dragging = true
			theme:Apply(knobFace)
			fromX(input.Position.X)
		end
	end)
	window:_connect(UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			fromX(input.Position.X)
		end
	end))
	window:_connect(UserInputService.InputEnded:Connect(function(input)
		if dragging and isClick(input) then
			dragging = false
			theme:Apply(knobFace)
		end
	end))

	render(true)
	return register(self.Window, options, slider)
end

-- stepper (NSStepper with a number field) ---------------------------------------------

function Section:AddStepper(options)
	local theme = self.Window.Theme
	local min, max = options.Min or 0, options.Max or 100
	local step = options.Step or 1
	if min > max then
		min, max = max, min
	end
	if step <= 0 then
		step = 1
	end
	local suffix = options.Suffix or ""
	local default = math.clamp(options.Default or min, min, max)
	local stepper = { Type = "Stepper", Value = default, Default = default }
	local row = self:_row(options, rowHeight(options))
	self:_text(row, options, 110)

	local decimals = 0
	local stepText = tostring(step)
	local dot = stepText:find("%.")
	if dot then
		decimals = #stepText - dot
	end
	local function format(value)
		return (decimals > 0 and string.format("%." .. decimals .. "f", value) or tostring(math.floor(value + 0.5))) .. suffix
	end

	local fieldFocused = false
	local field = create("TextBox", {
		Name = "Value",
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -36, 0.5, 0),
		Size = UDim2.fromOffset(64, 24),
		FontFace = Fonts.Regular,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	}, { corner(5), pad(8, 8, 0, 0) })
	local fieldBorder = stroke(field)
	local fieldRing = focusRing(theme, field, 5)
	theme:Bind(field, { BackgroundColor3 = "Field", TextColor3 = "Text" })
	theme:Bind(fieldBorder, {
		Color = function(c)
			return fieldFocused and c.Accent or c.Line
		end,
		Transparency = function(c)
			return fieldFocused and 0 or c.BorderT
		end,
	})

	local arrows = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(18, 24),
		Parent = row,
	}, { corner(5) })
	theme:Bind(arrows, { BackgroundColor3 = "Control" })
	theme:Bind(stroke(arrows), { Color = "Line", Transparency = "BorderT" })
	topHighlight(theme, arrows, 5)
	local split = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.new(1, -6, 0, 1),
		ZIndex = 2,
		Parent = arrows,
	})
	theme:Bind(split, { BackgroundColor3 = "Line", BackgroundTransparency = "BorderT" })

	local function render()
		if not fieldFocused then
			field.Text = format(stepper.Value)
		end
	end
	function stepper:Set(value, silent)
		value = math.clamp(tonumber(value) or stepper.Value, min, max)
		value = tonumber(string.format("%." .. decimals .. "f", value))
		if value == stepper.Value then
			render()
			return
		end
		stepper.Value = value
		render()
		if not silent and options.Callback then
			task.spawn(options.Callback, value)
		end
	end

	-- each half repeats while held, like the real control. Every press gets its
	-- own token so a quick second click can't revive the first press's repeat.
	local function half(glyphName, y, direction)
		local pressed = false
		local pressToken
		local button = create("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = "",
			Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(1, 0.5),
			ZIndex = 3,
			Parent = arrows,
		})
		local glyph = icon(glyphName, 8, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = button,
		})
		theme:Bind(glyph, { ImageColor3 = function(c)
			return pressed and c.Accent or c.Text
		end })
		button.MouseButton1Down:Connect(function()
			local token = {}
			pressToken = token
			pressed = true
			theme:Apply(glyph)
			stepper:Set(stepper.Value + step * direction)
			task.delay(0.4, function()
				while pressed and pressToken == token do
					stepper:Set(stepper.Value + step * direction)
					task.wait(0.07)
				end
			end)
		end)
		local function release()
			if pressed then
				pressed = false
				pressToken = nil
				theme:Apply(glyph)
			end
		end
		button.MouseButton1Up:Connect(release)
		button.MouseLeave:Connect(release)
		self.Window:_connect(UserInputService.InputEnded:Connect(function(input)
			if isClick(input) then
				release()
			end
		end))
	end
	half("chevron-up", 0, 1)
	half("chevron-down", 0.5, -1)

	field.Focused:Connect(function()
		fieldFocused = true
		fieldRing.Visible = true
		field.Text = decimals > 0 and string.format("%." .. decimals .. "f", stepper.Value) or tostring(stepper.Value)
		theme:Apply(fieldBorder)
	end)
	field.FocusLost:Connect(function()
		fieldFocused = false
		fieldRing.Visible = false
		theme:Apply(fieldBorder)
		stepper:Set(tonumber((field.Text:gsub("[^%d%.%-]", ""))))
	end)
	render()
	return register(self.Window, options, stepper)
end

-- push buttons ----------------------------------------------------------------------

-- With ButtonText: a row with a title on the left and the button on the right.
-- Without: one full-width push button.
function Section:AddButton(options)
	local theme = self.Window.Theme
	local object = {}
	if options.ButtonText then
		local row = self:_row(options, rowHeight(options))
		local width = measure(options.ButtonText, Fonts.Medium, 13) + 28 + (options.Icon and 21 or 0)
		self:_text(row, options, width)
		local holder = create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(width, 26),
			Parent = row,
		})
		local button, text = pushButton(theme, holder, options)
		object.Instance = button
		function object:SetText(value)
			text.Text = value
		end
	else
		local row = self:_row(options, 46)
		local holder = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 9),
			Size = UDim2.new(1, -24, 0, 28),
			Parent = row,
		})
		local button, text = pushButton(theme, holder, options)
		object.Instance = button
		function object:SetText(value)
			text.Text = value
		end
	end
	return register(self.Window, options, object)
end

-- a grid of push buttons, two per row by default
function Section:AddButtons(buttons, columns)
	columns = columns or 2
	local titles = {}
	for _, options in ipairs(buttons) do
		table.insert(titles, options.Title or "")
	end
	local row = self:_row({ Title = "Buttons" }, 0, table.concat(titles, " "))
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	local grid = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = row,
	}, {
		pad(12, 12, 10, 10),
		create("UIGridLayout", {
			CellSize = UDim2.new(1 / columns, -(8 * (columns - 1)) / columns, 0, 28),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local objects = {}
	for index, options in ipairs(buttons) do
		local cell = create("Frame", { BackgroundTransparency = 1, LayoutOrder = index, Parent = grid })
		objects[index] = pushButton(self.Window.Theme, cell, options)
	end
	return objects
end

-- dropdown ----------------------------------------------------------------------------------
-- A field showing the current choice with a chevron; its list drops down right
-- underneath (see OpenMenu). Options: Options, Default, Multi, Placeholder,
-- Searchable (default: more than eight options), MaxRows, Width, Callback, Flag.

function Section:AddDropdown(options)
	options = options or {}
	local window, theme = self.Window, self.Window.Theme
	local multi = options.Multi == true
	local dropdown = { Type = "Dropdown", Multi = multi, Options = table.clone(options.Options or options.Values or {}) }
	if multi then
		dropdown.Value = {}
		dropdown.Default = {}
		for _, item in ipairs(type(options.Default) == "table" and options.Default or {}) do
			if table.find(dropdown.Options, item) then
				dropdown.Value[item] = true
				table.insert(dropdown.Default, item)
			end
		end
	else
		if options.Default ~= nil and table.find(dropdown.Options, options.Default) then
			dropdown.Value = options.Default
		end
		if dropdown.Value == nil and not options.Placeholder then
			dropdown.Value = dropdown.Options[1]
		end
		dropdown.Default = dropdown.Value
	end
	local hasTitle = options.Title and options.Title ~= ""
	local row = self:_row(options, rowHeight(options))

	-- wide enough for the longest choice
	local widest = measure(options.Placeholder or "Select", Fonts.Regular, 13)
	for _, item in ipairs(dropdown.Options) do
		widest = math.max(widest, measure(tostring(item), Fonts.Regular, 13))
	end
	if multi then
		widest += measure(" +9", Fonts.Regular, 13)
	end
	local width = options.Width or math.clamp(widest + 46, 132, self.Narrow and 170 or 230)
	if hasTitle then
		self:_text(row, options, width)
	end

	local hovered, open = false, false
	local button = create("TextButton", {
		Name = "Dropdown",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = hasTitle and UDim2.fromOffset(width, 28) or UDim2.new(1, -24, 0, 28),
		Parent = row,
	}, { corner(7) })
	local border = stroke(button)
	topHighlight(theme, button, 7)
	local valueText = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -40, 1, 0),
		FontFace = Fonts.Regular,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	})
	-- the accent box with a chevron, as on macOS pull-down buttons; it flips while open
	local arrowBox = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		ZIndex = 2,
		Parent = button,
	}, { corner(5) })
	local chevron = icon("chevron-down", 12, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 3,
		Parent = arrowBox,
	})
	theme:Bind(arrowBox, { BackgroundColor3 = function(c)
		return (hovered or open) and c.AccentHover or c.Accent
	end })
	local function isEmpty()
		return (multi and next(dropdown.Value) == nil) or (not multi and dropdown.Value == nil)
	end
	theme:Bind(button, { BackgroundColor3 = function(c)
		return open and c.ControlPress or hovered and c.ControlHover or c.Control
	end })
	-- dark mode bezels have no outline (just the top highlight); light mode a hairline
	theme:Bind(border, { Color = "Line", Transparency = function(c)
		return c.Line == Color3.new(1, 1, 1) and 1 or c.BorderT
	end })
	theme:Bind(chevron, { ImageColor3 = "OnAccent" })
	theme:Bind(valueText, { TextColor3 = function(c)
		return isEmpty() and c.Muted or c.Text
	end })
	local function paint()
		theme:Apply(button)
		theme:Apply(arrowBox)
		tween(chevron, { Rotation = open and 180 or 0 }, 0.25)
	end

	-- the chosen items, in the order of the list (multi-select)
	function dropdown:GetSelected()
		local out = {}
		if not multi then
			if dropdown.Value ~= nil then
				out[1] = dropdown.Value
			end
			return out
		end
		for _, item in ipairs(dropdown.Options) do
			if dropdown.Value[item] then
				table.insert(out, item)
			end
		end
		return out
	end
	-- room for the text inside the button, in unscaled pixels
	local function textRoom()
		if hasTitle then
			return width - 40
		end
		local actual = button.AbsoluteSize.X / math.max(window.Scale.Scale, 0.01)
		return (actual > 60 and actual or width) - 40
	end
	local function display()
		if multi then
			local chosen = dropdown:GetSelected()
			if #chosen == 0 then
				valueText.Text = options.Placeholder or "None"
			else
				-- every name when they fit; otherwise "First +N"
				local names = {}
				for index, item in ipairs(chosen) do
					names[index] = tostring(item)
				end
				local text = table.concat(names, ", ")
				if #names > 1 and measure(text, Fonts.Regular, 13) > textRoom() then
					text = ("%s +%d"):format(names[1], #names - 1)
				end
				valueText.Text = text
			end
		else
			valueText.Text = dropdown.Value ~= nil and tostring(dropdown.Value) or (options.Placeholder or "Select")
		end
		theme:Apply(valueText)
	end
	local function fire()
		if options.Callback then
			task.spawn(options.Callback, multi and dropdown:GetSelected() or dropdown.Value)
		end
	end

	-- values that aren't in the list are ignored (nil clears a single choice)
	function dropdown:Set(value, silent)
		if multi then
			local chosen = {}
			for _, item in ipairs(type(value) == "table" and value or {}) do
				if table.find(dropdown.Options, item) then
					chosen[item] = true
				end
			end
			dropdown.Value = chosen
		else
			if value ~= nil and not table.find(dropdown.Options, value) then
				return
			end
			dropdown.Value = value
		end
		display()
		if not silent then
			fire()
		end
	end

	-- replace the list; choices that are no longer in it are dropped
	function dropdown:Refresh(items)
		items = table.clone(items or {})
		if open then
			window:ClosePopover()
		end
		dropdown.Options = items
		if multi then
			for item in pairs(dropdown.Value) do
				if not table.find(items, item) then
					dropdown.Value[item] = nil
				end
			end
		elseif dropdown.Value == nil or not table.find(items, dropdown.Value) then
			if options.Placeholder then
				dropdown.Value = nil
			else
				dropdown.Value = items[1]
			end
		end
		display()
	end
	dropdown.SetOptions = dropdown.Refresh

	button.MouseEnter:Connect(function()
		hovered = true
		paint()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		paint()
	end)
	-- the list opens scrolled to the current choice (or the first chosen one)
	local function selectedIndex()
		if multi then
			for index, item in ipairs(dropdown.Options) do
				if dropdown.Value[item] then
					return index
				end
			end
			return nil
		end
		return table.find(dropdown.Options, dropdown.Value)
	end
	button.Activated:Connect(function()
		if open then
			return
		end
		open = true
		paint()
		local popover = window:OpenMenu(button, {
			Items = dropdown.Options,
			Multi = multi,
			Align = "Right",
			Searchable = options.Searchable,
			MaxRows = options.MaxRows,
			Selected = selectedIndex(),
			IsSelected = function(item)
				if multi then
					return dropdown.Value[item] == true
				end
				return dropdown.Value == item
			end,
			OnPick = function(item)
				if multi then
					dropdown.Value[item] = not dropdown.Value[item] or nil
				else
					dropdown.Value = item
				end
				display()
				fire()
			end,
			OnSetAll = function(on)
				dropdown.Value = {}
				if on then
					for _, item in ipairs(dropdown.Options) do
						dropdown.Value[item] = true
					end
				end
				display()
				fire()
			end,
		})
		popover.OnClose = function()
			open = false
			paint()
		end
	end)
	display()
	if not hasTitle then
		-- a full-width button only knows its real width once it's laid out
		button:GetPropertyChangedSignal("AbsoluteSize"):Connect(display)
	end
	return register(self.Window, options, dropdown)
end

-- text field ------------------------------------------------------------------------

function Section:AddInput(options)
	local theme = self.Window.Theme
	local input = { Type = "Input", Value = options.Default or "", Default = options.Default or "" }
	local hasTitle = options.Title and options.Title ~= ""
	local width = options.Width or (self.Narrow and 130 or 190)
	local row = self:_row(options, rowHeight(options), (options.Title or "") .. " " .. (options.Placeholder or ""))
	if hasTitle then
		self:_text(row, options, width)
	end
	local focused = false
	local field = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = hasTitle and UDim2.fromOffset(width, 26) or UDim2.new(1, -24, 0, 26),
		Parent = row,
	}, { corner(6) })
	local border = stroke(field)
	local ring = focusRing(theme, field, 6)
	local box = create("TextBox", {
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(9, 0),
		Size = UDim2.new(1, -18, 1, 0),
		Text = tostring(input.Value),
		PlaceholderText = options.Placeholder or "",
		FontFace = Fonts.Regular,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = field,
	})
	theme:Bind(field, { BackgroundColor3 = "Field" })
	theme:Bind(box, { TextColor3 = "Text", PlaceholderColor3 = "Muted" })
	theme:Bind(border, {
		Color = function(c)
			return focused and c.Accent or c.Line
		end,
		Transparency = function(c)
			return focused and 0 or c.BorderT
		end,
	})
	box.Focused:Connect(function()
		focused = true
		ring.Visible = true
		theme:Apply(border)
	end)
	box.FocusLost:Connect(function(enterPressed)
		focused = false
		ring.Visible = false
		theme:Apply(border)
		local value = box.Text
		if options.Numeric then
			value = tonumber(value)
			if not value then
				box.Text = tostring(input.Value)
				return
			end
		end
		if value == input.Value then
			return
		end
		input.Value = value
		if options.Callback then
			task.spawn(options.Callback, value, enterPressed)
		end
	end)

	function input:Set(value, silent)
		if value == nil then
			value = ""
		end
		input.Value = value
		box.Text = tostring(value)
		if not silent and options.Callback then
			task.spawn(options.Callback, value)
		end
	end
	return register(self.Window, options, input)
end

-- shortcut recorder -----------------------------------------------------------------

function Section:AddKeybind(options)
	local window = self.Window
	local row = self:_row(options, rowHeight(options))
	self:_text(row, options, 110)
	local holder = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(110, 24),
		Parent = row,
	})
	local initial = resolveKey(options.Default)
	local keyState = shortcutField(window, holder, initial, options.ChangedCallback)
	local keybind = { Type = "Keybind", State = keyState, Default = initial }
	setmetatable(keybind, { __index = function(_, key)
		if key == "Value" then
			return keyState.Key
		end
	end })
	window:_connect(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or window.ListeningForKey or keyState.Listening then
			return
		end
		if keyState.Key and input.KeyCode == keyState.Key and options.Callback then
			task.spawn(options.Callback, keyState.Key)
		end
	end))
	function keybind:Set(key)
		keyState:Set(key)
		if options.ChangedCallback then
			task.spawn(options.ChangedCallback, keyState.Key)
		end
	end
	return register(self.Window, options, keybind)
end

-- segmented control (NSSegmentedControl) -----------------------------------------------

function Section:AddSegmented(options)
	local theme = self.Window.Theme
	local items = options.Options or {}
	local count = math.max(#items, 1)
	local segmented = { Type = "Segmented", Value = options.Default or items[1], Default = options.Default or items[1] }
	local segmentWidth = 0
	for _, item in ipairs(items) do
		segmentWidth = math.max(segmentWidth, measure(tostring(item), Fonts.Medium, 13) + 26)
	end
	local width = segmentWidth * count + 4
	local hasTitle = options.Title and options.Title ~= ""
	local hasDescription = options.Description and options.Description ~= ""
	local baseHeight = rowHeight(options)
	local row = self:_row(options, baseHeight)
	local title, description
	if hasTitle then
		title = self:_text(row, options, width)
		description = row:FindFirstChild("Description")
	end
	local track = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(width, 26),
		Parent = row,
	}, { corner(7) })
	theme:Bind(track, { BackgroundColor3 = "Line", BackgroundTransparency = function(c)
		return c.Line == Color3.new(1, 1, 1) and 0.92 or 0.94
	end })
	-- segments are laid out in fractions of this inner strip, so the control can
	-- shrink or stretch with the row instead of overflowing it
	local inner = create("Frame", {
		Name = "Segments",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 0),
		Size = UDim2.new(1, -4, 1, 0),
		Parent = track,
	})
	local indicator = create("Frame", {
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(1 / count, 0, 1, -4),
		Parent = inner,
	}, { corner(5) })
	theme:Bind(indicator, { BackgroundColor3 = "Segment" })
	theme:Bind(stroke(indicator), { Color = Color3.new(0, 0, 0), Transparency = function(c)
		return c.Line == Color3.new(1, 1, 1) and 0.7 or 0.9
	end })
	topHighlight(theme, indicator, 5)

	-- thin separators between segments, hidden next to the selected one
	local separators = {}
	for i = 1, count - 1 do
		local line = create("Frame", {
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(i / count, 0, 0.5, 0),
			Size = UDim2.fromOffset(1, 12),
			Parent = inner,
		})
		theme:Bind(line, { BackgroundColor3 = "Line", BackgroundTransparency = "BorderT" })
		separators[i] = line
	end

	local labels = {}
	local function render(instant)
		local index = table.find(items, segmented.Value) or 1
		local position = UDim2.new((index - 1) / count, 0, 0, 2)
		if instant then
			indicator.Position = position
		else
			tween(indicator, { Position = position }, 0.25)
		end
		for i, line in ipairs(separators) do
			line.Visible = i ~= index and i ~= index - 1
		end
		for _, label in ipairs(labels) do
			theme:Apply(label, instant)
		end
	end

	function segmented:Set(value, silent)
		if not table.find(items, value) then
			return
		end
		segmented.Value = value
		render()
		if not silent and options.Callback then
			task.spawn(options.Callback, value)
		end
	end

	for index, item in ipairs(items) do
		local button = create("TextButton", {
			Name = tostring(item),
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale((index - 1) / count, 0),
			Size = UDim2.fromScale(1 / count, 1),
			Text = tostring(item),
			FontFace = Fonts.Medium,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = inner,
		})
		theme:Bind(button, { TextColor3 = function(c)
			return segmented.Value == item and c.Text or c.SubText
		end })
		table.insert(labels, button)
		button.Activated:Connect(function()
			if segmented.Value ~= item then
				segmented:Set(item)
			end
		end)
	end
	render(true)

	-- Layout: title on the left and the control on the right when both fit;
	-- otherwise (narrow columns) the title goes on top and the control runs the
	-- full width of the row underneath it.
	local titleNeed = 0
	if hasTitle then
		titleNeed = measure(options.Title, Fonts.Regular, 14)
		if hasDescription then
			titleNeed = math.max(titleNeed, math.min(measure(options.Description, Fonts.Regular, 12), 120))
		end
		titleNeed = math.min(titleNeed, 140) + 12
	end
	local function logicalWidth()
		-- AbsoluteSize includes every UIScale above the row; undo them
		local scale = 1
		local node = row.Parent
		while node do
			local uiScale = node:FindFirstChildOfClass("UIScale")
			if uiScale then
				scale *= uiScale.Scale
			end
			node = node.Parent
		end
		return row.AbsoluteSize.X / math.max(scale, 0.01)
	end
	local lastMode, lastWidth
	local function layout()
		local available = logicalWidth()
		if available < 1 then
			return -- not on screen yet; laid out once it gets a size
		end
		local inline = 12 + titleNeed + width + 12 <= available
		local mode = (inline or not hasTitle) and "inline" or "stacked"
		local trackWidth = math.min(width, available - 24)
		if mode == lastMode and (mode == "stacked" or trackWidth == lastWidth) then
			return
		end
		lastMode, lastWidth = mode, trackWidth
		if mode == "inline" then
			row.Size = UDim2.new(1, 0, 0, baseHeight)
			track.AnchorPoint = Vector2.new(1, 0.5)
			track.Position = UDim2.new(1, -12, 0.5, 0)
			track.Size = UDim2.fromOffset(trackWidth, 26)
			if title then
				local reserve = -(24 + trackWidth + 12)
				title.Position = hasDescription and UDim2.fromOffset(12, 10) or UDim2.new(0, 12, 0.5, -9)
				title.Size = UDim2.new(1, reserve, 0, 18)
				if description then
					description.Size = UDim2.new(1, reserve, 0, 15)
				end
			end
		else
			local top = hasDescription and 52 or 34
			row.Size = UDim2.new(1, 0, 0, top + 26 + 10)
			track.AnchorPoint = Vector2.new(0, 0)
			track.Position = UDim2.fromOffset(12, top)
			track.Size = UDim2.new(1, -24, 0, 26)
			title.Position = UDim2.fromOffset(12, 10)
			title.Size = UDim2.new(1, -24, 0, 18)
			if description then
				description.Size = UDim2.new(1, -24, 0, 15)
			end
		end
	end
	row:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()

	return register(self.Window, options, segmented)
end

-- colour swatches (the accent picker) ---------------------------------------------------
-- Auto = true adds macOS's "Multicolor" swatch in front: it stands for no colour
-- (Value nil), meaning "use the theme's own".

function Section:AddSwatches(options)
	local colors = options.Colors or ACCENTS
	local auto = options.Auto == true
	local initial = options.Default
	if initial == nil and not auto then
		initial = colors[1]
	end
	local swatches = { Type = "Swatches", Value = initial, Default = initial }
	local size, gap = 18, 9
	local count = #colors + (auto and 1 or 0)
	local width = count * size + math.max(count - 1, 0) * gap
	local row = self:_row(options, rowHeight(options))
	self:_text(row, options, width + 4)
	local holder = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(width, size),
		Parent = row,
	})
	local marks = {}
	local function isSelected(color)
		if color == nil then
			return swatches.Value == nil
		end
		return swatches.Value ~= nil and color:ToHex() == swatches.Value:ToHex()
	end
	local function render()
		for _, mark in ipairs(marks) do
			local selected = isSelected(mark.Color)
			tween(mark.Dot, { BackgroundTransparency = selected and 0 or 1 }, 0.15)
			tween(mark.Ring, { Transparency = selected and 0.35 or 1 }, 0.15)
		end
	end
	function swatches:Set(color, silent)
		swatches.Value = color
		render()
		if not silent and options.Callback then
			task.spawn(options.Callback, color)
		end
	end

	local function swatch(slot, color)
		local button = create("TextButton", {
			Name = color and ("Swatch" .. slot) or "Multicolor",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
			BackgroundColor3 = color or Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((slot - 1) * (size + gap) + size / 2, size / 2),
			Size = UDim2.fromOffset(size, size),
			Parent = holder,
		}, { corner("full") })
		if color then
			create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(220, 220, 220)),
				Parent = button,
			})
		else
			-- the rainbow of the accent colours
			local keypoints = {}
			for i = 1, 7 do
				table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / 6, ACCENTS[i]))
			end
			create("UIGradient", { Rotation = 45, Color = ColorSequence.new(keypoints), Parent = button })
		end
		stroke(button, { Color = Color3.new(0, 0, 0), Transparency = 0.82 })
		local ring = Instance.new("UIStroke")
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Thickness = 2
		ring.Transparency = 1
		pcall(function()
			ring.BorderStrokePosition = Enum.BorderStrokePosition.Outer
			ring.BorderOffset = UDim.new(0, 2)
		end)
		ring.Color = color or Color3.fromRGB(150, 150, 156)
		local ringHolder = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = button,
		}, { corner("full") })
		ring.Parent = ringHolder
		local dot = create("Frame", {
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = button,
		}, { corner("full") })
		local scale = create("UIScale", { Parent = button })
		table.insert(marks, { Color = color, Dot = dot, Ring = ring })
		button.MouseEnter:Connect(function()
			tween(scale, { Scale = 1.12 }, 0.12)
		end)
		button.MouseLeave:Connect(function()
			tween(scale, { Scale = 1 }, 0.12)
		end)
		button.Activated:Connect(function()
			swatches:Set(color)
		end)
	end

	if auto then
		swatch(1, nil)
	end
	for index, color in ipairs(colors) do
		swatch(index + (auto and 1 or 0), color)
	end
	render()
	return register(self.Window, options, swatches)
end

-- progress bar (NSProgressIndicator) ------------------------------------------------------

function Section:AddProgress(options)
	local theme = self.Window.Theme
	local progress = { Value = math.clamp(options.Default or options.Value or 0, 0, 1) }
	local hasTitle = options.Title and options.Title ~= ""
	local row = self:_row(options, rowHeight(options))
	local barWidth = self.Narrow and 120 or 200
	if hasTitle then
		self:_text(row, options, barWidth + 44)
	end
	local percent = create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(36, 16),
		FontFace = Fonts.Regular,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	theme:Bind(percent, { TextColor3 = "SubText" })
	local track = create("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -54, 0.5, 0),
		Size = hasTitle and UDim2.fromOffset(barWidth, 6) or UDim2.new(1, -66, 0, 6),
		Parent = row,
	}, { corner("full") })
	local fill = create("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = track }, { corner("full") })
	theme:Bind(track, { BackgroundColor3 = "Track" })
	theme:Bind(fill, { BackgroundColor3 = "Accent" })
	function progress:Set(value)
		progress.Value = math.clamp(tonumber(value) or 0, 0, 1)
		percent.Text = math.floor(progress.Value * 100 + 0.5) .. "%"
		tween(fill, { Size = UDim2.fromScale(progress.Value, 1) }, 0.3)
	end
	progress:Set(progress.Value)
	return progress
end

-- paragraph / label / divider -------------------------------------------------------------

function Section:AddParagraph(options)
	if type(options) == "string" then
		options = { Content = options }
	end
	local theme = self.Window.Theme
	local row = self:_row({ Title = options.Title or "Paragraph" }, 0, (options.Title or "") .. " " .. (options.Content or ""))
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	local body = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = row,
	}, { pad(12, 12, 11, 12), list(3) })
	local title
	if options.Title then
		title = create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Text = options.Title,
			FontFace = Fonts.SemiBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Parent = body,
		})
		theme:Bind(title, { TextColor3 = "Text" })
	end
	local content = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = options.Content or "",
		FontFace = Fonts.Regular,
		TextSize = 13,
		TextWrapped = true,
		RichText = options.RichText == true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LineHeight = 1.15,
		LayoutOrder = 2,
		Parent = body,
	})
	theme:Bind(content, { TextColor3 = "SubText" })

	local paragraph = {}
	function paragraph:Set(newOptions)
		if type(newOptions) == "string" then
			newOptions = { Content = newOptions }
		end
		if title and newOptions.Title then
			title.Text = newOptions.Title
		end
		if newOptions.Content then
			content.Text = newOptions.Content
		end
	end
	return paragraph
end

function Section:AddLabel(text)
	return self:AddParagraph({ Content = text })
end

-- kept for compatibility: groups already separate their rows with hairlines
function Section:AddDivider() end

-- tabs forward element calls to an implicit, untitled section
for _, method in ipairs({
	"AddToggle", "AddCheckbox", "AddSlider", "AddStepper", "AddButton", "AddButtons", "AddDropdown",
	"AddInput", "AddKeybind", "AddSegmented", "AddSwatches", "AddProgress", "AddParagraph", "AddLabel", "AddDivider",
}) do
	Tab[method] = function(self, ...)
		self.DefaultSection = self.DefaultSection or self:AddSection()
		return self.DefaultSection[method](self.DefaultSection, ...)
	end
end

-- configs -------------------------------------------------------------------------
-- Saved with the executor's file API when it exists (writefile & co.);
-- otherwise kept in memory for the session.

local function fileApi()
	return typeof(writefile) == "function"
		and typeof(readfile) == "function"
		and typeof(isfile) == "function"
		and typeof(listfiles) == "function"
		and typeof(isfolder) == "function"
		and typeof(makefolder) == "function"
end

local function exportFlag(object)
	if object.Type == "Dropdown" and object.Multi then
		return object:GetSelected()
	elseif object.Type == "Keybind" then
		return object.Value and object.Value.Name or "None"
	elseif object.Type == "Swatches" then
		return object.Value and object.Value:ToHex()
	end
	return object.Value
end

local function importFlag(object, value)
	if object.Type == "Keybind" then
		object:Set(resolveKey(value))
	elseif object.Type == "Swatches" then
		object:Set(Color3.fromHex(value))
	else
		object:Set(value)
	end
end

function Window:_configStore()
	local folder = self.Options.ConfigFolder or "fihOS"
	local directory = folder .. "/configs"
	local store = {}
	if fileApi() then
		local function ensure()
			if not isfolder(folder) then
				makefolder(folder)
			end
			if not isfolder(directory) then
				makefolder(directory)
			end
		end
		function store.List()
			ensure()
			local names = {}
			for _, path in ipairs(listfiles(directory)) do
				local name = path:match("([^/\\]+)%.json$")
				if name then
					table.insert(names, name)
				end
			end
			table.sort(names)
			return names
		end
		function store.Read(name)
			local path = directory .. "/" .. name .. ".json"
			return isfile(path) and HttpService:JSONDecode(readfile(path)) or nil
		end
		function store.Write(name, data)
			ensure()
			writefile(directory .. "/" .. name .. ".json", HttpService:JSONEncode(data))
		end
		function store.Delete(name)
			local path = directory .. "/" .. name .. ".json"
			if isfile(path) and typeof(delfile) == "function" then
				delfile(path)
			end
		end
		function store.GetAutoload()
			local path = folder .. "/autoload.txt"
			return isfile(path) and readfile(path) or nil
		end
		function store.SetAutoload(name)
			ensure()
			if name then
				writefile(folder .. "/autoload.txt", name)
			elseif isfile(folder .. "/autoload.txt") and typeof(delfile) == "function" then
				delfile(folder .. "/autoload.txt")
			end
		end
		store.Persistent = true
	else
		local memory = Library.MemoryConfigs
		function store.List()
			local names = {}
			for name in pairs(memory) do
				if string.sub(name, 1, 1) ~= "\0" then
					table.insert(names, name)
				end
			end
			table.sort(names)
			return names
		end
		function store.Read(name)
			return memory[name]
		end
		function store.Write(name, data)
			memory[name] = data
		end
		function store.Delete(name)
			memory[name] = nil
		end
		function store.GetAutoload()
			return memory["\0autoload"]
		end
		function store.SetAutoload(name)
			memory["\0autoload"] = name
		end
		store.Persistent = false
	end
	return store
end

-- returns whether it was written
function Window:SaveConfig(name)
	local data = {}
	for flag, object in pairs(self.Flags) do
		local ok, value = pcall(exportFlag, object)
		if ok and value ~= nil then
			data[flag] = value
		end
	end
	local ok, problem = pcall(self.Configs.Write, name, data)
	if not ok then
		warn(('fihOS: could not save configuration "%s": %s'):format(tostring(name), tostring(problem)))
	end
	return ok
end

-- returns false when there's no such configuration (or its file is damaged)
function Window:LoadConfig(name)
	local ok, data = pcall(self.Configs.Read, name)
	if not ok or type(data) ~= "table" then
		return false
	end
	for flag, value in pairs(data) do
		local object = self.Flags[flag]
		if object then
			pcall(importFlag, object, value)
		end
	end
	return true
end

function Window:ResetFlags()
	for _, object in pairs(self.Flags) do
		if type(object.Set) == "function" then
			pcall(object.Set, object, object.Default)
		end
	end
end

function Window:CenterWindow()
	self.RestPosition = UDim2.fromScale(0.5, 0.5)
	if self.IsOpen then
		tween(self.Root, { Position = self.RestPosition }, 0.35)
	else
		self.Root.Position = self.RestPosition
	end
end

-- configs tab (optional): save your options under a name, load them again, and pick
-- one to load at launch.
function Window:AddConfigTab(options)
	options = options or {}
	local store = self.Configs
	local tab = self:AddTab({
		Title = options.Title or "Configs",
		Icon = options.Icon or "folder",
		Color = options.Color,
		Description = options.Description or "Save your options and load them again later.",
	})
	self.ConfigTab = tab

	local configs = tab:AddSection({
		Title = "Configurations",
		Footer = store.Persistent and "Saved to your executor's workspace folder."
			or "File access isn't available here, so configurations last for this session only.",
	})
	local nameInput = configs:AddInput({ Title = "Name", Placeholder = "New configuration" })
	local picker, autoToggle, status
	local function autoloadText()
		return ("Loads at launch: %s"):format(store.GetAutoload() or "none")
	end
	local function syncAutoload()
		autoToggle:Set(picker.Value ~= nil and store.GetAutoload() == picker.Value, true)
		status:Set(autoloadText())
	end
	picker = configs:AddDropdown({
		Title = "Saved",
		Options = store.List(),
		Placeholder = "None",
		Callback = function()
			syncAutoload()
		end,
	})
	local function refresh(select)
		picker:Refresh(store.List())
		if select then
			picker:Set(select, true)
		end
		syncAutoload()
	end
	local function cleanName(text)
		text = (text or ""):gsub("[^%w%-_ ]", ""):sub(1, 40)
		text = text:match("^%s*(.-)%s*$")
		return text ~= "" and text or nil
	end
	-- feedback goes to a banner, or to the status line when banners are off
	local statusToken
	local function notify(title, content)
		if self.NotificationsEnabled == false then
			local token = {}
			statusToken = token
			status:Set(content)
			task.delay(4, function()
				if statusToken == token then
					status:Set(autoloadText())
				end
			end)
		else
			self:Notify({ Title = title, Content = content, Duration = 4 })
		end
	end
	configs:AddButtons({
		{ Title = "Create", Callback = function()
			local name = cleanName(nameInput.Value)
			if not name then
				return notify("Name needed", "Type a name for the configuration first.")
			end
			if store.Read(name) then
				return notify("Already exists", ('"%s" is already saved. Use Save to overwrite it.'):format(name))
			end
			if not self:SaveConfig(name) then
				return notify("Couldn't save", "The configuration could not be written.")
			end
			nameInput:Set("", true)
			refresh(name)
			notify("Configuration created", ('Saved "%s".'):format(name))
		end },
		{ Title = "Save", Callback = function()
			local name = picker.Value or cleanName(nameInput.Value)
			if not name then
				return notify("Nothing selected", "Pick a configuration or type a name.")
			end
			if not self:SaveConfig(name) then
				return notify("Couldn't save", "The configuration could not be written.")
			end
			refresh(name)
			notify("Configuration saved", ('Saved "%s".'):format(name))
		end },
		{ Title = "Load", Callback = function()
			local name = picker.Value
			if not name or not self:LoadConfig(name) then
				return notify("Nothing to load", "Pick a saved configuration first.")
			end
			notify("Configuration loaded", ('Loaded "%s".'):format(name))
		end },
		{ Title = "Delete", Style = "Danger", Callback = function()
			local name = picker.Value
			if not name then
				return notify("Nothing selected", "Pick a configuration to delete.")
			end
			store.Delete(name)
			if store.GetAutoload() == name then
				store.SetAutoload(nil)
			end
			picker:Set(nil, true)
			refresh()
			notify("Configuration deleted", ('Deleted "%s".'):format(name))
		end },
	}, 4)
	autoToggle = configs:AddToggle({
		Title = "Load at launch",
		Description = "Loads the selected configuration when " .. BRAND.Name .. " starts",
		Track = false,
		Callback = function(on)
			local name = picker.Value
			if on and not name then
				autoToggle:Set(false, true)
				return notify("Nothing selected", "Pick a configuration to load at launch.")
			end
			if on then
				store.SetAutoload(name)
			elseif store.GetAutoload() == name then
				store.SetAutoload(nil)
			end
			status:Set(autoloadText())
		end,
	})
	status = configs:AddLabel(autoloadText())

	refresh()
	local autoload = store.GetAutoload()
	if autoload and self:LoadConfig(autoload) then
		picker:Set(autoload, true)
		syncAutoload()
		notify("Configuration loaded", ('Loaded "%s" automatically.'):format(autoload))
	end
	return tab
end
Window.AddSettingsTab = Window.AddConfigTab -- older name

return Library
