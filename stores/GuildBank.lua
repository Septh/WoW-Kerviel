
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local module  = Kerviel:NewModule('GuildBank', 'AceHook-3.0')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Données pour le module
module.storeInfo = {
	-- Module
	order = 40,
	framed = true,
	-- Bouton
	text  = _G.GUILD_BANK,
	icon  = 'Interface\\AddOns\\Kerviel\\img\\GuildBank',
}

-- Donnés
local NUM_BLOCKS            = 7
local NUM_COLUMNS_PER_BLOCK = 2
local NUM_SLOTS_PER_COLUMN  = 7
local NUM_GUILDBANK_SLOTS   = NUM_BLOCKS * NUM_COLUMNS_PER_BLOCK * NUM_SLOTS_PER_COLUMN

local frame, buttons
local tabsDropDown, displayedGuildKey

-- Donnés sauvegardées
local ns_defaults = {
	char = {
		tabsview = 0,
	},
	guild = {
		-- tabs = {},
	}
}

-------------------------------------------------------------------------------
-- Gestion du module
-------------------------------------------------------------------------------
function module:IsStorageAvailable(charKey)
	local guildKey = Kerviel:GetGuildKey(charKey)
	local guildData = guildKey and self:GetData(guildKey)
	return guildData and guildData.tabs
end

function module:ChangeDisplayedCharacter(charKey)
	self:UpdateFrame(charKey)
end

function module:GetData(guildKey)
	local sv = rawget(self.db, 'sv')
	return sv.guild and sv.guild[guildKey]
end

function module:GetFrame()
	if not frame then self:CreateFrame() end
	return frame
end

-------------------------------------------------------------------------------
-- Recherche d'objet
-------------------------------------------------------------------------------
function module:SearchInGuild(guildKey, itemID)
	local results, found = nil, 0

	local guildData = self:GetData(guildKey)
	if guildData and guildData.tabs then
		for tab = 1, 8 do
			local tabData = guildData.tabs[tab] or self.EmptyTable
			if tabData.slots then
				local count = 0
				for j = 1, NUM_GUILDBANK_SLOTS do
					local id, num = self:GetItem(tabData.slots, j)
					if id == itemID then
						count = count + num
					end
				end
				if count > 0 then
					results = results or Kerviel:NewTable()
					table.insert(results, { ['Onglet #'..tab] = count } )
					found = found + count
				end
			end
		end
	end

	return found, results
end

-------------------------------------------------------------------------------
-- Gestion de la fenêtre
-------------------------------------------------------------------------------
function module:UpdateFrame(charKey)

	-- Rien à faire si la frame n'est pas affichée
	if not frame or not frame:IsVisible() then return end

	-- charKey == nil > redessine la fenêtre seulement si le personnage actuel est affiché
	-- charKey == 'nom' > redessine la fenêtre pour le personnage demandé
	if not charKey then
		charKey = Kerviel.playerCharKey
		if charKey ~= Kerviel.displayedCharKey then return end
	end

	-- Trouve la guide à afficher
	local guildKey = Kerviel:GetGuildKey(charKey)
	if guildKey then
		local guildData = self:GetData(guildKey)
		if guildData and guildData.tabs then

			-- Nom de la guide
			frame.above.tabsText:SetFormattedText('%s :', guildKey)
			frame.above:Show()

			-- Onglet
			local tab = guildKey == displayedGuildKey and UIDropDownMenu_GetSelectedValue(tabsDropDown) or 1
			UIDropDownMenu_EnableDropDown(tabsDropDown)
			UIDropDownMenu_Initialize(tabsDropDown, tabsDropDown.initialize)
			UIDropDownMenu_SetSelectedValue(tabsDropDown, tab)
			displayedGuildKey = guildKey

			-- Le contenu
			if guildData.tabs[tab] and guildData.tabs[tab].slots then
				for i = 1, NUM_GUILDBANK_SLOTS do
					Kerviel:UpdateItemButton(buttons[i], self:GetItem(guildData.tabs[tab].slots, i))
				end
				frame.contents:Show()
				frame.error:Hide()
			else
				frame.contents:Hide()
				frame.error:Show()
				frame.error.text:SetFormattedText('Pas de données pour cet onglet', tab)
			end
		else
			frame.above:Hide()
			frame.contents:Hide()
			frame.error:Show()
			frame.error.text:SetFormattedText('Pas de données pour la guilde "%s"', guildKey)

			UIDropDownMenu_SetText(tabsDropDown, 'Aucun onglet')
			UIDropDownMenu_DisableDropDown(tabsDropDown)
		end
	else
		frame.above:Hide()
		frame.contents:Hide()
		frame.error:Show()
		frame.error.text:SetFormattedText('"%s" n\'est pas dans une guilde', charKey)

		UIDropDownMenu_SetText(tabsDropDown, 'Aucun onglet')
		UIDropDownMenu_DisableDropDown(tabsDropDown)
	end
end

