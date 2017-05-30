
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Upvalues
local GetItemInfo, GetContainerItemInfo = _G.GetItemInfo, _G.GetContainerItemInfo

-------------------------------------------------------------------------------
-- Gestion des modules
-------------------------------------------------------------------------------
local stores = {}
local storePrototype = {

	-- Raccourcis pour le pool de tables
	EmptyTable = {},
	NewTable   = Kerviel.NewTable,
	DelTable   = Kerviel.DelTable,
	CopyTable  = Kerviel.CopyTable,

	-- Fonctions remplacées par les modules
	SearchInChar = function(self, itemID) return nil end,
	SearchInBank = function(self, itemID) return nil end,
	SearchByName = function(self, name)   return nil end,

	-- Envoie un message à la fenêtre principale
	NotifyUpdate = function(self)
		self:SendMessage('StorageUpdated', self)
	end,

	-- Retourne le contenu (id, count) d'un slot dans la base de données d'un module, ou nil si ce slot est vide
	GetItem = function(self, db, slot)
		return db and (next(db[slot] or self.EmptyTable)) or nil
	end,

	-- Sauve le contenu d'un slot dans la base de données d'un module
	PutItem = function(self, db, slot, itemID, itemCount)
		if not db then return end

		-- Vérifie si le contenu de ce slot a changé depuis la dernière sauvegarde
		local savedID, savedCount = self:GetItem(db, slot)
		local changed = (itemID ~= savedID) or (itemCount ~= savedCount)
		if changed then
			-- Si oui, supprime ce qui s'y trouvait
			if savedID then
				Kerviel:RemGlobalIem(savedID, savedCount)
			end

			-- Et sauve le nouveau contenu
			if itemID then
				db[slot] = self:NewTable(db[slot])
				db[slot][itemID] = itemCount

				-- Met à jour la base de données globale
				Kerviel:AddGlobalIem(itemID, itemCount)
			else
				db[slot] = self:DelTable(db[slot])
			end
		end
		return changed
	end,

	PutContainerItem = function(self, db, containerID, slot)
		local _, itemCount, _, _, _, _, _, _, _, itemID = GetContainerItemInfo(containerID, slot)
		return self:PutItem(db, slot, itemID, itemCount)
	end,

	-- Supprime un nombre d'objets d'un slot, ou toute la pile si itemCount == nil
	RemItem = function(self, db, slot, itemID, itemCount)
		local actual = (db and db[slot] and db[slot][itemID]) or 0
		local newCount = actual - (itemCount or actual)
		if newCount > 0 then
			db[slot][itemID] = newCount
		else
			db[slot] = self:DelTable(db[slot])
		end

		-- Met à jour la base de données globale
		Kerviel:RemGlobalIem(itemID, itemCount)
	end,

	-- Met à jour le bouton d'un slot
	UpdateItemButton = function(self, button, itemID, itemCount)
		local _, itemQuality, itemTexture
		if itemID then
			button.hasItem = true
			button.itemID  = itemID

			_, _, itemQuality, _, _, _, _, _, _, itemTexture, _ = GetItemInfo(itemID)
			if itemTexture then
				button.icon:SetTexture(itemTexture)
				button.icon:Show()
			elseif not button:IsEventRegistered('GET_ITEM_INFO_RECEIVED') then
				-- Affiche un ? temporaire. Le handler dans Kerviel.xml mettra la bonne texture plus tard.
				button:RegisterEvent('GET_ITEM_INFO_RECEIVED')
				button.icon:SetTexture('Interface\\ICONS\\INV_Misc_QuestionMark')
				button.icon:Show()
			end

			button:Enable()
			if itemCount > 1 or button.isBag then
				button.Count:SetText(itemCount)
				button.Count:Show()
			else
				button.Count:Hide()
			end
		else
			button:Disable()
			button.hasItem = nil
			button.itemID  = nil
			button.icon:Hide()
			button.Count:Hide()
		end

		if not button.isBag then
			SetItemButtonQuality(button, itemQuality, itemID)
		end
	end
}

-------------------------------------------------------------------------------
function Kerviel:NewStore(name, info, ...)

	-- Crée le module avec les bibliothèques et le prototype
	local store = self:NewModule(name, storePrototype, 'AceConsole-3.0', 'AceEvent-3.0', ...)
	store.storeInfo = info or {}

	-- Insère le module à sa place dans le tableau trié
	local pos = 1
	while pos < #stores do
		if (store.storeInfo.order or 0) > (stores[pos].storeInfo.order or 0) then
			break
		end
		pos = pos + 1
	end
	table.insert(stores, pos, store)

	-- Retourne le module
	return store
end

-------------------------------------------------------------------------------
function Kerviel:SortStores()
	table.sort(stores, function(s1, s2)
		return (s1.storeInfo.order or 0) < (s2.storeInfo.order or 0)
	end)
end

-------------------------------------------------------------------------------
function Kerviel:IterateStores()
	return ipairs(stores)
end
