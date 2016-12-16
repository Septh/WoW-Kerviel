
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):NewAddon('Kerviel', 'AceConsole-3.0', 'AceEvent-3.0')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Données
Kerviel.playerCharName    = UnitName('player')
Kerviel.playerCharRealm   = GetRealmName()
Kerviel.playerCharKey     = Kerviel.playerCharName .. ' - ' .. Kerviel.playerCharRealm

Kerviel.playerGuildName   = nil
Kerviel.playerGuildRealm  = nil
Kerviel.playerGuildKey    = nil

Kerviel.displayedCharKey  = Kerviel.playerCharKey
Kerviel.displayedGuildKey = Kerviel.playerGuildKey

local MAIN_FRAME_WIDTH  = 231
local MAIN_FRAME_HEIGHT = 71
local mainFrame, charsDropDown
local allRealms, allChars = {}, {}
local sideBarButtons = {}

-- Données sauvegardées
local db_defaults = {
	global = {
		items = {},
	},
	locale = {
		items = {},
	},
	profile = {
		separateTooltip = true,		-- Tooltip séparé ?
		blankLineBefore = true,		-- Si intégré, ajouter une ligne vide ?
		showAllRealms   = false,	-- Afficher tous les royaumes ou seulement le royaume courant ?
		showAllFactions = false,	-- Afficher toutes les factions ?
		showSources     = false,	-- Afficher le détail des sources ?
		ttHeaderColor   = { r = 0xff/255, g = 0xd2/255, b = 0x00/255 },
		ttCharColor     = { r = 0x33/255, g = 0xff/255, b = 0x99/255 },
		ttGuildColor    = { r = 0x33/255, g = 0xff/255, b = 0x99/255 },
	}
}

-------------------------------------------------------------------------------
-- Gestion du menu principal
-------------------------------------------------------------------------------
local function SideBarButton_OnClick(clickedButton)

	-- Sélectionne ce bouton, déselectionne tous les autres
	for _, module in ipairs(Kerviel.stores) do
		local button = sideBarButtons[module:GetName()]
		if button == clickedButton then
			button.selected:Show()

			-- Ancre la frame du module à la frame principale
			local subFrame = module:GetFrame()
			subFrame:SetParent(mainFrame.contents)
			subFrame:ClearAllPoints()
			subFrame:SetPoint('TOPLEFT', mainFrame.contents, 'TOPLEFT', 0, 0)

			-- Ajuste la taille de la frame principale
			local w, h = subFrame:GetSize()
			mainFrame:SetSize(MAIN_FRAME_WIDTH + w, MAIN_FRAME_HEIGHT + h)

			-- Affiche la frame du module
			PlaySound('igMainMenuOpen')
			subFrame:Show()
		elseif button then
			button.selected:Hide()
			module:GetFrame():Hide()
		end
	end
end

-------------------------------------------------------------------------------
function Kerviel:UpdateSideBarButton(button, name)
	local module = self:GetModule(name)
	if module:IsStorageAvailable(self.displayedCharKey) then
		-- button:GetNormalTexture():SetVertexColor(1, 1, 1)
		button.icon:SetDesaturated(false)
	else
		-- button:GetNormalTexture():SetVertexColor(0.3, 0.3, 0.3)
		button.icon:SetDesaturated(true)
	end
end

-------------------------------------------------------------------------------
function Kerviel:UpdateSideBarButtons()
	for name, button in pairs(sideBarButtons) do
		self:UpdateSideBarButton(button, name)
	end
end

-------------------------------------------------------------------------------
local function OnStorageChanged(evt, which)
	for name, button in pairs(sideBarButtons) do
		if name == which then
			Kerviel:UpdateSideBarButton(button, name)
		end
	end
end

-------------------------------------------------------------------------------
function Kerviel:CreateSideBarButtons()
	local lastButton
	for _, module in ipairs(self.stores) do
		local storeInfo = module.storeInfo
		if storeInfo.framed then

			local button = CreateFrame('Button', nil, mainFrame.sideBar, 'KervielMenuBarButtonTemplate')
			button:SetScript('OnClick', SideBarButton_OnClick)
			button:SetText(storeInfo.text)
			button.icon:SetTexture(storeInfo.icon)

			if lastButton then
				button:SetPoint('TOP', lastButton, 'BOTTOM', 0, 0)
			else
				button:SetPoint('TOP', mainFrame.sideBar.sep, 'BOTTOM', 2, -4)
			end
			lastButton = button

			sideBarButtons[module:GetName()] = button
		end
	end

	-- Actualise le menu lorsqu'un module a de nouvelles données
	self.RegisterCallback(self, 'StorageChanged', OnStorageChanged)
end

-------------------------------------------------------------------------------
-- Gestion de la frame principale
-------------------------------------------------------------------------------
local function DropDownMenu_OnClick(entry, arg1, arg2, checked)

	-- Met le menu à jour
	UIDropDownMenu_SetSelectedValue(charsDropDown, entry.value, true)
	CloseDropDownMenus()

	-- Affiche ce personnage
	Kerviel:ChangeDisplayedCharacter(entry.value)
end

-------------------------------------------------------------------------------
local function DropDownMenu_Checked(entry)
	return UIDropDownMenu_GetSelectedValue(charsDropDown) == entry.value
end

-------------------------------------------------------------------------------
function DropDownMenu_Initialize(dropdown, level)
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
		info.checked = DropDownMenu_Checked
		info.func    = DropDownMenu_OnClick
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
			info.checked = DropDownMenu_Checked
			info.func    = DropDownMenu_OnClick
			UIDropDownMenu_AddButton(info, level)
		end
	end
