local ABS_PlayerName = nil;
local ABS_SpellBookNameToId = {};
local ABS_InventoryItemNameToId = {};
local ABS_BagItemNameToId = {};
local MAX_ACTIONS = 144;

function ABS_OnLoad()
	this:RegisterEvent("VARIABLES_LOADED");
	
	SLASH_ABS1 = "/ABS";
	SlashCmdList["ABS"] = function(msg)
		ABS_SlashCommand(msg);
	end
end

function ABS_SaveProfile( profileName )
	if ( profileName == "" ) then
		return;
	end;
	if ( ABS_Layout[ ABS_PlayerName ][ profileName ] ~= nil ) then
		ABS_Layout[ ABS_PlayerName ][ profileName ] = nil;
	end
	ABS_Layout[ ABS_PlayerName ][ profileName ] = {};
	ABS_Layout[ ABS_PlayerName ][ profileName ][ "spells" ] = {};
	ABS_Layout[ ABS_PlayerName ][ profileName ][ "macros" ] = {};
	ABS_Layout[ ABS_PlayerName ][ profileName ][ "items" ] = {};
	
	ABS_Tooltip:SetOwner(this, "ANCHOR_NONE");
	
	local scStatus = GetCVar("autoSelfCast");
	SetCVar( "autoSelfCast", 0 );
	for i = 1, MAX_ACTIONS do
		if ( HasAction( i ) ~= nil ) then
			local macroName = GetActionText( i );
			if ( macroName ~= nil ) then -- It is a macro
				ABS_Layout[ ABS_PlayerName ][ profileName ][ "macros" ][ i ] = macroName;
			else -- It is a spell or an item
				ABS_Tooltip:ClearLines();
				ABS_Tooltip:SetAction( i );
				
				PickupAction( i );
				local isASpell = CursorHasSpell();
				PlaceAction( i );
				if ( isASpell ) then -- It is a spell
					local spellName = nil;
					local rank = nil;
					
					if (ABS_TooltipTextLeft1:IsShown()) then
						spellName = ABS_TooltipTextLeft1:GetText();
					end
					if (ABS_TooltipTextRight1:IsShown()) then
						rank = ABS_TooltipTextRight1:GetText();
					end
					
					ABS_Layout[ ABS_PlayerName ][ profileName ][ "spells" ][ i ] = {};
					ABS_Layout[ ABS_PlayerName ][ profileName ][ "spells" ][ i ][ "name" ] = spellName;
					ABS_Layout[ ABS_PlayerName ][ profileName ][ "spells" ][ i ][ "rank" ] = rank; -- can be text or nil
				else -- It is an item
					local itemName = nil;
					
					if (ABS_TooltipTextLeft1:IsShown()) then
						itemName = ABS_TooltipTextLeft1:GetText();
					end
					
					ABS_Layout[ ABS_PlayerName ][ profileName ][ "items" ][ i ] = itemName;
				end
			end
		end
	end
	
	SetCVar( "autoSelfCast", scStatus );
	DEFAULT_CHAT_FRAME:AddMessage( "Profile \""..profileName.."\" has been saved." );
end

