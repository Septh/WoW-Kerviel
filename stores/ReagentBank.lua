
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local module  = Kerviel:NewModule('ReagentBank')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Données pour le module
module.storeInfo = {
	-- Module
	order = 20,
	framed = true,
	-- Bouton
	text  = _G.REAGENT_BANK,
	icon  = 'Interface\\AddOns\\Kerviel\\img\\Reagent',
}

-- Donnés
local NUM_BLOCKS            = 7
local NUM_COLUMNS_PER_BLOCK = 2
local NUM_SLOTS_PER_COLUMN  = 7
local NUM_REAGENTBANK_SLOTS = NUM_BLOCKS * NUM_COLUMNS_PER_BLOCK * NUM_SLOTS_PER_COLUMN
local REAGENTBANK_CONTAINER = _G.REAGENTBANK_CONTAINER

local frame, buttons

-- Donnés sauvegardées
local ns_defaults = {
	char = {
		unlocked = true,
		-- slots = {}
	}
}

-------------------------------------------------------------------------------
-- Gestion du module
-------------------------------------------------------------------------------
function module:IsStorageAvailable(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey] and sv.char[charKey].slots
end

function module:ChangeDisplayedCharacter(charKey)
	self:UpdateFrame(charKey)
end

function module:GetData(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey]
end

function module:GetFrame()
	if not frame then self:CreateFrame() end
	return frame
end

-------------------------------------------------------------------------------
-- Recherche d'objet
-------------------------------------------------------------------------------
function module:SearchInChar(charKey, itemID)
	local results, found = nil, 0

	local charData = self:GetData(charKey)
	if charData and charData.slots then
		for i = 1, NUM_REAGENTBANK_SLOTS do
			local id, num = self:GetItem(charData.slots, i)
			if id == itemID then
				found = found + num
			end
		end
		if found > 0 then
			results = Kerviel:NewTable()
			table.insert(results, { ['Banque de composants'] = found } )
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

	-- Trouve la DB pour le personnage demandé
	local charData = self:GetData(charKey)
	if charData and charData.slots then
		frame.error:Hide()
		frame.contents:Show()

		-- Redessine les 98 slots
		for i = 1, NUM_REAGENTBANK_SLOTS do
			Kerviel:UpdateItemButton(buttons[i], self:GetItem(charData.slots, i))
		end
	elseif charData and not charData.unlocked then
		frame.contents:Hide()
		frame.error:Show()
		frame.error.text:SetFormattedText('"%s" n\'a pas accès à sa banque de composants', charKey)
	else
		frame.contents:Hide()
		frame.error:Show()
		frame.error.text:SetFormattedText('Pas de données pour "%s"', charKey)
	end
end

-------------------------------------------------------------------------------
local function Frame_OnShow(frame)
	module:UpdateFrame(Kerviel.displayedCharKey)
end

function module:CreateFrame()

	-- Crée la frame
	frame = CreateFrame('Frame', nil, nil, 'KervielReagentBankFrameTemplate')
	frame.size = NUM_REAGENTBANK_SLOTS			-- Permet d'appeler certaines fonctions
	frame:SetID(REAGENTBANK_CONTAINER)			-- de FrameXML/BankFrame.lua
	frame:SetScript('OnShow', Frame_OnShow)

	-- Crée les 7 blocs * 2 colonnes * 7 lignes = 98 boutons
	buttons = {}
	for i = 1, NUM_BLOCKS do
		local left = 6
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
end

-------------------------------------------------------------------------------
-- Gestion de la banque de composants
-------------------------------------------------------------------------------
function module:BANKFRAME_OPENED(evt)

	-- Sauve le contenu de la banque de composants
	self.db.char.unlocked = IsReagentBankUnlocked()
	if self.db.char.unlocked then
		self.db.char.slots  = Kerviel:AssertTable(self.db.char.slots)
		for i = 1, NUM_REAGENTBANK_SLOTS do
			self:PutContainerItem(REAGENTBANK_CONTAINER, i, self.db.char.slots)
		end
	end

	-- Redessine la fenêtre
	self:UpdateFrame()

	-- Prévient la fenêtre principale de rafraîchir son menu
	Kerviel.callbacks:Fire('StorageChanged', self:GetName())
end

-------------------------------------------------------------------------------
function module:PLAYERREAGENTBANKSLOTS_CHANGED(evt, arg1)
	arg1 = tonumber(arg1)

	-- Sauve le nouveau contenu
	local changed = self:PutContainerItem(REAGENTBANK_CONTAINER, arg1, self.db.char.slots)

	-- Et redessine le slot si la banque du personnage courant est affichée
	if changed and frame and frame:IsVisible() and Kerviel.displayedCharKey == Kerviel.playerCharKey then
		Kerviel:UpdateItemButton(buttons[arg1], self:GetItem(self.db.char.slots, arg1))
	end
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
	self:RegisterEvent('BANKFRAME_OPENED')
	self:RegisterEvent('PLAYERREAGENTBANKSLOTS_CHANGED')

	-- Pas dispo avant PLAYER_ENTERING_WORLD
	self.db.char.unlocked = IsReagentBankUnlocked()
end
