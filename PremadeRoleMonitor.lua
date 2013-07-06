--[[
  Copyright 2013 Dan Lynch

  This file is part of Premade Role Monitor.

  Premade Role Monitor is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by the Free
  Software Foundation, either version 3 of the License, or (at your option) any
  later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, see <http://www.gnu.org/licenses>.

  This program is designed specifically to work with the World of Warcraft
  client. Therefore, if you modify this program, or any covered work, by
  linking or combining it with the World of Warcraft client (or a modified
  version of that client), you have permission to convey the resulting work.
--]]

local MAX_ROWS = 25;
local SORT_ORDER = {
    -- a sensible order in which to sort players based on role(s) chosen
    INLINE_TANK_ICON,
    INLINE_TANK_ICON .. INLINE_DAMAGER_ICON,
    INLINE_TANK_ICON .. INLINE_HEALER_ICON .. INLINE_DAMAGER_ICON,
    INLINE_TANK_ICON .. INLINE_HEALER_ICON,
    INLINE_HEALER_ICON,
    INLINE_HEALER_ICON .. INLINE_DAMAGER_ICON,
    INLINE_DAMAGER_ICON,
    ""
};
local PLAYERS_PER_ROLE_LFR = {
    [INLINE_TANK_ICON] = 2,
    [INLINE_HEALER_ICON] = 6,
    [INLINE_DAMAGER_ICON] = 17
};
local TOTAL_PLAYERS_LFR = 25;

local active = false; -- are we currently updating role choices?
local data = {};

local function prepareForReset()
    -- the next role choice we receive will force a reset of the data because
    -- it represents the start of a new role selection process
    active = false;
end

local function redrawFrame()
    if (active) then
        local rowIndex = 1;
        local tankOnlyCount = 0;
        local healerOnlyCount = 0;
        local damagerOnlyCount = 0;
        local nonTankCount = 0;
        local nonHealerCount = 0;
        local nonDamagerCount = 0;
        for i = 1, #SORT_ORDER do
            for name, rolesChosen in pairs(data) do
                if (rolesChosen == SORT_ORDER[i]) then
                    local rowFrame =
                        _G["PremadeRoleMonitorRow" .. rowIndex];

                    rowFrame.name.text:SetText(name);
                    rowFrame.name.name = name;
                    rowFrame.chosenRoles:SetText(rolesChosen);
                    rowFrame:Show();
                    rowIndex = rowIndex + 1;

                    if (rolesChosen ~= "") then
                        if (rolesChosen == INLINE_TANK_ICON) then
                            tankOnlyCount = tankOnlyCount + 1;
                        elseif (rolesChosen == INLINE_HEALER_ICON) then
                            healerOnlyCount = healerOnlyCount + 1;
                        elseif (rolesChosen == INLINE_DAMAGER_ICON) then
                            damagerOnlyCount = damagerOnlyCount + 1;
                        end
                        if (not(string.find(rolesChosen, INLINE_TANK_ICON,
                                1, true))) then
                            nonTankCount = nonTankCount + 1;
                        end
                        if (not(string.find(rolesChosen, INLINE_HEALER_ICON,
                                1, true))) then
                            nonHealerCount = nonHealerCount + 1;
                        end
                        if (not(string.find(rolesChosen, INLINE_DAMAGER_ICON,
                                1, true))) then
                            nonDamagerCount = nonDamagerCount + 1;
                        end
                    end
                end
            end
        end

        if (nonDamagerCount >
            TOTAL_PLAYERS_LFR - PLAYERS_PER_ROLE_LFR[INLINE_DAMAGER_ICON]) then
            PremadeRoleMonitorFrameWarning:SetText(
                "Too many non-" .. INLINE_DAMAGER_ICON);
        end
        if (nonHealerCount >
            TOTAL_PLAYERS_LFR - PLAYERS_PER_ROLE_LFR[INLINE_HEALER_ICON]) then
            PremadeRoleMonitorFrameWarning:SetText(
                "Too many non-" .. INLINE_HEALER_ICON);
        end
        if (nonTankCount >
            TOTAL_PLAYERS_LFR - PLAYERS_PER_ROLE_LFR[INLINE_TANK_ICON]) then
            PremadeRoleMonitorFrameWarning:SetText(
                "Too many non-" .. INLINE_TANK_ICON);
        end

        if (damagerOnlyCount > PLAYERS_PER_ROLE_LFR[INLINE_DAMAGER_ICON]) then
            PremadeRoleMonitorFrameWarning:SetText(
                "Too many " .. INLINE_DAMAGER_ICON .. "-only");
        end
        if (healerOnlyCount > PLAYERS_PER_ROLE_LFR[INLINE_HEALER_ICON]) then
            PremadeRoleMonitorFrameWarning:SetText(
                "Too many " .. INLINE_HEALER_ICON .. "-only");
        end
        if (tankOnlyCount > PLAYERS_PER_ROLE_LFR[INLINE_TANK_ICON]) then
            PremadeRoleMonitorFrameWarning:SetText(
                "Too many " .. INLINE_TANK_ICON .. "-only");
        end

        PremadeRoleMonitorFrame:Show();
    end
