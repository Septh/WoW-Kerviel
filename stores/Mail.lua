
-- TODO: Prendre en compte les envois de mails aux alts

-- Environnement
local Kerviel = LibStub('AceAddon-3.0'):GetAddon('Kerviel')
local module  = Kerviel:NewModule('Mail')
local L       = LibStub('AceLocale-3.0'):GetLocale('Kerviel')

-- Donnés pour le module
module.storeInfo = {
	-- Module
	order = 50,
	framed = true,
	-- Bouton
	text  = _G.MAIL_LABEL,
	icon  = 'Interface\\AddOns\\Kerviel\\img\\Mail',
}

-- Données
local MAX_MAILS_DISPLAYED = 5
local MAX_ATTACHMENTS_PER_MAIL = 16

local ONE_DAY = 60*60*24
local EXPIRY_ALERT = ONE_DAY * 5
local EXPIRY_WARNING = ONE_DAY * 10

local frame
local mails, buttons

-- Donnés sauvegardées
local ns_defaults = {
	char = {
		lastRead = 0,
		-- mails = {},
	}
}

-------------------------------------------------------------------------------
-- Gestion du module
-------------------------------------------------------------------------------
function module:IsStorageAvailable(charKey)
	local sv = rawget(self.db, 'sv')
	return sv.char and sv.char[charKey] and sv.char[charKey].mails
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
	if charData and charData.mails then
		local now = time()
		for mail = 1, #charData.mails do
			local mailData = charData.mails[mail]

			-- Ignore les mails renvoyés ou perdus
			local expiry = floor(now - charData.lastRead + (mailData.daysLeft * ONE_DAY))
			if expiry > 0 and mailData.attachments then
				for j = 1, #mailData.attachments do
					local id, num = self:GetItem(mailData.attachments, j)
					if id == itemID then
						found = found + num
					end
				end
			end
		end
		if found > 0 then
			results = Kerviel:NewTable()
			table.insert(results, { ['Courrier'] = found } )
		end
	end

	return found, results
end

