/*
    Function: cbr_fnc_markSent
    Позначає засічку як передану. Сервером, бо журнал станції його.
*/

params ["_veh", "_id", "_chan"];

if (!isServer || {isNull _veh}) exitWith {};

private _log = _veh getVariable ["cbr_acq", []];
private _idx = _log findIf { (_x select 0) == _id };
if (_idx < 0) exitWith {};

(_log select _idx) set [6, _chan];
_veh setVariable ["cbr_acq", _log, true];
