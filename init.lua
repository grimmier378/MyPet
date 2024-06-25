--[[
	Title: Generic Script Template
	Author: Grimmier
	Includes: 
	Description: Generic Script Template with ThemeZ Suppport
]]

-- Load Libraries
local mq = require('mq')
local ImGui = require('ImGui')
local LoadTheme = require('lib.theme_loader')
local Icon = require('mq.ICONS')
local rIcon -- resize icon variable holder
local lIcon -- lock icon variable holder

-- Variables
local script = 'MyPet' -- Change this to the name of your script
local meName -- Character Name
local themeName = 'Default'
local gIcon = Icon.MD_SETTINGS -- Gear Icon for Settings
local themeID = 1
local theme, defaults, settings = {}, {}, {}
local RUNNING = true
local showMainGUI, showConfigGUI = true, false
local scale = 1
local aSize, locked, hasThemeZ = false, false, false
local petHP, petTarg, petDist, petBuffs, petName, petTargHP, petLvl, petBuffCount = 0, nil, 0, {}, 'No Pet', 0, -1, 0
local lastCheck = 0
local btnKeys = { "Attack", "Back", "Taunt", "Follow", "Guard", "Focus", "Sit", "Hold", "Stop", "Bye", "Regroup", "Report", "Swarm", "Kill" }

-- GUI Settings
local winFlags = bit32.bor(ImGuiWindowFlags.None)
local animSpell = mq.FindTextureAnimation('A_SpellIcons')
local animItem = mq.FindTextureAnimation('A_DragItem')
local iconSize = 20

-- File Paths
local themeFile = string.format('%s/MyUI/MyThemeZ.lua', mq.configDir)
local configFile = string.format('%s/MyUI/%s/%s_Configs.lua', mq.configDir, script, script)
local themezDir = mq.luaDir .. '/themez/init.lua'

-- Default Settings
defaults = {
	Scale = 1.0,
	LoadTheme = 'Default',
	locked = false,
	AutoSize = false,
	ButtonsRow = 2,
	Buttons = {
		Attack = { show = true, cmd = "/pet attack"},
		Back =  { show = true, cmd = "/pet back off"},
		Taunt =  { show = true, cmd = "/pet taunt"},
		Follow =  { show = true, cmd = "/pet follow"},
		Guard = { show = true, cmd = "/pet guard"},
		Focus =  { show = false, cmd = "/pet focus"},
		Sit =  { show = true, cmd = "/pet sit"},
		Hold =  { show = false, cmd = "/pet hold"},
		Stop =  { show = false, cmd = "/pet stop"},
		Bye =  { show = true, cmd = "/pet get lost"},
		Regroup =  { show = false, cmd = "/pet regroup"},
		Report =  { show = true, cmd = "/pet report health"},
		Swarm =  { show = false, cmd = "/pet swarm"},
		Kill =  { show = false, cmd = "/pet kill"},
	},
}

---comment Check to see if the file we want to work on exists.
---@param name string -- Full Path to file
---@return boolean -- returns true if the file exists and false otherwise
local function File_Exists(name)
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
end

local function loadTheme()
	-- Check for the Theme File
	if File_Exists(themeFile) then
		theme = dofile(themeFile)
	else
		-- Create the theme file from the defaults
		theme = require('themes') -- your local themes file incase the user doesn't have one in config folder
		mq.pickle(themeFile, theme)
	end
	-- Load the theme from the settings file
	themeName = settings[script].LoadTheme or 'Default'
	-- Find the theme ID
	if theme and theme.Theme then
		for tID, tData in pairs(theme.Theme) do
			if tData['Name'] == themeName then
				themeID = tID
			end
		end
	end
end

local function getPetData()
	lastCheck = os.time()
	if mq.TLO.Pet() == 'NO PET' then return end
	-- petBuffs = {}
	petBuffCount = 0
	petDist = mq.TLO.Pet.Distance() or 0
	for i = 1 , 120 do
		local name = mq.TLO.Pet.Buff(i).Name() or nil
		local id = mq.TLO.Pet.Buff(i).ID() or 0
		local beneficial = mq.TLO.Pet.Buff(i).Beneficial() or nil
		local icon = mq.TLO.Pet.Buff(i).SpellIcon() or 0
		local slot = i
		
		if petBuffs[i] ~= nil and petBuffs[i].Slot == i then
			petBuffs[i] = {Name = name, ID = id, Beneficial = beneficial, Icon = icon, Slot = slot}
			petBuffCount = petBuffCount + 1
		elseif name == nil then
			petBuffs[i] = nil
		elseif name ~= nil then
			petBuffCount = petBuffCount + 1
			petBuffs[i] = {Name = name, ID = id, Beneficial = beneficial, Icon = icon, Slot = slot}
		end
	end
