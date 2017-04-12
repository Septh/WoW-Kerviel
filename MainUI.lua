
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local mainUI  = Kerviel:NewModule('MainUI', 'AceConsole-3.0', 'AceEvent-3.0', 'AceHook-3.0')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Données locales
local MAIN_FRAME_WIDTH  = 231
local MAIN_FRAME_HEIGHT = 71
local allRealms, allChars = {}, {}
local mainFrame, charsDropDown
local orderedStores = {}
local storesButtons = {}

-------------------------------------------------------------------------------
-- Initialisation du module
-------------------------------------------------------------------------------
function mainUI:OnInitialize()
end

-------------------------------------------------------------------------------
function mainUI:OnEnable()

	-- Actualise le menu lorsqu'un module a de nouvelles données
	self:RegisterMessage('StorageChanged')

	-- TODO: Tout ce qui suit est à supprimer
	if true then
		_G.Kerviel = Kerviel
		-- Kerviel.db:ResetDB()
		-- Kerviel:ShowFrame()
		-- StoreButton_OnClick(storesButtons['Mail'])
		self:RegisterChatCommand('qq', 'ToggleFrame')
		self:RegisterChatCommand('qqrst', function() Kerviel.db:ResetDB(); ReloadUI() end)
	end
end

-------------------------------------------------------------------------------
-- Affiche ou masque la fenêtre principale
-------------------------------------------------------------------------------
function mainUI:ToggleFrame()

	-- Cache la frame si affichée
	if mainFrame and mainFrame:IsShown() then
		mainFrame:Hide()
		return
	end

	-- Crée la frame si ce n'est pas déjà fait
	if not mainFrame then
		mainFrame = CreateFrame('Frame', 'KervielMainFrame', UIParent, 'KervielMainFrameTemplate')
		mainFrame.TitleText:SetText(string.format('%s v%s', GetAddOnMetadata(Kerviel:GetName(), 'Title'), GetAddOnMetadata(Kerviel:GetName(), 'Version')))
		mainFrame.info.text:SetText(Kerviel.playerCharKey)

		charsDropDown = mainFrame.sideBar.dropdown

		-- Remplit le dropdown des personnages et crée les boutons des modules
		self:PopulateCharsDropDown()
		self:PopulateStoresButtons()

		-- Expérimental : gère le clic sur l'ensemble du menu, pas seulement sur son bouton
		charsDropDown:SetScript('OnMouseDown', function(dropdown, arg)
			local f = dropdown.Button:GetScript('OnClick')
			if f then f(dropdown.Button, arg, true)
			end
		end)
	end

	-- Sélectionne le personnage courant et le premier module
	self:ChangeDisplayedCharacter(Kerviel.playerCharKey)
	for _, store in ipairs(orderedStores) do
		local button = storesButtons[store]
		if button then
			button:Click('leftButton', true)
			break
		end
	end

	-- Affiche la frame
	mainFrame:Show()
end

-------------------------------------------------------------------------------
-- Gestion du menu déroulant des personnages
-------------------------------------------------------------------------------
local function CharsDropDown_OnClick(entry, arg1, arg2, checked)

	-- Met le menu à jour
	UIDropDownMenu_SetSelectedValue(charsDropDown, entry.value, true)
	CloseDropDownMenus()

	-- Affiche ce personnage
	mainUI:ChangeDisplayedCharacter(entry.value)
end

-------------------------------------------------------------------------------
local function CharsDropDown_Checked(entry)
	return UIDropDownMenu_GetSelectedValue(charsDropDown) == entry.value
end

