#include "defines.h"

/*
    Function: cbr_fnc_stockApply
    Підключення однієї штатної машини. Модуль Едему старший: машину, яку
    він уже налаштував, штатний список не чіпає.
*/

params ["_veh"];

if (!isServer) exitWith {};
if (isNull _veh || {_veh getVariable ["cbr_initDone", false]}) exitWith {};
if ((cbr_stockList findIf { _veh isKindOf _x }) < 0) exitWith {};

[_veh, []] call cbr_fnc_addRadar;