end

local function loadSettings()
	local newSetting = false -- Check if we need to save the settings file

	-- Check Settings File_Exists
	if not File_Exists(configFile) then
		-- Create the settings file from the defaults
		settings[script] = defaults
		mq.pickle(configFile, settings)
		loadSettings()
	else
		-- Load settings from the Lua config file
		settings = dofile(configFile)
		-- Check if the settings are missing from the file
		if settings[script] == nil then
			settings[script] = {}
			settings[script] = defaults
			newSetting = true
		end
	end

	-- Check if the settings are missing and use defaults if they are
	if settings[script].Buttons == nil then
		settings[script].Buttons = defaults.Buttons
		newSetting = true
	end

	if settings[script].ButtonsRow == nil then
		settings[script].ButtonsRow = defaults.ButtonsRow
		newSetting = true
	end

	if settings[script].locked == nil then
		settings[script].locked = false
		newSetting = true
	end

	if settings[script].Scale == nil then
		settings[script].Scale = 1
		newSetting = true
	end

	if not settings[script].LoadTheme then
		settings[script].LoadTheme = 'Default'
		newSetting = true
	end

	if settings[script].AutoSize == nil then
		settings[script].AutoSize = aSize
		newSetting = true
	end

	-- Load the theme
	loadTheme()

	-- Set the settings to the variables
	aSize = settings[script].AutoSize
	locked = settings[script].locked
	scale = settings[script].Scale
	themeName = settings[script].LoadTheme

	-- Save the settings if new settings were added
	if newSetting then mq.pickle(configFile, settings) end

end

