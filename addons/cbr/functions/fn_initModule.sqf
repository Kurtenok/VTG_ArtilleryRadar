#include "defines.h"

// Модуль Едему (isGlobal = 2 — усі машини й JIP): чіпляє радар до
// синхронізованої техніки

params ["_logic", "_units", "_activated"];

if (!_activated) exitWith {};
if (is3DEN) exitWith {};

private _cfgArgs = configOf _logic >> "Arguments";
private _fnc_arg = {
    params ["_name", "_fallback"];
    private _cfg = _cfgArgs >> _name >> "defaultValue";
    _logic getVariable [_name, [_fallback, getNumber _cfg] select (isNumber _cfg)]
};

private _settings = [
    ["Range", CBR_RANGE] call _fnc_arg,
    ["Sector", CBR_SECTOR] call _fnc_arg,
    ["Error", CBR_ERROR] call _fnc_arg,
    ["Delay", CBR_DELAY] call _fnc_arg,
    ["Floor", CBR_ERROR_MIN] call _fnc_arg,
    ["Shots", CBR_ERROR_SHOTS] call _fnc_arg
];

private _targets = (synchronizedObjects _logic) select {
    _x isKindOf "AllVehicles" && {!(_x isKindOf "CAManBase")}
};

if (_targets isNotEqualTo []) then {
    { [_x, _settings] call cbr_fnc_addRadar } forEach _targets;
} else {
    // у Zeus синхронізації немає — чіпляємось до найближчої техніки
    if (!local _logic) exitWith {};

    private _near = (nearestObjects [_logic, ["AllVehicles"], 30]) select {
        !(_x isKindOf "CAManBase")
    };
    if (_near isEqualTo []) exitWith {};

    [_near select 0, _settings] remoteExec ["cbr_fnc_addRadar", 0, _near select 0];
};
