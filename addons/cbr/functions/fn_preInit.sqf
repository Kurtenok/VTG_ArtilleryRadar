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

// Строк позначки — єдине, що стосується лише показу, але й він
// глобальний: карта в союзників має бути однакова
[
    "cbr_set_life", "SLIDER",
    [localize "STR_cbr_set_life", localize "STR_cbr_set_life_desc"],
    _cat,
    [30, 3600, CBR_MARKER_LIFE, -1],   // [мін, макс, дефолт, знаків після коми]
    1
] call CBA_fnc_addSetting;