local function DrawInspectableSpellIcon(iconID, bene, name,  i)
	local spell = mq.TLO.Spell(petBuffs[i].ID)
	local cursor_x, cursor_y = ImGui.GetCursorPos()
	local beniColor = IM_COL32(0,20,180,190) -- blue benificial default color
	if iconID == 0 then
		ImGui.SetWindowFontScale(settings[script].Scale)
		ImGui.Dummy(iconSize, iconSize)
		ImGui.SetWindowFontScale(1)
		return
	end
	animSpell:SetTextureCell(iconID or 0)
	if not bene then
		beniColor = IM_COL32(255,0,0,190) --red detrimental
	end
	ImGui.GetWindowDrawList():AddRectFilled(ImGui.GetCursorScreenPosVec() + 1,
	ImGui.GetCursorScreenPosVec() + iconSize, beniColor)
	ImGui.SetCursorPos(cursor_x+3, cursor_y+3)
	ImGui.DrawTextureAnimation(animSpell, iconSize - 5, iconSize - 5)
	ImGui.SetCursorPos(cursor_x+2, cursor_y+2)
	local sName = name or '??'
	ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")

	ImGui.SetCursorPos(cursor_x, cursor_y)
	ImGui.InvisibleButton(sName, ImVec2(iconSize, iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
	if ImGui.BeginPopupContextItem() then
		if ImGui.MenuItem("Inspect##PetBuff"..i) then
			spell.Inspect()
			if mq.TLO.MacroQuest.BuildName()=='Emu' then
				mq.cmdf("/nomodkey /altkey /notify PetInfoWindow PetBuff%s leftmouseup", i-1)
			end
		end
		if ImGui.MenuItem("Remove##PetBuff"..i) then
			mq.cmdf("/nomodkey /ctrlkey /notify PetInfoWindow PetBuff%s leftmouseup", i-1)
		end
		if ImGui.MenuItem("Block##PetBuff"..i) then
			mq.cmdf("/blockspell add pet '%s'",petBuffs[i].ID)
		end
		ImGui.EndPopup()
	end
	if ImGui.IsItemHovered() then
		ImGui.SetWindowFontScale(settings[script].Scale)
		ImGui.BeginTooltip()
		ImGui.Text(sName)
		ImGui.EndTooltip()
	end
	ImGui.PopID()
end
local function sortButtons()
	table.sort(btnKeys)
end

local function Draw_GUI()

	if showMainGUI then
		-- Sort the buttons before displaying them
		sortButtons()
		-- Set Window Name
		local winName = string.format('%s##Main_%s', script, meName)
		-- Load Theme
		local ColorCount, StyleCount = LoadTheme.StartTheme(theme.Theme[themeID])
		-- Create Main Window
		local openMain, showMain = ImGui.Begin(winName, true, winFlags)
		-- Check if the window is open
		if not openMain then
			showMainGUI = false
		end
		-- Check if the window is showing
		if showMain then
			-- Set Window Font Scale
			ImGui.SetWindowFontScale(scale)
			if ImGui.BeginPopupContextWindow() then
				if ImGui.MenuItem("Settings") then
					-- Toggle Config Window
					showConfigGUI = not showConfigGUI
				end
				ImGui.EndPopup()
			end
			if petName == 'No Pet' then
				ImGui.Text("No Pet")
			else
				local r, g, b, a = 1, 1, 1, 0.8
				petHP = mq.TLO.Me.Pet.PctHPs() or 0
				petTarg = mq.TLO.Pet.Target.DisplayName() or nil
				petTargHP = mq.TLO.Pet.Target.PctHPs() or 0
				petLvl = mq.TLO.Pet.Level() or -1
				if ImGui.BeginTable("##SplitWindow", 2, bit32.bor(ImGuiTableFlags.BordersOuter, ImGuiTableFlags.ScrollY, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable), ImVec2(-1, -1)) then
					ImGui.TableSetupColumn(petName .. "##MainPetInfo", ImGuiTableColumnFlags.None, -1)
					ImGui.TableSetupColumn("Buffs##PetBuffs", ImGuiTableColumnFlags.None, -1)
					ImGui.TableSetupScrollFreeze(0, 1)
					ImGui.TableHeadersRow()
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					ImGui.BeginGroup()
					ImGui.Text("Dist: %.2f", petDist)
					ImGui.SameLine()
					ImGui.Text("Lvl: %s", petLvl)
					r = 1
					b = b * (100 - petHP) / 100
					g = 0
					ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(r, g, b, a))
					ImGui.ProgressBar(petHP / 100, -1, 15)
					ImGui.PopStyleColor()
					ImGui.EndGroup()
					if ImGui.IsItemHovered() then
	
						local iconID = mq.TLO.Cursor.Icon() or 0
						if iconID > 0 then
							local itemIcon = mq.FindTextureAnimation('A_DragItem')
							itemIcon:SetTextureCell(iconID-500)
							ImGui.BeginTooltip()
							ImGui.DrawTextureAnimation(itemIcon, 40, 40)
							ImGui.EndTooltip()
						end
						if ImGui.IsMouseReleased(ImGuiMouseButton.Left)  then
							mq.cmdf("/target %s", petName)
							if mq.TLO.Cursor() then
								mq.cmdf('/multiline ; /tar id %s; /face; /if (${Cursor.ID}) /click left target',mq.TLO.Me.Pet.ID())
							end
						end
	
					end
					ImGui.Text("Target: %s", petTarg)
					if petTarg ~= nil then
						r, g, b, a = 1, 1, 1, 0.8
						r = r * petTargHP / 100
						g = g * (100 - petTargHP) / 100
						b = 0
						ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(r, g, b, a))
						ImGui.ProgressBar(petTargHP / 100, -1, 15)
						ImGui.PopStyleColor()
					else
						ImGui.Dummy(20, 15)
					end
					ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 2, 2)

					-- Buttons Section
					local btnCount = 0
					for i = 1, #btnKeys do

						if settings[script].Buttons[btnKeys[i]].show then
							if ImGui.Button(btnKeys[i] .. "##ButtonPet_" .. btnKeys[i], 60, 20) then
								mq.cmd(settings[script].Buttons[btnKeys[i]].cmd)
							end
							btnCount = btnCount + 1
							if btnCount < settings[script].ButtonsRow and i < #btnKeys then
								ImGui.SameLine()
							else
								btnCount = 0
							end
						end
					end
					ImGui.PopStyleVar()

					ImGui.TableNextColumn()

					local max = math.floor((ImGui.GetColumnWidth() / iconSize) - 1)
					local cnt = 0
					ImGui.BeginChild('PetBuffs##PetBuf', 0.0, -1, ImGuiWindowFlags.AlwaysAutoResize)
					ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0.0, 0.0)
					local petDrawBuffCount = 0
					local i = 1
					while petDrawBuffCount ~= petBuffCount do
						if petBuffs[i] ~= nil then
							DrawInspectableSpellIcon(petBuffs[i].Icon, petBuffs[i].Beneficial, petBuffs[i].Name, i)
							petDrawBuffCount = petDrawBuffCount + 1
							if cnt < max and petDrawBuffCount < petBuffCount then
								ImGui.SameLine()
								cnt = cnt + 1
							else
								cnt = 0
							end
						else
							ImGui.Dummy(20, 20)
							if cnt < max and petDrawBuffCount < petBuffCount then
								ImGui.SameLine()
								cnt = cnt + 1
							else
								cnt = 0
							end
						end
						i = i + 1
					end
					ImGui.PopStyleVar()
					ImGui.EndChild()

					ImGui.EndTable()
				end
			end
			-- Reset Font Scale
			ImGui.SetWindowFontScale(1)
			LoadTheme.EndTheme(ColorCount, StyleCount)
			ImGui.End()
		else
			LoadTheme.EndTheme(ColorCount, StyleCount)
			ImGui.End()
		end
	end

	if showConfigGUI then
			local winName = string.format('%s Config##Config_%s',script, meName)
			local ColCntConf, StyCntConf = LoadTheme.StartTheme(theme.Theme[themeID])
			local openConfig, showConfig = ImGui.Begin(winName,true,bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize))
			if not openConfig then
				showConfigGUI = false
			end
			if showConfig then

				-- Configure ThemeZ --
				ImGui.SeparatorText("Theme##"..script)
				ImGui.Text("Cur Theme: %s", themeName)

				-- Combo Box Load Theme
				if ImGui.BeginCombo("Load Theme##"..script, themeName) then
					for k, data in pairs(theme.Theme) do
						local isSelected = data.Name == themeName
						if ImGui.Selectable(data.Name, isSelected) then
							theme.LoadTheme = data.Name
							themeID = k
							themeName = theme.LoadTheme
						end
					end
					ImGui.EndCombo()
				end

				-- Configure Scale --
				scale = ImGui.SliderFloat("Scale##"..script, scale, 0.5, 2)
				if scale ~= settings[script].Scale then
					if scale < 0.5 then scale = 0.5 end
					if scale > 2 then scale = 2 end
				end

				-- Edit ThemeZ Button if ThemeZ lua exists.
				if hasThemeZ then
					if ImGui.Button('Edit ThemeZ') then
						mq.cmd("/lua run themez")
					end
					ImGui.SameLine()
				end

				-- Reload Theme File incase of changes --
				if ImGui.Button('Reload Theme File') then
					loadTheme()
				end

				-- Configure Toggles for Button Display --

				ImGui.SeparatorText("Buttons##"..script)
				ImGui.Text("Buttons to Display")
				ImGui.SameLine()
				ImGui.SetNextItemWidth(100)
				settings[script].ButtonsRow = ImGui.InputInt("Buttons Per Row##"..script, settings[script].ButtonsRow, 1, 5)

				-- Save & Close Button --
				if ImGui.Button("Save & Close") then
					settings[script].Scale = scale
					settings[script].LoadTheme = themeName
					mq.pickle(configFile, settings)
					showConfigGUI = false
				end
				ImGui.Separator()
				if ImGui.BeginTable("ButtonToggles##Toggles", 3, ImGuiTableFlags.ScrollY, ImVec2(-1,200)) then
					ImGui.TableSetupColumn("Col1", ImGuiTableColumnFlags.None, -1)
					ImGui.TableSetupColumn("Col2", ImGuiTableColumnFlags.None, -1)
					ImGui.TableSetupColumn("Col3", ImGuiTableColumnFlags.None, -1)
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
				
					local atkToggle = settings[script].Buttons.Attack.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Attack", atkToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Attack.show = not settings[script].Buttons.Attack.show
					end
					
					ImGui.TableNextColumn()

					local tauntToggle = settings[script].Buttons.Taunt.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Taunt", tauntToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Taunt.show = not settings[script].Buttons.Taunt.show
					end

					ImGui.TableNextColumn()

					local backToggle = settings[script].Buttons.Back.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Back", backToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Back.show = not settings[script].Buttons.Back.show
					end

					ImGui.TableNextRow()
					ImGui.TableNextColumn()

					local followToggle = settings[script].Buttons.Follow.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Follow", followToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Follow.show = not settings[script].Buttons.Follow.show
					end
					
					ImGui.TableNextColumn()

					local guardToggle = settings[script].Buttons.Guard.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Guard", guardToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Guard.show = not settings[script].Buttons.Guard.show
					end
					
					ImGui.TableNextColumn()
					
					local sitToggle = settings[script].Buttons.Sit.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Sit", sitToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Sit.show = not settings[script].Buttons.Sit.show
					end

					ImGui.TableNextRow()
					ImGui.TableNextColumn()

					local byeToggle = settings[script].Buttons.Bye.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Bye", byeToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Bye.show = not settings[script].Buttons.Bye.show
					end

					ImGui.TableNextColumn()

					local focusToggle = settings[script].Buttons.Focus.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Focus", focusToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Focus.show = not settings[script].Buttons.Focus.show
					end

					ImGui.TableNextColumn()

					local holdToggle = settings[script].Buttons.Hold.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Hold", holdToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Hold.show = not settings[script].Buttons.Hold.show
					end
					ImGui.TableNextRow()

					ImGui.TableNextColumn()

					local stopToggle = settings[script].Buttons.Stop.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Stop", stopToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Stop.show = not settings[script].Buttons.Stop.show
					end

					ImGui.TableNextColumn()

					local regroupToggle = settings[script].Buttons.Regroup.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Regroup", regroupToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Regroup.show = not settings[script].Buttons.Regroup.show
					end

					ImGui.TableNextColumn()

					local swarmToggle = settings[script].Buttons.Swarm.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Swarm", swarmToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Swarm.show = not settings[script].Buttons.Swarm.show
					end
					ImGui.TableNextRow()

					ImGui.TableNextColumn()

					local killToggle = settings[script].Buttons.Kill.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Kill", killToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Kill.show = not settings[script].Buttons.Kill.show
					end

					ImGui.TableNextColumn()

					local reportToggle = settings[script].Buttons.Report.show and Icon.FA_TOGGLE_ON or Icon.FA_TOGGLE_OFF
					ImGui.Text("%s Report", reportToggle)
					if ImGui.IsItemClicked(0) then
						settings[script].Buttons.Report.show = not settings[script].Buttons.Report.show
					end
					ImGui.EndTable()
				end
				
				-- Configure Toggles for AutoSize and Lock --
				LoadTheme.EndTheme(ColCntConf, StyCntConf)
				ImGui.End()
			else
				LoadTheme.EndTheme(ColCntConf, StyCntConf)
				ImGui.End()
			end
	end