-------------------------------------------------------------------------------
local function CharsDropDown_Initialize(dropdown, level)
	if not level then return end

	local info = UIDropDownMenu_CreateInfo()
	if level == 1 then
		wipe(info)
		info.isTitle = 1
		info.text    = 'Personnage connecté'
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.text    = Kerviel.playerCharName
		info.value   = Kerviel.playerCharKey
		info.checked = CharsDropDown_Checked
		info.func    = CharsDropDown_OnClick
		UIDropDownMenu_AddButton(info, level)

		if #allRealms > 1 or #allChars[Kerviel.playerCharRealm] > 1 then
			wipe(info)
			UIDropDownMenu_AddSeparator(info, level)

			wipe(info)
			info.isTitle = 1
			info.text    = 'Tous les personnages'
			UIDropDownMenu_AddButton(info, level)

			wipe(info)
			for _,realm in ipairs(allRealms) do
				info.keepShownOnClick = 1
				info.notCheckable     = 1
				info.hasArrow         = true
				info.text             = realm
				info.value            = realm
				UIDropDownMenu_AddButton(info, level)
			end
		end

	elseif level == 2 and allChars[UIDROPDOWNMENU_MENU_VALUE] then
		for _, name in ipairs(allChars[UIDROPDOWNMENU_MENU_VALUE]) do
			wipe(info)
			info.text    = name
			info.value   = name .. ' - ' .. UIDROPDOWNMENU_MENU_VALUE
			info.checked = CharsDropDown_Checked
			info.func    = CharsDropDown_OnClick
			UIDropDownMenu_AddButton(info, level)
		end
	end
end

-------------------------------------------------------------------------------
function mainUI:PopulateCharsDropDown()

	wipe(allRealms)
	wipe(allChars)

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

	UIDropDownMenu_SetWidth(charsDropDown, 150)
	UIDropDownMenu_JustifyText(charsDropDown, 'LEFT')
	UIDropDownMenu_Initialize(charsDropDown, CharsDropDown_Initialize)
	UIDropDownMenu_SetSelectedValue(charsDropDown, Kerviel.playerCharKey)
	UIDropDownMenu_SetText(charsDropDown, Kerviel.playerCharKey)
end

-------------------------------------------------------------------------------
-- Gestion des boutons des modules
-------------------------------------------------------------------------------
local function StoreButton_OnClick(clickedButton)

	-- Sélectionne ce bouton, déselectionne tous les autres
	for _, store in ipairs(orderedStores) do
		local button = storesButtons[store]
		if button == clickedButton then
			button.selected:Show()

			-- Ancre la frame du module à la frame principale
			local modFrame = store:GetFrame()
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
			store:GetFrame():Hide()
		end
	end
end

-------------------------------------------------------------------------------
function mainUI:UpdateStoreButton(store, button)

	if store:IsStorageAvailableFor(Kerviel.displayedCharKey) then
		button.icon:SetDesaturated(false)
	else
		button.icon:SetDesaturated(true)
	end
end

-------------------------------------------------------------------------------
function mainUI:PopulateStoresButtons()

	-- Trie les modules par ordre de priorité
	wipe(orderedStores)
	for _, store in Kerviel:IterateStores() do
		table.insert(orderedStores, store)
	end
	table.sort(orderedStores, function(s1, s2)
		return (s1.storeInfo.order or 0) < (s2.storeInfo.order or 0)
	end)

	-- (Re)crée les boutons
	local prevButton
	for i, store in ipairs(orderedStores) do
		if store.storeInfo.framed then
			local button = storesButtons[store] or CreateFrame('Button', nil, mainFrame.sideBar, 'KervielMenuBarButtonTemplate')
			storesButtons[store] = button

			button:SetScript('OnClick', StoreButton_OnClick)
			button:SetText(store.storeInfo.text)
			button.icon:SetTexture(store.storeInfo.icon)

			if prevButton then
				button:SetPoint('TOP', prevButton, 'BOTTOM', 0, 0)
			else
				button:SetPoint('TOP', mainFrame.sideBar.sep, 'BOTTOM', 2, -4)
			end
			prevButton = button
		end
	end
end

-------------------------------------------------------------------------------
function mainUI:StorageChanged(msg, store)
	local button = storesButtons[store]
	if button then
		self:UpdateStoreButton(store, button)
	end
end

-------------------------------------------------------------------------------
-- Gestion du personnage affiché
-------------------------------------------------------------------------------
function mainUI:ChangeDisplayedCharacter(charKey)

	-- Sauve le nom du personnage affiché
	Kerviel.displayedCharKey = charKey

	-- Affiche les données de ce personnage
	for store in pairs(storesButtons) do
		if store.ChangeDisplayedCharacter then
			store:ChangeDisplayedCharacter(charKey)
		end
	end

	-- Synchronise les boutons du menu principal pour ce personnage
	for store, button in pairs(storesButtons) do
		self:UpdateStoreButton(store, button)
	end
end
