--[[
* Copyright (c) 2023 tirem [github.com/tirem] under the GPL-3.0 license
]]--

require('common');
require('helpers');
local statusTable = require('status.statustable');

-- TO DO: Audit these messages for which ones are actually useful
local statusOnMes = T{160, 164, 166, 186, 194, 203, 205, 230, 236, 266, 267, 268, 269, 237, 271, 272, 277, 278, 279, 280, 319, 320, 375, 412, 645, 754, 755, 804};
local statusOffMes = T{206, 64, 159, 168, 204, 206, 321, 322, 341, 342, 343, 344, 350, 378, 531, 647, 805, 806};
local deathMes = T{6, 20, 97, 113, 406, 605, 646};
local spellDamageMes = T{2, 252, 264, 265};

local function GetPartyMemberIds()
	local partyMemberIds = T{};
	local party = AshitaCore:GetMemoryManager():GetParty();
	for i = 0, 5 do
		if (party:GetMemberIsActive(i) == 1) then
			table.insert(partyMemberIds, party:GetMemberServerId(i));
		end
	end
	return partyMemberIds;
end

local function GetIsMob(index)
	return (bit.band(AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(index), 0x10) ~= 0);
end

local function GetIsValidMob(mobIdx)
    local renderflags = AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags0(mobIdx);
    if bit.band(renderflags, 0x200) ~= 0x200 or bit.band(renderflags, 0x4000) ~= 0 then
        return false;
    end
	return true;
end


local function GetIndexFromId(id)
    local entMgr = AshitaCore:GetMemoryManager():GetEntity();
    
    --Shortcut for monsters/static npcs..
    if (bit.band(id, 0x1000000) ~= 0) then
        local index = bit.band(id, 0xFFF);
        if (index >= 0x900) then
            index = index - 0x100;
        end

        if (index < 0x900) and (entMgr:GetServerId(index) == id) then
            return index;
        end
    end

    for i = 1,0x8FF do
        if entMgr:GetServerId(i) == id then
            return i;
        end
    end

    return 0;
end

