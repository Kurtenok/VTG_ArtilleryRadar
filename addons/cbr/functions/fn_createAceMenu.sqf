#include "defines.h"

/*
    Function: cbr_fnc_createAceMenu
    Пункт «сісти за пульт» у самодіях екіпажу. Клієнтський: меню
    будується в кожного свій.
*/

params ["_veh"];

if (!hasInterface || {isNull _veh}) exitWith {};

private _action = [
    "cbr_console",
    localize "STR_cbr_open",
    "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\radio_ca.paa",
    { [] call cbr_fnc_console },
    { [_target] call cbr_fnc_canUse }
] call ace_interact_menu_fnc_createAction;

[_veh, 1, ["ACE_SelfActions"], _action] call ace_interact_menu_fnc_addActionToObject;
