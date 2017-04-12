
-- Données pour le module
local storeInfo = {
	order = 10,
}

-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local store   = Kerviel:NewStore('Equipment', storeInfo)
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

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
function store:IsStorageAvailableFor(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey] and sv.char[charKey].slots
end

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
function store:PLAYER_EQUIPMENT_CHANGED(evt, arg1)
	arg1 = tonumber(arg1)
	local itemID = GetInventoryItemID('player', arg1)
	self:PutItem(self.db.char.slots, arg1, itemID, 1)
end

-------------------------------------------------------------------------------
-- Initialisation
-------------------------------------------------------------------------------
function store:OnEnable()

	-- Ecoute les événements
	self:RegisterEvent('PLAYER_EQUIPMENT_CHANGED')

	-- Sauvegarde l'équipement actuel
	for i = FIRST_EQUIPMENT_SLOT, LAST_EQUIPMENT_SLOT do
		self:PLAYER_EQUIPMENT_CHANGED(nil, i)
	end
end

-------------------------------------------------------------------------------
function store:OnInitialize()

	-- Initialise les données sauvegardées de ce module
	self.db = Kerviel.db:RegisterNamespace(self:GetName(), ns_defaults)
end
