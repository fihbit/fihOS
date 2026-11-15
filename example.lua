-- fihOS demo
-- In your own game, use require(ReplicatedStorage.fihOS) instead of the loadstring line.
local fihOS = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/fihOS/main/fihOS.lua"))()

local Window = fihOS:CreateWindow({
	ToggleKey = Enum.KeyCode.RightControl,
})

-- General ----------------------------------------------------------------------
local General = Window:AddTab({ Title = "General", Icon = "house", Description = "Core features and quick actions." })

local behaviour = General:AddSection("Behaviour")
behaviour:AddToggle({
	Title = "Enabled",
	Description = "Master switch for every module",
	Default = true,
	Keybind = Enum.KeyCode.F,
	Flag = "Enabled",
})
behaviour:AddToggle({ Title = "Auto refresh", Default = true, Flag = "AutoRefresh" })
behaviour:AddDropdown({ Title = "Mode", Options = { "Balanced", "Precise", "Relaxed" }, Default = "Balanced", Flag = "Mode" })
behaviour:AddSlider({ Title = "Intensity", Min = 0, Max = 100, Default = 65, Suffix = "%", Flag = "Intensity" })
behaviour:AddStepper({ Title = "Retries", Min = 0, Max = 10, Default = 3, Flag = "Retries" })

local actions = General:AddSection("Actions")
actions:AddButton({
	Title = "Run once",
	Description = "Fires the action a single time",
	ButtonText = "Run",
	Style = "Primary",
	Callback = function()
		Window:Notify({ Title = "Done", Content = "The action ran successfully." })
	end,
})
actions:AddKeybind({
	Title = "Quick action",
	Default = Enum.KeyCode.G,
	Flag = "QuickAction",
	Callback = function()
		Window:Notify({ Title = "Quick action", Content = "Triggered with G." })
	end,
})
actions:AddProgress({ Title = "Daily goal", Default = 0.42 })

-- Filters ----------------------------------------------------------------------
local Filters = Window:AddTab({ Title = "Filters", Icon = "users", Description = "Choose who and where things apply." })

local who = Filters:AddSection("Who")
who:AddDropdown({
	Title = "Include",
	Options = { "Friends", "Teammates", "Everyone" },
	Default = { "Friends" },
	Multi = true,
	Flag = "Include",
})
who:AddInput({ Title = "Name", Placeholder = "Username", Flag = "NameFilter" })
who:AddCheckbox({ Title = "Notify when someone joins", Default = true, Flag = "JoinNotify" })
who:AddCheckbox({ Title = "Ignore muted players", Flag = "IgnoreMuted" })

local where = Filters:AddSection("Where")
where:AddDropdown({
	Title = "Region",
	Options = {
		"Auto", "US East", "US West", "US Central", "Canada", "Brazil",
		"UK", "Germany", "France", "Netherlands", "Japan", "Singapore", "Australia",
	},
	Default = "Auto",
	Flag = "Region",
})
where:AddSegmented({ Title = "Priority", Options = { "Low", "Mid", "High" }, Default = "Mid", Flag = "Priority" })

-- Activity ---------------------------------------------------------------------
local Activity = Window:AddTab({ Title = "Activity", Icon = "activity" })

local session = Activity:AddSection({
	Title = "Session",
	Footer = "Toggles that are on show up in the island's Running list.",
})
session:AddToggle({ Title = "Session logger", Flag = "Logger" })
session:AddSwatches({
	Title = "Marker colour",
	Colors = {
		Color3.fromRGB(122, 118, 255),
		Color3.fromRGB(10, 132, 255),
		Color3.fromRGB(60, 200, 120),
		Color3.fromRGB(245, 195, 60),
		Color3.fromRGB(255, 95, 150),
	},
	Flag = "MarkerColor",
})
session:AddParagraph({
	Title = "About fihOS",
	Content = "Hover the island at the top of the screen for live stats; click it or press RCtrl to open this window.",
})

-- Configs (save / load / load at launch) ------------------------------------------
Window:AddConfigTab()

Window:Notify({ Title = "fihOS is ready", Content = "Hover the island at the top for live stats. Click it or press RCtrl to open." })
