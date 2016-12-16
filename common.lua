
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')

-- Callbacks
Kerviel.callbacks = LibStub('CallbackHandler-1.0'):New(Kerviel)

-- Upvalues
local strsplit, strtrim = strsplit, strtrim
local wipe = table.wipe
local GetRealmName = GetRealmName
local GetItemInfo = GetItemInfo
local GetContainerItemInfo = GetContainerItemInfo

-------------------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------------------
function Kerviel:Dump(...)
	if not IsAddOnLoaded('Blizzard_DebugTools') then UIParentLoadAddOn('Blizzard_DebugTools') end
	DevTools_Dump(...)
end

-------------------------------------------------------------------------------
-- Tables
-- TODO: implémenter un pool
-------------------------------------------------------------------------------
function Kerviel:NewTable(t)
	return wipe(t or {})
end

function Kerviel:DelTable(t)
	return nil
end

function Kerviel:AssertTable(t)
	return t or self:NewTable()
end

function Kerviel:CopyTable(src, dst)
	if type(dst) ~= "table" then dst = self:NewTable() end
	if type(src) == "table" then
		for k,v in pairs(src) do
			dst[k] = type(v) == "table" and self:CopyTable(v) or v
		end
	end
	return dst
end

-------------------------------------------------------------------------------
-- Gestion de la base de données globale
-------------------------------------------------------------------------------
function Kerviel:AddGlobalIem(itemID, itemCount)

	-- Ajoute le nombre d'items à la base globale
	-- self.db.global.items[itemID] = (self.db.global.items[itemID] or 0) + itemCount

	-- Ajoute le nom de l'item à la base locale
	local name = GetItemInfo(itemID)
	if name then
		self.db.locale.items[name] = itemID
	end
end

-------------------------------------------------------------------------------
function Kerviel:RemGlobalIem(itemID, itemCount)
	if not itemID then return end

	-- Retire le nombre d'items de la base globale, mais laisse son nom dans la base locale
	-- local count = (self.db.global.items[itemID] or 0) - (itemCount or 0)
	-- self.db.global.items[itemID] = count > 0 and count or nil
end

-------------------------------------------------------------------------------
-- Gestion commune des boutons
-------------------------------------------------------------------------------
local function GetItemInfoDelayed(button, evt, itemID)
	if evt == 'GET_ITEM_INFO_RECEIVED' and itemID == button.itemID then

		-- Affiche la texture
		local _, itemTexture, itemQuality
		_, _, itemQuality, _, _, _, _, _, _, itemTexture, _ = GetItemInfo(itemID)

		if itemTexture then
			if button:IsVisible() then
				button.icon:SetTexture(itemTexture)
				button.icon:Show()
				_G.SetItemButtonQuality(button, itemQuality, itemID)
			end

			-- Plus besoin de ça
			button:UnregisterEvent(evt)
			button:SetScript('OnEvent', nil)
		end
	end
end

-------------------------------------------------------------------------------
function Kerviel:UpdateItemButton(button, itemID, itemCount)
	local _, itemQuality, itemTexture
	if itemID then
		button.hasItem = true
		button.itemID = itemID

		_, _, itemQuality, _, _, _, _, _, _, itemTexture, _ = GetItemInfo(itemID)
		if itemTexture then
			button.icon:SetTexture(itemTexture)
			button.icon:Show()
		elseif not button:IsEventRegistered('GET_ITEM_INFO_RECEIVED') then
			button.icon:SetTexture('Interface\\ICONS\\INV_Misc_QuestionMark')
			button.icon:Show()
			-- Tente de mettre à jour la texture plus tard
			button:RegisterEvent('GET_ITEM_INFO_RECEIVED')
			button:SetScript('OnEvent', GetItemInfoDelayed)
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
		_G.SetItemButtonQuality(button, itemQuality, itemID)
	end
end