local function ParseActionPacket(e)
    local bitData;
    local bitOffset;
    local maxLength = e.size * 8;
    local function UnpackBits(length)
        if ((bitOffset + length) >= maxLength) then
            maxLength = 0; --Using this as a flag since any malformed fields mean the data is trash anyway.
            return 0;
        end
        local value = ashita.bits.unpack_be(bitData, 0, bitOffset, length);
        bitOffset = bitOffset + length;
        return value;
    end

    local actionPacket = T{};
    bitData = e.data_raw;
    bitOffset = 40;
    actionPacket.UserId = UnpackBits(32);
    actionPacket.UserIndex = GetIndexFromId(actionPacket.UserId); --Many implementations of this exist, or you can comment it out if not needed.  It can be costly.
    local targetCount = UnpackBits(6);
    --Unknown 4 bits
    bitOffset = bitOffset + 4;
    actionPacket.Type = UnpackBits(4);
    -- Bandaid fix until we have more flexible packet parsing
    if actionPacket.Type == 8 or actionPacket.Type == 9 then
        actionPacket.Param = UnpackBits(16);
        actionPacket.SpellGroup = UnpackBits(16);
    else
        -- Not every action packet has the same data at the same offsets so we just skip this for now
        actionPacket.Param = UnpackBits(32);
    end

    actionPacket.Recast = UnpackBits(32);

    actionPacket.Targets = T{};
    if (targetCount > 0) then
        for i = 1,targetCount do
            local target = T{};
            target.Id = UnpackBits(32);
            local actionCount = UnpackBits(4);
            target.Actions = T{};
            if (actionCount == 0) then
                break;
            else
                for j = 1,actionCount do
                    local action = {};
                    action.Reaction = UnpackBits(5);
                    action.Animation = UnpackBits(12);
                    action.SpecialEffect = UnpackBits(7);
                    action.Knockback = UnpackBits(3);
                    action.Param = UnpackBits(17);
                    action.Message = UnpackBits(10);
                    action.Flags = UnpackBits(31);

                    local hasAdditionalEffect = (UnpackBits(1) == 1);
                    if hasAdditionalEffect then
                        local additionalEffect = {};
                        additionalEffect.Damage = UnpackBits(10);
                        additionalEffect.Param = UnpackBits(17);
                        additionalEffect.Message = UnpackBits(10);
                        action.AdditionalEffect = additionalEffect;
                    end

                    local hasSpikesEffect = (UnpackBits(1) == 1);
                    if hasSpikesEffect then
                        local spikesEffect = {};
                        spikesEffect.Damage = UnpackBits(10);
                        spikesEffect.Param = UnpackBits(14);
                        spikesEffect.Message = UnpackBits(10);
                        action.SpikesEffect = spikesEffect;
                    end

                    target.Actions:append(action);
                end
            end
            actionPacket.Targets:append(target);
        end
    end

    if  (maxLength ~= 0) and (#actionPacket.Targets > 0) then
        return actionPacket;
    end
end

local function ParseMobUpdatePacket(e)
	if (e.id == 0x00E) then
		local mobPacket = T{};
		mobPacket.monsterId = struct.unpack('L', e.data, 0x04 + 1);
		mobPacket.monsterIndex = struct.unpack('H', e.data, 0x08 + 1);
		mobPacket.updateFlags = struct.unpack('B', e.data, 0x0A + 1);
		if (bit.band(mobPacket.updateFlags, 0x02) == 0x02) then
			mobPacket.newClaimId = struct.unpack('L', e.data, 0x2C + 1);
		end
		return mobPacket;
	end
end

local function ParseMessagePacket(e)
    local basic = {
        sender     = struct.unpack('i4', e, 0x04 + 1),
        target     = struct.unpack('i4', e, 0x08 + 1),
        param      = struct.unpack('i4', e, 0x0C + 1),
        value      = struct.unpack('i4', e, 0x10 + 1),
        sender_tgt = struct.unpack('i2', e, 0x14 + 1),
        target_tgt = struct.unpack('i2', e, 0x16 + 1),
        message    = struct.unpack('i2', e, 0x18 + 1),
    }
    return basic
end

-------------------------------------------------------------------------------
-- exported functions
-------------------------------------------------------------------------------

local statusTracker = { 
    trackedEntities = T{}; -- entites by serverId that we are tracking buffs and debuffs on
    relevantTargets = T{}; -- targets by targetIndex that are relevant to the player
};

-- if a mob updates its claimid to be us or a party member add it to the list
statusTracker.HandleMobUpdatePacket = function(e)
    local mobUpdate = ParseMobUpdatePacket(e);
	if (mobUpdate == nil) then 
		return; 
	end
    if (GetIsValidMob(mobUpdate.monsterIndex)) then
        if (mobUpdate.newClaimId ~= nil) then	
            local partyMemberIds = GetPartyMemberIds();
            if ((partyMemberIds:contains(mobUpdate.newClaimId))) then
                statusTracker.relevantTargets[mobUpdate.monsterIndex] = 1;
            end
        end
    else
        statusTracker.relevantTargets[mobUpdate.monsterIndex] = nil; -- Clear non valid mobs that have received an update
    end
end

statusTracker.HandleActionPacket = function(e)

    local action = ParseActionPacket(e);
    if (action == nil) then
        return;
    end

    local relevantTarget = GetIsMob(action.UserIndex) and GetIsValidMob(action.UserIndex);

    local now = os.time()

    local partyMemberIds = GetPartyMemberIds();
    for _, target in pairs(action.Targets) do
        -- Update our relvant enemies first
        if (relevantTarget and partyMemberIds:contains(target.Id)) then
            statusTracker.relevantTargets[action.UserIndex] = 1;
        end
        for _, ability in pairs(target.Actions) do
            -- Set up our state
            local spell = action.Param
            local message = ability.Message
            if (statusTracker.trackedEntities[target.Id] == nil) then
                statusTracker.trackedEntities[target.Id] = T{};
            end
            
            -- Bio and Dia
            if action.Type == 4 and spellDamageMes:contains(message) then
                local expiry = nil

                if spell == 23 or spell == 33 or spell == 230 then
                    expiry = now + 60
                elseif spell == 24 or spell == 231 then
                    expiry = now + 120
                elseif spell == 25 or spell == 232 then
                    expiry = now + 150
                end

                if spell == 23 or spell == 24 or spell == 25 or spell == 33 then
                    statusTracker.trackedEntities[target.Id][134] = expiry
                    statusTracker.trackedEntities[target.Id][135] = nil
                elseif spell == 230 or spell == 231 or spell == 232 then
                    statusTracker.trackedEntities[target.Id][134] = nil
                    statusTracker.trackedEntities[target.Id][135] = expiry
                end

            elseif statusOnMes:contains(message) then
                -- Regular debuffs
                local buffId = ability.Param or (action.Type == 4 and statusTable.GetBuffIdBySpellId(spell) or nil);
                if (buffId == nil) then
                    return
                end

                if spell == 58 or spell == 80 then -- para/para2
                    statusTracker.trackedEntities[target.Id][buffId] = now + 120
                elseif spell == 56 or spell == 79 then -- slow/slow2
                    statusTracker.trackedEntities[target.Id][buffId] = now + 180
                elseif spell == 216 then -- gravity
                    statusTracker.trackedEntities[target.Id][buffId] = now + 120
                elseif spell == 254 or spell == 276 then -- blind/blind2
                    statusTracker.trackedEntities[target.Id][buffId] = now + 180
                elseif spell == 59 or spell == 359 then -- silence/ga
                    statusTracker.trackedEntities[target.Id][buffId] = now + 120
                elseif spell == 253 or spell == 259 or spell == 273 or spell == 274 then -- sleep/2/ga/2
                    statusTracker.trackedEntities[target.Id][buffId] = now + 90
                elseif spell == 258 or spell == 362 then -- bind
                    statusTracker.trackedEntities[target.Id][buffId] = now + 60
                elseif spell == 252 then -- stun
                    statusTracker.trackedEntities[target.Id][buffId] = now + 5
                elseif spell <= 229 and spell >= 220 then -- poison/2
                    statusTracker.trackedEntities[target.Id][buffId] = now + 120
                -- Elemental debuffs
                elseif spell == 239 then -- shock
                    statusTracker.trackedEntities[target.Id][buffId] = now + 120
                elseif spell == 238 then -- rasp
                    statusTracker.trackedEntities[target.Id][buffId] = now + 120
                elseif spell == 237 then -- choke
                    statusTracker.trackedEntities[target.Id][buffId] = now + 120
                elseif spell == 236 then -- frost
                    statusTracker.trackedEntities[target.Id][buffId] = now + 120
                elseif spell == 235 then -- burn
                    statusTracker.trackedEntities[target.Id][buffId] = now + 120
                elseif spell == 240 then -- drown
                    statusTracker.trackedEntities[target.Id][buffId] = now + 120
                else                                        -- Handle unknown status effect @ 5 minutes
                    statusTracker.trackedEntities[target.Id][buffId] = now + 300;
                end
            end
        end
    end
end

local ptrPartyBuffs = ashita.memory.find('FFXiMain.dll', 0, 'B93C0000008D7004BF????????F3A5', 9, 0);
ptrPartyBuffs = ashita.memory.read_uint32(ptrPartyBuffs);

-- Call once at plugin load and keep reference to table
statusTracker.ReadPartyBuffsFromMemory = function()
    local ptrPartyBuffs = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('party.statusicons'));
    local partyBuffTable = {};
    for memberIndex = 0,4 do
        local memberPtr = ptrPartyBuffs + (0x30 * memberIndex);
        local playerId = ashita.memory.read_uint32(memberPtr);
        if (playerId ~= 0) then
            local buffs = {};
            local empty = false;
            for buffIndex = 0,31 do
                if empty then
                    buffs[buffIndex + 1] = -1;
                else
                    local highBits = ashita.memory.read_uint8(memberPtr + 8 + (math.floor(buffIndex / 4)));
                    local fMod = math.fmod(buffIndex, 4) * 2;
                    highBits = bit.lshift(bit.band(bit.rshift(highBits, fMod), 0x03), 8);
                    local lowBits = ashita.memory.read_uint8(memberPtr + 16 + buffIndex);
                    local buff = highBits + lowBits;
                    if buff == 255 then
                        empty = true;
                        buffs[buffIndex + 1] = -1;
                    else
                        buffs[buffIndex + 1] = buff;
                    end
                end
            end
            partyBuffTable[playerId] = buffs;
        end
    end
    return partyBuffTable;