end

local function Init()
	-- Load Settings
	loadSettings()
	-- Get Character Name
	meName = mq.TLO.Me.Name()
	-- Check if ThemeZ exists
	if File_Exists(themezDir) then
		hasThemeZ = true
	end
	-- Initialize ImGui
	mq.imgui.init(script, Draw_GUI)
	getPetData()
end

local function Loop()
	-- Main Loop
	while RUNNING do
		RUNNING = showMainGUI
		-- Make sure we are still in game or exit the script.
		if mq.TLO.EverQuest.GameState() ~= "INGAME" then printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", script) mq.exit() end
		petName = mq.TLO.Pet.DisplayName() or 'No Pet'
		-- Process ImGui Window Flag Changes
		winFlags = locked and bit32.bor(ImGuiWindowFlags.NoMove) or bit32.bor(ImGuiWindowFlags.None)
		winFlags = aSize and bit32.bor(winFlags, ImGuiWindowFlags.AlwaysAutoResize) or winFlags
		if petName ~= 'No Pet' then
			local curTime = os.time()
			if curTime - lastCheck > 1 then
				getPetData()
			end
		end
		mq.delay(1)

	end
end
-- Make sure we are in game before running the script
if mq.TLO.EverQuest.GameState() ~= "INGAME" then printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", script) mq.exit() end
Init()
Loop()