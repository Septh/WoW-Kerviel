
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):NewAddon('Kerviel', 'AceConsole-3.0', 'AceEvent-3.0')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Données partagées avec les modules
Kerviel.playerCharName    = UnitName('player')
Kerviel.playerCharRealm   = GetRealmName()
Kerviel.playerCharKey     = Kerviel.playerCharName .. ' - ' .. Kerviel.playerCharRealm

Kerviel.playerGuildName   = nil
Kerviel.playerGuildRealm  = nil
Kerviel.playerGuildKey    = nil

Kerviel.displayedCharKey  = Kerviel.playerCharKey
Kerviel.displayedGuildKey = Kerviel.playerGuildKey

-- Tableau des modules
Kerviel.stores = {}

-- Données sauvegardées
local db_defaults = {
	global = {
		items = {},
	},
	locale = {
		items = {},
	},
	profile = {
		separateTooltip = true,		-- Tooltip séparé ?
		blankLineBefore = true,		-- Si intégré, ajouter une ligne vide ?
		showAllRealms   = false,	-- Afficher tous les royaumes ou seulement le royaume courant ?
		showAllFactions = false,	-- Afficher toutes les factions ?
		showSources     = true,		-- Afficher le détail des sources ?
		colors          = {
			header   = { 0xff/255, 0xd2/255, 0x00/255 },
			char     = { 0x33/255, 0xff/255, 0x99/255 },
			guild    = { 0x33/255, 0xff/255, 0x99/255 },
		},
		ttHeaderColor   = { r = 0xff/255, g = 0xd2/255, b = 0x00/255 },
		ttCharColor     = { r = 0x33/255, g = 0xff/255, b = 0x99/255 },
		ttGuildColor    = { r = 0x33/255, g = 0xff/255, b = 0x99/255 },
	}
}

-------------------------------------------------------------------------------
-- Initialisation
-------------------------------------------------------------------------------
function Kerviel:OnInitialize()

	-- Crée ou charge les données sauvegardées globales
	self.db = LibStub('AceDB-3.0-GuildMod'):New('KervielDB', db_defaults, true)
end

-------------------------------------------------------------------------------
function Kerviel:OnEnable()

	-- Actualise les données sur le personnage
	self.db.char.class   = select(2, UnitClass('player'))
	self.db.char.faction = UnitFactionGroup('player')
	self.db.char.level   = UnitLevel('player')
	self.db.char.money   = GetMoney()

	-- Actualise les données sur la guilde
	self:PLAYER_GUILD_UPDATE(nil, 'player')

	-- Trie les modules
	table.sort(self.stores, function(s1, s2)
		return (s1.storeInfo.order or 0) < (s2.storeInfo.order or 0)
	end)

	-- Ecoute les événements qui nous intéressent
	self:RegisterEvent('PLAYER_MONEY')
	self:RegisterEvent('PLAYER_LEVEL_UP')
	self:RegisterEvent('GUILDBANK_UPDATE_MONEY')
	self:RegisterEvent('PLAYER_GUILD_UPDATE')
end

-------------------------------------------------------------------------------
-- Gestion du personnage connecté
-------------------------------------------------------------------------------
function Kerviel:PLAYER_MONEY(evt)
	self.db.char.money = GetMoney()
end

-------------------------------------------------------------------------------
function Kerviel:PLAYER_LEVEL_UP(evt, level)
	self.db.char.level = level and tonumber(level) or UnitLevel(player)
end

-------------------------------------------------------------------------------
function Kerviel:GUILDBANK_UPDATE_MONEY(evt)
	local money = GetGuildBankMoney()
	if money > 0 then
		self.db.guild.money = money
	end
end

-------------------------------------------------------------------------------
function Kerviel:PLAYER_GUILD_UPDATE(evt, arg1)
	if arg1 == 'player' then
		if IsInGuild() then
			local guildName, _, _, guildRealm = GetGuildInfo('player')
			if guildName then
				self.playerGuildName  = guildName
				self.playerGuildRealm = guildRealm or self.playerCharRealm
				self.playerGuildKey   = self:MakeCharKey(guildName, self.playerGuildRealm)

				self.db.char.guild    = self.playerGuildKey
				self.db.guild.faction = self.db.char.faction
			end
		else
			self.playerGuildName  = nil
			self.playerGuildRealm = nil
			self.playerGuildKey   = nil

			self.db.char.guild    = nil
		end
	end
