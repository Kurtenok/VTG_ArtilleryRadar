/*
    Function: cbr_fnc_drop
    Прибрати засічку з журналу. Виконується на машині ОПЕРАТОРА — тій,
    що веде журнал: інакше запис зник би на сервері, а оператор
    наступним пострілом повернув би свою копію назад.
*/

params ["_veh", "_id"];

if (isNull _veh) exitWith {};

private _log = _veh getVariable ["cbr_acq", []];
private _idx = _log findIf { (_x select 0) == _id };
if (_idx < 0) exitWith {};

_log deleteAt _idx;
_veh setVariable ["cbr_acq", _log, true];
