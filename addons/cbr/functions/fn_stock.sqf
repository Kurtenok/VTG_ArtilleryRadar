#include "defines.h"

/*
    Function: cbr_fnc_stock
    Штатні радари: рядок класів із налаштувань CBA. Реєстр обробника
    складається раз, а вішається на AllVehicles — щоб і техніка, яка
    з'явилась пізніше, підхопилась сама.
*/

if (!isServer) exitWith {};

private _rows = missionNamespace getVariable ["cbr_set_vehicles", ""];
cbr_stockList = (_rows splitString ", " apply { toLower _x }) select { _x != "" };

{ [_x] call cbr_fnc_stockApply } forEach vehicles;

if (cbr_stockEh) exitWith {};
cbr_stockEh = true;

["AllVehicles", "init", {
    [_this select 0] call cbr_fnc_stockApply;
}, true, ["CAManBase"], false] call CBA_fnc_addClassEventHandler;
