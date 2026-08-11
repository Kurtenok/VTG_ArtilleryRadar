/*
    Function: cbr_fnc_drop
    Прибрати засічку з журналу станції. Сервером, бо журнал його: інакше
    в одного оператора запис зникне, а в другого лишиться.
*/

params ["_veh", "_id"];

if (!isServer || {isNull _veh}) exitWith {};

private _log = _veh getVariable ["cbr_acq", []];
private _idx = _log findIf { (_x select 0) == _id };
if (_idx < 0) exitWith {};

_log deleteAt _idx;
_veh setVariable ["cbr_acq", _log, true];
