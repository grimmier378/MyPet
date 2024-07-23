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
local meName = mq.TLO.Me.Name() or 'none'-- Character Name
local themeName = 'Default'
local gIcon = Icon.MD_SETTINGS -- Gear Icon for Settings
local themeID = 1
local theme, defaults, settings, btnInfo = {}, {}, {}, {}
local RUNNING = true
local showMainGUI, showConfigGUI = true, false
local scale = 1
local aSize, locked, hasThemeZ = false, false, false
local petHP, petTarg, petDist, petBuffs, petName, petTargHP, petLvl, petBuffCount = 0, nil, 0, {}, 'No Pet', 0, -1, 0
local lastCheck = 0
local btnKeys = { "Attack", "Back", "Taunt", "Follow", "Guard", "Focus", "Sit", "Hold", "Stop", "Bye", "Regroup", "Report", "Swarm", "Kill" }
btnInfo = { attack = false, back = false, taunt = false, follow = false, guard = false, focus = false, sit = false, hold = false, stop = false, bye = false, regroup = false, report = false, swarm = false, kill = false }
-- GUI Settings
local winFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoFocusOnAppearing)
local animSpell = mq.FindTextureAnimation('A_SpellIcons')
local animItem = mq.FindTextureAnimation('A_DragItem')
local iconSize = 20
local autoHide = false
local checkStates = false
local showTitleBar = true

-- File Paths
local themeFile = string.format('%s/MyUI/MyThemeZ.lua', mq.configDir)
local configFileOld = string.format('%s/MyUI/%s/%s_Configs.lua', mq.configDir, script, script)
local configFile = string.format('%s/MyUI/%s/%s/%s.lua', mq.configDir, script,mq.TLO.EverQuest.Server(), meName)
local themezDir = mq.luaDir .. '/themez/init.lua'

