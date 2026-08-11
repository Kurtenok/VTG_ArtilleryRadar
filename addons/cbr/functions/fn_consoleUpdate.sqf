#include "defines.h"

/*
    Function: cbr_fnc_consoleUpdate
    Журнал і рядок стану. Раз на чверть секунди, бо цифри тут міняються
    подіями, а не щокадру; рух розгортки веде обробник малювання.
*/

private _veh = uiNamespace getVariable ["cbr_veh", objNull];
if (isNull _veh) exitWith {};

// журнал станції, без протухлих записів; свіжі — зверху
private _log = (_veh getVariable ["cbr_acq", []]) select { (time - (_x select 4)) < CBR_ACQ_LIFE };
_log = [_log, [], { -(_x select 4) }, "ASCEND"] call BIS_fnc_sortBy;
uiNamespace setVariable ["cbr_log", _log];

private _sel = (uiNamespace getVariable ["cbr_sel", 0]) max 0 min (((count _log) - 1) max 0);
uiNamespace setVariable ["cbr_sel", _sel];

private _bearing = _veh getVariable ["cbr_bearing", getDir _veh];
private _sector = _veh getVariable ["cbr_sector", CBR_SECTOR];

(uiNamespace getVariable ["cbr_status", controlNull]) ctrlSetStructuredText parseText format [
    "<t color='#8affa0'>%1</t>   <t color='#4d7a58'>|</t>   %2 <t color='#ffffff'>%3</t>   <t color='#4d7a58'>|</t>   %4 <t color='#ffffff'>%5</t>   <t color='#4d7a58'>|</t>   %6 <t color='#ffffff'>%7</t>   <t color='#4d7a58'>|</t>   %8 <t color='#ffffff'>%9</t>",
    localize "STR_cbr_ui_title",
    localize "STR_cbr_ui_bearing", format ["%1", round _bearing],
    localize "STR_cbr_ui_sector", format ["%1", round _sector],
    localize "STR_cbr_ui_acq", format ["%1", count _log],
    // поточний час: без нього час засічки нема з чим порівняти
    localize "STR_cbr_ui_now", [daytime] call cbr_fnc_hhmm
];

// рядки журналу: час, квадрат, калібр, швидкість, пострілів
{
    private _c = _x;
    private _i = _forEachIndex;

    private _del = (uiNamespace getVariable ["cbr_dels", []]) param [_i, controlNull];
    _del ctrlShow (_i < count _log);

    if (_i >= count _log) exitWith { _c ctrlSetStructuredText parseText ""; _c ctrlCommit 0 };

    (_log select _i) params ["_id", "_p", "_cal", "_speed", "_at", "_rounds", "", ["_fireAz", 0], ["_when", 0]];

    private _colour = switch (true) do {
        case (_i == _sel): { "#ff9926" };
        case ((time - _at) < CBR_HOT_AGE): { "#ffffff" };
        default { "#5af080" };
    };

    private _calText = [format ["%1", _cal], "---"] select (_cal <= 0);

    _c ctrlSetStructuredText parseText format [
        "<t color='%1'>%2 %3  %4  %5  %6  %7  x%8</t>",
        _colour,
        ["  ", ">"] select (_i == _sel),
        [_when] call cbr_fnc_hhmm,
        mapGridPosition _p,
        _calText,
        _speed,
        format ["%1", round _fireAz],
        _rounds
    ];
    _c ctrlCommit 0;
} forEach (uiNamespace getVariable ["cbr_rows", []]);
