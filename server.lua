
-- Send request to change traffic light to all clients
RegisterServerEvent("PapaGTraffic:setLight")
AddEventHandler("PapaGTraffic:setLight", function(coords)
    TriggerClientEvent("PapaGTraffic:setLight", -1, coords)
end)
