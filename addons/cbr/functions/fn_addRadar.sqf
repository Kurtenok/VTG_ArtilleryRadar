#include "defines.h"

/*
    Function: cbr_fnc_addRadar
    Робить машину контрбатарейним радаром:
        [_veh, [дальність, сектор, похибка]] call cbr_fnc_addRadar;

    Реєстр веде КОЖНА машина: за ним машина стрільця вирішує, чи є сенс
    узагалі щось надсилати. Тому список і найбільша дальність публічні.
*/

params [
    ["_veh", objNull, [objNull]],
    ["_settings", [], [[]]]
];

if (isNull _veh) exitWith {};

_settings params [
    ["_range", CBR_RANGE, [0]],
    ["_sector", CBR_SECTOR, [0]],
    ["_error", CBR_ERROR, [0]]
];

if (isServer) then {
    // останній виклик виграє: модуль Едему йде після штатного списку
    _range = _range max 0;
    _veh setVariable ["cbr_range", _range, true];
    _veh setVariable ["cbr_sector", 0 max _sector min 360, true];
    _veh setVariable ["cbr_error", _error max 0, true];

    // найбільша дальність у місії: одним порівнянням машина стрільця
    // відсікає обстріли, до яких жоден радар не дотягується
    if (_range > (missionNamespace getVariable ["cbr_maxRange", 0])) then {
        cbr_maxRange = _range;
        publicVariable "cbr_maxRange";
    };

    if (!(_veh getVariable ["cbr_initDone", false])) then {
        _veh setVariable ["cbr_initDone", true, true];

        // початковий напрямок сектора — куди дивиться машина; далі його
        // веде оператор із пульта
        _veh setVariable ["cbr_bearing", getDir _veh, true];

        if (isNil "cbr_radars") then { cbr_radars = [] };
        cbr_radars pushBack _veh;
        publicVariable "cbr_radars";
    };
};

// меню клієнтське — будується в кожного
if (hasInterface) then { [_veh] call cbr_fnc_createAceMenu };
