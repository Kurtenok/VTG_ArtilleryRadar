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
// зона, що малюється, і є зона сканування: одне число, без усереднень
private _far = _veh getVariable ["cbr_range", CBR_RANGE];

private _half = _sector / 2;
private _fnc_at = {
    params ["_az", "_dist"];
    [(_pos select 0) + _dist * sin _az, (_pos select 1) + _dist * cos _az]
};

// --- дуги дальності ---
private _from = _bearing - _half;
private _to = _bearing + _half;

// проміжні дуги з постійним кроком, зовнішня — рівно на дальності
private _marks = [];
private _d = CBR_RING_STEP;
while { _d < _far } do {
    _marks pushBack [_d, CBR_COL_FAINT];
    _d = _d + CBR_RING_STEP;
};
_marks pushBack [_far, CBR_COL_DIM];

{
    _x params ["_d", "_col"];

    private _prev = [_from, _d] call _fnc_at;
    private _az = _from + CBR_ARC_STEP;
    while { _az < _to } do {
        private _p = [_az, _d] call _fnc_at;
        _map drawLine [_prev, _p, _col];
        _prev = _p;
        _az = _az + CBR_ARC_STEP;
    };
    _map drawLine [_prev, [_to, _d] call _fnc_at, _col];

    // підпис по осі сектора; півкілометри пишемо з десятою
    private _km = _d / 1000;
    private _txt = if ((_km - floor _km) < 0.05) then { str round _km } else { _km toFixed 1 };

    _map drawIcon [
        "#(argb,8,8,3)color(0,0,0,0)", CBR_COL_DIM,
        [_bearing, _d] call _fnc_at, 0, 0, 0,
        _txt, 0, CBR_RING_TEXT, "RobotoCondensed"
    ];
} forEach _marks;

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
    _pos, CBR_ICON_SIZE, CBR_ICON_SIZE, 0, "", 0, 0, "RobotoCondensed"
];

// --- засічки ---
private _sel = uiNamespace getVariable ["cbr_sel", 0];
private _now = time;

{
    _x params ["_id", "_p", "_cal", "_speed", "_at", "_rounds", ["_err", 0], ["_fireAz", 0], ["_when", 0]];

    private _age = _now - _at;
    private _col = [CBR_COL_FIX, CBR_COL_SEL] select (_forEachIndex == _sel);

    /*
        Коло невизначеності — не прикраса: його радіус і є похибка
        зворотної екстраполяції, а сама засічка зміщена всередині нього
        випадково. Тобто знаряддя стоїть ДЕСЬ У КОЛІ, і оператор бачить
        саме це, а не вдавану точність.
    */
    if (_err > 0) then {
        _map drawEllipse [_p, _err, _err, 0, _col, ""];
    };

    /*
        Куди било знаряддя: короткий вектор від засічки за азимутом
        стрільби. Каже, КОГО накривають, — з самої позиції цього не видно
    */
    private _len = (_err * 1.5) max 300;
    _map drawLine [
        _p,
        [(_p select 0) + _len * sin _fireAz, (_p select 1) + _len * cos _fireAz],
        _col
    ];

    // на індикаторі — усе, що потрібно для рішення, без заглядання в
    // журнал: чим били, скільки разів і коли
    private _what = if (_cal > 0) then {
        format [localize "STR_cbr_label", _cal, _speed]
    } else {
        format [localize "STR_cbr_label_nocal", _speed]
    };

    private _label = format ["%1  %2  x%3  %4", _id, _what, _rounds, [_when] call cbr_fnc_hhmm];

    /*
        Імпульс появи. Фаза береться від віку засічки, а не від
        загального часу, тож кожна нова починає власний відлік і не
        пульсує в такт із сусідніми.
    */
    private _pop = 0;
    if (_age < CBR_PING_FOR && {_err > 0}) then {
        private _t = (_age mod CBR_PING_PERIOD) / CBR_PING_PERIOD;

        private _r = _err * (0.35 + CBR_PING_GROW * _t);
        _map drawEllipse [
            _p, _r, _r, 0,
            [_col select 0, _col select 1, _col select 2, (1 - _t) * (_col select 3)],
            ""
        ];

        // сама позначка на початку імпульсу трохи набрякає
        _pop = 0.35 * (1 - _t);
    };

    private _size = CBR_ICON_SIZE * (1 + _pop);
    _map drawIcon [
        "\A3\ui_f\data\map\markers\military\triangle_CA.paa", _col,
        _p, _size, _size, 0,
        _label, 0, CBR_TEXT_SIZE, "RobotoCondensed"
    ];
} forEach (uiNamespace getVariable ["cbr_log", []]);
