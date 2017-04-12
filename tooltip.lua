
-- Environnement
local Kerviel     = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local module      = Kerviel:NewModule('tooltip', 'AceHook-3.0')
local L           = LibStub('AceLocale-3.0'):GetLocale('Kerviel')
local LibExtraTip = LibStub('LibExtraTip-1')

-- Données
local SHOW_NOT     = 0		-- Ne pas montrer dans le tooltip
local SHOW_SELF    = 1		-- Personnage courant seulement
local SHOW_FACTION = 2		-- Tous les personnages de la même faction (limité au royaume courant)
local SHOW_REALM   = 3		-- Tous les personnages du royaume courant
local SHOW_ALL     = 4		-- Tous les personnages de tous les royaumes

local itemBindings = {
	[_G.ITEM_SOULBOUND]           = SHOW_SELF,		-- Lié
	[_G.ITEM_CONJURED]            = SHOW_FACTION,	-- Objet invoqué
	[_G.ITEM_BIND_QUEST]          = SHOW_SELF,		-- Objet de quête
	[_G.ITEM_BIND_ON_PICKUP]      = SHOW_SELF,		-- lié quand ramassé
	[_G.ITEM_BIND_ON_EQUIP]       = SHOW_FACTION,	-- Lié quand équipé
	[_G.ITEM_BIND_ON_USE]         = SHOW_FACTION,	-- Lié quand utilisé
	[_G.ITEM_ACCOUNTBOUND]        = SHOW_ALL,		-- Lié au compte
	[_G.ITEM_BIND_TO_ACCOUNT]     = SHOW_ALL,		-- Lié au compte
	[_G.ITEM_BIND_TO_BNETACCOUNT] = SHOW_ALL,		-- Lié au compte Battle.net
	[_G.ITEM_BNETACCOUNTBOUND]    = SHOW_ALL,		-- Lié au compte Battle.net
}

local EmptyTable = {}
local sortedRealms, sortedChars, sortedGuilds = {}, {}, {}
local charResults, guildResults, numResults

