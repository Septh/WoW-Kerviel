
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local module  = Kerviel:NewModule('Bags')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Données pour le module
module.storeInfo = {
	-- Module
	order = 2,
}

-- Données
local FIRST_BAG = _G.BACKPACK_CONTAINER
local LAST_BAG  = _G.BACKPACK_CONTAINER + NUM_BAG_SLOTS

local delayedBagUpdates = {}

-- Donnés sauvegardées
local ns_defaults = {
	char = {
		bags = {}
	}
}

-------------------------------------------------------------------------------
-- Gestion du module
-------------------------------------------------------------------------------
function module:IsStorageAvailable(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey] and sv.char[charKey].bags
end

function module:GetData(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey]
end

-------------------------------------------------------------------------------
-- Recherche d'objet
-------------------------------------------------------------------------------
function module:SearchInChar(charKey, itemID)
	local results, found = nil, 0

	local charData = self:GetData(charKey)
	if charData and charData.bags then
		for i = FIRST_BAG, LAST_BAG do
			local bagData = charData.bags[i + 1] or self.EmptyTable
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
					table.insert(results, { ['Sac #'..(i + 1)] = count } )
					found = found + count
				end
			end
		end
	end
	return found, results
end

-------------------------------------------------------------------------------
-- Gestion du contenu des sacs
-------------------------------------------------------------------------------
function module:SaveBag(bagNum)
	local containerID = bagNum
	local bagItemID   = bagNum == 0 and 'Backpack' or GetInventoryItemID('player', ContainerIDToInventoryID(containerID))
	local bagSize     = GetContainerNumSlots(containerID)
	local bagFree     = GetContainerNumFreeSlots(containerID)

	-- Les emplacements sont numérotés à partir de 1 dans la DB
	bagNum = bagNum + 1

	-- Sauve le contenu du sac
	if bagItemID then
		self.db.char.bags[bagNum] = Kerviel:AssertTable(self.db.char.bags[bagNum])
		self.db.char.bags[bagNum].slots = Kerviel:AssertTable(self.db.char.bags[bagNum].slots)
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
function module:BAG_UPDATE_DELAYED(evt)
	-- First In, First Out
	for i, bagNum in ipairs(delayedBagUpdates) do
		self:SaveBag(bagNum)
	end
	table.wipe(delayedBagUpdates)
end

-------------------------------------------------------------------------------
function module:BAG_UPDATE(evt, arg1)
	local bagNum = tonumber(arg1)
	if bagNum >= FIRST_BAG and bagNum <= LAST_BAG then
		-- L'événement peut surgir plusieurs fois pour un même sac,
		-- on attend donc BAG_UPDATE_DELAYED pour mettre le sac à jour
		if not tContains(delayedBagUpdates, bagNum) then
			table.insert(delayedBagUpdates, bagNum)
		end
	end
end

-------------------------------------------------------------------------------
-- Initialisation
-------------------------------------------------------------------------------
function module:OnInitialize()

	-- Initialise les données sauvegardées
	self.db = Kerviel.db:RegisterNamespace(self:GetName(), ns_defaults)
	local _ = self.db.char.dummy	-- Force l'initialisation des metatables d'AceDB pour le personnage courant
end

-------------------------------------------------------------------------------
function module:OnEnable()

	-- Sauve le contenu de tous les sacs
	for i = FIRST_BAG, LAST_BAG do
		self:SaveBag(i)
	end

	-- Ecoute les événements
	self:RegisterEvent('BAG_UPDATE')
	self:RegisterEvent('BAG_UPDATE_DELAYED')
end