function ABS_LoadProfile( profileName )
	if ( ABS_Layout[ ABS_PlayerName ][ profileName ] == nil ) then
		DEFAULT_CHAT_FRAME:AddMessage( "Profile \""..profileName.."\" has not been saved previously and cannot be loaded." );
		return;
	end
	local scStatus = GetCVar("autoSelfCast");
	SetCVar( "autoSelfCast", 0 );
	-- First find ids of all spells and items because vanilla API sucks and you can't fetch spells by name.
	-- Spells
	for i = 1, MAX_SKILLLINE_TABS do
		local name, _, offset, numSpells = GetSpellTabInfo(i);
		if ( not name ) then break; end
		for s = offset + 1, offset + numSpells do
			local spellName, spellRank = GetSpellName( s, BOOKTYPE_SPELL );
			if ( spellRank ~= "" ) then spellName = spellName.." "..spellRank; end
			ABS_SpellBookNameToId[ spellName ] = s;
		end
	end
	
	ABS_Tooltip:SetOwner(this, "ANCHOR_NONE");
	
	-- Inventory (equipped) items
	for i = 1, 19 do
		ABS_Tooltip:ClearLines();
		hasItem, _, _ = ABS_Tooltip:SetInventoryItem( "player", i );
		if ( hasItem ) then
			local itemName = nil;
			
			if ( ABS_TooltipTextLeft1:IsShown() ) then
				itemName = ABS_TooltipTextLeft1:GetText();
				ABS_InventoryItemNameToId[ itemName ] = i;
			end
		end
	end
	
	-- Bag items
	for i = 0, NUM_BAG_SLOTS do
		for j = 1, GetContainerNumSlots( i ) do
			texture, itemCount = GetContainerItemInfo( i, j );
			if ( texture ) then
				ABS_Tooltip:ClearLines();
				ABS_Tooltip:SetBagItem( i, j );
				local itemName = nil;
				
				if ( ABS_TooltipTextLeft1:IsShown() ) then
					itemName = ABS_TooltipTextLeft1:GetText();
					
					ABS_BagItemNameToId[ itemName ] = {};
					ABS_BagItemNameToId[ itemName ][ "bag" ] = i;
					ABS_BagItemNameToId[ itemName ][ "slot" ] = j;
				end
			end
		end
	end
	
	
	-- Place spells, items and macros on the action bars.
	for i = 1, MAX_ACTIONS do
		if ( ABS_Layout[ ABS_PlayerName ][ profileName ][ "spells" ][ i ] ~= nil ) then -- It is a spell
			local spellName = ABS_Layout[ ABS_PlayerName ][ profileName ][ "spells" ][ i ][ "name" ];
			local spellRank = ABS_Layout[ ABS_PlayerName ][ profileName ][ "spells" ][ i ][ "rank" ];
			if ( spellRank ~= nil ) then spellName = spellName.." "..spellRank; end
			local spellID = ABS_SpellBookNameToId[ spellName ];
			if ( spellID == nil ) then
				DEFAULT_CHAT_FRAME:AddMessage( "Spell \""..spellName.."\" is not learnt at the moment." );
				PickupAction( i );
				ClearCursor();
			else
				PickupSpell( spellID, BOOKTYPE_SPELL);
				PlaceAction( i );
			end
		elseif ( ABS_Layout[ ABS_PlayerName ][ profileName ][ "macros" ][ i ] ~= nil ) then -- It is a macro
			local macroIdx = GetMacroIndexByName( ABS_Layout[ ABS_PlayerName ][ profileName ][ "macros" ][ i ] );
			if ( macroIdx > 0 ) then
				PickupMacro( macroIdx );
				PlaceAction( i );
			elseif ( GetSuperMacroInfo( ABS_Layout[ ABS_PlayerName ][ profileName ][ "macros" ][ i ], "texture" ) ) then
				PickupMacro( 0, ABS_Layout[ ABS_PlayerName ][ profileName ][ "macros" ][ i ] );
				PlaceAction( i );
			end
		elseif ( ABS_Layout[ ABS_PlayerName ][ profileName ][ "items" ][ i ] ~= nil ) then -- It is an item
			local itemName = ABS_Layout[ ABS_PlayerName ][ profileName ][ "items" ][ i ];
			if ( ABS_InventoryItemNameToId[ itemName ] ~= nil ) then
				local itemID = ABS_InventoryItemNameToId[ itemName ];
				PickupInventoryItem( itemID );
				PlaceAction( i );
			elseif ( ABS_BagItemNameToId[ itemName ] ~= nil ) then
				local bagID = ABS_BagItemNameToId[ itemName ][ "bag" ];
				local slotID = ABS_BagItemNameToId[ itemName ][ "slot" ];
				PickupContainerItem( bagID, slotID );
				PlaceAction( i );
			end
		elseif ( HasAction( i ) ~= nil ) then
			PickupAction( i );
			ClearCursor();
		end
	end
	SetCVar( "autoSelfCast", scStatus );
	ABS_SpellBookNameToId = {}
	ABS_InventoryItemNameToId = {}
	ABS_BagItemNameToId = {}
	DEFAULT_CHAT_FRAME:AddMessage( "Profile \""..profileName.."\" has been loaded." );