end

-------------------------------------------------------------------------------
-- Gestion de la base de données globale
-------------------------------------------------------------------------------
function Kerviel:AddGlobalIem(itemID, itemCount)
	if type(itemCount) ~= "number" then return end

	-- Ajoute le nombre d'items à la base globale
	self.db.global.items[itemID] = (self.db.global.items[itemID] or 0) + itemCount

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
	local count = (self.db.global.items[itemID] or 0) - (itemCount or 0)
	self.db.global.items[itemID] = count > 0 and count or nil
end

-------------------------------------------------------------------------------
-- Gestion des tables
-- TODO: implémenter un pool
-------------------------------------------------------------------------------
local EmptyTable = {}

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
-- Fonctions utilitaires diverses
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
-- Gestion des modules
-------------------------------------------------------------------------------
local storePrototype = {

	-- Gestion des tables
	EmptyTable  = {},
	NewTable    = Kerviel.NewTable,
	DelTable    = Kerviel.DelTable,
	AssertTable = Kerviel.AssertTable,
	CopyTable   = Kerviel.CopyTable,

	-- Retourne le contenu (id, count) d'un slot dans la base de données d'un module, ou nil si ce slot est vide
	GetItem = function(store, db, index)
		return next(db[index] or {})
	end,

	-- Sauve le contenu d'un slot dans la base de données d'un module
	PutItem = function(store, db, index, itemID, itemCount)

		-- Vérifie si le contenu de ce slot a changé depuis la dernière sauvegarde
		local savedID, savedCount = store:GetItem(db, index)
		local changed = itemID ~= savedID or itemCount ~= savedCount
		if changed then
			-- Oui, supprime ce qui s'y trouvait
			if savedID then
				Kerviel:RemGlobalIem(savedID, savedCount)
			end

			-- Et sauve le nouveau contenu
			if itemID then
				db[index] = store:NewTable(db[index])
				db[index][itemID] = itemCount

				-- Met à jour la base de données globale
				Kerviel:AddGlobalIem(itemID, itemCount)
			else
				store:DelTable(db[index])
				db[index] = nil
			end
		end
		return changed
	end,

	PutContainerItem = function(store, containerID, index, db)
		local _, count, _, _, _, _, _, _, _, id = GetContainerItemInfo(containerID, index)
		return store:PutItem(db, index, id, count)
	end,

	-- Supprime un nombre d'objets d'un slot, ou toute la pile si itemCount == nil
	RemItems = function(store, db, index, itemID, itemCount)
		if not db[index] or not db[index][itemID] then return end

		-- Retire le nombre
		local newCount = db[index][itemID] - (itemCount or db[index][itemID])
		if newCount > 0 then
			db[index][itemID] = newCount
		else
			db[index] = store:DelTable(db[index])
		end

		-- Met à jour la base de données globale
		Kerviel:RemGlobalIem(itemID, itemCount)
	end,

	-- Met à jour le bouton d'un slot
	UpdateItemButton = function(store, button, itemID, itemCount)
		local _, itemQuality, itemTexture
		if itemID then
			button.hasItem = true
			button.itemID = itemID

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
	end,

	-- Envoie un message à la fenêtre principale
	NotifyChange = function(store)
		store:SendMessage('StorageChanged', store)
	end
}

function Kerviel:NewStore(name, info, ...)

	-- Crée le module avec les bibliothèques et le prototype
	local store = self:NewModule(name, storePrototype, 'AceConsole-3.0', 'AceEvent-3.0', ...)
	store.storeInfo = info

	self.stores[name] = store
	return store
end

-------------------------------------------------------------------------------
function Kerviel:GetStore(name)
	return self:GetModule(name)
end

-------------------------------------------------------------------------------
function Kerviel:IterateStores()
	return pairs(self.stores)
end

-------------------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------------------
function Kerviel:Dump(...)
	if not IsAddOnLoaded('Blizzard_DebugTools') then UIParentLoadAddOn('Blizzard_DebugTools') end
	if IsAddOnLoaded('Blizzard_DebugTools') then
		DevTools_Dump(...)
	end
end
