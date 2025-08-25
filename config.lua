-- config.lua
Config = {}

-- =============================================================================
-- DISCORD WEBHOOK
-- =============================================================================
Config.DiscordWebhookUrl = "TU_URL_DE_WEBHOOK_AQUÍ"  -- Pega la URL de tu webhook de Discord aquí. Si se deja en blanco, no se enviará nada.

-- =============================================================================
-- SISTEMA DUAL: PUNTOS Y MONEDAS
-- =============================================================================
Config.PointsPerCapture = 3       -- Puntos otorgados al capturar una zona
Config.PointsPerKill = 1          -- Puntos por eliminar a un rival
Config.PointsPerLeaderKill = 5    -- Puntos por eliminar a un líder enemigo
Config.PassivePointInterval = 300 -- 300s = 5 minutos para los puntos de control de zona
Config.PointsPerControlledZone = 1 -- Puntos otorgados por cada zona en el intervalo

Config.CoinsPerSecondDefault = 1  -- Monedas que cada facción genera por segundo por defecto
Config.CoinsPerZoneBonus = 2      -- Monedas ADICIONALES por segundo por CADA zona controlada

-- =============================================================================
-- OPCIONES GENERALES DEL EVENTO
-- =============================================================================
Config.EventDuration = 900          -- Duración total del evento en segundos (900s = 15 minutos)
Config.RespawnDelay = 60            -- Tiempo en segundos que un jugador debe esperar para reaparecer
Config.BlackoutDuration = 180       -- Duración del apagón en segundos (180s = 3 minutos)
Config.EventDimension = 1337        -- Dimensión virtual para aislar a los jugadores. 0 es la normal.
Config.EventWeather = 'HALLOWEEN'   -- Climas: CLEAR, EXTRASUNNY, CLOUDS, OVERCAST, RAIN, CLEARING, THUNDER, SMOG, FOGGY, XMAS, HALLOWEEN
Config.MinPlayersPerFaction = 3     -- Mínimo de jugadores requeridos en CADA facción para poder iniciar
Config.CaptureTime = 180            -- Tiempo en segundos para capturar una zona

-- =============================================================================
-- COMANDOS
-- =============================================================================
Config.AdminCommandOpen = "abrirregistro"
Config.AdminCommandStart = "iniciarconquista"
Config.AdminCommandCancel = "cancelarregistro"
Config.StatusCommand = "estadoequipos"      -- Muestra el conteo de jugadores ANTES de empezar
Config.PlayerStatusCommand = "estado"       -- Comando para que el jugador vea el estado de su facción
Config.AdminStatusCommand = "estadoadmin"   -- Comando admin para ver el estado de todas las facciones
Config.AdminReportCommand = "reportepartida" -- NUEVO: Comando para enviar el informe final al webhook
Config.AdminPlayerReportCommand = "reportejugadores" -- NUEVO: Comando para el informe de K/D por jugador

-- =============================================================================
-- CONFIGURACIÓN DE ZONAS Y OBJETOS
-- =============================================================================

-- Zona de Registro
Config.RegistrationZone = {
    coords = vector3(-167.3, -961.5, 29.4),
    radius = 25.0,
    blip = { sprite = 164, color = 2, scale = 1.0, text = "Registro para Conquista" }
}

-- Blip de Líder
Config.LeaderBlip = {
    sprite = 445, -- Ícono de estrella
    color = 6,    -- Color Morado/Púrpura
    scale = 1.2,
    shortRange = true,
    display = 2
}