-------------------------------------------------------------------------------
local function Frame_OnShow(frame)
	module:UpdateFrame(Kerviel.displayedCharKey)
end

-------------------------------------------------------------------------------
local function TabsDropDown_OnClick(entry, arg1, arg2, checked)
	UIDropDownMenu_SetSelectedValue(tabsDropDown, entry.value)
	module:UpdateFrame(Kerviel.displayedCharKey)
end

local function TabsDropDown_Checked(entry)
	return UIDropDownMenu_GetSelectedValue(tabsDropDown) == entry.value
end

local function TabsDropDown_Initialize()
	local sv = rawget(module.db, 'sv')
	local guildKey = Kerviel:GetGuildKey(Kerviel.displayedCharKey)
	local guildData = guildKey and sv.guild and sv.guild[guildKey]

	if not guildData or not guildData.tabs then return end

	-- Remplit le menu avec la liste des onglets
	local info = UIDropDownMenu_CreateInfo()
	for i = 1, #guildData.tabs do
		wipe(info)
		info.text       = guildData.tabs[i].name
		info.icon       = guildData.tabs[i].icon
		info.isNotRadio = true
		info.value      = i
		info.checked    = TabsDropDown_Checked
		info.func       = TabsDropDown_OnClick
		info.minWidth   = _G.KervielGuildBankFrameDropDownMenuMiddle:GetWidth()
		UIDropDownMenu_AddButton(info)
	end
end

-------------------------------------------------------------------------------
function module:UIDropDownMenu_RefreshDropDownSize(dropDownListFrame)

	-- HACK --
	-- Redessine le menu avec des entrées et des icônes plus grandes
	if dropDownListFrame.dropdown == tabsDropDown then
		local ICON_SIZE = 32
		local BUTTON_HEIGHT = ICON_SIZE + 8

		for i = 1, dropDownListFrame.numButtons do
			local button = _G['DropDownList1Button'.. i]
			button:SetHeight(BUTTON_HEIGHT)
			if i > 1 then
				button:ClearAllPoints()
				button:SetPoint('TOPLEFT', _G['DropDownList1Button'.. (i - 1)], 'BOTTOMLEFT', 0, 0)
			end
			_G['DropDownList1Button' .. i .. 'Icon']:SetSize(ICON_SIZE, ICON_SIZE)
		end
		dropDownListFrame:SetWidth(_G.KervielGuildBankFrameDropDownMenuMiddle:GetWidth() + 2 * UIDROPDOWNMENU_BORDER_HEIGHT)
		dropDownListFrame:SetHeight(dropDownListFrame.numButtons * BUTTON_HEIGHT + 2 * UIDROPDOWNMENU_BORDER_HEIGHT)
	else
		-- Si ce n'est pas notre menu, il faut rétablir la hauteur par défaut
		for i = 1, dropDownListFrame.numButtons do
			_G['DropDownList1Button'.. i]:SetHeight(UIDROPDOWNMENU_BUTTON_HEIGHT)
		end
	end
	-- /HACK --
end

