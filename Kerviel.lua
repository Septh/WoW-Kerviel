
-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):NewAddon('Kerviel', 'AceConsole-3.0', 'AceEvent-3.0')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Upvalues
local wipe, abs = table.wipe, math.abs
local IsAddOnLoaded = _G.IsAddOnLoaded
local UnitName, GetRealmName, UnitClass, UnitFactionGroup, UnitLevel = _G.UnitName, _G.GetRealmName, _G.UnitClass, _G.UnitFactionGroup, _G.UnitLevel
local GetMoney = _G.GetMoney
local IsInGuild, GetGuildInfo, GetGuildBankMoney = _G.IsInGuild, _G.GetGuildInfo, _G.GetGuildBankMoney
local GetItemInfo = _G.GetItemInfo

-- Données partagées avec les modules
Kerviel.playerCharName    = UnitName('player')
Kerviel.playerCharRealm   = GetRealmName()
Kerviel.playerCharKey     = Kerviel.playerCharName .. ' - ' .. Kerviel.playerCharRealm

Kerviel.playerGuildName   = nil
Kerviel.playerGuildRealm  = nil
Kerviel.playerGuildKey    = nil

Kerviel.displayedCharKey  = Kerviel.playerCharKey
Kerviel.displayedGuildKey = Kerviel.playerGuildKey

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
		ttHeaderColor   = { r = 0xff/255, g = 0xd2/255, b = 0x00/255 },
		ttCharColor     = { r = 0x33/255, g = 0xff/255, b = 0x99/255 },
		ttGuildColor    = { r = 0x33/255, g = 0xff/255, b = 0x99/255 },
	}
}

-------------------------------------------------------------------------------
-- Gestion des tables
-------------------------------------------------------------------------------
local FreeTables = setmetatable({}, { __mode = 'kv' }) -- Weak table
local UsedTables = {}
local EmptyTable = {}

function Kerviel:NewTable(t)
	if type(t) == 'table' then
		for k,v in pairs(t) do
			t[k] = self:DelTable(v)
		end
	end
	if UsedTables[t] then
		wipe(t)
	else
		t = next(FreeTables) or {}
		FreeTables[t] = nil
		UsedTables[t] = t
	end
	return t
end

function Kerviel:DelTable(t)
	if type(t) == 'table' then
		for k,v in pairs(t) do
			t[k] = self:DelTable(v)
		end
	end
	if UsedTables[t] then
		FreeTables[t] = t
		UsedTables[t] = nil
	end
	return nil
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
	local pct = current / (abs(maxi - mini) or 1)
	if pct > 0.5 then
		return (1.0 - pct) * 2, 1.0, 0, 1.0
	else
		return 1.0, pct * 2, 0, 1.0
	end
end

-------------------------------------------------------------------------------
function Kerviel:AceCharKey(blizzCharKey)
	local name, realm = ('-'):split(blizzCharKey, 2)
	return name:trim() .. ' - ' .. (realm and realm:trim() or GetRealmName())
end

function Kerviel:MakeCharKey(name, realm)
	return name:trim() .. ' - ' .. realm:trim()
end

function Kerviel:SplitCharKey(charKey)
	local name, realm = ('-'):split(charKey, 2)
	return name:trim(), realm:trim()
end

function Kerviel:InvertCharKey(charKey)
	local name, realm = ('-'):split(charKey, 2)
	return realm:trim() .. ' - ' .. name:trim()
end

function Kerviel:NamePart(charOrGuildKey, keepOtherRealms)
	local name, realm = ('-'):split(charOrGuildKey, 2)
	return (keepOtherRealms and realm:trim() ~= GetRealmName()) and charOrGuildKey or name:trim()
end

function Kerviel:RealmPart(charKey)
	local name, realm = ('-'):split(charKey, 2)
	return realm and realm:trim() or GetRealmName()
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
-- Gestion de la base de données globale
-------------------------------------------------------------------------------
function Kerviel:AddGlobalIem(itemID, itemCount)
	if not itemID or (type(itemCount) ~= "number") then return end

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
	local actual = (self.db.global.items[itemID] or 0)
	local newCount = actual - (itemCount or actual)
	self.db.global.items[itemID] = newCount > 0 and newCount or nil
end

-------------------------------------------------------------------------------
-- Gestion du personnage connecté
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
function Kerviel:PLAYER_MONEY(evt)
	self.db.char.money = GetMoney()
end

-------------------------------------------------------------------------------
function Kerviel:PLAYER_LEVEL_UP(evt, level)
	self.db.char.level = level and tonumber(level) or UnitLevel(player)
end

-------------------------------------------------------------------------------
-- Initialisation
-------------------------------------------------------------------------------
function Kerviel:OnEnable()

	-- Actualise les données sur le personnage
	self.db.char.class   = select(2, UnitClass('player'))
	self.db.char.faction = UnitFactionGroup('player')
	self:PLAYER_LEVEL_UP()
	self:PLAYER_MONEY()
	self:PLAYER_GUILD_UPDATE(nil, 'player')

	-- Ecoute les événements qui nous intéressent
	self:RegisterEvent('PLAYER_LEVEL_UP')
	self:RegisterEvent('PLAYER_MONEY')
	self:RegisterEvent('PLAYER_GUILD_UPDATE')
	self:RegisterEvent('GUILDBANK_UPDATE_MONEY')
end

-------------------------------------------------------------------------------
function Kerviel:OnInitialize()

	-- Crée ou charge les données sauvegardées
	self.db = LibStub('AceDB-3.0-GuildMod'):New('KervielDB', db_defaults, true)
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