-- Default Settings
defaults = {
	Scale = 1.0,
	LoadTheme = 'Default',
	AutoHide = false,
	locked = false,
	ShowTitlebar = true,
	AutoSize = false,
	ButtonsRow = 2,
	IconSize = 20,
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
	ConColors = {
		['RED'] = {0.9, 0.4, 0.4, 0.8},
		['YELLOW'] = {1, 1, 0, 1},
		['WHITE'] = {1, 1, 1, 1},
		['BLUE'] = {0.2, 0.2, 1, 1},
		['LIGHT BLUE'] = {0, 1, 1, 1},
		['GREEN'] = {0, 1, 0, 1},
		['GREY'] = {0.6, 0.6, 0.6, 1},
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
	if mq.TLO.Pet() == 'NO PET' then petBuffs = {} return end
	-- petBuffs = {}
	local tmpBuffCnt = 0
	for i = 1 , 120 do
		local name = mq.TLO.Me.PetBuff(i)() or 'None'
		local id = mq.TLO.Spell(name).ID() or 0
		local beneficial = mq.TLO.Spell(id).Beneficial() or nil
		local icon = mq.TLO.Spell(id).SpellIcon() or 0
		local slot = i
		petBuffs[i] = {}
		petBuffs[i] = {Name = name, ID = id, Beneficial = beneficial, Icon = icon, Slot = slot}
		if name ~= 'None' then
			tmpBuffCnt = tmpBuffCnt + 1
		end
	end
	petBuffCount = tmpBuffCnt
end

local function loadSettings()
	local newSetting = false -- Check if we need to save the settings file

	-- Check Settings File_Exists
	if not File_Exists(configFile) then
		if File_Exists(configFileOld) then
			-- Load the old settings file
			settings = dofile(configFileOld)
			-- Save the settings to the new file
			mq.pickle(configFile, settings)
		else
			-- Create the settings file from the defaults
			settings[script] = defaults
			mq.pickle(configFile, settings)
		end
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

	if settings[script].ShowTitlebar == nil then
		settings[script].ShowTitlebar = true
		newSetting = true
	end

	if settings[script].IconSize == nil then
		settings[script].IconSize = defaults.IconSize
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

	if settings[script].AutoHide == nil then
		settings[script].AutoHide = autoHide
		newSetting = true
	end

	if settings[script].ConColors == nil then
		settings[script].ConColors = {}
		for k, v in pairs(defaults.ConColors) do
			settings[script].ConColors[k] = {}
			settings[script].ConColors[k] = v
		end
		newSetting = true
	end

	-- Load the theme
	loadTheme()

	-- Set the settings to the variables
	showTitleBar = settings[script].ShowTitlebar
	autoHide = settings[script].AutoHide
	aSize = settings[script].AutoSize
	locked = settings[script].locked
	scale = settings[script].Scale
	themeName = settings[script].LoadTheme

	-- Save the settings if new settings were added
	if newSetting then mq.pickle(configFile, settings) end

end

local function GetButtonStates()
		local stance = mq.TLO.Pet.Stance()
		btnInfo.follow = stance == 'FOLLOW' and true or false
		btnInfo.guard = stance == 'GUARD' and true or false
		btnInfo.sit = mq.TLO.Pet.Sitting() and true or false
		btnInfo.taunt = mq.TLO.Pet.Taunt() and true or false
		btnInfo.stop = mq.TLO.Pet.Stop() and true or false
		btnInfo.hold = mq.TLO.Pet.Hold() and true or false
		btnInfo.focus = mq.TLO.Pet.Focus() and true or false
		btnInfo.regroup = mq.TLO.Pet.ReGroup() and true or false
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
		if (autoHide and petName ~= 'No Pet') or not autoHide then

			ImGui.SetNextWindowSize(ImVec2(275, 255), ImGuiCond.FirstUseEver)
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
					local lockLabel = locked and 'Unlock' or 'Lock'
					if ImGui.MenuItem(lockLabel.."##MyPet") then
						locked = not locked
	
						settings[script].locked = locked
						mq.pickle(configFile, settings)
					end
					local titleBarLabel = showTitleBar and 'Hide Title Bar' or 'Show Title Bar'
					if ImGui.MenuItem(titleBarLabel.."##MyPet") then
						showTitleBar = not showTitleBar
						settings[script].ShowTitlebar = showTitleBar
						mq.pickle(configFile, settings)
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
					if ImGui.BeginTable("##SplitWindow", 2, bit32.bor(ImGuiTableFlags.BordersOuter, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable), ImVec2(-1, -1)) then
						ImGui.TableSetupColumn(petName .. "##MainPetInfo", ImGuiTableColumnFlags.None, -1)
						ImGui.TableSetupColumn("Buffs##PetBuffs", ImGuiTableColumnFlags.None, -1)
						ImGui.TableSetupScrollFreeze(0, 1)
						ImGui.TableHeadersRow()
						ImGui.TableNextRow()
						ImGui.TableNextColumn()
						ImGui.BeginGroup()
						ImGui.Text("Lvl:")
						ImGui.SameLine()
						ImGui.TextColored(0,1,1,1,"%s", petLvl)
						ImGui.SameLine()
						ImGui.Text("Dist:")
						ImGui.SameLine()
						petDist = mq.TLO.Pet.Distance() or 0

						if petDist >= 150 then
							ImGui.TextColored(1,0,0,1,"%.0f", petDist)
						else
							ImGui.TextColored(0,1,0,1,"%.0f", petDist)
						end

						r = 1
						b = b * (100 - petHP) / 100
						g = 0
						local yPos = ImGui.GetCursorPosY() -1
						ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(r, g, b, a))
						ImGui.ProgressBar(petHP / 100, -1, 15, "##")
						ImGui.PopStyleColor()
						ImGui.SetCursorPosY(yPos)
						ImGui.SetCursorPosX(ImGui.GetColumnWidth() /2)
						ImGui.Text("%.1f%%", petHP)
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
						local conCol = mq.TLO.Pet.Target.ConColor() or 'WHITE'
						if conCol == nil then conCol = 'WHITE' end
						local txCol = settings[script].ConColors[conCol]
						ImGui.TextColored(ImVec4(txCol[1],txCol[2],txCol[3],txCol[4]),"%s", petTarg)
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
								local tmpname = btnKeys[i] or 'none'
								tmpname = string.lower(tmpname)
								if btnInfo[tmpname] ~= nil then
									if btnInfo[tmpname] then
										ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0, 1, 1, 1))
										if ImGui.Button(btnKeys[i] .. "##ButtonPet_" .. btnKeys[i], 60, 20) then
											mq.cmd(settings[script].Buttons[btnKeys[i]].cmd)
										end
										ImGui.PopStyleColor()
									else
										if ImGui.Button(btnKeys[i] .. "##ButtonPet_" .. btnKeys[i], 60, 20) then
											mq.cmd(settings[script].Buttons[btnKeys[i]].cmd)
										end
									end
									btnCount = btnCount + 1
									if btnCount < settings[script].ButtonsRow and i < #btnKeys then
										ImGui.SameLine()
									else
										btnCount = 0
									end
								end
							end
						end
						
						ImGui.PopStyleVar()

						ImGui.TableNextColumn()

						local maxPerRow = math.floor((ImGui.GetColumnWidth() / iconSize) - 1)
						local rowCnt = 0
						ImGui.BeginChild('PetBuffs##PetBuf', 0.0, -1, bit32.bor(ImGuiChildFlags.None), bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoScrollbar))
						ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0.0, 0.0)
						local petDrawBuffCount = 0
						local idx = 1
						while petDrawBuffCount ~= petBuffCount do
							if petBuffs[idx] == nil then break end
							if petBuffs[idx].Name ~= 'None' then
								DrawInspectableSpellIcon(petBuffs[idx].Icon, petBuffs[idx].Beneficial, petBuffs[idx].Name, idx)
								petDrawBuffCount = petDrawBuffCount + 1
								if rowCnt < maxPerRow and petDrawBuffCount < petBuffCount then
									ImGui.SameLine()
									rowCnt = rowCnt + 1
								else
									rowCnt = 0
								end
							else
								ImGui.Dummy(20, 20)
								if rowCnt < maxPerRow and petDrawBuffCount < petBuffCount then
									ImGui.SameLine()
									rowCnt = rowCnt + 1
								else
									rowCnt = 0
								end
							end
							idx = idx + 1
						end
						ImGui.PopStyleVar()
						ImGui.EndChild()

						ImGui.EndTable()
					end
				end
				-- Reset Font Scale
				ImGui.SetWindowFontScale(1)
			end
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
				if ImGui.CollapsingHeader("Theme##"..script) then

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
				end

				if ImGui.CollapsingHeader('ConColors##ConColors') then
					ImGui.SeparatorText("Con Colors")

					if ImGui.BeginTable('##PConCol', 2) then
						ImGui.TableNextColumn()
						settings[script].ConColors.RED = ImGui.ColorEdit4("RED##ConColors", settings[script].ConColors.RED, ImGuiColorEditFlags.NoInputs)
						ImGui.TableNextColumn()
						settings[script].ConColors.YELLOW = ImGui.ColorEdit4("YELLOW##ConColors", settings[script].ConColors.YELLOW, ImGuiColorEditFlags.NoInputs)
						ImGui.TableNextColumn()
						settings[script].ConColors.WHITE = ImGui.ColorEdit4("WHITE##ConColors", settings[script].ConColors.WHITE, ImGuiColorEditFlags.NoInputs)
						ImGui.TableNextColumn()
						settings[script].ConColors.BLUE = ImGui.ColorEdit4("BLUE##ConColors", settings[script].ConColors.BLUE, ImGuiColorEditFlags.NoInputs)
						ImGui.TableNextColumn()
						settings[script].ConColors['LIGHT BLUE'] = ImGui.ColorEdit4("LIGHT BLUE##ConColors", settings[script].ConColors['LIGHT BLUE'], ImGuiColorEditFlags.NoInputs)
						ImGui.TableNextColumn()
						settings[script].ConColors.GREEN = ImGui.ColorEdit4("GREEN##ConColors", settings[script].ConColors.GREEN, ImGuiColorEditFlags.NoInputs)
						ImGui.TableNextColumn()
						settings[script].ConColors.GREY = ImGui.ColorEdit4("GREY##ConColors", settings[script].ConColors.GREY, ImGuiColorEditFlags.NoInputs)
						ImGui.EndTable()
					end

				end
				-- Configure Toggles for Button Display --
				
				iconSize = ImGui.InputInt("Icon Size##"..script, iconSize, 1, 5)
				autoHide = ImGui.Checkbox("Auto Hide##"..script, autoHide)
				ImGui.SameLine()
				locked = ImGui.Checkbox("Lock Window##"..script, locked)
				ImGui.SameLine()
				showTitleBar = ImGui.Checkbox("Show Title Bar##"..script, showTitleBar)
				
				ImGui.SeparatorText("Buttons##"..script)
				if ImGui.CollapsingHeader('Buttons##PetConfigButtons') then
					ImGui.Text("Buttons to Display")
					ImGui.SameLine()
					ImGui.SetNextItemWidth(100)
					settings[script].ButtonsRow = ImGui.InputInt("Buttons Per Row##"..script, settings[script].ButtonsRow, 1, 5)
				end
				-- Save & Close Button --
				if ImGui.Button("Save & Close") then
					settings[script].ShowTitlebar = showTitleBar
					settings[script].locked = locked
					settings[script].Scale = scale
					settings[script].IconSize = iconSize
					settings[script].LoadTheme = themeName
					settings[script].AutoHide = autoHide
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
	configFile = string.format('%s/MyUI/%s/%s/%s.lua', mq.configDir, script,mq.TLO.EverQuest.Server(), meName)
	-- Check if ThemeZ exists
	if File_Exists(themezDir) then
		hasThemeZ = true
	end
	-- Initialize ImGui
	mq.imgui.init(script, Draw_GUI)
	getPetData()
	lastCheck = os.time()
	GetButtonStates()