-------------------------------------------------------------------------------
-- Fonctions diverses
-------------------------------------------------------------------------------
function Kerviel:GetFadedColor(mini, maxi, current)

	-- Retourne une teinte de couleur allant du vert (si 'current' est proche de 'mini')
	-- au jaune (à mi-chemin) au rouge (si proche de 'maxi')
	local pct = current / ((maxi - mini) or 1)
	local r, g

	-- Those 7 lines were shamelessly stolen from CT_UnitFrames.lua
	if (pct > 0.5) then
		r = (1.0 - pct) * 2
		g = 1.0
	else
		r = 1.0
		g = pct * 2
	end

	return r, g, 0, 0.8
end

-------------------------------------------------------------------------------
function Kerviel:AceCharKey(blizzCharKey)
	local name, realm = strsplit('-', blizzCharKey, 2)
	return name .. ' - ' .. (realm or GetRealmName())
end

function Kerviel:MakeCharKey(name, realm)
	return strtrim(name) .. ' - ' .. strtrim(realm)
end

function Kerviel:SplitCharKey(charKey)
	local name, realm = strsplit('-', charKey, 2)
	return strtrim(name), strtrim(realm)
end

function Kerviel:InvertCharKey(charKey)
	local name, realm = strsplit('-', charKey, 2)
	return strtrim(realm) .. ' - ' .. strtrim(name)
end

function Kerviel:NamePart(charKey, keepOtherRealms)
	local name, realm = strsplit('-', charKey, 2)
	return (keepOtherRealms and strtrim(realm) ~= GetRealmName()) and charKey or strtrim(name)
end

function Kerviel:RealmPart(charKey)
	local name, realm = strsplit('-', charKey, 2)
	return strtrim(realm)
end

-------------------------------------------------------------------------------
function Kerviel:GetGuildKey(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey] and sv.char[charKey].guild
end

-------------------------------------------------------------------------------
function Kerviel:ItemIDFromLink(link)
	return tonumber(link:match('item:(%d+)'))
end

-------------------------------------------------------------------------------
-- Prototype des modules
-------------------------------------------------------------------------------
Kerviel:SetDefaultModuleLibraries('AceConsole-3.0', 'AceEvent-3.0')

Kerviel:SetDefaultModulePrototype({

	EmptyTable = {},

	-- Retourne le contenu (id, count) d'un slot dans la base de données d'un module, ou nil si ce slot est vide
	GetItem = function(module, db, index)
		return next(db[index] or module.EmptyTable)
	end,

	-- Sauve le contenu d'un slot dans la base de données d'un module
	PutItem = function(module, db, index, itemID, itemCount)

		-- Vérifie si le contenu de ce slot a changé depuis la dernière sauvegarde
		local savedID, savedCount = module:GetItem(db, index)
		local changed = itemID ~= savedID or itemCount ~= savedCount
		if changed then
			-- Oui, supprime ce qui s'y trouvait
			if savedID then
				Kerviel:RemGlobalIem(savedID, savedCount)
			end

			-- Et sauve le nouveau contenu
			if itemID then
				db[index] = Kerviel:NewTable(db[index])
				db[index][itemID] = itemCount

				-- Met à jour la base de données globale
				Kerviel:AddGlobalIem(itemID, itemCount)
			else
				Kerviel:DelTable(db[index])
				db[index] = nil
			end
		end
		return changed
	end,

	PutContainerItem = function(module, containerID, index, db)
		local _, count, _, _, _, _, _, _, _, id = GetContainerItemInfo(containerID, index)
		return module:PutItem(db, index, id, count)
	end,

	-- Supprime un nombre d'objets d'un slot, ou toute la pile si itemCount == nil
	RemItem = function(module, db, index, itemID, itemCount)
		if not db[index] or not db[index][itemID] then return end

		-- Retire le nombre
		local newCount = db[index][itemID] - (itemCount or 0)
		if newCount > 0 then
			db[index][itemID] = newCount
		else
			Kerviel:DelTable(db[index])
			db[index] = nil
		end

		-- Met à jour la base de données globale
		Kerviel:RemGlobalIem(itemID, itemCount)
	end
})
