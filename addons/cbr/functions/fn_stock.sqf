#include "defines.h"

/*
    Function: cbr_fnc_stock
    Штатні радари: рядок класів із налаштувань CBA. Обробник вішається на
    AllVehicles, щоб техніка, яка з'явилась пізніше, підхопилась сама.

    Іде на КОЖНІЙ машині: сервер по цьому списку реєструє станції, а
    клієнт будує пункт меню. На локальному хості різниці не видно, а на
    виділеному сервері пульта інакше не було б ні в кого.
*/

private _rows = missionNamespace getVariable ["cbr_set_vehicles", ""];
cbr_stockList = (_rows splitString ", " apply { toLower _x }) select { _x != "" };

{ [_x] call cbr_fnc_stockApply } forEach vehicles;

if (cbr_stockEh) exitWith {};
cbr_stockEh = true;

["AllVehicles", "init", {
    [_this select 0] call cbr_fnc_stockApply;
}, true, ["CAManBase"], false] call CBA_fnc_addClassEventHandler;
