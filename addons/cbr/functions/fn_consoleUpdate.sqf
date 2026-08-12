#include "defines.h"

/*
    Function: cbr_fnc_consoleUpdate
    Журнал і рядок стану. Раз на чверть секунди, бо цифри тут міняються
    подіями, а не щокадру; рух розгортки веде обробник малювання.
*/

private _veh = uiNamespace getVariable ["cbr_veh", objNull];
if (isNull _veh) exitWith {};

private _raw = _veh getVariable ["cbr_acq", []];
private _log = uiNamespace getVariable ["cbr_log", []];

/*
    Журнал міняється подіями — постріл раз на кілька секунд, — а тік
    іде чотири рази на секунду. Тому сортування й складання підписів
    робляться лише коли він справді змінився або коли з нього щось
    протухло за віком.

    Порівнюється КОПІЯ: запис оновлюється на місці, і посилання
    зрівнялося б саме із собою, скільки б не мінялось.
*/
if (
    _raw isNotEqualTo (uiNamespace getVariable ["cbr_raw", []])
    || {_log findIf { (time - (_x select 4)) >= CBR_ACQ_LIFE } > -1}
) then {
    uiNamespace setVariable ["cbr_raw", +_raw];

    // без протухлих записів; свіжі — зверху
    _log = _raw select { (time - (_x select 4)) < CBR_ACQ_LIFE };
    _log = [_log, [], { -(_x select 4) }, "ASCEND"] call BIS_fnc_sortBy;
    uiNamespace setVariable ["cbr_log", _log];

    /*
        Підписи для індикатора збираються тут — вони міняються подіями,
        а малювання йде щокадру. Складати два десятки рядків по
        шістдесят разів на секунду нема сенсу.
    */
    private _fmtCal = localize "STR_cbr_label";
    private _fmtNo = localize "STR_cbr_label_nocal";

    uiNamespace setVariable ["cbr_labels", _log apply {
        _x params ["_id", "", "_cal", "_speed", "", "_rounds", "", "", ["_when", 0]];
        format [
            "%1  %2  x%3  %4",
            _id,
            [format [_fmtNo, _speed], format [_fmtCal, _cal, _speed]] select (_cal > 0),
            _rounds,
            [_when] call cbr_fnc_hhmm
        ]
    }];
};

private _sel = (uiNamespace getVariable ["cbr_sel", 0]) max 0 min (((count _log) - 1) max 0);
uiNamespace setVariable ["cbr_sel", _sel];

private _bearing = _veh getVariable ["cbr_bearing", getDir _veh];
private _sector = _veh getVariable ["cbr_sector", CBR_SECTOR];

// parseText і перемальовування коштують помітно дорожче за порівняння
// рядків, а стан на пульті стоїть без змін більшість тіків
private _fnc_set = {
    params ["_ctrl", "_text"];
    if ((_ctrl getVariable ["cbr_last", ""]) isEqualTo _text) exitWith {};
    _ctrl setVariable ["cbr_last", _text];
    _ctrl ctrlSetStructuredText parseText _text;
    _ctrl ctrlCommit 0;
};

[uiNamespace getVariable ["cbr_status", controlNull], format [
    "<t color='#8affa0'>%1</t>   <t color='#4d7a58'>|</t>   %2 <t color='#ffffff'>%3</t>   <t color='#4d7a58'>|</t>   %4 <t color='#ffffff'>%5</t>   <t color='#4d7a58'>|</t>   %6 <t color='#ffffff'>%7</t>   <t color='#4d7a58'>|</t>   %8 <t color='#ffffff'>%9</t>",
    localize "STR_cbr_ui_title",
    localize "STR_cbr_ui_bearing", format ["%1", round _bearing],
    localize "STR_cbr_ui_sector", format ["%1", round _sector],
    localize "STR_cbr_ui_acq", format ["%1", count _log],
    // поточний час: без нього час засічки нема з чим порівняти
    localize "STR_cbr_ui_now", [daytime] call cbr_fnc_hhmm
]] call _fnc_set;

// рядки журналу: час, квадрат, калібр, швидкість, пострілів
{
    private _c = _x;
    private _i = _forEachIndex;

    private _del = (uiNamespace getVariable ["cbr_dels", []]) param [_i, controlNull];
    _del ctrlShow (_i < count _log);

    if (_i >= count _log) exitWith { [_c, ""] call _fnc_set };

    (_log select _i) params ["_id", "_p", "_cal", "_speed", "", "_rounds", "", ["_fireAz", 0], ["_when", 0]];

    private _colour = ["#ffffff", "#ff9926"] select (_i == _sel);

    private _calText = [format ["%1", _cal], "---"] select (_cal <= 0);

    [_c, format [
        "<t color='%1'>%2 %3  %4  %5  %6  %7  x%8</t>",
        _colour,
        ["  ", ">"] select (_i == _sel),
        [_when] call cbr_fnc_hhmm,
        mapGridPosition _p,
        _calText,
        _speed,
        format ["%1", round _fireAz],
        _rounds
    ]] call _fnc_set;
} forEach (uiNamespace getVariable ["cbr_rows", []]);
