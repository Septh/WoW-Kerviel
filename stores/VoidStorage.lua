
-- Données pour le module
local storeInfo = {
	order  = 70,
	framed = true,
	text   = _G.VOID_STORAGE,
	icon   = 'Interface\\AddOns\\Kerviel\\img\\Void',
}

-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local store   = Kerviel:NewStore('VoidStorage', storeInfo)
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Donnés
local NUM_BLOCKS            = 5
local NUM_COLUMNS_PER_BLOCK = 2
local NUM_SLOTS_PER_COLUMN  = 8
local NUM_SLOTS_PER_BLOCK   = NUM_COLUMNS_PER_BLOCK * NUM_SLOTS_PER_COLUMN
local NUM_VOIDSTORAGE_PAGES = 2
local NUM_VOIDSTORAGE_SLOTS = NUM_BLOCKS * NUM_COLUMNS_PER_BLOCK * NUM_SLOTS_PER_COLUMN

local frame, buttons
local displayedPage

-- Donnés sauvegardées
local ns_defaults = {
	char = {
		unlocked = true,
		-- pages = {},
	}
}

-------------------------------------------------------------------------------
-- Gestion du store
-------------------------------------------------------------------------------
function store:IsStorageAvailableFor(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey] and sv.char[charKey].pages
end

function store:SetDisplayedCharacter(msg, charKey)
	self:UpdateFrame(charKey)
end

function store:GetDataFor(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey]
end

function store:GetFrame()
	if not frame then self:CreateFrame() end
	return frame
end

-------------------------------------------------------------------------------
-- Recherche d'objet
-------------------------------------------------------------------------------
function store:SearchInChar(charKey, itemID)
	local results, found = nil, 0

	local charData = self:GetDataFor(charKey)
	if charData and charData.pages then
		for page = 1, NUM_VOIDSTORAGE_PAGES do
			local pageData = charData.pages[page] or self.EmptyTable
			if pageData.slots then
				local count = 0
				for j = 1, NUM_VOIDSTORAGE_SLOTS do
					local id, num = self:GetItem(pageData.slots, j)
					if id == itemID then
						count = count + num
					end
				end
				if count > 0 then
					results = results or Kerviel:NewTable()
					table.insert(results, { ['Chambre du vide #'..page] = count } )
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
function store:UpdateFrame(charKey)

	-- Rien à faire si la frame n'est pas affichée
	if not frame or not frame:IsVisible() then return end

	-- charKey == nil > redessine la fenêtre seulement si le personnage actuel est affiché
	-- charKey == 'nom' > redessine la fenêtre pour le personnage demandé
	if not charKey then
		charKey = Kerviel.playerCharKey
		if charKey ~= Kerviel.displayedCharKey then return end
	end

	-- Trouve la DB pour le personnage demandé
	local charData = self:GetDataFor(charKey)
	if charData and charData.pages then
		frame.error:Hide()
		frame.contents:Show()

		if displayedPage == 1 then
			frame.contents.prevButton:Disable()
			frame.contents.nextButton:Enable()
		elseif displayedPage == NUM_VOIDSTORAGE_PAGES then
			frame.contents.prevButton:Enable()
			frame.contents.nextButton:Disable()
		end

		-- Redessine les 80 slots
		for i = 1, NUM_VOIDSTORAGE_SLOTS do
			self:UpdateItemButton(buttons[i], self:GetItem(charData.pages[displayedPage].slots, i))
		end
	elseif charData and not charData.unlocked then
		frame.contents:Hide()
		frame.error:Show()
		frame.error.text:SetFormattedText('"%s" n\'a pas accès sa chambre du vide', charKey)
	else
		frame.contents:Hide()
		frame.error:Show()
		frame.error.text:SetFormattedText('Pas de données pour "%s"', charKey)
	end
end

-------------------------------------------------------------------------------
local function PrevButton_Click()
	if displayedPage > 1 then
		displayedPage = displayedPage - 1
		store:UpdateFrame(Kerviel.displayedCharKey)
	end
end

local function NextButton_Click()
	if displayedPage < NUM_VOIDSTORAGE_PAGES then
		displayedPage = displayedPage + 1
		store:UpdateFrame(Kerviel.displayedCharKey)
	end
