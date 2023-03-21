
--[[
* Copyright (c) 2023 tirem [github.com/tirem] under the GPL-3.0 license
]]--
  
require('common');
local function GetLibPath()
    return debug.getinfo(2, "S").source:sub(2);
end

-- Setup globals for addons and rest of lib to access
local libPath = GetLibPath();
statusIcons = dofile(string.gsub(libPath, 'status.lua', 'statusicons.lua'));
statusTracker = dofile(string.gsub(libPath, 'status.lua', 'statustracker.lua'));
statusTable = dofile(string.gsub(libPath, 'status.lua', 'statustable.lua'));
statusHelpers = dofile(string.gsub(libPath, 'status.lua', 'statushelpers.lua'));

local status = T{};

status.GetStatusIdsById = function(ServerId)
    return statusTracker.GetStatusEffects(ServerId);
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
        return statusIcons.get_icon_image(StatusId);
    else
        return statusIcons.get_icon_from_theme(StatusId, Theme);
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
    return statusTracker.GetRelevantTargets();
end

status.ClearIconCache = function()
    statusIcons.clear_cache();
end

status.GetIconThemePaths = function()
    return statusIcons.get_status_theme_paths();
end

return status;