end

function hasElements( T )
	local count = 0;
	for _ in pairs( T ) do
		count = count + 1;
		break;
	end
	return count;
end

function ABS_ListProfiles()
	if ( ABS_Layout[ ABS_PlayerName ] == nil or hasElements( ABS_Layout[ ABS_PlayerName ] ) == 0 ) then
		DEFAULT_CHAT_FRAME:AddMessage( "You have no profiles saved for this character." );
		return
	end
	DEFAULT_CHAT_FRAME:AddMessage( "This character has following profiles saved:" );
	
	for profileName, val in pairs( ABS_Layout[ ABS_PlayerName ] ) do
		DEFAULT_CHAT_FRAME:AddMessage( profileName );
	end
	
end

function ABS_RemoveProfile( profileName )
	if ( ABS_Layout[ ABS_PlayerName ][ profileName ] == nil ) then
		DEFAULT_CHAT_FRAME:AddMessage( "You have no profile '"..profileName.."' saved for this character." );
		return
	end
	
	ABS_Layout[ ABS_PlayerName ][ profileName ] = nil;
	DEFAULT_CHAT_FRAME:AddMessage( "Profile '"..profileName.."' has been removed." );
end

function ABS_OnEvent()
	if ( event == "VARIABLES_LOADED" ) then
		ABS_PlayerName = UnitName("player").." of "..GetCVar("realmName");
		
		if ( ABS_Layout == nil ) then 
			ABS_Layout = {};
		end
		
		if ( ABS_Layout[ ABS_PlayerName ] == nil ) then 
			ABS_Layout[ ABS_PlayerName ] = {};
		end

		if (ABS_ButtonPosition == nil) then
			ABS_ButtonPosition = 60;
		end
		
		UIDropDownMenu_Initialize( getglobal( "ABS_DropDownMenu" ), ABS_DropDownMenu_OnLoad, "MENU" );
		ABSButton_UpdatePosition()
	end
end

function ABS_SlashCommand(msg)
	if ( msg == "" ) then
		DEFAULT_CHAT_FRAME:AddMessage( "ActionBarProfiles, by <Vanguard> of Kronos and Emerald Dream" );
		DEFAULT_CHAT_FRAME:AddMessage( "/abs save [profileName]" );
		DEFAULT_CHAT_FRAME:AddMessage( "/abs load [profileName]" );
		DEFAULT_CHAT_FRAME:AddMessage( "/abs remove [profileName]" );
		DEFAULT_CHAT_FRAME:AddMessage( "/abs list" );
	end
	for profileName in string.gfind( msg, "save (.*)" ) do
		ABS_SaveProfile( profileName );
	end
	for profileName in string.gfind( msg, "load (.*)" ) do
		ABS_LoadProfile( profileName );
	end
	for profileName in string.gfind( msg, "remove (.*)" ) do
		ABS_RemoveProfile( profileName );
	end
	for profileName in string.gfind( msg, "list" ) do
		ABS_ListProfiles();
	end
end