end

local function processChatMsgSystem(message)
    if (message == ERR_LFG_ROLE_CHECK_ABORTED) then
        prepareForReset();
    elseif (message == ERR_LFG_ROLE_CHECK_FAILED) then
        prepareForReset();
    elseif (message == ERR_LFG_ROLE_CHECK_FAILED_TIMEOUT) then
        prepareForReset();
    elseif (message == ERR_LFG_ROLE_CHECK_FAILED_NOT_VIABLE) then
        prepareForReset();
    elseif (message == ERR_LFG_JOINED_QUEUE) then
        prepareForReset();
    elseif (message == ERR_LFG_JOINED_RF_QUEUE) then
        prepareForReset();
    elseif (message == ERR_LFG_JOINED_SCENARIO_QUEUE) then
        prepareForReset();
    elseif (message == ERR_LFG_LEFT_QUEUE) then
        prepareForReset();
    elseif (message == ERR_LFG_PROPOSAL_DECLINED_PARTY) then
        prepareForReset();
    elseif (message == ERR_LFG_PROPOSAL_DECLINED_SELF) then
        prepareForReset();
    elseif (message == ERR_LFG_PROPOSAL_FAILED) then
        prepareForReset();
    end
end

local function processGroupRosterUpdate()
    if (active) then
        local numGroupMembers = GetNumGroupMembers();
        if (numGroupMembers > 1) then
            local raidMembers = {};

            -- add all new raid members to the data structure
            for raidIndex = 1, numGroupMembers do
                local name = GetRaidRosterInfo(raidIndex);
                raidMembers[name] = true;
                if (data[name] == nil) then
                    data[name] = "";
                end
            end

            -- remove all former raid members from the data structure
            for name, _ in pairs(data) do
                if (raidMembers[name] == nil) then
                    data[name] = nil;
                end
            end
        else
            -- we are not in a party or raid group
            prepareForReset();
        end
    end
end

local function processRoleCheckRoleChosen(player, isTank, isHealer, isDamage)
    if (active == false) then
        -- this is a new role selection process so reset the data structure
        data = {};
        PremadeRoleMonitorFrameWarning:SetText("");
        active = true;
        processGroupRosterUpdate();
    end
    local rolesChosen = "";
    if (isTank) then
        rolesChosen = rolesChosen .. INLINE_TANK_ICON;
    end
    if (isHealer) then
        rolesChosen = rolesChosen .. INLINE_HEALER_ICON;
    end
    if (isDamage) then
        rolesChosen = rolesChosen .. INLINE_DAMAGER_ICON;
    end

    data[player] = rolesChosen;
end

function PremadeRoleMonitorFrame_OnLoad(self)
    self:RegisterEvent("LFG_ROLE_CHECK_ROLE_CHOSEN");
    self:RegisterEvent("GROUP_ROSTER_UPDATE");
    self:RegisterEvent("CHAT_MSG_SYSTEM");

    local prevRowFrame = PremadeRoleMonitorRow1;
    for i = 2, MAX_ROWS do
        local rowFrame = CreateFrame("FRAME", "PremadeRoleMonitorRow" .. i,
            PremadeRoleMonitorFrame, "PremadeRoleMonitorRowTemplate");
        rowFrame:SetPoint("TOPLEFT", prevRowFrame, "BOTTOMLEFT", 0, 0);
        rowFrame:SetPoint("TOPRIGHT", prevRowFrame, "BOTTOMRIGHT", 0, 0);
        prevRowFrame = rowFrame;
    end

    redrawFrame();
end

function PremadeRoleMonitorFrame_OnEvent(self, event, ...)
    if (event == "LFG_ROLE_CHECK_ROLE_CHOSEN") then
        processRoleCheckRoleChosen(...);
    elseif (event == "GROUP_ROSTER_UPDATE") then
        processGroupRosterUpdate();
    elseif (event == "CHAT_MSG_SYSTEM") then
        processChatMsgSystem(...);
    end

    redrawFrame();
end
