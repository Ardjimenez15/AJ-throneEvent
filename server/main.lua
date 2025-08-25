-- server/main.lua
local isConquestActive, isRegistrationOpen = false, false
local zoneStates, playerFactions, playerLocations = {}, {}, {}
local gameTimer, passivePointTimer, blackoutTimer = 0, 0, 0
local factionPoints, factionCoins, factionCoinRates = {}, {}, {}
local policeStationOwnerFaction, seaportOwnerFaction, hospitalOwnerFaction, towerOwnerFaction = nil, nil, nil, nil
local factionLeaders = {}
local isBlackoutActive = false
local lastGameResults = nil
local playerStats = {} -- [source] = { kills = 0, deaths = 0 }


-- =============================================================================
-- GESTIÓN DE MUERTES Y PUNTOS POR BAJA
-- =============================================================================
AddEventHandler('playerDied', function(player, reason, killer)
    if not isConquestActive then return end
    local victimId = GetPlayerServerId(player)
    
    -- Contar la muerte del jugador
    if playerStats[victimId] then
        playerStats[victimId].deaths = playerStats[victimId].deaths + 1
    end

    if not killer or killer == player then return end
    local killerId = GetPlayerServerId(killer)
    local victimFaction = playerFactions[victimId]
    local killerFaction = playerFactions[killerId]

    if not victimFaction or not killerFaction or victimFaction == killerFaction then return end
    
    -- Contar la baja del asesino
    if playerStats[killerId] then
        playerStats[killerId].kills = playerStats[killerId].kills + 1
    end

    if factionLeaders[victimFaction] and factionLeaders[victimFaction] == victimId then
        factionPoints[killerFaction] = (factionPoints[killerFaction] or 0) + Config.PointsPerLeaderKill
        local victimName, killerName = GetPlayerName(victimId), GetPlayerName(killerId)
        TriggerClientEvent('ox:notify', -1, {
            title = '¡Líder Caído!',
            description = ('%s (%s) ha eliminado al líder de %s, %s. ¡Ganan %d puntos!'):format(killerName, Config.Factions[killerFaction].label, Config.Factions[victimFaction].label, victimName, Config.PointsPerLeaderKill),
            type = 'error', duration = 8000
        })
        PromoteNewLeader(victimFaction)
    else
        factionPoints[killerFaction] = (factionPoints[killerFaction] or 0) + Config.PointsPerKill
        oxlib.notify({ source = killerId, description = ('+ %d Punto por eliminar a un rival'):format(Config.PointsPerKill), type = 'success' })
    end
end)

-- =============================================================================
-- GESTIÓN DEL EVENTO Y COMANDOS
-- =============================================================================
function ResetGameState()
    isConquestActive, isRegistrationOpen, isBlackoutActive = false, false, false
    zoneStates, playerFactions, playerLocations, factionLeaders = {}, {}, {}, {}
    factionPoints, factionCoins, factionCoinRates = {}, {}, {}
    policeStationOwnerFaction, seaportOwnerFaction, hospitalOwnerFaction, towerOwnerFaction = nil, nil, nil, nil
    gameTimer, blackoutTimer, passivePointTimer = 0, 0, 0
    playerStats = {}
    lastGameResults = nil
end

oxlib.registerCommand(Config.AdminCommandOpen, 'admin', function(source)
    if isConquestActive or isRegistrationOpen then return oxlib.notify({ source = source, type = 'error', description = 'Ya hay un registro o una conquista en curso.' }) end
    ResetGameState()
    lastGameResults = nil -- Limpiar el informe de la partida anterior al iniciar un nuevo registro
    isRegistrationOpen = true
    TriggerClientEvent('conquest:createRegistrationZone', -1, Config.RegistrationZone)
    TriggerClientEvent('ox:notify', -1, { title = 'Reclutamiento Abierto', description = '¡Dirígete a la zona de registro para unirte a una facción! Usa /estadoequipos para ver los miembros.', type = 'inform' })
end, { help = 'Abre el registro para el evento.' })

