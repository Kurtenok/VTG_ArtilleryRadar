#include "defines.h"

/*
    Function: cbr_fnc_detect
    Постріл по ОДНІЙ станції, на машині її оператора.

    Рахує той, хто станцією користується: сервер із цього не робить
    нічого. Важке тут одне — зворотна екстраполяція й точка падіння, і
    лягає воно рівно на того, хто дивиться на індикатор.

    Дальність, сектор і сторону вже перевірила машина стрільця: сюди
    доходять лише постріли, які станція справді бачить.

    Лінія візування до знаряддя не перевіряється навмисно — радар
    бачить не гармату, а снаряд у верхній частині дуги, де рельєфу вже
    немає. Тому він і працює по цілях за хребтом.
*/

// _pos це дуло — з нього рахується вогнева; _track це знятий стан
// снаряда на вільній ділянці дуги, з нього рахується точка падіння
params ["_radar", "_pos", "_track", "_ammo", "_speed", "_fireAz"];
if (isNull _radar) exitWith {};

private _cal = [_ammo] call cbr_fnc_caliber;

_track params ["_tPos", "_tVel"];
private _impact = [_tPos, _tVel, _ammo] call cbr_fnc_impact;

// базова похибка зворотної екстраполяції на цій дальності
private _dist = (getPosASL _radar) distance _pos;
private _base = _dist * (_radar getVariable ["cbr_error", CBR_ERROR]);

/*
    Засічка лягає в журнал не миттєво: станції треба відстежити
    ділянку дуги, перш ніж рахувати назад. Затримка — за модулем.
*/
[{
    params ["_radar", "_pos", "_cal", "_speed", "_fireAz", "_base", "_impact"];
    if (isNull _radar) exitWith {};

    /*
        Журнал живе на самій станції й публічний: його бачить будь-хто
        з екіпажу, він переживає пересадку оператора, і мережею йде
        один запис на постріл, а не розсилка на всю сторону.
    */
    private _log = _radar getVariable ["cbr_acq", []];
    private _old = time - CBR_ACQ_LIFE;
    _log = _log select { (_x select 4) > _old };

    /*
        Постріли з тієї самої позиції — одна вогнева, а не десяток
        записів. Але «та сама» це ще й той самий снаряд: якщо з двору
        б'ють і танк, і гаубиця, це дві різні цілі, які просто стоять
        поруч, і зводити їх в одну не можна.
    */
    private _idx = _log findIf {
        (_x select 1) distance2D _pos < CBR_MERGE
        && {(_x select 2) == _cal}
        && {abs ((_x select 3) - _speed) < CBR_SAME_SPEED * ((_x select 3) max _speed)}
    };

    /*
        Скільки замірів уже є по цій позиції — стільки разів її й
        міряли. Коло звужується з кожним, доходячи до межі на
        CBR_ERROR_SHOTS пострілі; далі точніше вже не буде.

        min _base — на випадок ближньої цілі, де базова похибка й так
        менша за межу: точність не має ПОГІРШУВАТИСЬ від замірів.
    */
    private _rounds = 1;
    if (_idx > -1) then { _rounds = ((_log select _idx) select 5) + 1 };

    private _t = ((_rounds - 1) / ((CBR_ERROR_SHOTS - 1) max 1)) min 1;
    private _err = (CBR_ERROR_MIN + (_base - CBR_ERROR_MIN) * ((1 - _t) ^ 2)) min _base;

    // засічка зміщена всередині кола випадково, тож на індикаторі
    // знаряддя опиниться не в центрі, а будь-де в ньому
    private _fnc_blur = {
        params ["_p", "_radius"];
        private _r = _radius * sqrt (random 1);
        private _a = random 360;
        [(_p select 0) + _r * sin _a, (_p select 1) + _r * cos _a, 0]
    };

    private _fix = [_pos, _err] call _fnc_blur;

    // прильоти НАКОПИЧУЮТЬСЯ: по кількох розривах видно всю смугу,
    // яку накриває батарея, а не лише останній снаряд
    private _hits = [];
    if (_idx > -1) then {
        private _fresh = time - CBR_IMPACT_LIFE;
        _hits = ((_log select _idx) param [9, []]) select { (_x select 2) > _fresh };
    };

    /*
        Точка падіння розмивається окремо й сильніше: похибка та сама
        кутова, але рахується до НЕЇ, а не до вогневої, і ще множиться,
        бо шлях уперед станція не бачила.
    */
    if (_impact isNotEqualTo []) then {
        private _hitErr = ((getPosASL _radar) distance _impact)
            * (_radar getVariable ["cbr_error", CBR_ERROR]) * CBR_IMPACT_ERR;

        _hits pushBack [[_impact, _hitErr] call _fnc_blur, _hitErr, time];
        if (count _hits > CBR_IMPACT_MAX) then { _hits deleteAt 0 };
    };

    if (_idx > -1) then {
        // Заміри йдуть від СВІЖОГО пострілу. Калібр у записі вже той
        // самий, а от азимут змінюється, коли батарея переносить
        // вогонь, і лишався б від найпершого пострілу
        private _acq = _log select _idx;
        _acq set [1, _fix];      // уточнена позиція
        _acq set [3, _speed];
        _acq set [4, time];
        _acq set [5, _rounds];
        _acq set [6, _err];      // і звужене коло
        _acq set [7, _fireAz];
        _acq set [9, _hits];
    } else {
        private _n = (_radar getVariable ["cbr_acqId", 0]) + 1;
        _radar setVariable ["cbr_acqId", _n];

        /*
            [0 номер, 1 точка, 2 калібр, 3 швидкість, 4 час місії,
             5 пострілів, 6 радіус невизначеності, 7 азимут стрільби,
             8 час доби, 9 прильоти]

            Час доби окремо від часу місії: перший потрібен оператору
            на екрані, другий — для віку засічки. Вивести один з
            одного не можна, бо прискорення часу розводить їх.
        */
        _log pushBack [_n, _fix, _cal, _speed, time, 1, _err, _fireAz, daytime, _hits];
        if (count _log > CBR_ACQ_MAX) then { _log deleteAt 0 };
    };

    _radar setVariable ["cbr_acq", _log, true];
}, [_radar, _pos, _cal, _speed, _fireAz, _base, _impact], _radar getVariable ["cbr_delay", CBR_DELAY]] call CBA_fnc_waitAndExecute;
