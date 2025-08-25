-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'Ardisson15'
description 'Minijuego de conquista de zonas con facciones, bonus y puntos.'
version '1.0.0'

-- Dependencias
shared_script '@oxlib/init.lua'
client_script '@ox_target/init.lua'

-- Archivos del script
server_script 'server/main.lua'
client_script 'client/main.lua'

shared_script 'config.lua'