oxlib.registerCommand(Config.AdminCommandStart, 'admin', function(source)
    if not isRegistrationOpen then return oxlib.notify({ source = source, type = 'error', description = ('Debes abrir el registro primero con /%s'):format(Config.AdminCommandOpen) }) end
    
    local memberCounts = {}
    for fKey, _ in pairs(Config.Factions) do memberCounts[fKey] = 0 end
    for _, fKey in pairs(playerFactions) do if memberCounts[fKey] then memberCounts[fKey] = memberCounts[fKey] + 1 end end
    
    local missingFactionsText = {}
    for fKey, count in pairs(memberCounts) do 
        if count < Config.MinPlayersPerFaction then 
            table.insert(missingFactionsText, ('- %s (%d/%d)'):format(Config.Factions[fKey].label, count, Config.MinPlayersPerFaction))
        end 
    end

    if #missingFactionsText > 0 then
        return oxlib.alertDialog({ source = source, header = 'Faltan Jugadores', content = 'No se puede iniciar. Faltan miembros en las siguientes facciones:\n\n' .. table.concat(missingFactionsText, '\n') })
    end

    isRegistrationOpen, isConquestActive = false, true
    gameTimer, passivePointTimer = Config.EventDuration, Config.PassivePointInterval
    for fKey, _ in pairs(Config.Factions) do factionPoints[fKey], factionCoins[fKey], factionCoinRates[fKey] = 0, 0, Config.CoinsPerSecondDefault end
    
    TriggerClientEvent('conquest:removeRegistrationZone', -1)
    for pSource, fKey in pairs(playerFactions) do
        SetPlayerRoutingBucket(pSource, Config.EventDimension)
        TriggerClientEvent('conquest:initializePlayer', pSource, Config.Factions[fKey].baseCoords, Config.EventWeather)
    end
    for zKey, zData in pairs(Config.Zones) do zoneStates[zKey] = { progress = {}, controllingFaction = nil, label = zData.label }; for fKey, _ in pairs(Config.Factions) do zoneStates[zKey].progress[fKey] = 0 end end
    
    AssignInitialLeaders()
    TriggerClientEvent('conquest:start', -1, Config.Zones)
    StartGameLoop()
end, { help = 'Inicia la conquista.' })

oxlib.registerCommand(Config.AdminCommandCancel, 'admin', function(source)
    if not isRegistrationOpen and not isConquestActive then return oxlib.notify({ source = source, type = 'error', description = 'No hay ningún evento activo que cancelar.' }) end
    if isConquestActive then 
        EndConquest() 
        TriggerClientEvent('ox:notify', -1, { title = 'Evento Cancelado', description = 'Un administrador ha finalizado la conquista.', type = 'error' })
    else
        TriggerClientEvent('conquest:removeRegistrationZone', -1)
        ResetGameState()
        TriggerClientEvent('ox:notify', -1, { title = 'Registro Cancelado', type = 'error' })
    end
end, { help = 'Cancela el registro o el evento en curso.' })

