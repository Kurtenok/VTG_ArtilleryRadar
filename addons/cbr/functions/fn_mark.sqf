#include "defines.h"

/*
    Function: cbr_fnc_mark
    Передана вогнева позиція на карті. Позначка локальна: її бачить
    лише своя сторона, і мережі вона не коштує нічого.
*/

params ["_pos", "_text"];

if (!hasInterface) exitWith {};

private _n = missionNamespace getVariable ["cbr_markerId", 0];
missionNamespace setVariable ["cbr_markerId", _n + 1];

private _marker = createMarkerLocal [format ["cbr_fix_%1", _n], _pos];
_marker setMarkerTypeLocal CBR_MARKER_TYPE;
_marker setMarkerColorLocal "ColorRed";
_marker setMarkerTextLocal _text;

[{ deleteMarkerLocal _this }, _marker, missionNamespace getVariable ["cbr_set_life", CBR_MARKER_LIFE]] call CBA_fnc_waitAndExecute;
