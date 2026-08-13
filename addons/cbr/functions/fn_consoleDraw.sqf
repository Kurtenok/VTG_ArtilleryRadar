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

private _from = _bearing - _half;
private _to = _bearing + _half;

/*
    Сітка сектора — дуги дальності, їх підписи й межі — від кадру не
    залежить: вона змінюється лише коли оператор довернув сектор або
    станція переїхала. Тому рахується один раз і лежить готовою.

    Раніше це були три сотні синусів щокадру: вісім дуг по два десятки
    точок, і все наново на кожному малюванні.
*/
private _key = [round (_pos select 0), round (_pos select 1), round _bearing, _sector, _far];
private _grid = uiNamespace getVariable ["cbr_grid", []];

if ((_grid param [0, []]) isNotEqualTo _key) then {
    private _lines = [];
    private _texts = [];

    private _fnc_arc = {
        params ["_d", "_col"];

        private _prev = [_from, _d] call _fnc_at;
        private _az = _from + CBR_ARC_STEP;
        while { _az < _to } do {
            private _p = [_az, _d] call _fnc_at;
            _lines pushBack [_prev, _p, _col];
            _prev = _p;
            _az = _az + CBR_ARC_STEP;
        };
        _lines pushBack [_prev, [_to, _d] call _fnc_at, _col];

        // підпис по осі сектора; півкілометри пишемо з десятою
        private _km = _d / 1000;
        _texts pushBack [
            CBR_ICO_NONE, CBR_COL_DIM,
            [_bearing, _d] call _fnc_at, 0, 0, 0,
            if ((_km - floor _km) < 0.05) then { str round _km } else { _km toFixed 1 },
            0, CBR_RING_TEXT, "RobotoCondensed"
        ];
    };

    // проміжні дуги з постійним кроком, зовнішня — рівно на дальності
    private _d = CBR_RING_STEP;
    while { _d < _far } do {
        [_d, CBR_COL_FAINT] call _fnc_arc;
        _d = _d + CBR_RING_STEP;
    };
    [_far, CBR_COL_DIM] call _fnc_arc;

    // межі сектора
    _lines pushBack [_pos, [_from, _far] call _fnc_at, CBR_COL_DIM];
    _lines pushBack [_pos, [_to, _far] call _fnc_at, CBR_COL_DIM];

    _grid = [_key, _lines, _texts];
    uiNamespace setVariable ["cbr_grid", _grid];
};

{ _map drawLine _x } forEach (_grid select 1);
{ _map drawIcon _x } forEach (_grid select 2);

// Розгортка навмисно повільніша за справжню — на екрані вона має
// читатися оком. Синус дає сповільнення біля країв, як у приводу
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
private _labels = uiNamespace getVariable ["cbr_labels", []];
private _now = time;

{
    _x params [
        "_id", "_p", "_cal", "_speed", "_at", "_rounds",
        ["_err", 0], ["_fireAz", 0], ["_when", 0]
    ];

    private _age = _now - _at;
    private _col = [CBR_COL_FIX, CBR_COL_SEL] select (_forEachIndex == _sel);

    // Радіус кола і є похибка, а засічка зміщена всередині нього
    // випадково: знаряддя стоїть ДЕСЬ у колі, а не в центрі
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

    // підпис зібрано в оновленні журналу: він міняється подіями, а не
    // щокадру, і складати його по два десятки разів на кадр нема сенсу
    private _label = _labels param [_forEachIndex, ""];

    /*
        Імпульс появи. Фаза береться від віку засічки, а не від
        загального часу, тож кожна нова починає власний відлік і не
        пульсує в такт із сусідніми.
    */
    if (_age < CBR_PING_FOR && {_err > 0}) then {
        private _t = (_age mod CBR_PING_PERIOD) / CBR_PING_PERIOD;

        private _r = _err * (0.35 + CBR_PING_GROW * _t);
        _map drawEllipse [
            _p, _r, _r, 0,
            [_col select 0, _col select 1, _col select 2, (1 - _t) * (_col select 3)],
            ""
        ];
    };

    // Значка у вогневої немає навмисно: її межі й так окреслює коло
    // невизначеності, а позначка поверх нього вдавала б точку, якої
    // станція не знає. Нульовий розмір лишає від виклику самий підпис
    _map drawIcon [
        CBR_ICO_NONE, _col,
        _p, 0, 0, 0,
        _label, 0, CBR_TEXT_SIZE, "RobotoCondensed"
    ];
} forEach (uiNamespace getVariable ["cbr_log", []]);

/*
    Снаряди в польоті — крапкою, без хвоста. Дуга прорахована ще при
    захопленні, тож кадр коштує підстановки часу.

    Малюється РІВНО той проміжок, поки снаряд у промені: увійшов —
    з'явився, вийшов — зник. За спиною станції він не тягнеться, бо
    там його вже ніхто не веде.

    Сектор при цьому питається ЗАРАЗ, а не береться з моменту
    захоплення: оператор міг довернути станцію, а вести те, на що вона
    більше не дивиться, вона не може.
*/
private _fmtCal = localize "STR_cbr_track";
private _fmtNo = localize "STR_cbr_track_nocal";
private _losMap = uiNamespace getVariable ["cbr_los", createHashMap];

{
    _x params ["_t0", "_arc", "_cal", "_tIn", "_tOut", "_id"];

    private _t = _now - _t0;
    if (_t < _tIn || {_t > _tOut}) then { continue };

    // перекритий будівлею — його зараз не видно. Новий снаряд поки не
    // дійшла черга вважається видимим: ділянку супроводу він уже пройшов
    if (!((_losMap getOrDefault [_id, [true]]) select 0)) then { continue };

    // положення за часом: відліки дуги рівні, тож досить підстановки
    private _last = (count _arc) - 1;
    private _u = ((_t / CBR_ARC_DT) max 0) min _last;
    private _i = floor _u;
    private _at = _arc select _i;
    if (_i < _last) then {
        _at = _at vectorAdd (((_arc select (_i + 1)) vectorDiff _at) vectorMultiply (_u - _i));
    };

    if (_sector < 360) then {
        private _az = ((_at select 0) - (_pos select 0)) atan2 ((_at select 1) - (_pos select 1));
        if (abs (((_az - _bearing + 540) mod 360) - 180) > _half) then { continue };
    };

    // швидкість дають самі відліки дуги: вони рівні за часом
    private _v = round (((_arc select ((_i + 1) min _last)) distance (_arc select _i)) / CBR_ARC_DT);
    private _h = round (_at select 2);

    _map drawIcon [
        CBR_ICO_SHELL, CBR_COL_MAIN,
        _at, CBR_SHELL_SIZE, CBR_SHELL_SIZE, 0,
        [format [_fmtNo, _v, _h], format [_fmtCal, _cal, _v, _h]] select (_cal > 0),
        0, CBR_TEXT_SIZE, "RobotoCondensed"
    ];
} forEach (_veh getVariable ["cbr_flight", []]);