-------------------------------------------------------------------------------
-- Gestion du tooltip
-------------------------------------------------------------------------------
local function AugmentTooltip(tooltip, itemLink, quantity, ...)
	local sv = rawget(Kerviel.db, 'sv')
	local opts = Kerviel.db.profile

	-- Recherche cet objet
	charResults  = Kerviel:NewTable(charResults)
	guildResults = Kerviel:NewTable(guildResults)
	numResults   = 0

	local itemID = Kerviel:ItemIDFromLink(itemLink)
	for _, store in Kerviel:IterateStores() do
		if store.SearchInChar then
			for charKey, charData in pairs(sv.char or EmptyTable) do
				local num, sources = store:SearchInChar(charKey, itemID)
				if num > 0 then
					charResults[charKey] = Kerviel:AssertTable(charResults[charKey])
					table.insert(charResults[charKey], sources)
					numResults = numResults + num
				end
			end
		end
		if store.SearchInGuild then
			for guildKey, guildData in pairs(sv.guild or EmptyTable) do
				local num, sources = store:SearchInGuild(guildKey, itemID)
				if num > 0 then
					guildResults[guildKey] = Kerviel:AssertTable(guildResults[guildKey])
					table.insert(guildResults[guildKey], sources)
					numResults = numResults + num
				end
			end
		end
	end

	-- Ajoute les résultats au tooltip
	if numResults > 0 then
		-- Scanne le tooltip pour déterminer quelles infos ajouter pour cet objet
		local showInfo
		if IsAltKeyDown() then
			showInfo = SHOW_ALL
		elseif IsShiftKeyDown() then
			showInfo = SHOW_FACTION
		else
			showInfo = SHOW_REALM
			for i = 1, tooltip:NumLines() do
				local line = _G[tooltip:GetName() .. 'TextLeft' .. i]:GetText() or ''
				if itemBindings[line] then
					showInfo = itemBindings[line]
					break
				end
			end
		end

		if showInfo > SHOW_NOT then
			local lastHeader
			local function addHeaderLine(text)
				if lastHeader ~= text then
					lastHeader = text
					LibExtraTip:AddLine(tooltip, text, opts.ttHeaderColor.r, opts.ttHeaderColor.g, opts.ttHeaderColor.b)
				end
			end

			local function addResultLine(key, results, color)
				local num = 0
				local arr = {}
				for _, sourceModule in ipairs(results) do
					for _, source in ipairs(sourceModule) do
						local name, count = next(source)
						table.insert(arr, string.format('%s : %d', name, count))
						num = num + count
					end
				end

				local left = string.format('%s en a %d', key, num)
				if opts.showSources or IsAltKeyDown() then
					local right = string.format('[%s]', table.concat(arr, ', '))
					LibExtraTip:AddDoubleLine(tooltip, left, right, color.r, color.g, color.b, color.r, color.g, color.b)
				else
					LibExtraTip:AddLine(tooltip, left, color.r, color.g, color.b)
				end
			end

			-- Tooltip séparé ?
			if opts.separateTooltip then
				LibExtraTip:SetEmbedMode(false)
			else
				LibExtraTip:SetEmbedMode(true)
				if opts.blankLineBefore then
					LibExtraTip:AddLine(tooltip, ' ')
				end
			end

			local showOtherChars    = showInfo > SHOW_SELF
			local showOtherFactions = opts.showAllFactions or (showInfo > SHOW_FACTION)
			local showOtherRealms   = opts.showAllRealms   or (showInfo > SHOW_REALM)

			for name, realm in ipairs(sortedRealms) do
				-- Personnages
				for _, charKey in ipairs(sortedChars[realm]) do
					if charResults[charKey] then
						local charData = sv.char[charKey]
						if (charData.faction == Kerviel.db.char.faction) or showOtherFactions then
							addHeaderLine(realm)
							addResultLine(' ' .. Kerviel:NamePart(charKey), charResults[charKey], opts.ttCharColor)
						end
					end
					if not showOtherChars then break end
				end
				-- Guildes
				for _, guildKey in ipairs(sortedGuilds[realm] or EmptyTable) do
					if guildResults[guildKey] then
						local guildData = sv.guild[guildKey]
						if (guildData.faction == Kerviel.db.char.faction) or showOtherFactions then
							addHeaderLine(realm)
							addResultLine(' <' .. Kerviel:NamePart(guildKey) .. '>', guildResults[guildKey], opts.ttGuildColor)
						end
					end
					if not showOtherChars then break end
				end
				if not showOtherRealms then break end
			end
		end

		-- Ajoute le total
		LibExtraTip:AddLine(tooltip, string.format('Total possédé : %d', numResults), opts.ttHeaderColor.r, opts.ttHeaderColor.g, opts.ttHeaderColor.b)
	end
end

-------------------------------------------------------------------------------
-- Initialisation
-------------------------------------------------------------------------------
function module:OnEnable()

	-- Recense et trie tous les personnages connus
	local sv = rawget(Kerviel.db, 'sv')
	for charKey, charData in pairs(sv.char) do
		local name, realm = Kerviel:SplitCharKey(charKey)

		-- Royaumes
		if not tContains(sortedRealms, realm) then
			table.insert(sortedRealms, realm)
		end

		-- Personnages
		if sortedChars[realm] then
			table.insert(sortedChars[realm], charKey)
		else
			sortedChars[realm] = { charKey }
		end

		-- Guildes
		if charData.guild then
			name, realm = Kerviel:SplitCharKey(charData.guild)
			if sortedGuilds[realm] then
				if not tContains(sortedGuilds[realm], charData.guild) then
					table.insert(sortedGuilds[realm], charData.guild)
				end
			else
				sortedGuilds[realm] = { charData.guild }
			end
		end
	end
	do
		-- Tri par ordre alphabétique, mais royaume, personnage et guilde courants en premier
		local criteria
		local function sorterFunc(a, b)
			if a == criteria then
				return true
			elseif b == criteria then
				return false
			else
				return a < b
			end
		end

		criteria = Kerviel.playerCharRealm; table.sort(sortedRealms, sorterFunc)
		for _, realm in ipairs(sortedRealms) do
			criteria = Kerviel.playerCharKey;  table.sort(sortedChars[realm]  or EmptyTable, sorterFunc)
			criteria = Kerviel.playerGuildKey; table.sort(sortedGuilds[realm] or EmptyTable, sorterFunc)
		end
	end
end

-------------------------------------------------------------------------------
function module:OnInitialize()

	-- Initialise LibExtraTip
	LibExtraTip:RegisterTooltip(GameTooltip)
	LibExtraTip:AddCallback(AugmentTooltip, 400)	-- Informant se met au niveau 300
end