-- FACCIONES
Config.Factions = {
    ['hermandad'] = {
        label = '🩸 Hermandad Roja', blipColor = 1, color = '#ff4d4d',
        baseCoords = vector3(1478.1, -2199.9, 70.9),
        vehicleSpawner = { cost = 150, model = 'schafter3', coords = vec3(1485.8, -2206.5, 70.9), color = {primary = {255, 0, 0}, secondary = {255, 0, 0}} },
        weaponVendor = {
            cost = 250, pedModel = 's_m_y_armoured_01', coords = vec4(1474.5, -2203.8, 70.9, 225.0),
            weapon = 'WEAPON_ASSAULTSMG', ammo = 120,
            ammoPack = { cost = 75, type = 'AMMO_SMG', quantity = 100 }
        }
    },
    ['cuervos'] = {
        label = '💀 Cuervos del Norte', blipColor = 38, color = '#cccccc',
        baseCoords = vector3(2490.4, 4970.2, 46.6),
        vehicleSpawner = { cost = 100, model = 'bifta', coords = vec3(2496.1, 4975.3, 46.6), color = {primary = {200, 200, 200}, secondary = {50, 50, 50}} },
        weaponVendor = {
            cost = 300, pedModel = 'g_m_y_lost_01', coords = vec4(2488.2, 4973.5, 46.6, 315.0),
            weapon = 'WEAPON_PUMPSHOTGUN_MK2', ammo = 30,
            ammoPack = { cost = 85, type = 'AMMO_SHOTGUN', quantity = 25 }
        }
    },
    ['caos'] = {
        label = '🔥 Hijos del Caos', blipColor = 83, color = '#ff9933',
        baseCoords = vector3(106.6, 3728.8, 42.9),
        vehicleSpawner = { cost = 125, model = 'kamacho', coords = vec3(100.8, 3733.9, 42.9), color = {primary = {255, 120, 0}, secondary = {0, 0, 0}} },
        weaponVendor = {
            cost = 275, pedModel = 'u_m_y_militaryaf_01', coords = vec4(108.9, 3731.8, 42.9, 135.0),
            weapon = 'WEAPON_CARBINERIFLE', ammo = 120,
            ammoPack = { cost = 80, type = 'AMMO_RIFLE', quantity = 100 }
        }
    },
    ['resistencia'] = {
        label = '🛡️ Resistencia Civil', blipColor = 3, color = '#3399ff',
        baseCoords = vector3(-1147.2, -1999.0, 13.1),
        vehicleSpawner = { cost = 125, model = 'baller2', coords = vec3(-1141.2, -2005.8, 13.1), color = {primary = {0, 80, 255}, secondary = {200, 200, 200}} },
        weaponVendor = {
            cost = 275, pedModel = 's_m_y_blackops_01', coords = vec4(-1149.8, -2002.1, 13.1, 45.0),
            weapon = 'WEAPON_SPECIALCARBINE', ammo = 120,
            ammoPack = { cost = 80, type = 'AMMO_RIFLE', quantity = 100 }
        }
    }
}

-- ZONAS DE CAPTURA
Config.Zones = {
    ['banco'] = {
        label = "Banco Central", coords = vector3(149.58, -1040.58, 29.37), radius = 75.0,
        blip = { sprite = 590, color = 4, scale = 1.2, text = "Captura: Banco" },
        bonusMultiplier = 3
    },
    ['electrica'] = {
        label = "Central Eléctrica", coords = vector3(727.2, -1300.9, 25.4), radius = 100.0,
        blip = { sprite = 590, color = 4, scale = 1.2, text = "Captura: Eléctrica" },
        triggersBlackout = true
    },
    ['comisaria'] = {
        label = "Comisaría de Policía", coords = vector3(441.4, -983.1, 30.7), radius = 60.0,
        blip = { sprite = 590, color = 4, scale = 1.2, text = "Captura: Comisaría" },
        specialVendors = {
            vehicleSpawner = { cost = 350, model = 'insurgent', coords = vec3(459.2, -1017.5, 28.4), color = {primary = {20, 20, 20}, secondary = {20, 20, 20}} },
            weaponVendor = {
                cost = 175, pedModel = 's_m_y_cop_01', coords = vec4(464.1, -1015.8, 28.4, 180.0),
                weapon = 'WEAPON_COMBATPISTOL', ammo = 60,
                ammoPack = { cost = 50, type = 'AMMO_PISTOL', quantity = 50 }
            }
        }
    },
    ['puerto'] = {
        label = "Puerto Marítimo", coords = vector3(-332.3, -2436.6, 6.0), radius = 150.0,
        blip = { sprite = 590, color = 4, scale = 1.2, text = "Captura: Puerto" },
        specialVendors = {
            helicopterSpawner = { cost = 500, model = 'buzzard2', coords = vec3(-495.0, -2530.0, 14.0), color = {primary = {25, 25, 25}, secondary = {10, 10, 10}} },
            boatSpawner = { cost = 200, model = 'dinghy4', coords = vec3(-290.0, -2580.0, 1.0), color = {primary = {255, 0, 0}, secondary = {255, 255, 255}} }
        }
    },
    ['hospital'] = {
        label = "Hospital Central", coords = vector3(340.5, -1398.5, 32.5), radius = 80.0,
        blip = { sprite = 590, color = 4, scale = 1.2, text = "Captura: Hospital" },
        respawnTimeMultiplier = 0.5
    },
    ['torre'] = {
        label = "Torre del Gobierno", coords = vector3(-130.8, -586.8, 166.0), radius = 50.0,
        blip = { sprite = 590, color = 4, scale = 1.2, text = "Captura: Torre" },
        specialVendors = {
            armorVendor = { cost = 75, pedModel = 's_m_y_blackops_02', coords = vec4(-135.0, -630.0, 168.0, 325.0) }
        }
    }
}