
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local module  = Kerviel:NewModule('Bank')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Données pour le module
module.storeInfo = {
	-- Module
	order  = 10,
	framed = true,
	-- Bouton
	text   = _G.BANK,
	icon   = 'Interface\\AddOns\\Kerviel\\img\\Bank',
}

-- Données
local BANK_CONTAINER    = _G.BANK_CONTAINER
local BANKBAG_CONTAINER = -4	-- Valeur "magique" utilisée dans BankFrame.lua/BankFrameItemButton_Update()

local NUM_BANK_SLOTS    = _G.NUM_BANKGENERIC_SLOTS
local FIRST_BANK_SLOT   = 1
local LAST_BANK_SLOT    = NUM_BANK_SLOTS

local NUM_BANK_BAGS     = _G.NUM_BANKBAGSLOTS
local FIRST_BANK_BAG    = _G.NUM_BAG_SLOTS
local LAST_BANK_BAG     = _G.NUM_BAG_SLOTS + _G.NUM_BANKBAGSLOTS

local frame, buttons, bagButtons
local delayedBagUpdates = {}

-- Donnés sauvegardées
local ns_defaults = {
	char = {
		-- slots = {},
		-- bags  = {},
		maxBags = NUM_BANK_BAGS,
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
	if charData then
		if charData.slots then
			local count = 0
			for i = 1, NUM_BANK_SLOTS do
				local id, num = self:GetItem(charData.slots, i)
				if id == itemID then
					count = count + num
				end
			end
			if count > 0 then
				results = results or Kerviel:NewTable()
				table.insert(results, { ['Banque'] = count } )
				found = found + count
			end
		end
		if charData.bags then
			for i = 1, NUM_BANK_BAGS do
				local bagData = charData.bags[i] or self.EmptyTable
				if bagData.slots then
					local count = 0
					for j = 1, bagData.size do
						local id, num = self:GetItem(bagData.slots, j)
						if id == itemID then
							count = count + num
						end
					end
					if count > 0 then
						results = results or Kerviel:NewTable()
						table.insert(results, { ['Sac de banque #'..i] = count } )
						found = found + count
					end
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

	-- Trouve la DB pour le personnage demandé
	local charData = self:GetData(charKey)
	if charData and charData.slots then
		frame.error:Hide()
		frame.contents:Show()

		-- Slots
		for i = 1, NUM_BANK_SLOTS do
			Kerviel:UpdateItemButton(buttons[i], self:GetItem(charData.slots, i))
		end

		-- Sacs
		for i = 1, NUM_BANK_BAGS do
			local button = bagButtons[i]
			if charData.bags and charData.bags[i] then

				-- Calcule le nombre d'emplacements disponibles dans ce sac
				local free = charData.bags[i].size
				if charData.bags[i].slots then
					for j = 1, charData.bags[i].size do
						if charData.bags[i].slots[j] then
							free = free - 1
						end
					end
				end

				-- Affiche l'icône du sac
				-- Le compteur affiche le nombre d'empacements disponbiles
				Kerviel:UpdateItemButton(button, charData.bags[i].id, free)
				button.icon:SetVertexColor(1, 1, 1)

				-- La couleur du bord rappelle s'il est plein ou vide
				button.IconBorder:SetVertexColor(Kerviel:GetFadedColor(0, charData.bags[i].size, free))
				button.IconBorder:Show()
			else
				-- Pas de sac dans cet emplacement
				Kerviel:UpdateItemButton(button, nil, nil)
				button.icon:SetTexture('Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag')

				-- Rougit l'icône si l'emplacement de sac n'est pas disponible
				button.icon:Show()
				if i > (charData.maxBags or 0) then
					button.icon:SetVertexColor(1, 0.1, 0.1)
				else
					button.icon:SetVertexColor(1, 1, 1)
				end
				button.IconBorder:Hide()
			end
		end
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
	frame = CreateFrame('Frame', nil, nil, 'KervielBankFrameTemplate')
	frame.size = NUM_BANK_SLOTS		-- Permet d'appeler certaines fonctions
	frame:SetID(BANK_CONTAINER)		-- de FrameXML/BankFrame.lua
	frame:SetScript('OnShow', Frame_OnShow)

	-- Crée les 28 emplacements primaires
	buttons = {}
	for i = 1, NUM_BANK_SLOTS do
		local button = CreateFrame('Button', nil, frame.contents, 'KervielItemButtonTemplate')
		table.insert(buttons, button)

		button:SetID(i)
		button.isBag = nil

		if i == 1 then
			button:SetPoint('LEFT', 28, 0)
			button:SetPoint('TOP', frame.contents.slotsText, 0, -25)
		elseif (i % 7) == 1 then
			button:SetPoint('TOPLEFT', buttons[i - 7], 'BOTTOMLEFT', 0, -7)
		else
			button:SetPoint('TOPLEFT', buttons[i - 1], 'TOPRIGHT', 12, 0)
		end

		local texture = frame.contents:CreateTexture(nil, 'BORDER', 'Bank-Slot-BG')
		texture:SetPoint('TOPLEFT', button, 'TOPLEFT', -6, 5)
		texture:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', 6, -7)
	end

	-- Ajoute les rivets entre les boutons
	for i = 1, 20 do
		if (i % 7) ~= 0 then
			local texture = frame.contents:CreateTexture(nil, 'BORDER', 'Bank-Rivet')
			texture:SetPoint('TOPLEFT',     buttons[i], 'BOTTOMRIGHT', 0, 2)
			texture:SetPoint('BOTTOMRIGHT', buttons[i], 'BOTTOMRIGHT', 12, -10)
		end
	end

	-- Crée les 7 sacs
	bagButtons = {}
	for i = 1, NUM_BANK_BAGS do
		local button = CreateFrame('Button', nil, frame.contents, 'KervielItemButtonTemplate')
		table.insert(bagButtons, button)

		button:SetID(i)
		button.isBag = 1

		if i == 1 then
			button:SetPoint('LEFT', 28, 0)
			button:SetPoint('TOP', frame.contents.bagsText, 0, -25)
		else
			button:SetPoint('TOPLEFT', bagButtons[i - 1], 'TOPRIGHT', 12, 0)
		end

		local texture = frame.contents:CreateTexture(nil, 'BORDER', 'Bank-Slot-BG')
		texture:SetPoint('TOPLEFT', button, 'TOPLEFT', -6, 5)
		texture:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', 6, -7)
	end

	-- Retourne la frame
	return frame
end

-------------------------------------------------------------------------------
-- Gestion du contenu de la banque
-------------------------------------------------------------------------------
function module:SaveBag(bagNum)
	local containerID = FIRST_BANK_BAG + bagNum	-- bagNum = 1 ... NUM_BANK_BAGS
	local bagItemID   = select(10, GetContainerItemInfo(BANKBAG_CONTAINER, bagNum))
	local bagSize     = GetContainerNumSlots(containerID)
	local bagFree     = GetContainerNumFreeSlots(containerID)

	-- Sauve le contenu du sac
	if bagItemID then
		self.db.char.bags[bagNum] = Kerviel:AssertTable(self.db.char.bags[bagNum])
		self.db.char.bags[bagNum].slots = Kerviel:AssertTable(self.db.char.bags[bagNum].slots)

		-- Met à jour les données sauvegardées pour ce sac
		for i = 1, math.max(bagSize, self.db.char.bags[bagNum].size or 0) do
			self:PutContainerItem(containerID, i, self.db.char.bags[bagNum].slots)
		end

		-- Sauve l'ID et la taille du sac lui-même
		self.db.char.bags[bagNum].id   = bagItemID
		self.db.char.bags[bagNum].size = bagSize
		if bagFree == bagSize then
			-- Sac vide
			Kerviel:DelTable(self.db.char.bags[bagNum].slots)
			self.db.char.bags[bagNum].slots = nil
		end
	else
		-- Pas de sac
		Kerviel:DelTable(self.db.char.bags[bagNum])
		self.db.char.bags[bagNum] = nil
	end

	return true
end

-------------------------------------------------------------------------------
function module:BANKFRAME_OPENED(evt)

	-- Sauve le contenu de la banque
	self.db.char.slots = Kerviel:AssertTable(self.db.char.slots)
	for i = 1, NUM_BANK_SLOTS do
		self:PutContainerItem(BANK_CONTAINER, i, self.db.char.slots)
	end

	-- Sauve le contenu des sacs de banque
	self.db.char.maxBags = GetNumBankSlots()
	self.db.char.bags = Kerviel:AssertTable(self.db.char.bags)
	for i = 1, NUM_BANK_BAGS do
		self:SaveBag(i)
	end

	-- Redessine la fenêtre
	self:UpdateFrame()

	-- Prévient la fenêtre principale de rafraîchir son menu
	Kerviel.callbacks:Fire('StorageChanged', self:GetName())
end

-------------------------------------------------------------------------------
function module:BAG_UPDATE_DELAYED(evt)

	if #delayedBagUpdates > 0 then
		-- First In, First Out
		for i, bagNum in ipairs(delayedBagUpdates) do
			self:SaveBag(bagNum)
		end
		table.wipe(delayedBagUpdates)

		-- Redessine la fenêtre
		self:UpdateFrame()
	end
end

-------------------------------------------------------------------------------
function module:BAG_UPDATE(evt, arg1)

	-- Vérifie si c'est un sac de banque et si la banque est ouverte
	-- (il y a parfois des BAG_UPDATE de banque au login)
	local bagNum = tonumber(arg1) - FIRST_BANK_BAG
	if bagNum >= 1 and bagNum <= NUM_BANK_BAGS and _G.BankFrame:IsShown() then
		-- L'événement peut surgir plusieurs fois pour un même sac,
		-- on attend donc BAG_UPDATE_DELAYED pour mettre le sac à jour
		if not tContains(delayedBagUpdates, bagNum) then
			table.insert(delayedBagUpdates, bagNum)
		end
	end
end

-------------------------------------------------------------------------------
function module:PLAYERBANKSLOTS_CHANGED(evt, arg1)
	arg1 = tonumber(arg1)
	if arg1 <= NUM_BANK_SLOTS then
		-- Un slot générique, on peut le mettre à jour immédiatement
		local changed = self:PutContainerItem(BANK_CONTAINER, arg1, self.db.char.slots)

		-- Redessine le slot si la banque du personnage courant est affichée
		if changed and frame and frame:IsVisible() and Kerviel.displayedCharKey == Kerviel.playerCharKey then
			Kerviel:UpdateItemButton(buttons[arg1], self:GetItem(self.db.char.slots, arg1))
		end
	else
		-- Un sac de banque, on attend BAG_UPDATE_DELAYED pour mettre ce sac à jour
		table.insert(delayedBagUpdates, arg1 - NUM_BANK_SLOTS)
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
	self:RegisterEvent('PLAYERBANKSLOTS_CHANGED')
	self:RegisterEvent('BAG_UPDATE')
	self:RegisterEvent('BAG_UPDATE_DELAYED')
end