-------------------------------------------------------------------------------
-- Gestion de la frame
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

	local charData = self:GetData(charKey)
	if charData and charData.mails then
		frame.error:Hide()
		frame.contents:Show()

		local now = time()
		local mailIndex = 1
		for i = 1, min(#charData.mails, MAX_MAILS_DISPLAYED) do
			local expiry = floor(now - charData.lastRead + (charData.mails[i].daysLeft * ONE_DAY))
			if expiry > 0 then
				-- Expéditeur
				mails[mailIndex].sender:SetFormattedText('De : %s', charData.mails[i].sender)

				-- Expiration
				if expiry < EXPIRY_ALERT then
					mails[mailIndex].daysLeft:SetText(RED_FONT_COLOR_CODE .. SecondsToTime(expiry) .. FONT_COLOR_CODE_CLOSE)
				elseif expiry < EXPIRY_WARNING then
					mails[mailIndex].daysLeft:SetText(ORANGE_FONT_COLOR_CODE .. SecondsToTime(expiry) .. FONT_COLOR_CODE_CLOSE)
				else
					mails[mailIndex].daysLeft:SetText(GREEN_FONT_COLOR_CODE .. SecondsToTime(expiry) .. FONT_COLOR_CODE_CLOSE)
				end

				-- Pièces jointes
				local numAttachments = min(#(charData.mails[i].attachments or self.EmptyTable), MAX_ATTACHMENTS_PER_MAIL)
				for j = 1, numAttachments do
					Kerviel:UpdateItemButton(buttons[mailIndex][j], self:GetItem(charData.mails[i].attachments, j))
				end
				for j = numAttachments + 1, MAX_ATTACHMENTS_PER_MAIL do
					Kerviel:UpdateItemButton(buttons[mailIndex][j], nil, nil)
				end

				mails[mailIndex]:Show()
				mailIndex = mailIndex + 1
			else
				-- Mail renvoyé ou perdu, on l'ignore, il sera supprimé au prochain scan de la boîte de réception
			end
		end
		for i = mailIndex, MAX_MAILS_DISPLAYED do
			mails[i]:Hide()
		end
	elseif charData and charData.lastRead then
		frame.contents:Hide()
		frame.error:Show()
		frame.error.text:SetFormattedText('La boîte de réception de "%s" ne contient pas d\'objets', charKey)
	else
		frame.contents:Hide()
		frame.error:Show()
		frame.error.text:SetFormattedText('Pas de données pour "%s"', charKey)
	end
end

-------------------------------------------------------------------------------
local function Frame_OnShow()
	module:UpdateFrame(Kerviel.displayedCharKey)
end

-------------------------------------------------------------------------------
function module:CreateFrame()

	-- Crée la frame
	frame = CreateFrame('Frame', nil, nil, 'KervielMailFrameTemplate')
	frame:SetScript('OnShow', Frame_OnShow)

	-- Crée les mails et leurs boutons
	mails = {}
	buttons = {}
	for i = 1, MAX_MAILS_DISPLAYED do
		local mail = CreateFrame('Frame', nil, frame.contents, 'KervielMailTemplate')
		table.insert(mails, mail)

		if i == 1 then
			mail:SetPoint('TOP', 0, 0)
		else
			mail:SetPoint('TOPLEFT', mails[i - 1], 'BOTTOMLEFT', 0, -1)
		end

		buttons[i] = {}
		for j = 1, MAX_ATTACHMENTS_PER_MAIL do
			local button = CreateFrame('Button', nil, mail, 'KervielMailItemButtonTemplate')
			table.insert(buttons[i], button)

			button:SetID(#buttons)
			button.isBag = nil

			if j == 1 then
				button:SetPoint('TOPLEFT', mail.sender, 'BOTTOMLEFT', 0, -4)
			else
				button:SetPoint('TOPLEFT', buttons[i][j - 1], 'TOPRIGHT', 7, 0)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Gestion du courrier
-------------------------------------------------------------------------------
function module:MAIL_INBOX_UPDATE(evt)
	if _G.MailFrame:IsShown() then

		-- Le plus simple pour l'instant est de tout supprimer puis de tout relire...
		-- TODO: trouver comment améliorer ça
		for i = 1, #(self.db.char.mails or self.EmptyTable) do
			for j = 1, #(self.db.char.mails[i].attachments or self.EmptyTable) do
				self:PutItem(self.db.char.mails[i].attachments, j, nil, nil)
			end
			Kerviel:DelTable(self.db.char.mails[i].attachments)
			self.db.char.mails[i].attachments = nil
		end
		Kerviel:DelTable(self.db.char.mails)
		self.db.char.mails = nil

		-- Dernière lecture de la boîte de réception
		self.db.char.lastRead = time()

		-- Sauvegarde uniquement les mails qui ont des pièces jointes
		local numItems, totalITems = GetInboxNumItems()
		if numItems > 0 then
			for i = 1, numItems do
				local _, _, sender, _, money, _, daysLeft, numAttachments = GetInboxHeaderInfo(i)

				if numAttachments then
					self.db.char.mails = Kerviel:AssertTable(self.db.char.mails)
					self.db.char.mails[i] = Kerviel:AssertTable(self.db.char.mails[i])
					self.db.char.mails[i].sender = sender
					self.db.char.mails[i].money = money
					self.db.char.mails[i].daysLeft = daysLeft

					self.db.char.mails[i].attachments = Kerviel:AssertTable(self.db.char.mails[i].attachments)
					for j = 1, numAttachments do
						local _, itemID, _, itemCount = GetInboxItem(i, j)
						self:PutItem(self.db.char.mails[i].attachments, j, itemID, itemCount)
					end
				end
			end
		end

		-- Redessine la fenêtre et met à jour le menu principal
		self:UpdateFrame()
		Kerviel.callbacks:Fire('StorageChanged', self:GetName())
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
	self:RegisterEvent('MAIL_INBOX_UPDATE')
end
