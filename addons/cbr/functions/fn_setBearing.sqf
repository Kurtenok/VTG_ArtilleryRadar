/*
    Function: cbr_fnc_setBearing
    Сервер закріплює напрямок сектора: рішення про засічку рахує він,
    тож і число має бути його.
*/

params ["_veh", "_bearing"];

if (!isServer || {isNull _veh}) exitWith {};

_veh setVariable ["cbr_bearing", (_bearing + 360) mod 360, true];
