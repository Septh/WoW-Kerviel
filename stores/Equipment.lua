
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local module  = Kerviel:NewModule('Equipment')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Données pour le module
module.storeInfo = {
	-- Module
	order = 1,
}

-- Données
local FIRST_EQUIPMENT_SLOT = _G.INVSLOT_FIRST_EQUIPPED
local LAST_EQUIPMENT_SLOT  = _G.INVSLOT_LAST_EQUIPPED

-- Donnés sauvegardées
local ns_defaults = {
	char = {
		slots = {}
	}
}

-------------------------------------------------------------------------------
-- Gestion du module
-------------------------------------------------------------------------------
function module:IsStorageAvailable(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey] and sv.char[charKey].slots
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
	if charData and charData.slots then
		for i = FIRST_EQUIPMENT_SLOT, LAST_EQUIPMENT_SLOT do
			local id, num = self:GetItem(charData.slots, i)
			if id == itemID then
				found = found + num
			end
		end
		if found > 0 then
			results = Kerviel:NewTable()
			table.insert(results, { ['Equipé'] = found } )
		end
	end

	return found, results
end

-------------------------------------------------------------------------------
-- Gestion de l'équipement
-------------------------------------------------------------------------------
function module:PLAYER_EQUIPMENT_CHANGED(evt, arg1)
	arg1 = tonumber(arg1)
	local itemID = GetInventoryItemID('player', arg1)
	self:PutItem(self.db.char.slots, arg1, itemID, 1)
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
	self:RegisterEvent('PLAYER_EQUIPMENT_CHANGED')

	-- Sauvegarde l'équipement actuel
	for i = FIRST_EQUIPMENT_SLOT, LAST_EQUIPMENT_SLOT do
		self:PLAYER_EQUIPMENT_CHANGED(nil, i)
	end
end
