#include "defines.h"

/*
    Function: cbr_fnc_report
    Засічка на карті. Позначка ЛОКАЛЬНА: її бачить лише своя сторона, і
    мережі вона не коштує нічого.

    Постріли зводяться у вогневі позиції: батарея дає десяток снарядів
    із того самого місця, і десяток позначок за двісті метрів одна від
    одної показував би не більше, ніж одна з лічильником. Справжній
    розрахунок міркує так само — його цікавить позиція, а не постріл.
*/

params ["_pos", "_cal", "_speed"];

if (!hasInterface) exitWith {};

if (isNil "cbr_fixes") then { cbr_fixes = [] };

private _life = missionNamespace getVariable ["cbr_set_life", CBR_MARKER_LIFE];

// [позначка, точка, скільки пострілів, до якого часу жити, калібр, швидкість]
private _idx = cbr_fixes findIf { (_x select 1) distance2D _pos < CBR_MERGE };

if (_idx > -1) exitWith {
    private _fix = cbr_fixes select _idx;
    _fix set [2, (_fix select 2) + 1];
    _fix set [3, time + _life];
    [_fix] call cbr_fnc_label;
};

private _n = missionNamespace getVariable ["cbr_markerId", 0];
missionNamespace setVariable ["cbr_markerId", _n + 1];

private _marker = createMarkerLocal [format ["cbr_fix_%1", _n], _pos];
_marker setMarkerTypeLocal CBR_MARKER_TYPE;
_marker setMarkerColorLocal "ColorRed";

private _fix = [_marker, _pos, 1, time + _life, _cal, _speed];
cbr_fixes pushBack _fix;
[_fix] call cbr_fnc_label;

// прибирання таймером на кожну позначку, без постійного циклу: у спокої
// мод не витрачає ані кадру
[{ _this call cbr_fnc_expire }, [_fix], _life] call CBA_fnc_waitAndExecute;
