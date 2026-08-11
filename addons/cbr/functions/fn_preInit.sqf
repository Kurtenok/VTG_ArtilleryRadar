#include "defines.h"

/*
    Налаштування CBA. Усі глобальні: список радарів мусить збігатися в
    усіх, інакше машина стрільця вирішить, що доповідати нема кому, і
    просто не надішле засічку.
*/

cbr_stockEh = false;
cbr_stockList = [];

private _cat = localize "STR_cbr_cat";

[
    "cbr_set_vehicles", "EDITBOX",
    [localize "STR_cbr_set_vehicles", localize "STR_cbr_set_vehicles_desc"],
    _cat, "", 1
] call CBA_fnc_addSetting;
