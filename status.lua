
--[[
* Copyright (c) 2023 tirem [github.com/tirem] under the GPL-3.0 license
]]--

require('common');

local icons = require('status.statusicons');
local table = require('status.statustable');
local tracker = require('status.statustracker');

local function GetStPartyIndex()
    local ptr = AshitaCore:GetPointerManager():Get('party');
    ptr = ashita.memory.read_uint32(ptr);
    ptr = ashita.memory.read_uint32(ptr);
    local isActive = (ashita.memory.read_uint32(ptr + 0x54) ~= 0);
    if isActive then
        return ashita.memory.read_uint8(ptr + 0x50);
    else
        return nil;
    end
end

--Thanks to Velyn for the event system and interface hidden signatures!
local pGameMenu = ashita.memory.find('FFXiMain.dll', 0, "8B480C85C974??8B510885D274??3B05", 16, 0);
local pEventSystem = ashita.memory.find('FFXiMain.dll', 0, "A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3", 0, 0);
local pInterfaceHidden = ashita.memory.find('FFXiMain.dll', 0, "8B4424046A016A0050B9????????E8????????F6D81BC040C3", 0, 0);

local function GetMenuName()
    local subPointer = ashita.memory.read_uint32(pGameMenu);
    local subValue = ashita.memory.read_uint32(subPointer);
    if (subValue == 0) then
        return '';
    end
    local menuHeader = ashita.memory.read_uint32(subValue + 4);
    local menuName = ashita.memory.read_string(menuHeader + 0x46, 16);
    return string.gsub(menuName, '\x00', '');
end

local function GetEventSystemActive()
    if (pEventSystem == 0) then
        return false;
    end
    local ptr = ashita.memory.read_uint32(pEventSystem + 1);
    if (ptr == 0) then
        return false;
    end

    return (ashita.memory.read_uint8(ptr) == 1);

end

local function GetInterfaceHidden()
    if (pEventSystem == 0) then
        return false;
    end
    local ptr = ashita.memory.read_uint32(pInterfaceHidden + 10);
    if (ptr == 0) then
        return false;
    end

    return (ashita.memory.read_uint8(ptr + 0xB4) == 1);
end

local status = T{};

status.GetGameInterfaceHidden = function(MenuNames)

	if (GetEventSystemActive()) then
		return true;
	end
	if (string.match(GetMenuName(), 'map')) then
		return true;
	end
    if (GetInterfaceHidden()) then
        return true;
    end
	if (tracker.bLoggedIn == false) then
		return true;
	end
    return false;
end

status.GetTargets = function()
    local playerTarget = AshitaCore:GetMemoryManager():GetTarget();
    local party = AshitaCore:GetMemoryManager():GetParty();

    if (playerTarget == nil or party == nil) then
        return nil, nil;
    end

    local mainTarget = playerTarget:GetTargetIndex(0);
    local secondaryTarget = playerTarget:GetTargetIndex(1);
    local partyTarget = GetStPartyIndex();

    if (partyTarget ~= nil) then
        secondaryTarget = mainTarget;
        mainTarget = party:GetMemberTargetIndex(partyTarget);
    end

    return mainTarget, secondaryTarget;
end

status.GetStatusIdsById = function(ServerId)
    return tracker.GetStatusEffects(ServerId);
end

status.GetStatusIdsByIndex = function(TargetIndex)
    return status.GetStatusIdsById(AshitaCore:GetMemoryManager():GetEntity():GetServerId(TargetIndex));
end

status.GetStatusIdsByEntity = function(Entity)
    return status.GetStatusIdsById(Entity.GetServerId());
end

status.GetStatusInfoById = function(ServerId, IconTheme)

    local allIds = status.GetStatusIdsById(ServerId);
    if (allIds == nil) then
        return nil; -- No status effects for this enemy
    end
    
    local statusInfo = T{};
    for i = 1,#allIds do
        statusInfo[i] = T{};
        statusInfo[i].id = allIds[i];
        statusInfo[i].icon = status.GetIconForStatusId(allIds[i], IconTheme);
        statusInfo[i].tooltip = status.GetTooptipForStatusId(allIds[i]);
    end
    return statusInfo;
end

status.GetStatusInfoByIndex = function(TargetIndex, Theme)
    return status.GetStatusInfoById(AshitaCore:GetMemoryManager():GetEntity():GetServerId(TargetIndex), Theme);
end

status.GetStatusInfoByEntity = function(Entity, Theme)
    return status.GetStatusInfoById(Entity.GetServerId(), Theme);
end

status.GetIconForStatusId = function(StatusId, Theme)
    if (Theme == nil) then
        return icons.get_icon_image(StatusId);
    else
        return icons.get_icon_from_theme(StatusId, Theme);
    end
end

status.GetTooptipForStatusId = function(StatusId)
    if (StatusId == nil or StatusId < 1 or StatusId > 0x3FF or StatusId == 255) then
        return;
    end

    local resMan = AshitaCore:GetResourceManager();
    local info = resMan:GetStatusIconByIndex(StatusId);
    local name = resMan:GetString('buffs.names', StatusId);
    local returnTable = T{ name = nil; description = nil;};
    if (name ~= nil and info ~= nil) then
        returnTable.name = name;
        if (info.Description[1] ~= nil) then
            returnTable.description = info.Description[1];
        end
    end
    return returnTable;
end

status.GetRelevantEnemies = function()
    return tracker.GetRelevantTargets();
end

status.ClearIconCache = function()
    icons.clear_cache();
end

status.GetIconThemePaths = function()
    return icons.get_status_theme_paths();
end

-------------------------------------------------------------------------------
-- Pass through functions for the status table
-------------------------------------------------------------------------------

-- Gets if a status effect is technically a positive status effect
status.GetIsBuff = function(StatusId)
    return table.IsBuff(StatusId);
end

-- Gets if a job is a spellcaster (uses MP) by their job abberviation
status.GetIsSpellcaster = function(JobAbv)
    return table.IsSpellcaster(JobAbv);
end

-- Gets if a pet is a job by by the pet name
status.GetIsJugPet = function(PetName)
    return table.IsJugPet(PetName);
end

-- Get a jobs SP (1, 2 hr) ability name by its job abberviation
status.GetSpAbilityName = function(JobAbv)
    return table.GetSPAbilityName(JobAbv);
end

return status;