#include "defines.h"

/*
    Function: cbr_fnc_slew
    Доворот сектора оператором. Напрямок публічний і живе на машині:
    його читає і індикатор, і перевірка сектора при засічці.
*/

params ["_veh", "_delta"];

private _bearing = ((_veh getVariable ["cbr_bearing", getDir _veh]) + _delta + 360) mod 360;
[_veh, _bearing] remoteExec ["cbr_fnc_setBearing", 2];

// у себе ставимо одразу, щоб індикатор не смикався на пінгу
_veh setVariable ["cbr_bearing", _bearing];