-- GUI --
function ABS_DropDownMenu_OnLoad()
	if ( UIDROPDOWNMENU_MENU_VALUE == "Delete menu" ) then
		local title	= {
			text 		= "Select a layout to delete",
			isTitle		= true,
			owner 		= this:GetParent(),
			justifyH 	= "CENTER",
		};
		UIDropDownMenu_AddButton( title, UIDROPDOWNMENU_MENU_LEVEL );
		
		for profileName, val in pairs( ABS_Layout[ ABS_PlayerName ] ) do
			local entry = {
				text 				= profileName,
				value 				= profileName,
				func				= function()
					ABS_RemoveProfile( this:GetText() );
				end,
				notCheckable 		= 1,
				owner 				= this:GetParent()
			};
			UIDropDownMenu_AddButton( entry, UIDROPDOWNMENU_MENU_LEVEL );
		end
		return;
	end
	
	local title	= {
		text 		= UnitName("player").."'s action bars",
		isTitle		= true,
		owner 		= this:GetParent(),
		justifyH 	= "CENTER",
	};
	UIDropDownMenu_AddButton( title, UIDROPDOWNMENU_MENU_LEVEL );
	
	for profileName, val in pairs( ABS_Layout[ ABS_PlayerName ] ) do
		local entry = {
			text 				= profileName,
			func 				= function()
				ABS_LoadProfile( this:GetText() );
			end,
			notCheckable 		= 1,
			owner 				= this:GetParent()
		};
		UIDropDownMenu_AddButton( entry, UIDROPDOWNMENU_MENU_LEVEL );
	end
	
	title	= {
		text 		= "Options",
		isTitle		= true,
		justifyH 	= "CENTER"
	};
	UIDropDownMenu_AddButton( title, UIDROPDOWNMENU_MENU_LEVEL );
	
	local info = {
		text 			= "Save current layout",
		func 			= function()
			StaticPopup_Show("ABS_NewProfile");
		end,
		notCheckable 	= 1,
		owner 			= this:GetParent()
	};
	UIDropDownMenu_AddButton( info, UIDROPDOWNMENU_MENU_LEVEL );
	
	info = {
		text 			= "Delete a layout",
		value			= "Delete menu",
		notCheckable 	= 1,
		hasArrow		= true
	};
	UIDropDownMenu_AddButton( info, UIDROPDOWNMENU_MENU_LEVEL );
end

function ABS_OnClick() 
	ToggleDropDownMenu( 1, nil, ABS_DropDownMenu, ActionBarProfiles_IconFrame, 0, 0 );
end

StaticPopupDialogs["ABS_NewProfile"] = {
	text = "Enter a name under which to save the current action bars layout",
	button1 = SAVE,
	button2 = CANCEL,
	OnAccept = function()
		local profileName = getglobal( this:GetParent():GetName().."EditBox" ):GetText();
		ABS_SaveProfile( profileName );
		getglobal( this:GetParent():GetName().."EditBox" ):SetText("");
	end,
	EditBoxOnEnterPressed = function()
		local profileName = this:GetText();
		ABS_SaveProfile( profileName );
		this:SetText("");
		local parent = this:GetParent();
		parent:Hide();
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	hasEditBox  = true,
	preferredIndex = 3
}

-- Positioning (Stole this part of code from Atlas addon) --
local ABS_ButtonRadius = 78;

function ABSButton_UpdatePosition()
	ActionBarProfiles_IconFrame:SetPoint(
		"TOPLEFT",
		"Minimap",
		"TOPLEFT",
		54 - ( ABS_ButtonRadius * cos( ABS_ButtonPosition ) ),
		( ABS_ButtonRadius * sin( ABS_ButtonPosition ) ) - 55
	);
end

function ABSButton_BeingDragged()
    local xpos,ypos = GetCursorPosition() 
    local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom() 

    xpos = xmin-xpos/UIParent:GetScale()+70 
    ypos = ypos/UIParent:GetScale()-ymin-70 

    ABSButton_SetPosition(math.deg(math.atan2(ypos,xpos)));
end

function ABSButton_SetPosition(v)
    if(v < 0) then
        v = v + 360;
    end

    ABS_ButtonPosition = v;
    ABSButton_UpdatePosition();
end