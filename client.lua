-- PARAMETERS --
local SEARCH_STEP_SIZE = 10.0                   -- Step size to search for traffic lights
local SEARCH_MIN_DISTANCE = 20.0                -- Minimum distance to search for traffic lights
local SEARCH_MAX_DISTANCE = 60.0                -- Maximum distance to search for traffic lights
                 -- Player must match traffic light orientation within threshold (degrees)
local TRAFFIC_LIGHT_POLL_FREQUENCY_MS = 1000    -- How often to check if a light is red (ms)
local TRAFFIC_LIGHT_DURATION_MS = 5000          -- Duration to turn light green (ms)

-- Array of all traffic light hashes
local trafficLightObjects = {
    [0] = 0x3e2b73a4,   -- prop_traffic_01a
    [1] = 0x336e5e2a,   -- prop_traffic_01b
    [2] = 0xd8eba922,   -- prop_traffic_01d
    [3] = 0xd4729f50,   -- prop_traffic_02a
    [4] = 0x272244b2,   -- prop_traffic_02b
    [5] = 0x33986eae,   -- prop_traffic_03a
    [6] = 0x2323cdc5    -- prop_traffic_03b
}

-- Client side event to set traffic light green, wait and reset state
RegisterNetEvent("PapaGTraffic:setLight")
AddEventHandler("PapaGTraffic:setLight", function(coords)
    -- Find traffic light using trafficLightObjects array
    for _, trafficLightObject in pairs(trafficLightObjects) do
        trafficLight = GetClosestObjectOfType(coords, 1.0, trafficLightObject, false, false, false)
        if trafficLight ~= 0 then
            -- Set traffic light green, delay and reset state
            SetEntityTrafficlightOverride(trafficLight, 0)
            Citizen.Wait(TRAFFIC_LIGHT_DURATION_MS)
            SetEntityTrafficlightOverride(trafficLight, -1)
            break
        end
    end
end)

Citizen.CreateThread(function()
    local lastTrafficLight = 0
    local SEARCH_RADIUS = 50.0
    local HEADING_THRESHOLD = 60
    local VERTICAL_ANGLE_THRESHOLD = 45
    local HORIZONTAL_FOV = 60  -- Horizontal Field of View in degrees
    local VERTICAL_FOV = 60    -- Vertical Field of View in degrees
    local function dotProduct2D(v1, v2)
        return v1.x * v2.x + v1.y * v2.y
    end
    -- Enhanced function to account for a broader field of view
    local function isTrafficLightInViewOfVehicle(vehicle, trafficLight)
        local vehiclePos = GetEntityCoords(vehicle)
        local lightPos = GetEntityCoords(trafficLight)
        local directionVector = vector3(lightPos.x - vehiclePos.x, lightPos.y - vehiclePos.y, lightPos.z - vehiclePos.z)
        directionVector = directionVector / math.sqrt(directionVector.x^2 + directionVector.y^2 + directionVector.z^2) -- Normalize

        local vehicleHeading = GetEntityHeading(vehicle)
        local rad = math.rad(vehicleHeading)
        local forwardVector = vector3(-math.sin(rad), math.cos(rad), 0) -- Forward vector for horizontal comparison

        -- Calculate horizontal and vertical angles
        local angleHorizontal = math.deg(math.acos(dotProduct2D(forwardVector, directionVector)))
        local angleVertical = math.deg(math.asin(directionVector.z))

        -- Check if within horizontal and vertical fields of view
        return math.abs(angleHorizontal) <= HORIZONTAL_FOV / 2 and math.abs(angleVertical) <= VERTICAL_FOV / 2
    end

    -- Helper function for 2D dot product
    local function dotProduct2D(v1, v2)
        return v1.x * v2.x + v1.y * v2.y
    end

    while true do
        Citizen.Wait(TRAFFIC_LIGHT_POLL_FREQUENCY_MS)
        print("[Debug] Advanced scanning for traffic lights...")

        local player = GetPlayerPed(-1)
        local vehicle = GetVehiclePedIsIn(player, false)

        if IsPedInAnyVehicle(player, false) then
            print("[Debug] In vehicle, scanning...")
            local playerPosition = GetEntityCoords(player)

            local trafficLight = 0
            -- Assuming SEARCH_MAX_DISTANCE, SEARCH_MIN_DISTANCE, and SEARCH_STEP_SIZE are predefined
            for _, trafficLightObject in pairs(trafficLightObjects) do
                trafficLight = GetClosestObjectOfType(playerPosition, SEARCH_RADIUS, trafficLightObject, false, false, false)
                if trafficLight ~= 0 then
                    print("[Debug] Potential traffic light spotted.")
                    if isTrafficLightInViewOfVehicle(vehicle, trafficLight) then
                        print("[Debug] Traffic light within view.")
                          if GetVehicleClass(vehicle) == 18 and IsVehicleSirenOn(vehicle) then
                                    print("[Debug] Emergency vehicle with active siren detected, setting traffic light to green.")
                                    TriggerServerEvent('PapaGTraffic:setLight', GetEntityCoords(trafficLight, false))
                                    lastTrafficLight = trafficLight
                                    Citizen.Wait(TRAFFIC_LIGHT_DURATION_MS)
                                    break  -- Exit the loop for the emergency vehicle
                                end
                                break  -- Exit the loop as a valid traffic light is found
            
                    else
                        print("[Debug] Traffic light out of view, continuing search...")
                        trafficLight = 0  -- Keep searching
                    end
                end
            end
        else
            print("[Debug] Not in vehicle or no traffic light in view.")
        end
    end
end)
function translateVector3(coord, heading, distance)
    local radians = heading * math.pi / 180.0
    return vector3(coord.x + math.sin(radians) * distance, coord.y + math.cos(radians) * distance, coord.z)
end

function math.angleDifference(a1, a2)
    local diff = (a2 - a1 + 180) % 360 - 180
    return diff < -180 and diff + 360 or diff
end

-- Get all nearby vehicles
-- TODO, can you force nearby vehicles to stop/go at lights using this and SetDriveTaskDrivingStyle()?
function getNearbyVehicles()
    local vehicles = {}
    local findHandle, vehicle = FindFirstVehicle()
    if findHandle then
        local retval = true
        while retval and vehicle ~= 0 do
            table.insert(vehicles, vehicle)
            retval, vehicle = FindNextVehicle()
        end
        EndFindVehicle(findHandle)
    end
    return vehicles
end
