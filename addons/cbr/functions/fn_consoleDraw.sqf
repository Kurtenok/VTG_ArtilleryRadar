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
        format ["%1", round (_d / 1000)], 0, CBR_RING_TEXT, "RobotoCondensed"
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
    _pos, CBR_ICON_SIZE, CBR_ICON_SIZE, 0, "", 0, 0, "RobotoCondensed"
];

// --- засічки ---
private _sel = uiNamespace getVariable ["cbr_sel", 0];
private _now = time;

{
    _x params ["_id", "_p", "_cal", "_speed", "_at", "_rounds", ["_sent", CBR_CH_NONE], ["_err", 0], ["_fireAz", 0]];

    private _age = _now - _at;
    private _fresh = _age < CBR_HOT_AGE;

    private _col = switch (true) do {
        case (_forEachIndex == _sel): { CBR_COL_SEL };
        case (_sent == CBR_CH_SIDE): { CBR_COL_SENT };
        case (_sent == CBR_CH_GROUP): { CBR_COL_SENT_GRP };
        case (_fresh): { CBR_COL_HOT };
        default { CBR_COL_MAIN };
    };

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

    private _label = if (_cal > 0) then {
        format ["%1  %2", _id, format [localize "STR_cbr_label", _cal, _speed]]
    } else {
        format ["%1  %2", _id, format [localize "STR_cbr_label_nocal", _speed]]
    };

    _map drawIcon [
        "\A3\ui_f\data\map\markers\military\triangle_CA.paa", _col,
        _p, CBR_ICON_SIZE, CBR_ICON_SIZE, 0,
        _label, 0, CBR_TEXT_SIZE, "RobotoCondensed"
    ];

    // свіжа засічка блимає другим кільцем: око само знайде її серед старих
    if (_fresh && {(floor (CBA_missionTime * 2)) % 2 == 0}) then {
        _map drawEllipse [_p, _err * 1.1, _err * 1.1, 0, _col, ""];
    };
} forEach (uiNamespace getVariable ["cbr_log", []]);
