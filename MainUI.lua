
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local mainUI  = Kerviel:NewModule('MainUI', 'AceConsole-3.0', 'AceEvent-3.0', 'AceHook-3.0')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Upvalues
local GetAddOnMetadata, ReloadUI = _G.GetAddOnMetadata, _G.ReloadUI
local PlaySound, CreateFrame = _G.PlaySound, _G.CreateFrame

-- Données locales
local MAIN_FRAME_WIDTH  = 231
local MAIN_FRAME_HEIGHT = 71
local allRealms, allChars = {}, {}
local mainFrame, charsDropDown
local mainButtons = {}

-------------------------------------------------------------------------------
-- Gestion des boutons des modules
-------------------------------------------------------------------------------
local function StoreButton_OnClick(clickedButton)

	-- Sélectionne ce bouton, déselectionne tous les autres
	for store, button in pairs(mainButtons) do
		local modFrame = store:GetFrame()
		if button == clickedButton then
			button.selected:Show()

			-- Ancre la frame du module à la frame principale
			modFrame:SetParent(mainFrame.contents)
			modFrame:ClearAllPoints()
			modFrame:SetPoint('TOPLEFT', mainFrame.contents, 'TOPLEFT', 0, 0)

			-- Ajuste la taille de la frame principale
			local w, h = modFrame:GetSize()
			mainFrame:SetSize(MAIN_FRAME_WIDTH + w, MAIN_FRAME_HEIGHT + h)

			-- Affiche la frame du module
			PlaySound('igMainMenuOpen')
			modFrame:Show()
		elseif button then
			button.selected:Hide()
			modFrame:Hide()
		end
	end
end

-------------------------------------------------------------------------------
local function StoreButton_Update(store, button)

	if store:IsStorageAvailableFor(Kerviel.displayedCharKey) then
		button.icon:SetDesaturated(false)
		button:SetNormalFontObject(GameFontNormal)
	else
		button.icon:SetDesaturated(true)
		button:SetNormalFontObject(GameFontDisable)
	end
end

-------------------------------------------------------------------------------
function mainUI:StorageUpdated(msg, store)
	local button = mainButtons[store]
	if button then
		StoreButton_Update(store, button)
	end
end

-------------------------------------------------------------------------------
-- Gestion du personnage affiché
-------------------------------------------------------------------------------
local function CharsDropDown_OnClick(entry, arg1, arg2, checked)

	-- Met le menu à jour
	Lib_UIDropDownMenu_SetSelectedValue(charsDropDown, entry.value, true)
	Lib_CloseDropDownMenus()

	-- Affiche ce personnage
	mainUI:ChangeDisplayedCharacter(entry.value)
end

-------------------------------------------------------------------------------
local function CharsDropDown_Checked(entry)
	return Lib_UIDropDownMenu_GetSelectedValue(charsDropDown) == entry.value
end

-------------------------------------------------------------------------------
local function CharsDropDown_Initialize(dropdown, level)
	if not level then return end

	local info = Lib_UIDropDownMenu_CreateInfo()
	if level == 1 then
		wipe(info)
		info.isTitle = 1
		info.text    = 'Personnage connecté'
		Lib_UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.text    = Kerviel.playerCharName
		info.value   = Kerviel.playerCharKey
		info.checked = CharsDropDown_Checked
		info.func    = CharsDropDown_OnClick
		Lib_UIDropDownMenu_AddButton(info, level)

		if #allRealms > 1 or #allChars[Kerviel.playerCharRealm] > 1 then
			wipe(info)
			Lib_UIDropDownMenu_AddSeparator(info, level)

			wipe(info)
			info.isTitle = 1
			info.text    = 'Tous les personnages'
			Lib_UIDropDownMenu_AddButton(info, level)

			wipe(info)
			for _,realm in ipairs(allRealms) do
				info.keepShownOnClick = 1
				info.notCheckable     = 1
				info.hasArrow         = true
				info.text             = realm
				info.value            = realm
				Lib_UIDropDownMenu_AddButton(info, level)
			end
		end

	elseif level == 2 and allChars[LIB_UIDROPDOWNMENU_MENU_VALUE] then
		for _, name in ipairs(allChars[LIB_UIDROPDOWNMENU_MENU_VALUE]) do
			wipe(info)
			info.text    = name
			info.value   = name .. ' - ' .. LIB_UIDROPDOWNMENU_MENU_VALUE
			info.checked = CharsDropDown_Checked
			info.func    = CharsDropDown_OnClick
			Lib_UIDropDownMenu_AddButton(info, level)
		end
	end