-------------------------------------------------------------------------------
function module:CreateFrame()

	-- Crée la frame
	frame = CreateFrame('Frame', nil, nil, 'KervielGuildBankFrameTemplate')
	frame:SetScript('OnShow', Frame_OnShow)

	-- Crée le menu déroulant des onglets
	self:SecureHook('UIDropDownMenu_RefreshDropDownSize')	-- HACK: embellit le menu

	tabsDropDown = frame.above.dropdown
	UIDropDownMenu_SetWidth(tabsDropDown, 200)
	UIDropDownMenu_JustifyText(tabsDropDown, 'LEFT')
	UIDropDownMenu_Initialize(tabsDropDown, TabsDropDown_Initialize)
	UIDropDownMenu_SetSelectedValue(tabsDropDown, 1)
	UIDropDownMenu_SetText(tabsDropDown, 'Aucun onglet')

	-- Expérimental : autorise le clic sur l'ensemble du menu, pas seulement le bouton
	tabsDropDown:SetScript('OnMouseDown', function(dropdown, arg)
		local f = dropdown.Button:GetScript('OnClick')
		if f then f(dropdown.Button, arg, true)
		end
	end)

	-- Crée les 7 blocs * 2 colonnes * 7 lignes = 98 boutons
	buttons = {}
	for i = 1, NUM_BLOCKS do
		local left = 7
		for j = 1, NUM_COLUMNS_PER_BLOCK do
			local top = -3
			for k = 1, NUM_SLOTS_PER_COLUMN do
				local button = CreateFrame('Button', nil, frame.contents, 'KervielItemButtonTemplate')
				table.insert(buttons, button)

				button:SetID(#buttons)
				button.isBag = nil

				button:SetPoint('TOPLEFT', frame.contents['BG' .. i], 'TOPLEFT', left, top)
				top = top - 44
			end
			left = left + 49
		end
	end

	-- Retourne la frame
	return frame
end

-------------------------------------------------------------------------------
-- Gestion de la banque de guilde
-------------------------------------------------------------------------------
local pickupTab, pickupSlot, pickupCount
function module:SplitGuildBankItem(tab, slot, count)

	-- 1ère étape du déplacement... On mémorise simplement l'action
	if not pickupTab then
		if count > 0 then
			pickupTab, pickupSlot, pickupCount = tab, slot, count
		end
		return
	end

	-- Déplacement au sein du même onglet > on laisse GUILDBANKBAGSLOTS_CHANGED gérer
	if pickupTab == tab then
		pickupTab, pickupSlot, pickupCount = nil, nil, nil
		return
	end

	-- Met à jour l'emplacement d'origine (l'emplacement de destination sera géré dans GUILDBANKBAGSLOTS_CHANGED)
	local orig_db = self.db.guild.tabs[pickupTab].slots; local orig_id, orig_count = self:GetItem(orig_db, pickupSlot)
	local dest_db = self.db.guild.tabs[tab].slots;       local dest_id, dest_count = self:GetItem(dest_db, slot)

	if dest_id and dest_id ~= orig_id then
		-- Slot d'origine <-> slot destination
		self:PutItem(orig_db, pickupSlot, dest_id, dest_count)
	else
		-- Slot origine -> slot destination
		self:RemItem(orig_db, pickupSlot, orig_id, pickupCount)
	end

	-- Laisse GUILDBANKBAGSLOTS_CHANGED gérer le reste pour l'onglet courant
	pickupTab, pickupSlot, pickupCount = nil, nil, nil
end

function module:PickupGuildBankItem(tab, slot)
	local _, count = self:GetItem(self.db.guild.tabs[tab].slots, slot)
	return self:SplitGuildBankItem(tab, slot, count or 0)
end

function module:GUILDBANK_ITEM_LOCK_CHANGED(evt)
	-- Permet de gérer l'annulation du déplacement d'un item
	if IsMouseButtonDown('RightButton') then
		pickupTab, pickupSlot, pickupCount = nil, nil, nil
	end
end

-------------------------------------------------------------------------------
function module:GUILDBANKBAGSLOTS_CHANGED(evt)

	-- Sauve le contenu de l'onglet affiché
	local tab = GetCurrentGuildBankTab()
	self.db.guild.tabs[tab].slots = Kerviel:AssertTable(self.db.guild.tabs[tab].slots)

	for i = 1, NUM_GUILDBANK_SLOTS do
		local _, count = GetGuildBankItemInfo(tab, i)
		local link     = GetGuildBankItemLink(tab, i)
		local id       = link and Kerviel:ItemIDFromLink(link) or nil

		-- Sauve le slot
		self:PutItem(self.db.guild.tabs[tab].slots, i, id, count)
	end

	-- Redessine la fenêtre et met à jour le menu principal
	self:UpdateFrame()
	Kerviel.callbacks:Fire('StorageChanged', self:GetName())
end

-------------------------------------------------------------------------------
function module:GUILDBANKFRAME_OPENED(evt)
	self:GUILDBANKBAGSLOTS_CHANGED(evt)
end

-------------------------------------------------------------------------------
function module:GUILDBANK_UPDATE_TABS(evt)

	-- Sauve les droits d'accès aux onglets dans la DB du personnage
	self.db.char.tabsview = 0

	-- Sauve le nom et l'icône des onglets dans la DB de guilde
	self.db.guild.tabs = Kerviel:AssertTable(self.db.guild.tabs)
	for i = 1, GetNumGuildBankTabs() do
		local name, icon, isViewable = GetGuildBankTabInfo(i)

		self.db.guild.tabs[i] = Kerviel:AssertTable(self.db.guild.tabs[i])
		self.db.guild.tabs[i].name = (not name or name == '') and _G.GUILDBANK_TAB_NUMBER:format(i) or name
		self.db.guild.tabs[i].icon = icon

		if isViewable then
			self.db.char.tabsview = self.db.char.tabsview + bit.lshift(1, i - 1)
		end
	end

	-- Actualise le dropdown
	self:UpdateFrame()
end

-------------------------------------------------------------------------------
-- Initialisation
-------------------------------------------------------------------------------
function module:OnInitialize()

	-- Initialise les données sauvegardées
	self.db = Kerviel.db:RegisterNamespace(self:GetName(), ns_defaults)
end

-------------------------------------------------------------------------------
function module:OnEnable()

	-- Ecoute les événements
	self:RegisterEvent('GUILDBANKFRAME_OPENED')
	self:RegisterEvent('GUILDBANKBAGSLOTS_CHANGED')
	self:RegisterEvent('GUILDBANK_UPDATE_TABS')

	-- Perme de suivre les items déplacés d'un onglet à un autre dans la banque
	self:RegisterEvent('GUILDBANK_ITEM_LOCK_CHANGED')
	self:SecureHook('PickupGuildBankItem')
	self:SecureHook('SplitGuildBankItem')
end
