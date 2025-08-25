-- client/main.lua
local isConquestActive, hasJoinedFaction, isPlayerDead, hasRespawnBuff, amILeader = false, false, false, false, false
local playerFaction = nil
local activeZones, activeBlips, leaderBlips = {}, {}, {}
local registrationZone, registrationBlip, vehicleTargetZone, weaponVendorPed = nil, nil, nil, nil
local specialVehicleTargetZone, specialWeaponVendorPed, specialHeliTargetZone, specialBoatTargetZone, specialArmorVendorPed = nil, nil, nil, nil, nil
local currentLeaders = {}

-- =============================================================================
-- INICIO Y FIN DEL EVENTO
-- =============================================================================
RegisterNetEvent('conquest:start', function(allZonesData)
    isConquestActive = true
    CleanUp(true)
    oxlib.showTextUI('', { position = 'top-center' })
    for zKey, zData in pairs(allZonesData) do
        local blip = AddBlipForCoord(zData.coords)
        SetBlipSprite(blip, zData.blip.sprite)
        SetBlipColour(blip, zData.blip.color)
        SetBlipScale(blip, zData.blip.scale)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(zData.blip.text)
        EndTextCommandSetBlipName(blip)
        activeBlips[zKey] = blip
        activeZones[zKey] = oxlib.createZone({
            center = zData.coords,
            radius = zData.radius,
            onEnter = function() TriggerServerEvent('conquest:updatePlayerLocation', zKey, true) end,
            onExit = function() TriggerServerEvent('conquest:updatePlayerLocation', zKey, false) end
        })
    end
    CreateThread(DeathHandlerLoop)
    CreateThread(LeaderBlipLoop)
end)

RegisterNetEvent('conquest:end', function(finalPoints)
    local winner, maxPoints = 'Nadie', 0
    local description = 'Puntuación Final:\n'
    for label, total in pairs(finalPoints) do
        description = description .. ('- %s: %d Puntos\n'):format(label, total)
        if total > maxPoints then maxPoints, winner = total, label end
    end
    oxlib.alertDialog({ header = '¡La Conquista ha Terminado!', content = description .. ('\n**Ganador: %s**'):format(winner), type = 'inform' })
    CleanUp()
end)

