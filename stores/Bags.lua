
-- Données pour le module
local storeInfo = {
	order = 20,
}

-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local store   = Kerviel:NewStore('Bags', storeInfo)
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

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
-- Initialisation
-------------------------------------------------------------------------------
function store:OnInitialize()

	-- Initialise les données sauvegardées
	self.db = Kerviel.db:RegisterNamespace(self:GetName(), ns_defaults)
end

-------------------------------------------------------------------------------
function store:OnEnable()

	-- Sauve le contenu de tous les sacs
	for i = FIRST_BAG, LAST_BAG do
		self:SaveBag(i)
	end

	-- Ecoute les événements
	self:RegisterEvent('BAG_UPDATE')
	self:RegisterEvent('BAG_UPDATE_DELAYED')
end

-------------------------------------------------------------------------------
-- Gestion du module
-------------------------------------------------------------------------------
function store:IsStorageAvailableFor(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey] and sv.char[charKey].bags
end

-------------------------------------------------------------------------------
function store:GetDataFor(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey]
end

-------------------------------------------------------------------------------
-- Recherche d'objet
-------------------------------------------------------------------------------
function store:SearchInChar(charKey, itemID)
	local results, found = nil, 0

	local charData = self:GetDataFor(charKey)
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
					results = results or self:NewTable()
					table.insert(results, { ['Sac #'..(i + 1)] = count } )
					found = found + count
				end
			end
		end
	end
	return found, results
end

-------------------------------------------------------------------------------
-- Gestion du contenu des sacs du personnage courant
-------------------------------------------------------------------------------
function store:SaveBag(bagNum)
	local bagItemID = (bagNum == FIRST_BAG) and 'BACKPACK' or GetInventoryItemID('player', ContainerIDToInventoryID(bagNum))
	local bagSize   = GetContainerNumSlots(bagNum)
	local bagFree   = GetContainerNumFreeSlots(bagNum)

	-- Sauve le contenu du sac
	local bagIndex = bagNum + 1	-- Les emplacements sont numérotés à partir de 1 dans la DB
	if bagItemID then
		self.db.char.bags[bagIndex] = self:NewTable(self.db.char.bags[bagIndex])
		self.db.char.bags[bagIndex].id   = bagItemID
		self.db.char.bags[bagIndex].size = bagSize

		-- Sauve le contenu du sac
		if bagFree == bagSize then
			self.db.char.bags[bagIndex].slots = self:DelTable(self.db.char.bags[bagIndex].slots)
		else
			self.db.char.bags[bagIndex].slots = self:NewTable(self.db.char.bags[bagIndex].slots)
			for i = 1, bagSize do
				self:PutContainerItem(self.db.char.bags[bagIndex].slots, bagNum, i)
			end
		end
	else
		-- Pas de sac
		self.db.char.bags[bagIndex] = self:DelTable(self.db.char.bags[bagIndex])
	end
end

-------------------------------------------------------------------------------
function store:BAG_UPDATE_DELAYED(evt)
	-- First In, First Out
	for i, bagNum in ipairs(delayedBagUpdates) do
		self:SaveBag(bagNum)
	end
	table.wipe(delayedBagUpdates)
end

-------------------------------------------------------------------------------
function store:BAG_UPDATE(evt, arg1)
	local bagNum = tonumber(arg1)
	if bagNum >= FIRST_BAG and bagNum <= LAST_BAG then
		-- L'événement peut surgir plusieurs fois pour un même sac,
		-- on attend donc BAG_UPDATE_DELAYED pour mettre le sac à jour
		if not tContains(delayedBagUpdates, bagNum) then
			table.insert(delayedBagUpdates, bagNum)
		end
	end
end
