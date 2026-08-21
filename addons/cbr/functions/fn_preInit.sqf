#include "defines.h"

// Налаштування CBA. Глобальні: список радарів мусить збігатися в усіх,
// інакше машина стрільця вирішить, що доповідати нема кому

cbr_stockEh = false;
cbr_stockList = [];

private _cat = localize "STR_cbr_cat";

[
    "cbr_set_vehicles", "EDITBOX",
    [localize "STR_cbr_set_vehicles", localize "STR_cbr_set_vehicles_desc"],
    _cat, "", 1
] call CBA_fnc_addSetting;
