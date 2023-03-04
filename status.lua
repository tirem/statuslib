
--[[
* Copyright (c) 2023 tirem [github.com/tirem] under the GPL-3.0 license
]]--

require('common');

local icons = require('status.statusicons');
local tracker = require('status.statustracker');

local status = T{};

status.helpers = require('status.statushelpers');

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

return status;