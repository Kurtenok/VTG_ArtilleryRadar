#include "defines.h"

/*
    Function: cbr_fnc_addRadar
    Робить машину контрбатарейним радаром:
        [_veh, [дальність, сектор, похибка, затримка]] call cbr_fnc_addRadar;

    Реєстр веде КОЖНА машина: за ним машина стрільця вирішує, кому саме
    надсилати засічку, — тому список і налаштування станцій публічні.
*/

params [
    ["_veh", objNull, [objNull]],
    ["_settings", [], [[]]]
];

if (isNull _veh) exitWith {};

_settings params [
    ["_range", CBR_RANGE, [0]],
    ["_sector", CBR_SECTOR, [0]],
    ["_error", CBR_ERROR, [0]],
    ["_delay", CBR_DELAY, [0]]
];

if (isServer) then {
    // останній виклик виграє: модуль Едему йде після штатного списку
    _range = _range max 0;
    _veh setVariable ["cbr_range", _range, true];
    _veh setVariable ["cbr_sector", 0 max _sector min 360, true];
    _veh setVariable ["cbr_error", _error max 0, true];
    // менше за супровід затримці бути нема сенсу: рахувати назад
    // станція починає лише після нього
    _veh setVariable ["cbr_delay", _delay max CBR_TRACK_MIN, true];

    if (!(_veh getVariable ["cbr_initDone", false])) then {
        _veh setVariable ["cbr_initDone", true, true];

        // початковий напрямок сектора — куди дивиться машина; далі його
        // веде оператор із пульта
        _veh setVariable ["cbr_bearing", getDir _veh, true];

        if (isNil "cbr_radars") then { cbr_radars = [] };
        cbr_radars pushBackUnique _veh;
        publicVariable "cbr_radars";

        // знищена станція випадає з переліку діючих: посадку екіпажу
        // стежить клієнт, а от загибель машини — лише сервер
        _veh addEventHandler ["Killed", { [] call cbr_fnc_manned }];
    };

    // машина могла приїхати вже з екіпажем — модулем Едему або з Zeus
    [] call cbr_fnc_manned;
};

// меню клієнтське — будується в кожного
if (hasInterface) then { [_veh] call cbr_fnc_createAceMenu };
