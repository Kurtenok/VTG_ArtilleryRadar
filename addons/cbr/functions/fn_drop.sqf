/*
    Function: cbr_fnc_drop
    Прибрати засічку з журналу станції.

    Виконується на машині ОПЕРАТОРА — тій самій, що веде журнал.
    Інакше запис зник би на сервері, а оператор наступним пострілом
    записав би свою копію назад разом із ним.
*/

params ["_veh", "_id"];

if (isNull _veh) exitWith {};

private _log = _veh getVariable ["cbr_acq", []];
private _idx = _log findIf { (_x select 0) == _id };
if (_idx < 0) exitWith {};

_log deleteAt _idx;
_veh setVariable ["cbr_acq", _log, true];