-- =============================================================================
-- BUCLE PRINCIPAL DEL JUEGO
-- =============================================================================
function StartGameLoop()
    CreateThread(function()
        local uiUpdateCounter = 5
        while isConquestActive and gameTimer > 0 do
            Wait(1000)
            gameTimer, passivePointTimer = gameTimer - 1, passivePointTimer - 1
            if isBlackoutActive then blackoutTimer = blackoutTimer - 1; if blackoutTimer <= 0 then isBlackoutActive = false; TriggerClientEvent('conquest:endBlackout', -1) end end
            for fKey, rate in pairs(factionCoinRates) do factionCoins[fKey] = (factionCoins[fKey] or 0) + rate end
            if passivePointTimer <= 0 then 
                for _, state in pairs(zoneStates) do 
                    if state.controllingFaction then 
                        factionPoints[state.controllingFaction] = (factionPoints[state.controllingFaction] or 0) + Config.PointsPerControlledZone 
                    end 
                end
                passivePointTimer = Config.PassivePointInterval 
            end
            local playersInZoneByFaction = {}; for zKey, _ in pairs(Config.Zones) do playersInZoneByFaction[zKey] = {}; for fKey, _ in pairs(Config.Factions) do playersInZoneByFaction[zKey][fKey] = 0 end end; for pSource, zKey in pairs(playerLocations) do if zKey and playerFactions[pSource] then playersInZoneByFaction[zKey][playerFactions[pSource]] = playersInZoneByFaction[zKey][playerFactions[pSource]] + 1 end end
            for zKey, state in pairs(zoneStates) do
                if not state.controllingFaction then
                    local dominantFaction, maxPlayers, tie = nil, 0, false; for fKey, count in pairs(playersInZoneByFaction[zKey]) do if count > maxPlayers then maxPlayers, dominantFaction, tie = count, fKey, false elseif count == maxPlayers and maxPlayers > 0 then tie = true end end
                    if dominantFaction and not tie then
                        state.progress[dominantFaction] = state.progress[dominantFaction] + 1
                        if state.progress[dominantFaction] >= Config.CaptureTime then
                            state.controllingFaction = dominantFaction; local zConfig = Config.Zones[zKey]
                            factionPoints[dominantFaction] = (factionPoints[dominantFaction] or 0) + Config.PointsPerCapture
                            local bonusToAdd = Config.CoinsPerZoneBonus; if zConfig.bonusMultiplier then bonusToAdd = bonusToAdd * zConfig.bonusMultiplier end; factionCoinRates[dominantFaction] = (factionCoinRates[dominantFaction] or 0) + bonusToAdd
                            if zConfig.triggersBlackout and not isBlackoutActive then isBlackoutActive, blackoutTimer = true, Config.BlackoutDuration; TriggerClientEvent('conquest:triggerBlackout', -1) end
                            if zKey == 'comisaria' then policeStationOwnerFaction = dominantFaction; TriggerClientEvent('conquest:policeStationCaptured', -1, dominantFaction)
                            elseif zKey == 'puerto' then seaportOwnerFaction = dominantFaction; TriggerClientEvent('conquest:seaportCaptured', -1, dominantFaction)
                            elseif zKey == 'hospital' then hospitalOwnerFaction = dominantFaction; TriggerClientEvent('conquest:hospitalCaptured', -1, dominantFaction)
                            elseif zKey == 'torre' then towerOwnerFaction = dominantFaction; TriggerClientEvent('conquest:towerCaptured', -1, dominantFaction)
                            end; TriggerClientEvent('conquest:zoneCaptured', -1, zKey, dominantFaction, Config.Factions[dominantFaction].label, state.label)
                        end
                    end
                end
            end
            if uiUpdateCounter <= 0 then TriggerClientEvent('conquest:updateScoreUI', -1, factionPoints, factionCoins, gameTimer); uiUpdateCounter = 5 end
        end
        if isConquestActive then EndConquest() end
    end)
end