end

local function Frame_OnShow()
	store:UpdateFrame(Kerviel.displayedCharKey)
end

function store:CreateFrame()

	-- Crée la frame
	frame = CreateFrame('Frame', nil, nil, 'KervielVoidStorageFrameTemplate')
	frame:SetScript('OnShow', Frame_OnShow)

	frame.contents.prevButton:SetScript('OnClick', PrevButton_Click)
	frame.contents.nextButton:SetScript('OnClick', NextButton_Click)

	displayedPage = 1

	-- Crée les 8 * 2 * 5 = 80 boutons
	buttons = {}
	for i = 1, NUM_VOIDSTORAGE_SLOTS do
		local slot = CreateFrame('Button', nil, frame.contents.inner, 'KervielVoidStorageItemButtonTemplate')
		if i == 1 then
			slot:SetPoint('TOPLEFT', 10, -8)
		elseif (i % NUM_SLOTS_PER_COLUMN) == 1 then
			if (i % NUM_SLOTS_PER_BLOCK) == 1 then
				slot:SetPoint('TOPLEFT', buttons[i - 8], "TOPRIGHT", 14, 0)
			else
				slot:SetPoint("TOPLEFT", buttons[i - 8], "TOPRIGHT", 7, 0)
			end
		else
			slot:SetPoint("TOPLEFT", buttons[i - 1], "BOTTOMLEFT", 0, -5)
		end

		slot:SetID(i)
		table.insert(buttons, slot)
	end
end

-------------------------------------------------------------------------------
-- Gestion de la chambre du vide
-------------------------------------------------------------------------------
function store:VOID_STORAGE_CONTENTS_UPDATE(evt)
	if self.db.char.unlocked then
		self.db.char.pages = Kerviel:NewTable(self.db.char.pages)

		for i = 1, NUM_VOIDSTORAGE_PAGES do
			self.db.char.pages[i] = Kerviel:NewTable(self.db.char.pages[i])
			self.db.char.pages[i].slots = Kerviel:NewTable(self.db.char.pages[i].slots)
			for j = 1, NUM_VOIDSTORAGE_SLOTS do
				local id = GetVoidItemInfo(i, j)
				local changed = self:PutItem(self.db.char.pages[i].slots, j, id, 1)

				if changed and frame and frame:IsVisible() and i == displayedPage and Kerviel.displayedCharKey == Kerviel.playerCharKey then
					self:UpdateItemButton(buttons[j], self:GetItem(self.db.char.pages[i].slots, j))
				end
			end
		end
	end

	-- Prévient la fenêtre principale de rafraîchir son menu
	self:NotifyUpdate()
end

-------------------------------------------------------------------------------
function store:VOID_STORAGE_UPDATE(evt)
	self.db.char.unlocked = CanUseVoidStorage()
end

-------------------------------------------------------------------------------
function store:VOID_TRANSFER_DONE(evt)
	self:VOID_STORAGE_CONTENTS_UPDATE(evt)
end

-------------------------------------------------------------------------------
function store:VOID_STORAGE_OPEN(evt)
	if IsVoidStorageReady() then
		self:VOID_STORAGE_CONTENTS_UPDATE(evt)
	end
end

-------------------------------------------------------------------------------
-- Initialisation
-------------------------------------------------------------------------------
function store:OnEnable()

	-- Ecoute les événements
	self:RegisterEvent('VOID_STORAGE_OPEN')
	self:RegisterEvent('VOID_TRANSFER_DONE')
	self:RegisterEvent('VOID_STORAGE_UPDATE')
	self:RegisterEvent('VOID_STORAGE_CONTENTS_UPDATE')

	self:RegisterMessage('SetDisplayedCharacter')

	-- Pas dispo avant PLAYER_ENTERING_WORLD
	self.db.char.unlocked = CanUseVoidStorage()
end

-------------------------------------------------------------------------------
function store:OnInitialize()

	-- Initialise les données sauvegardées
	self.db = Kerviel.db:RegisterNamespace(self:GetName(), ns_defaults)
end