end

statusTracker.partyBuffs = statusTracker.ReadPartyBuffsFromMemory();

--Call with incoming packet 0x076
statusTracker.HandlePartyUpdatePacket = function(e)
    local partyBuffTable = {};
    for i = 0,4 do
        local memberOffset = 0x04 + (0x30 * i) + 1;
        local memberId = struct.unpack('L', e.data, memberOffset);
        if memberId > 0 then
            local buffs = {};
            local empty = false;
            for j = 0,31 do
                if empty then
                    buffs[j + 1] = -1;
                else
                    --This is at offset 8 from member start.. memberoffset is using +1 for the lua struct.unpacks
                    local highBits = bit.lshift(ashita.bits.unpack_be(e.data_raw, memberOffset + 7, j * 2, 2), 8);
                    local lowBits = struct.unpack('B', e.data, memberOffset + 0x10 + j);
                    local buff = highBits + lowBits;
                    if (buff == 255) then
                        buffs[j + 1] = -1;
                        empty = true;
                    else
                        buffs[j + 1] = buff;
                    end
                end
            end
            partyBuffTable[memberId] = buffs;
        end
    end
    statusTracker.partyBuffs =  partyBuffTable;
end


statusTracker.HandleClearMessage = function(e)

    local parsedPacket = ParseMessagePacket(e.data)
    if (parsedPacket == nil) then
        return;
    end

        -- if we're tracking a mob that dies, reset its status
    if deathMes:contains(parsedPacket.message) and statusTracker.trackedEntities[parsedPacket.target] then
        statusTracker.trackedEntities[parsedPacket.target] = nil
    elseif statusOffMes:contains(parsedPacket.message) then
        if statusTracker.trackedEntities[parsedPacket.target] == nil then
            return
        end

        -- Clear the buffid that just wore off
        if (e.param ~= nil) then
            statusTracker.trackedEntities[parsedPacket.target][parsedPacket.param] = nil;
        end
    end
