if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Alias attested by the client's book 21337012 / 0 / 2124.
-- The Wood Orc stronghold of Mordécorce occupies the promontoire de Réman (POI name 10860933 / 0 / 777).
IHR_PlaceAliases = {
    {name="Mordécorce", targets={"promontoire de Réman", "forteresse Mordécorce", "forteresse de Mordécorce"}, contextual=true},
    {name="forteresse Mordécorce", targets={"promontoire de Réman", "forteresse de Mordécorce"}},
    {name="forteresse de Mordécorce", targets={"promontoire de Réman", "forteresse Mordécorce"}},
}
