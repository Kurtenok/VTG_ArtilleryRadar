/*
    Function: cbr_fnc_setBearing
    Сервер закріплює напрямок сектора: число публічне й має бути
    однакове в усіх, зокрема в того, хто сяде за пульт наступним.
*/

params ["_veh", "_bearing"];

if (!isServer || {isNull _veh}) exitWith {};

_veh setVariable ["cbr_bearing", (_bearing + 360) mod 360, true];