end

statusTracker.GetStatusEffects = function(serverId)

    -- If this is just the player return the buffs in memory
	if (serverId == AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0)) then
        return AshitaCore:GetMemoryManager():GetPlayer():GetBuffs();
    end

    -- If this is a party member just return the party member
    if (GetPartyMemberIds():contains(serverId)) then
        return statusTracker.partyBuffs[serverId];
    end

    -- Collect our manually tracked entities if it's neither of those
    if (statusTracker.trackedEntities[serverId] == nil) then
        return nil;
    end
    local returnTable = {};
    for k,v in pairs(statusTracker.trackedEntities[serverId]) do
        if (v ~= 0 and v > os.time()) then
            table.insert(returnTable, k);
        else
            statusTracker.trackedEntities[serverId][k] = nil; -- Clear this entry if it's not valid
        end
    end
    return returnTable;
end

statusTracker.GetRelevantTargets = function()
    return statusTracker.relevantTargets;
end


-- The usual packet event doesn't register in libs but this __settings one does. Feels bad.
ashita.events.register('packet_in', '__status_packet_in_cb', function (e)
    
	if (e.id == 0x076) then
		statusTracker.HandlePartyUpdatePacket(e);
    elseif (e.id == 0x00A) then -- Clear everything on zone
        statusTracker.trackedEntities = T{};
        statusTracker.relevantTargets = T{};
	elseif (e.id == 0x0029) then
		statusTracker.HandleClearMessage(e);
    elseif (e.id == 0x0028) then
        statusTracker.HandleActionPacket(e);
    elseif (e.id == 0x00E) then
        statusTracker.HandleMobUpdatePacket(e);
    end
end);

return statusTracker;