#include "defines.h"

/*
    Function: cbr_fnc_createAceMenu
    Пункт «сісти за пульт» у самодіях екіпажу. Клієнтський: меню
    будується в кожного свій.

    Рівно раз на машину. Реєстрація може прийти двічі — модулем Едему й
    штатним списком класів, а сам список ще й перечитується на зміну
    налаштувань CBA, — і кожен зайвий раз додавав би ще один пункт у
    меню. Позначка МІСЦЕВА: публічна приїхала б із запізненням, і в цю
    щілину пункт устигав би подвоїтись.
*/

params ["_veh"];

if (!hasInterface || {isNull _veh}) exitWith {};
if (_veh getVariable ["cbr_menuDone", false]) exitWith {};
_veh setVariable ["cbr_menuDone", true];

private _action = [
    "cbr_console",
    localize "STR_cbr_open",
    "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\radio_ca.paa",
    { [] call cbr_fnc_console },
    { [_target] call cbr_fnc_canUse }
] call ace_interact_menu_fnc_createAction;

[_veh, 1, ["ACE_SelfActions"], _action] call ace_interact_menu_fnc_addActionToObject;