end

-------------------------------------------------------------------------------
function mainUI:ChangeDisplayedCharacter(charKey)

	-- Sauve le nom du personnage affiché
	Kerviel.displayedCharKey = charKey

	-- Affiche les données de ce personnage
	self:SendMessage('SetDisplayedCharacter', charKey)

	-- Synchronise les boutons du menu principal pour ce personnage
	for store, button in pairs(mainButtons) do
		StoreButton_Update(store, button)
	end
end

-------------------------------------------------------------------------------
-- Gestion de la fenêtre principale
-------------------------------------------------------------------------------
function mainUI:ToggleUI()

	-- Crée la frame si ce n'est pas déjà fait
	if not mainFrame then
		mainFrame = CreateFrame('Frame', 'KervielMainFrame', UIParent, 'KervielMainFrameTemplate')
		mainFrame.TitleText:SetText(('%s v%s'):format(GetAddOnMetadata(Kerviel:GetName(), 'Title'), GetAddOnMetadata(Kerviel:GetName(), 'Version')))
		mainFrame.info.text:SetText(Kerviel.playerCharKey)

		-- Remplit le dropdown des personnages
		charsDropDown = mainFrame.sideBar.dropdown

		local sv = rawget(Kerviel.db, 'sv')
		for charKey in pairs(sv.char) do
			local name, realm = Kerviel:SplitCharKey(charKey)
			if allChars[realm] then
				table.insert(allChars[realm], name)
			else
				allChars[realm] = { name }
				table.insert(allRealms, realm)
			end
		end
		table.sort(allRealms)
		for _, realm in ipairs(allRealms) do
			table.sort(allChars[realm])
		end

		Lib_UIDropDownMenu_SetWidth(charsDropDown, 150)
		Lib_UIDropDownMenu_JustifyText(charsDropDown, 'LEFT')
		Lib_UIDropDownMenu_Initialize(charsDropDown, CharsDropDown_Initialize)
		Lib_UIDropDownMenu_SetSelectedValue(charsDropDown, Kerviel.playerCharKey)
		Lib_UIDropDownMenu_SetText(charsDropDown, Kerviel.playerCharKey)

		-- Expérimental : gère le clic sur l'ensemble du menu, pas seulement sur son bouton
		charsDropDown:SetScript('OnMouseDown', function(dropdown, arg)
			local f = dropdown.Button:GetScript('OnClick')
			if f then f(dropdown.Button, arg, true)
			end
		end)

		-- Crée les boutons des modules
		local firstButton, lastButton
		for _, store in Kerviel:IterateStores() do
			if store.storeInfo.framed then
				local button = CreateFrame('Button', nil, mainFrame.sideBar, 'KervielMenuBarButtonTemplate')
				mainButtons[store] = button

				button:SetScript('OnClick', StoreButton_OnClick)
				button:SetText(store.storeInfo.text)
				button.icon:SetTexture(store.storeInfo.icon)

				firstButton = firstButton or button
				if lastButton then
					button:SetPoint('TOP', lastButton, 'BOTTOM', 0, 0)
				else
					button:SetPoint('TOP', mainFrame.sideBar.sep, 'BOTTOM', 2, -4)
				end
				lastButton = button
			end
		end

		-- Sélectionne le personnage courant et le premier module
		self:ChangeDisplayedCharacter(Kerviel.playerCharKey)
		firstButton:Click('leftButton', true)
	end

	-- Cache la frame si affichée
	if mainFrame:IsShown() then
		mainFrame:Hide()
	else
		mainFrame:Show()
	end
end

-------------------------------------------------------------------------------
-- Initialisation du module
-------------------------------------------------------------------------------
function mainUI:OnEnable()

	-- Actualise le menu lorsqu'un module a de nouvelles données
	self:RegisterMessage('StorageUpdated')

	-- TODO: Tout ce qui suit est à supprimer
	if true then
		_G.Kerviel = Kerviel
		-- Kerviel.db:ResetDB()
		-- Kerviel:ShowFrame()
		-- StoreButton_OnClick(mainButtons['Mail'])
		self:RegisterChatCommand('qq', 'ToggleUI')
		self:RegisterChatCommand('qqrst', function() Kerviel.db:ResetDB(); ReloadUI() end)
	end
end