function CleanUp(keepFactionStatus)
    isConquestActive = false
    oxlib.hideTextUI()
    SetArtificialLightsState(false)
    for _, z in pairs(activeZones) do if z and z.remove then z:remove() end end; activeZones = {}
    for _, b in pairs(activeBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end; activeBlips = {}
    if registrationZone then registrationZone:remove() end; registrationZone = nil
    if registrationBlip and DoesBlipExist(registrationBlip) then RemoveBlip(registrationBlip) end; registrationBlip = nil
    if vehicleTargetZone then exports.ox_target:removeZone(vehicleTargetZone) end; vehicleTargetZone = nil
    if weaponVendorPed and DoesEntityExist(weaponVendorPed) then DeleteEntity(weaponVendorPed) end; weaponVendorPed = nil
    if specialVehicleTargetZone then exports.ox_target:removeZone(specialVehicleTargetZone) end; specialVehicleTargetZone = nil
    if specialWeaponVendorPed and DoesEntityExist(specialWeaponVendorPed) then DeleteEntity(specialWeaponVendorPed) end; specialWeaponVendorPed = nil
    if specialHeliTargetZone then exports.ox_target:removeZone(specialHeliTargetZone) end; specialHeliTargetZone = nil
    if specialBoatTargetZone then exports.ox_target:removeZone(specialBoatTargetZone) end; specialBoatTargetZone = nil
    if specialArmorVendorPed and DoesEntityExist(specialArmorVendorPed) then DeleteEntity(specialArmorVendorPed) end; specialArmorVendorPed = nil
    for _, b in pairs(leaderBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end; leaderBlips, currentLeaders, amILeader = {}, {}, false
    isPlayerDead, hasRespawnBuff = false, false
    if not keepFactionStatus then hasJoinedFaction, playerFaction = false, nil end
end

-- =============================================================================
-- GESTIÓN DEL JUGADOR Y REGISTRO
-- =============================================================================
RegisterNetEvent('conquest:initializePlayer', function(baseCoords, weatherType)
    SetEntityCoords(PlayerPedId(), baseCoords.x, baseCoords.y, baseCoords.z, false, false, false, true)
    SetWeatherTypePersist(weatherType); SetWeatherTypeNowPersist(weatherType)
    CreateVehicleSpawnerTarget()
    CreateWeaponVendor()
end)

RegisterNetEvent('conquest:resetPlayerState', function() ClearWeatherTypeOverride() end)

RegisterNetEvent('conquest:createRegistrationZone', function(zoneData)
    if registrationZone then registrationZone:remove() end; if registrationBlip then RemoveBlip(registrationBlip) end
    registrationBlip = AddBlipForCoord(zoneData.coords); SetBlipSprite(registrationBlip, zoneData.blip.sprite); SetBlipColour(registrationBlip, zoneData.blip.color); SetBlipScale(registrationBlip, zoneData.blip.scale); BeginTextCommandSetBlipName("STRING"); AddTextComponentString(zoneData.blip.text); EndTextCommandSetBlipName(registrationBlip)
    registrationZone = oxlib.createZone({ center = zoneData.coords, radius = zoneData.radius, onEnter = function() if not hasJoinedFaction then OpenFactionSelectMenu() end end })
end)

RegisterNetEvent('conquest:removeRegistrationZone', function()
    if registrationZone then registrationZone:remove(); registrationZone = nil end
    if registrationBlip then RemoveBlip(registrationBlip); registrationBlip = nil end
end)

function OpenFactionSelectMenu()
    if hasJoinedFaction then return end
    local factionOptions = {}
    for key, data in pairs(Config.Factions) do table.insert(factionOptions, { value = key, label = data.label, description = 'Únete a esta facción para la conquista.' }) end
    oxlib.select({ title = 'Elige tu Facción', options = factionOptions }, function(result)
        if result then
            TriggerServerEvent('conquest:joinFaction', result.value)
            hasJoinedFaction = true
            playerFaction = result.value
        end
    end)
end

function DeathHandlerLoop()
    while isConquestActive do
        Wait(500)
        if IsEntityDead(PlayerPedId()) and not isPlayerDead then
            isPlayerDead = true
            local respawnDuration, respawnLabel, respawnIcon = Config.RespawnDelay, 'REGENERANDO...', 'fa-solid fa-skull'
            if hasRespawnBuff then
                respawnDuration = respawnDuration * (Config.Zones.hospital.respawnTimeMultiplier or 1.0)
                respawnLabel, respawnIcon = 'REGENERACIÓN RÁPIDA...', 'fa-solid fa-heart-pulse'
            end
            oxlib.progress({
                duration = respawnDuration * 1000, label = respawnLabel, icon = respawnIcon,
                onFinish = function()
                    local b = Config.Factions[playerFaction].baseCoords
                    NetworkResurrectLocalPlayer(b.x, b.y, b.z, b.w or 0.0, true, false)
                    local p = PlayerPedId()
                    SetEntityHealth(p, GetEntityMaxHealth(p)); SetPedArmour(p, 100)
                    RemoveAllPedWeapons(p, true)
                    isPlayerDead = false
                end
            })
        end
    end
end

-- =============================================================================
-- INTERFAZ Y NOTIFICACIONES
-- =============================================================================
RegisterNetEvent('conquest:updateScoreUI', function(points, coins, timer)
    if not isConquestActive then return end
    local timeString = string.format('%02d:%02d', math.floor(timer / 60), timer % 60)
    local text = ('<h1 style="text-align:center;">Tiempo Restante: %s</h1><div style="display:flex; justify-content:space-around;">'):format(timeString)
    for key, data in pairs(Config.Factions) do
        text = text .. ('<div style="text-align:center; padding: 0 15px;">' ..
            '<span style="color:%s; font-weight:bold;">%s</span><br/>' ..
            '<span style="font-size:1.5em;">%d Puntos</span><br/>' ..
            '<span style="font-size:0.9em; opacity:0.8;">%d 🪙</span></div>'):format(data.color, data.label, points[key] or 0, coins[key] or 0)
    end
    text = text .. '</div>'
    oxlib.setTextUI(text)
end)

-- =============================================================================
-- LÓGICA DE ZONAS ESPECIALES Y LÍDERES
-- =============================================================================
RegisterNetEvent('conquest:zoneCaptured', function(zoneKey, factionKey, factionLabel, zoneLabel)
    if not isConquestActive then return end
    local zoneConfig = Config.Zones[zoneKey]
    if zoneConfig.bonusMultiplier or zoneConfig.triggersBlackout then
        -- Las alertas grandes son manejadas por eventos específicos como policeStationCaptured, etc.
    else
        oxlib.notify({ title = '¡Zona Capturada!', description = ('%s ha sido capturada por %s'):format(zoneLabel, factionLabel), type = 'success' })
    end
    local blip = activeBlips[zoneKey]
    if blip and DoesBlipExist(blip) then SetBlipColour(blip, Config.Factions[factionKey].blipColor) end
    if activeZones[zoneKey] then activeZones[zoneKey]:remove(); activeZones[zoneKey] = nil end
end)

RegisterNetEvent('conquest:triggerBlackout', function() if isConquestActive then SetArtificialLightsState(true); oxlib.notify({ title = '¡APAGÓN EN LA CIUDAD!', description = 'La Central Eléctrica ha sido tomada.', type = 'error', duration = 7000 }) end end)
RegisterNetEvent('conquest:endBlackout', function() SetArtificialLightsState(false); if isConquestActive then oxlib.notify({ title = 'Se Restablece la Energía', type = 'success' }) end end)

RegisterNetEvent('conquest:updateLeaders', function(serverLeaders)
    currentLeaders = serverLeaders
    local myId, wasLeader = GetPlayerServerId(PlayerId()), amILeader
    amILeader = false
    for _, leaderId in pairs(currentLeaders) do if leaderId == myId then amILeader = true; break end end
    if amILeader and not wasLeader then oxlib.notify({ title = '¡HAS SIDO ASCENDIDO!', description = 'Ahora eres el líder de tu facción. ¡Cuidado, serás un objetivo prioritario!', type = 'inform', duration = 10000, icon = 'fa-solid fa-star' }) end
end)

function LeaderBlipLoop()
    while isConquestActive do
        for _, blip in pairs(leaderBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end; leaderBlips = {}
        for _, leaderId in pairs(currentLeaders) do
            if leaderId ~= GetPlayerServerId(PlayerId()) then
                local leaderPlayer = GetPlayerFromServerId(leaderId)
                if leaderPlayer and leaderPlayer ~= -1 then
                    local leaderPed = GetPlayerPed(leaderPlayer)
                    if leaderPed and DoesEntityExist(leaderPed) then
                        local blip = AddBlipForEntity(leaderPed)
                        SetBlipSprite(blip, Config.LeaderBlip.sprite); SetBlipColour(blip, Config.LeaderBlip.color); SetBlipScale(blip, Config.LeaderBlip.scale); SetBlipDisplay(blip, Config.LeaderBlip.display); SetBlipAsShortRange(blip, Config.LeaderBlip.shortRange)
                        table.insert(leaderBlips, blip)
                    end
                end
            end
        end
        Wait(1000)
    end
end

-- =============================================================================
-- CREACIÓN DE VENDEDORES Y OBJETOS
-- =============================================================================
RegisterNetEvent('conquest:spawnFactionVehicle', function(sourceType)
    local spawnerConfig
    if sourceType == 'comisaria_special' then spawnerConfig = Config.Zones.comisaria.specialVendors.vehicleSpawner
    elseif sourceType == 'seaport_heli' then spawnerConfig = Config.Zones.puerto.specialVendors.helicopterSpawner
    elseif sourceType == 'seaport_boat' then spawnerConfig = Config.Zones.puerto.specialVendors.boatSpawner
    else spawnerConfig = Config.Factions[sourceType].vehicleSpawner end
    if not spawnerConfig then return end
    
    local modelHash = GetHashKey(spawnerConfig.model); RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(100) end
    local veh = CreateVehicle(modelHash, spawnerConfig.coords, 0.0, true, false)
    SetVehicleCustomPrimaryColour(veh, spawnerConfig.color.primary[1], spawnerConfig.color.primary[2], spawnerConfig.color.primary[3])
    SetVehicleCustomSecondaryColour(veh, spawnerConfig.color.secondary[1], spawnerConfig.color.secondary[2], spawnerConfig.color.secondary[3])
    SetVehicleOnGroundProperly(veh); TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1); SetModelAsNoLongerNeeded(modelHash)
end)

async function CreatePedVendor(config, onSelectWeapon, onSelectAmmo)
    local modelHash = GetHashKey(config.pedModel); RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(50) end
    local ped = CreatePed(4, modelHash, config.coords.x, config.coords.y, config.coords.z, config.coords.w, false, false)
    FreezeEntityPosition(ped, true); SetEntityInvincible(ped, true); SetBlockingOfNonTemporaryEvents(ped, true)
    local targetOptions = {}
    if config.weapon then table.insert(targetOptions, { label = ('Comprar %s (%d 🪙)'):format(config.weapon:gsub("WEAPON_", ""), config.cost), icon = 'fa-solid fa-gun', onSelect = onSelectWeapon }) end
    if config.ammoPack then table.insert(targetOptions, { label = ('Comprar Munición (%d 🪙)'):format(config.ammoPack.cost), icon = 'fa-solid fa-box-archive', onSelect = onSelectAmmo }) end
    if config.cost and not config.weapon then table.insert(targetOptions, { label = ('Comprar Blindaje (%d 🪙)'):format(config.cost), icon = 'fa-solid fa-shield-halved', onSelect = onSelectWeapon }) end
    exports.ox_target:addEntity(ped, targetOptions)
    return ped
end

function CreateVehicleSpawnerTarget() local cfg = Config.Factions[playerFaction].vehicleSpawner; if not cfg then return end; vehicleTargetZone = 'conquest_spawner_'..playerFaction; exports.ox_target:addBoxZone({ coords = cfg.coords, size = vec3(3,3,2), options = {{ name = vehicleTargetZone, label = ('Solicitar %s (%d 🪙)'):format(cfg.model, cfg.cost), icon = 'fa-solid fa-car', onSelect = function() TriggerServerEvent('conquest:requestVehicleSpawn') end }} }) end
async function CreateWeaponVendor() local cfg = Config.Factions[playerFaction].weaponVendor; if not cfg then return end; weaponVendorPed = await CreatePedVendor(cfg, function() TriggerServerEvent('conquest:requestWeaponPurchase') end, function() TriggerServerEvent('conquest:requestAmmoPurchase') end) end
RegisterNetEvent('conquest:policeStationCaptured', function(owner) if owner == playerFaction then oxlib.notify({title='¡Ventaja Táctica!', description='Has desbloqueado equipo especial en la Comisaría.'}); CreateSpecialVehicleTarget(); CreateSpecialWeaponVendor() end end)
function CreateSpecialVehicleTarget() local cfg = Config.Zones.comisaria.specialVendors.vehicleSpawner; if not cfg then return end; specialVehicleTargetZone = 'conquest_special_spawner'; exports.ox_target:addBoxZone({ coords = cfg.coords, size = vec3(3,3,2), options = {{ name = specialVehicleTargetZone, label = ('Solicitar %s (%d 🪙)'):format(cfg.model, cfg.cost), icon = 'fa-solid fa-shield-halved', onSelect = function() TriggerServerEvent('conquest:requestSpecialVehiclePurchase') end }} }) end
async function CreateSpecialWeaponVendor() local cfg = Config.Zones.comisaria.specialVendors.weaponVendor; if not cfg then return end; specialWeaponVendorPed = await CreatePedVendor(cfg, function() TriggerServerEvent('conquest:requestSpecialWeaponPurchase') end, function() TriggerServerEvent('conquest:requestSpecialAmmoPurchase') end) end
RegisterNetEvent('conquest:seaportCaptured', function(owner) if owner == playerFaction then oxlib.notify({title='¡Dominio Logístico!', description='Has desbloqueado vehículos aéreos y marítimos en el Puerto.'}); CreateSpecialHeliTarget(); CreateSpecialBoatTarget() end end)
function CreateSpecialHeliTarget() local cfg = Config.Zones.puerto.specialVendors.helicopterSpawner; if not cfg then return end; specialHeliTargetZone = 'conquest_special_heli'; exports.ox_target:addBoxZone({ coords = cfg.coords, size = vec3(5,5,3), options = {{ name = specialHeliTargetZone, label = ('Solicitar %s (%d 🪙)'):format(cfg.model, cfg.cost), icon = 'fa-solid fa-helicopter', onSelect = function() TriggerServerEvent('conquest:requestSpecialHeliPurchase') end }} }) end
function CreateSpecialBoatTarget() local cfg = Config.Zones.puerto.specialVendors.boatSpawner; if not cfg then return end; specialBoatTargetZone = 'conquest_special_boat'; exports.ox_target:addSphereZone({ coords = cfg.coords, radius = 3.0, options = {{ name = specialBoatTargetZone, label = ('Solicitar %s (%d 🪙)'):format(cfg.model, cfg.cost), icon = 'fa-solid fa-ship', onSelect = function() TriggerServerEvent('conquest:requestSpecialBoatPurchase') end }} }) end
RegisterNetEvent('conquest:hospitalCaptured', function(owner) if owner == playerFaction then hasRespawnBuff = true; oxlib.notify({title='¡Ventaja Médica!', description='Tu tiempo de reaparición se ha reducido a la mitad.'}) end end)
RegisterNetEvent('conquest:towerCaptured', function(owner) if owner == playerFaction then oxlib.notify({title='¡Posición Fortificada!', description='Has desbloqueado un proveedor de blindaje.'}); CreateSpecialArmorVendor() end end)
async function CreateSpecialArmorVendor() local cfg = Config.Zones.torre.specialVendors.armorVendor; if not cfg then return end; specialArmorVendorPed = await CreatePedVendor(cfg, function() TriggerServerEvent('conquest:requestSpecialArmorPurchase') end) end