end

local function Loop()
	-- Main Loop
	while RUNNING do
		RUNNING = showMainGUI
		-- Make sure we are still in game or exit the script.
		if mq.TLO.EverQuest.GameState() ~= "INGAME" then printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", script) mq.exit() end
		petName = mq.TLO.Pet.DisplayName() or 'No Pet'
		local curTime = os.time()
		-- Process ImGui Window Flag Changes
		winFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoFocusOnAppearing)
		winFlags = locked and bit32.bor(ImGuiWindowFlags.NoMove,ImGuiWindowFlags.NoResize, winFlags) or winFlags
		-- winFlags = aSize and bit32.bor(winFlags, ImGuiWindowFlags.AlwaysAutoResize) or winFlags
		winFlags = not showTitleBar and bit32.bor(winFlags, ImGuiWindowFlags.NoTitleBar) or winFlags
		if petName ~= 'No Pet' then
			GetButtonStates()
			if curTime - lastCheck > 1 then
				getPetData()
				lastCheck = curTime
			end
		else
			petBuffCount = 0
			petBuffs = {}
		end

		mq.delay(33)

	end
end
-- Make sure we are in game before running the script
if mq.TLO.EverQuest.GameState() ~= "INGAME" then printf("\aw[\at%s\ax] \arNot in game, \ayTry again later...", script) mq.exit() end
Init()
Loop()