end

-------------------------------------------------------------------------------
function Kerviel:ShowFrame()

	-- Crée la frame si ce n'est pas déjà fait
	if not mainFrame then
		mainFrame = CreateFrame('Frame', 'KervielMainFrame', UIParent, 'KervielMainFrameTemplate')
		mainFrame.TitleText:SetText(string.format('%s v%s', GetAddOnMetadata(self:GetName(), 'Title'), GetAddOnMetadata(self:GetName(), 'Version')))
		mainFrame.info.text:SetText(self.playerCharKey)

		-- Initialise le dropdown des personnages et sélectionne le personnage actuel
		charsDropDown = mainFrame.sideBar.dropdown

		local sv = rawget(self.db, 'sv')
		for charKey in pairs(sv.char) do
			local name, realm = self:SplitCharKey(charKey)
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
		UIDropDownMenu_Initialize(charsDropDown, DropDownMenu_Initialize)
		UIDropDownMenu_SetSelectedValue(charsDropDown, self.playerCharKey)
		UIDropDownMenu_SetText(charsDropDown, self.playerCharKey)

		charsDropDown:SetScript('OnMouseDown', function(dropdown, arg)
			-- Expérimental : autorise le clic sur l'ensemble du menu, pas seulement le bouton
			local f = dropdown.Button:GetScript('OnClick')
			if f then f(dropdown.Button, arg, true)
			end
		end)

		-- Crée le menu principal avec les boutons des modules
		self:CreateSideBarButtons()

		-- Commence avec le 1er module
		self:ChangeDisplayedCharacter(self.playerCharKey)
		for _, module in ipairs(self.stores) do
			local button = sideBarButtons[module:GetName()]
			if button then
				SideBarButton_OnClick(button)
				break
			end
		end
	end

	-- Affiche la frame
	mainFrame:Show()
end

-------------------------------------------------------------------------------
-- Gestion du personnage affiché
-------------------------------------------------------------------------------
function Kerviel:ChangeDisplayedCharacter(charKey)

	-- Sauve le nom du personnage affiché
	self.displayedCharKey = charKey

	-- Affiche les données de ce personnage
	for _, module in ipairs(self.stores) do
		if module.ChangeDisplayedCharacter then
			module:ChangeDisplayedCharacter(charKey)
		end
	end

	-- Synchronise les boutons du menu principal pour ce personnage
	self:UpdateSideBarButtons()
end

-------------------------------------------------------------------------------
-- Gestion du personnage connecté
-------------------------------------------------------------------------------
function Kerviel:PLAYER_MONEY(evt)
	self.db.char.money = GetMoney()
end

-------------------------------------------------------------------------------
function Kerviel:PLAYER_LEVEL_UP(evt, level)
	self.db.char.level = level and tonumber(level) or UnitLevel(player)
end

-------------------------------------------------------------------------------
function Kerviel:GUILDBANK_UPDATE_MONEY(evt)
	local money = GetGuildBankMoney()
	if money > 0 then
		self.db.guild.money = money
	end
end

-------------------------------------------------------------------------------
function Kerviel:PLAYER_GUILD_UPDATE(evt, arg1)
	if arg1 == 'player' then
		if IsInGuild() then
			local guildName, _, _, guildRealm = GetGuildInfo('player')
			if guildName then
				self.playerGuildName  = guildName
				self.playerGuildRealm = guildRealm or self.playerCharRealm
				self.playerGuildKey   = self:MakeCharKey(guildName, self.playerGuildRealm)

				self.db.char.guild    = self.playerGuildKey
				self.db.guild.faction = self.db.char.faction
			end
		else
			self.playerGuildName  = nil
			self.playerGuildRealm = nil
			self.playerGuildKey   = nil

			self.db.char.guild    = nil
		end
	end
end

-------------------------------------------------------------------------------
-- Initialisation
-------------------------------------------------------------------------------
function Kerviel:OnInitialize()

	-- Crée ou charge les données sauvegardées
	self.db = LibStub('AceDB-3.0-GuildMod'):New('KervielDB', db_defaults, true)
end

-------------------------------------------------------------------------------
function Kerviel:OnEnable()

	-- Actualise les données sur le personnage
	self.db.char.class   = select(2, UnitClass('player'))
	self.db.char.faction = UnitFactionGroup('player')
	self.db.char.level   = UnitLevel('player')
	self.db.char.money   = GetMoney()

	-- Actualise les données sur la guilde
	self:PLAYER_GUILD_UPDATE(nil, 'player')

	-- Recense et trie tous les modules
	self.stores = {}
	for _, module in self:IterateModules() do
		if module.storeInfo then
			table.insert(self.stores, module)
		end
	end
	table.sort(self.stores, function(s1, s2)
		return (s1.storeInfo.order or 0) < (s2.storeInfo.order or 0)
	end)

	-- Ecoute les événements
	self:RegisterEvent('PLAYER_MONEY')
	self:RegisterEvent('PLAYER_LEVEL_UP')
	self:RegisterEvent('GUILDBANK_UPDATE_MONEY')
	self:RegisterEvent('PLAYER_GUILD_UPDATE')

	-- TODO: Tout ce qui suit est à supprimer
	if true then
		_G.Kerviel = Kerviel
		-- self.db:ResetDB()
		-- self:ShowFrame()
		-- SideBarButton_OnClick(sideBarButtons['Mail'])
		self:RegisterChatCommand('qq', 'ShowFrame')
	end
end
