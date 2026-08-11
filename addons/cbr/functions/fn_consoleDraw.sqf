#include "defines.h"

/*
    Function: cbr_fnc_consoleDraw
    Малювання поверх індикатора. Викликається рушієм щокадру, тож тут
    немає ані пошуків, ані звернень до мережі — лише геометрія за
    готовими числами.

    Малюється те саме, що бачить оператор справжньої станції: межі
    сектора, дуги дальності, розгортка й засічки. Дуга з відрізків —
    інакше її нема чим накреслити на карті.
*/

params ["_map"];

private _veh = uiNamespace getVariable ["cbr_veh", objNull];
if (isNull _veh) exitWith {};

private _pos = getPosATL _veh;
private _bearing = _veh getVariable ["cbr_bearing", getDir _veh];
private _sector = _veh getVariable ["cbr_sector", CBR_SECTOR];
private _ranges = _veh getVariable ["cbr_ranges", [CBR_RANGE_MORTAR, CBR_RANGE_GUN, CBR_RANGE_ROCKET]];
private _far = selectMax _ranges;

private _half = _sector / 2;
private _fnc_at = {
    params ["_az", "_dist"];
    [(_pos select 0) + _dist * sin _az, (_pos select 1) + _dist * cos _az]
};

// --- дуги дальності ---
private _from = _bearing - _half;
private _to = _bearing + _half;

for "_ring" from 1 to CBR_RINGS do {
    private _d = _far * _ring / CBR_RINGS;
    private _col = [CBR_COL_FAINT, CBR_COL_DIM] select (_ring == CBR_RINGS);

    private _prev = [_from, _d] call _fnc_at;
    private _az = _from + CBR_ARC_STEP;
    while { _az < _to } do {
        private _p = [_az, _d] call _fnc_at;
        _map drawLine [_prev, _p, _col];
        _prev = _p;
        _az = _az + CBR_ARC_STEP;
    };
    _map drawLine [_prev, [_to, _d] call _fnc_at, _col];

    // підпис дальності по осі сектора
    _map drawIcon [
        "#(argb,8,8,3)color(0,0,0,0)", CBR_COL_DIM,
        [_bearing, _d] call _fnc_at, 0, 0, 0,
        format ["%1", round (_d / 1000)], 0, 22 * CBR_PH, "RobotoCondensed"
    ];
};

// --- межі сектора ---
_map drawLine [_pos, [_from, _far] call _fnc_at, CBR_COL_DIM];
_map drawLine [_pos, [_to, _far] call _fnc_at, CBR_COL_DIM];

/*
    Розгортка. Справжня станція проходить сектор кілька разів на
    секунду; тут навмисно повільніше — на екрані це має читатися оком,
    а не миготіти. Кут береться від синуса, тож промінь сповільнюється
    біля країв, як механічний привід.
*/
private _phase = sin (360 * (CBA_missionTime / CBR_SWEEP_PERIOD));
private _sw = _bearing + _half * _phase;
_map drawLine [_pos, [_sw, _far] call _fnc_at, CBR_COL_MAIN];

// сама станція
_map drawIcon [
    "\A3\ui_f\data\map\markers\nato\o_installation.paa", CBR_COL_MAIN,
    _pos, 26 * CBR_PW, 26 * CBR_PH, 0, "", 0, 0, "RobotoCondensed"
];

// --- засічки ---
private _sel = uiNamespace getVariable ["cbr_sel", 0];
private _now = time;

{
    _x params ["_id", "_p", "_cal", "_speed", "_at", "_rounds"];

    private _age = _now - _at;
    private _col = switch (true) do {
        case (_forEachIndex == _sel): { CBR_COL_SEL };
        case (_x param [6, false]): { CBR_COL_SENT };
        case (_age < CBR_HOT_AGE): { CBR_COL_HOT };
        default { CBR_COL_MAIN };
    };

    _map drawIcon [
        "\A3\ui_f\data\map\markers\military\triangle_CA.paa", _col,
        _p, 22 * CBR_PW, 22 * CBR_PH, 0,
        format ["%1", _id], 0, 20 * CBR_PH, "RobotoCondensed"
    ];

    // свіжу засічку обводимо колом, що стягується: око само її знайде
    if (_age < CBR_HOT_AGE) then {
        private _r = 400 * (1 - _age / CBR_HOT_AGE) + 60;
        _map drawEllipse [_p, _r, _r, 0, _col, ""];
    };
} forEach (uiNamespace getVariable ["cbr_log", []]);