function EndConquest()
        if not isConquestActive then return end
    
    do
        local finalData = {}
        local zonesByFaction = {}
        for zKey, state in pairs(zoneStates) do if state.controllingFaction then zonesByFaction[state.controllingFaction] = (zonesByFaction[state.controllingFaction] or 0) + 1 end end

        for fKey, data in pairs(Config.Factions) do
            finalData[fKey] = {
                label = data.label, color = data.color,
                points = factionPoints[fKey] or 0, coins = factionCoins[fKey] or 0,
                zonesCaptured = zonesByFaction[fKey] or 0,
                members = {} -- Nueva tabla para las stats de los miembros
            }
        end
        
        -- Poblar la tabla de miembros con sus stats finales
        for source, fKey in pairs(playerFactions) do
            if finalData[fKey] then
                local stats = playerStats[source] or { kills = 0, deaths = 0 }
                table.insert(finalData[fKey].members, {
                    name = GetPlayerName(source),
                    kills = stats.kills,
                    deaths = stats.deaths
                })
            end
        end
        lastGameResults = finalData
    end

    if isBlackoutActive then TriggerClientEvent('conquest:endBlackout', -1) end
    
    local finalPoints = factionPoints
    
    -- << INICIO DE CAMBIOS: Preparar y enviar Webhook >>
    if Config.DiscordWebhookUrl and Config.DiscordWebhookUrl:match("^https://discord.com/api/webhooks") then
        local winnerLabel = 'Nadie'
        local winnerKey = nil
        local maxPoints = -1

        for fKey, points in pairs(factionPoints) do
            if points > maxPoints then
                maxPoints = points
                winnerKey = fKey
                winnerLabel = Config.Factions[fKey].label
            end
        end

        if winnerKey then
            -- Recopilar todos los datos necesarios
            local winnerData = Config.Factions[winnerKey]
            local winnerCoins = factionCoins[winnerKey] or 0
            
            local zonesCaptured = 0
            for _, state in pairs(zoneStates) do
                if state.controllingFaction == winnerKey then
                    zonesCaptured = zonesCaptured + 1
                end
            end

            local members = {}
            for source, fKey in pairs(playerFactions) do
                if fKey == winnerKey then
                    table.insert(members, GetPlayerName(source))
                end
            end
            local memberList = #members > 0 and table.concat(members, '\n') or 'Sin miembros'

            -- Construir el mensaje embed
            local colorHex = winnerData.color:gsub("#", "")
            local colorDecimal = tonumber("0x" .. colorHex)

            local embed = {
                {
                    title = "🏆 Resultados de la Conquista 🏆",
                    description = "La facción **" .. winnerLabel .. "** ha ganado la batalla!",
                    color = colorDecimal,
                    fields = {
                        { name = 'Puntos Finales', value = '`' .. maxPoints .. '`', inline = true },
                        { name = 'Monedas Acumuladas', value = '`' .. winnerCoins .. '` 🪙', inline = true },
                        { name = 'Zonas Controladas', value = '`' .. zonesCaptured .. '`', inline = true },
                        { name = '🛡️ Miembros Victoriosos', value = memberList }
                    },
                    footer = {
                        text = GetCurrentResourceName() .. " | " .. os.date('%Y-%m-%d %H:%M:%S')
                    }
                }
            }

            -- Enviar el webhook
            PerformHttpRequest(Config.DiscordWebhookUrl, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
        end
    end
    for pSource, _ in pairs(playerFactions) do
        SetPlayerRoutingBucket(pSource, 0)
        TriggerClientEvent('conquest:resetPlayerState', pSource)
    end
    TriggerClientEvent('conquest:end', -1, finalPoints)
    ResetGameState()
end

-- =============================================================================
-- NUEVO COMANDO DE INFORME
-- =============================================================================
oxlib.registerCommand(Config.AdminReportCommand, 'admin', function(source)
    if not lastGameResults then
        return oxlib.notify({ source = source, type = 'error', description = 'No hay datos de la última partida para reportar.' })
    end
    
    if not Config.DiscordWebhookUrl or not Config.DiscordWebhookUrl:match("^https://discord.com/api/webhooks") then
        return oxlib.notify({ source = source, type = 'error', description = 'La URL del webhook de Discord no está configurada correctamente.' })
    end

    local embedFields = {}
    for fKey, data in pairs(lastGameResults) do
        table.insert(embedFields, {
            name = data.label,
            value = ('🏆 Puntos: **%d**\n🪙 Monedas: **%d**\n🗺️ Zonas: **%d**'):format(data.points, data.coins, data.zonesCaptured),
            inline = false -- Poner false para que cada facción tenga su propio bloque
        })
    end

    local embed = {
        {
            title = "📜 Reporte Final de la Conquista 📜",
            description = "A continuación se muestra un resumen del rendimiento de cada facción en la última partida.",
            color = 15844367, -- Color dorado
            fields = embedFields,
            footer = {
                text = "Informe generado por " .. GetPlayerName(source)
            }
        }
    }
    
    PerformHttpRequest(Config.DiscordWebhookUrl, function(err, text, headers) end, 'POST', json.encode({embeds = embed, username = "Reportero de Conquista"}), { ['Content-Type'] = 'application/json' })

    oxlib.notify({ source = source, type = 'success', description = 'El informe de la partida ha sido enviado al canal de Discord.' })

end, { help = 'Envía un resumen completo de la última partida al webhook de Discord.' })

-- =============================================================================
-- NUEVO COMANDO DE INFORME DE JUGADORES
-- =============================================================================
oxlib.registerCommand(Config.AdminPlayerReportCommand, 'admin', function(source)
    if not lastGameResults then
        return oxlib.notify({ source = source, type = 'error', description = 'No hay datos de la última partida para reportar.' })
    end
    
    if not Config.DiscordWebhookUrl or not Config.DiscordWebhookUrl:match("^https://discord.com/api/webhooks") then
        return oxlib.notify({ source = source, type = 'error', description = 'La URL del webhook de Discord no está configurada.' })
    end

    local embedFields = {}
    for fKey, data in pairs(lastGameResults) do
        local memberStatsString = ""
        if #data.members > 0 then
            -- Ordenar a los miembros por kills (de mayor a menor)
            table.sort(data.members, function(a, b) return a.kills > b.kills end)

            for _, memberData in ipairs(data.members) do
                memberStatsString = memberStatsString .. string.format("`%s` - **K:** %d / **D:** %d\n", memberData.name, memberData.kills, memberData.deaths)
            end
        else
            memberStatsString = "_Sin participantes_"
        end

        -- Prevenir que el campo exceda el límite de caracteres de Discord
        if string.len(memberStatsString) > 1024 then
            memberStatsString = string.sub(memberStatsString, 1, 1020) .. "\n..."
        end

        table.insert(embedFields, {
            name = data.label,
            value = memberStatsString,
            inline = false
        })
    end

    local embed = {
        {
            title = "📊 Reporte de Jugadores de la Conquista 📊",
            description = "Estadísticas de Kills (K) y Muertes (D) para cada participante, ordenados por Kills.",
            color = 3447003, -- Color azul claro
            fields = embedFields,
            footer = { text = "Informe generado por " .. GetPlayerName(source) }
        }
    }
    
    PerformHttpRequest(Config.DiscordWebhookUrl, function(err, text, headers) end, 'POST', json.encode({embeds = embed, username = "Analista de Batalla"}), { ['Content-Type'] = 'application/json' })

    oxlib.notify({ source = source, type = 'success', description = 'El informe de jugadores ha sido enviado al canal de Discord.' })

end, { help = 'Envía un resumen de K/D de todos los jugadores al webhook.' })

-- =============================================================================
-- GESTIÓN DE LÍDERES
-- =============================================================================
function AssignInitialLeaders()
    local playersByFaction = {}; for s, f in pairs(playerFactions) do if not playersByFaction[f] then playersByFaction[f] = {} end; table.insert(playersByFaction[f], s) end
    for f, p in pairs(playersByFaction) do if #p > 0 then factionLeaders[f] = p[math.random(#p)] end end
    TriggerClientEvent('conquest:updateLeaders', -1, factionLeaders)
end

function PromoteNewLeader(factionKey)
    local remaining = {}; for s, f in pairs(playerFactions) do if f == factionKey then table.insert(remaining, s) end end
    if #remaining > 0 then factionLeaders[factionKey] = remaining[math.random(#remaining)] else factionLeaders[factionKey] = nil end
    TriggerClientEvent('conquest:updateLeaders', -1, factionLeaders)
end

-- =============================================================================
-- EVENTOS DE RED (JUGADORES Y COMPRAS)
-- =============================================================================
RegisterNetEvent('conquest:joinFaction', function(factionKey)
    local source = source
    if not isRegistrationOpen or playerFactions[source] or not Config.Factions[factionKey] then return end
    playerFactions[source] = factionKey
    
    -- Inicializar las estadísticas para el nuevo jugador
    playerStats[source] = { kills = 0, deaths = 0 }

    oxlib.notify({source = source, description = 'Te has unido a ' .. Config.Factions[factionKey].label})
end)

RegisterNetEvent('conquest:updatePlayerLocation', function(zoneKey, inZone)
    local source = source
    playerLocations[source] = inZone and zoneKey or nil
end)

function HandlePurchase(source, condition, cost, onSuccess, onError)
    local factionKey = playerFactions[source]
    if not factionKey then return end

    if condition() then
        if factionCoins[factionKey] >= cost then
            factionCoins[factionKey] = factionCoins[factionKey] - cost
            onSuccess()
        else
            oxlib.notify({source=source, type='error', description='Tu facción no tiene suficientes monedas.'})
        end
    else
        oxlib.notify({source=source, type='error', description='No tienes acceso a este vendedor.'})
    end
end

RegisterNetEvent('conquest:requestVehicleSpawn', function() local s = source; local cfg = Config.Factions[playerFactions[s]].vehicleSpawner; HandlePurchase(s, function() return true end, cfg.cost, function() TriggerClientEvent('conquest:spawnFactionVehicle', s, playerFactions[s]) end) end)
RegisterNetEvent('conquest:requestWeaponPurchase', function() local s = source; local cfg = Config.Factions[playerFactions[s]].weaponVendor; HandlePurchase(s, function() return true end, cfg.cost, function() GiveWeaponToPed(GetPlayerPed(s), GetHashKey(cfg.weapon), cfg.ammo, false, true) end) end)
RegisterNetEvent('conquest:requestAmmoPurchase', function() local s = source; local cfg = Config.Factions[playerFactions[s]].weaponVendor.ammoPack; HandlePurchase(s, function() return true end, cfg.cost, function() AddAmmoToPedByType(GetPlayerPed(s), GetHashKey(cfg.type), cfg.quantity) end) end)
RegisterNetEvent('conquest:requestSpecialVehiclePurchase', function() local s=source; local cfg = Config.Zones.comisaria.specialVendors.vehicleSpawner; HandlePurchase(s, function() return playerFactions[s] == policeStationOwnerFaction end, cfg.cost, function() TriggerClientEvent('conquest:spawnFactionVehicle', s, 'comisaria_special') end) end)
RegisterNetEvent('conquest:requestSpecialWeaponPurchase', function() local s=source; local cfg = Config.Zones.comisaria.specialVendors.weaponVendor; HandlePurchase(s, function() return playerFactions[s] == policeStationOwnerFaction end, cfg.cost, function() GiveWeaponToPed(GetPlayerPed(s), GetHashKey(cfg.weapon), cfg.ammo, false, true) end) end)
RegisterNetEvent('conquest:requestSpecialAmmoPurchase', function() local s=source; local cfg = Config.Zones.comisaria.specialVendors.weaponVendor.ammoPack; HandlePurchase(s, function() return playerFactions[s] == policeStationOwnerFaction end, cfg.cost, function() AddAmmoToPedByType(GetPlayerPed(s), GetHashKey(cfg.type), cfg.quantity) end) end)
RegisterNetEvent('conquest:requestSpecialHeliPurchase', function() local s=source; local cfg = Config.Zones.puerto.specialVendors.helicopterSpawner; HandlePurchase(s, function() return playerFactions[s] == seaportOwnerFaction end, cfg.cost, function() TriggerClientEvent('conquest:spawnFactionVehicle', s, 'seaport_heli') end) end)
RegisterNetEvent('conquest:requestSpecialBoatPurchase', function() local s=source; local cfg = Config.Zones.puerto.specialVendors.boatSpawner; HandlePurchase(s, function() return playerFactions[s] == seaportOwnerFaction end, cfg.cost, function() TriggerClientEvent('conquest:spawnFactionVehicle', s, 'seaport_boat') end) end)
RegisterNetEvent('conquest:requestSpecialArmorPurchase', function() local s=source; local cfg = Config.Zones.torre.specialVendors.armorVendor; HandlePurchase(s, function() return playerFactions[s] == towerOwnerFaction end, cfg.cost, function() SetPedArmour(GetPlayerPed(s), 100) end) end)

-- =============================================================================
-- COMANDOS DE ESTADO
-- =============================================================================
oxlib.registerCommand(Config.PlayerStatusCommand, false, function(source)
    if not isConquestActive then return oxlib.notify({ source = source, description = 'La conquista no está activa.', type = 'error' }) end
    local factionKey = playerFactions[source]
    if not factionKey then return oxlib.notify({ source = source, description = 'No perteneces a ninguna facción en este evento.', type = 'warn' }) end
    oxlib.alertDialog({ source = source, header = 'Estado de tu Facción: ' .. Config.Factions[factionKey].label, content = ('- Puntos: **%d**\n- Monedas: **%d 🪙**'):format(factionPoints[factionKey] or 0, factionCoins[factionKey] or 0) })
end, { help = 'Muestra los puntos y monedas de tu facción.' })

oxlib.registerCommand(Config.AdminStatusCommand, 'admin', function(source)
    if not isConquestActive and not isRegistrationOpen then return oxlib.notify({ source = source, description = 'Ningún evento está activo.', type = 'error' }) end
    local memberCounts = {}; for fKey, _ in pairs(Config.Factions) do memberCounts[fKey] = 0 end; for _, fKey in pairs(playerFactions) do if memberCounts[fKey] then memberCounts[fKey] = memberCounts[fKey] + 1 end end
    local content = 'Resumen completo:\n\n'; for key, data in pairs(Config.Factions) do
        content = content .. ('**%s**\n- Puntos: `%d`\n- Monedas: `%d 🪙`\n- Miembros: `%d`\n\n'):format(data.label, factionPoints[key] or 0, factionCoins[key] or 0, memberCounts[key] or 0)
    end
    oxlib.alertDialog({ source = source, header = 'Estado General del Evento', content = content })
end, { help = 'Muestra un resumen completo de todas las facciones.' })

AddEventHandler('playerDropped', function(reason)
    local source = source
    if playerFactions[source] then
        if isRegistrationOpen then
            -- ... (Notificar que un jugador se fue durante el registro)
        elseif isConquestActive then
            local factionKey = playerFactions[source]
            if factionLeaders[factionKey] and factionLeaders[factionKey] == source then
                PromoteNewLeader(factionKey)
            end
        end
        playerFactions[source] = nil
        playerLocations[source] = nil
    end
end)
