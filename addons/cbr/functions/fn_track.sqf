#include "defines.h"

/*
    Function: cbr_fnc_track
    Ділянка дуги, на якій снаряд справді в промені станції:
    [коли ввійшов, коли вийшов] у секундах польоту, або [], якщо не
    входив узагалі.

    Це ЄДИНА геометрія на весь мод, і від неї годуються дві різні
    задачі. Снаряду досить самого факту: увійшов у зону — видно, вийшов
    — зник, і за спиною станції він більше не тягнеться. Знаряддю цього
    мало: щоб порахувати назад до вогневої, ділянку треба ще й вести
    якийсь час.

    Тому тут не вирішується, чи буде засічка, — тут лише міряється, що
    станція бачила. Рішення приймає той, кому воно потрібне.

    Береться ПЕРШИЙ суцільний проміжок. Дуга може зачепити зону двічі,
    але другий захід — це вже кінець падіння, і станції з нього користі
    немає.

    Перешкоди двох різних родів, і однією перевіркою їх не взяти:
    рельєф читається відліками карти висот, а поставлені об'єкти —
    коротким променем біля самої антени. Про бункер карта висот не знає
    нічого, а стріляти променем на двадцять кілометрів заради далекої
    будівлі коштувало б дорожче за все інше разом.
*/

params ["_radar", "_arc"];

// антена стоїть над корпусом, і це не дрібниця: із неї видно за
// найближчий пагорб
private _eye = (getPosASL _radar) vectorAdd [0, 0, CBR_MAST];

private _range = _radar getVariable ["cbr_range", CBR_RANGE];
private _sector = _radar getVariable ["cbr_sector", CBR_SECTOR];
private _bear = _radar getVariable ["cbr_bearing", getDir _radar];
private _half = _sector / 2;

// чи не затуляє рельєф; викликається лише коли геометрія вже зійшлась
private _fnc_clear = {
    params ["_d", "_dist"];

    private _steps = (ceil (_dist / CBR_LOS_STEP)) max CBR_LOS_MIN;
    private _blocked = false;
    private _k = 1;

    while { !_blocked && {_k < _steps} } do {
        private _s = _eye vectorAdd (_d vectorMultiply (_k / _steps));
        _blocked = (getTerrainHeightASL [_s select 0, _s select 1]) > (_s select 2);
        _k = _k + 1;
    };

    !_blocked
};

/*
    Чи не затуляє щось поставлене поруч: стіна, дах, склепіння бункера.

    Промінь іде від САМОЇ машини, а не від щогли: чотири підняті метри
    виводять початок вище даху одноповерхового будинку, і станція
    зсередини бачила б усе небо.

    LOD штатні. «GEOM» — це геометрія зіткнень, нею перевіряють, чи
    влізе об'єкт, а не чи видно крізь нього; у будівель вона груба й
    променю не перешкода.
*/
private _fnc_open = {
    params ["_d", "_dist"];

    private _from = getPosASL _radar;
    private _end = _from vectorAdd (_d vectorMultiply ((CBR_CLEAR min _dist) / _dist));
    lineIntersectsSurfaces [_from, _end, _radar, objNull, true, 1] isEqualTo []
};

private _in = -1;
private _out = -1;
private _i = 0;

while { _out < 0 && {_i < count _arc} } do {
    private _d = (_arc select _i) vectorDiff _eye;
    private _dist = vectorMagnitude _d;

    /*
        Порядок перевірок за ціною. Геометрія це кілька множень, а
        профіль рельєфу — сотня звернень до карти висот, тож він
        останній і рахується лише для точок, які й так у зоні.
    */
    private _ok = _dist <= _range;

    // нижче кута променя снаряд ще не піднявся
    if (_ok) then {
        private _flat = sqrt (((_d select 0) ^ 2) + ((_d select 1) ^ 2));
        _ok = ((_d select 2) atan2 _flat) >= CBR_BEAM_MIN;
    };

    // напрямок сектора веде оператор із пульта; 360 = круговий огляд
    if (_ok && {_sector < 360}) then {
        private _az = (_d select 0) atan2 (_d select 1);
        _ok = abs (((_az - _bear + 540) mod 360) - 180) <= _half;
    };

    // рельєф дешевший за промінь, тож він перший
    if (_ok) then { _ok = [_d, _dist] call _fnc_clear };
    if (_ok) then { _ok = [_d, _dist] call _fnc_open };

    if (_ok) then {
        if (_in < 0) then { _in = _i };
    } else {
        if (_in > -1) then { _out = _i - 1 };
    };

    _i = _i + 1;
};

if (_in < 0) exitWith { [] };

// не вийшов до самого падіння — значить вів його до кінця
if (_out < 0) then { _out = (count _arc) - 1 };

[_in * CBR_ARC_DT, _out * CBR_ARC_DT]
