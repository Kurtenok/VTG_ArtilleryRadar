#include "defines.h"

/*
    Function: cbr_fnc_stock
    Штатні радари: рядок класів із налаштувань CBA. Реєстр обробника
    складається раз, а вішається на AllVehicles — щоб і техніка, яка
    з'явилась пізніше, підхопилась сама.

    Іде на КОЖНІЙ машині, не лише на сервері. Сервер по цьому списку
    реєструє станції, а клієнт будує пункт меню — і без цього на
    виділеному сервері пульта не було б ні в кого: гравці ходили б
    навколо станції зі штатного списку без жодної дії. На локальному
    хості це не видно, бо там сервер і гравець — та сама машина.
*/

private _rows = missionNamespace getVariable ["cbr_set_vehicles", ""];
cbr_stockList = (_rows splitString ", " apply { toLower _x }) select { _x != "" };

{ [_x] call cbr_fnc_stockApply } forEach vehicles;

if (cbr_stockEh) exitWith {};
cbr_stockEh = true;

["AllVehicles", "init", {
    [_this select 0] call cbr_fnc_stockApply;
}, true, ["CAManBase"], false] call CBA_fnc_addClassEventHandler;
