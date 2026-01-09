local uiOpen = false
local locked = false

-- RANGE AYARLARI
local FRONT_RANGE = 35.0
local REAR_RANGE  = 35.0

-- SON OKUNAN VERİLER
local lastFront = { plate = "UNKNOWN", index = 0 }
local lastRear  = { plate = "UNKNOWN", index = 0 }
local lastVehicle = "UNKNOWN"

------------------------------------------------
-- İZİNLİ ARAÇ KONTROLÜ
------------------------------------------------
local function IsAllowedVehicle(vehicle)
    if vehicle == 0 then return false end

    local model = GetEntityModel(vehicle)
    local name = GetDisplayNameFromVehicleModel(model)
    name = string.lower(name)

    return Config.AllowedVehicles[name] == true
end

------------------------------------------------
-- /plakaokuyucu
------------------------------------------------
RegisterCommand("plakaokuyucu", function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end

    local veh = GetVehiclePedIsIn(ped, false)
    if not IsAllowedVehicle(veh) then return end

    uiOpen = not uiOpen
    SendNUIMessage({
        action = uiOpen and "open" or "close"
    })
end)

------------------------------------------------
-- F5 KİLİT (ÖN + ARKA)
------------------------------------------------
CreateThread(function()
    while true do
        Wait(0)

        if uiOpen and IsControlJustPressed(0, 166) then -- F5
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if not IsAllowedVehicle(veh) then return end

            locked = not locked
            SendNUIMessage({
                action = "lock",
                state = locked
            })
        end
    end
end)

------------------------------------------------
-- ANA OKUMA THREAD
------------------------------------------------
CreateThread(function()
    while true do
        Wait(800)

        if not uiOpen then goto skip end

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        -- Araçtan inince veya izinli araç değilse kapat
        if veh == 0 or not IsAllowedVehicle(veh) then
            uiOpen = false
            SendNUIMessage({ action = "close" })
            goto skip
        end

        -- Kilitliyken okuma yapma
        if locked then goto skip end

        -- ÖN / ARKA ARAÇLAR
        local frontVeh = GetVehicleInFront(ped, FRONT_RANGE)
        local rearVeh  = GetVehicleInBack(ped, REAR_RANGE)

        -- ÖN OKUMA
        if frontVeh ~= 0 then
            lastFront.plate = GetVehicleNumberPlateText(frontVeh)
            lastFront.index = GetVehicleNumberPlateTextIndex(frontVeh)
            lastVehicle = GetLabelText(
                GetDisplayNameFromVehicleModel(GetEntityModel(frontVeh))
            )
        end

        -- ARKA OKUMA
        if rearVeh ~= 0 then
            lastRear.plate = GetVehicleNumberPlateText(rearVeh)
            lastRear.index = GetVehicleNumberPlateTextIndex(rearVeh)
        end

        -- UI GÜNCELLE
        SendNUIMessage({
            action = "update",
            vehicle = lastVehicle,
            frontPlate = lastFront,
            rearPlate  = lastRear
        })

        ::skip::
    end
end)

------------------------------------------------
-- ÖN ARAÇ BUL (LOS KONTROLLÜ)
------------------------------------------------
function GetVehicleInFront(ped, range)
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local dest = coords + forward * range

    local ray = StartShapeTestRay(
        coords.x, coords.y, coords.z + 0.6,
        dest.x, dest.y, dest.z,
        10,
        ped,
        0
    )

    local _, hit, _, _, entity = GetShapeTestResult(ray)

    if hit == 1 and entity ~= 0 and IsEntityAVehicle(entity) then
        if HasEntityClearLosToEntity(ped, entity, 17) then
            return entity
        end
    end

    return 0
end

------------------------------------------------
-- ARKA ARAÇ BUL (LOS KONTROLLÜ)
------------------------------------------------
function GetVehicleInBack(ped, range)
    local coords = GetEntityCoords(ped)
    local backward = -GetEntityForwardVector(ped)
    local dest = coords + backward * range

    local ray = StartShapeTestRay(
        coords.x, coords.y, coords.z + 0.6,
        dest.x, dest.y, dest.z,
        10,
        ped,
        0
    )

    local _, hit, _, _, entity = GetShapeTestResult(ray)

    if hit == 1 and entity ~= 0 and IsEntityAVehicle(entity) then
        if HasEntityClearLosToEntity(ped, entity, 17) then
            return entity
        end
    end

    return 0
end
