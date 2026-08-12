#include "defines.h"

/*
    Function: cbr_fnc_detect
    Постріл проти всіх радарів місії, лише на сервері: рішення про
    засічку не має розходитись.

    Лінія візування до знаряддя не перевіряється навмисно — радар
    бачить не гармату, а снаряд у верхній частині дуги, де рельєфу вже
    немає. Тому він і працює по цілях за хребтом.
*/

params ["_pos", "_vel", "_ammo", "_speed", "_fireAz", "_side"];

private _cal = [_ammo] call cbr_fnc_caliber;

// точка падіння одна на постріл, скільки б станцій його не бачило
private _impact = [_pos, _vel, _ammo] call cbr_fnc_impact;

// журнал у кожної станції свій; карти засічка не чіпає, поки оператор
// не виведе її сам
private _seen = [];

{
    private _radar = _x;
    if (isNull _radar || {!alive _radar}) then { continue };

    private _rSide = [_radar] call cbr_fnc_side;
    if (_rSide isEqualTo civilian) then { continue };

    // свій вогонь радар теж бачить, але доповідати про нього нема сенсу
    if (_rSide getFriend _side >= 0.6) then { continue };

    private _rPos = getPosASL _radar;
    private _dist = _rPos distance _pos;
    if (_dist > (_radar getVariable ["cbr_range", CBR_RANGE])) then { continue };

    // напрямок сектора веде оператор із пульта; 360 = круговий огляд
    private _sector = _radar getVariable ["cbr_sector", CBR_SECTOR];
    if (_sector < 360) then {
        private _to = _pos vectorDiff _rPos;
        private _az = (_to select 0) atan2 (_to select 1);
        private _bearing = _radar getVariable ["cbr_bearing", getDir _radar];
        if (abs (((_az - _bearing + 540) mod 360) - 180) > _sector / 2) then { continue };
    };

    _seen pushBack [_radar, _dist];
} forEach cbr_radars;

{
    _x params ["_radar", "_dist"];

    // базова похибка зворотної екстраполяції на цій дальності
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

        // постріли з тієї самої позиції — одна вогнева, а не десяток записів
        private _idx = _log findIf { (_x select 1) distance2D _pos < CBR_MERGE };

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

        /*
            Точка падіння розмивається окремо й сильніше: похибка та
            сама кутова, але рахується до НЕЇ, а не до вогневої, і ще
            множиться, бо шлях уперед станція не бачила.
        */
        // прильоти НАКОПИЧУЮТЬСЯ: по кількох розривах видно всю смугу,
        // яку накриває батарея, а не лише останній снаряд
        private _hits = [];
        if (_idx > -1) then {
            private _fresh = time - CBR_IMPACT_LIFE;
            _hits = ((_log select _idx) param [9, []]) select { (_x select 2) > _fresh };
        };

        if (_impact isNotEqualTo []) then {
            private _hitErr = ((getPosASL _radar) distance _impact)
                * (_radar getVariable ["cbr_error", CBR_ERROR]) * CBR_IMPACT_ERR;

            _hits pushBack [[_impact, _hitErr] call _fnc_blur, _hitErr, time];
            if (count _hits > CBR_IMPACT_MAX) then { _hits deleteAt 0 };
        };

        if (_idx > -1) then {
            private _acq = _log select _idx;
            _acq set [1, _fix];      // уточнена позиція
            _acq set [4, time];
            _acq set [5, _rounds];
            _acq set [6, _err];      // і звужене коло
            _acq set [9, _hits];
        } else {
            private _n = (_radar getVariable ["cbr_acqId", 0]) + 1;
            _radar setVariable ["cbr_acqId", _n];

            /*
                [0 номер, 1 точка, 2 калібр, 3 швидкість, 4 час місії,
                 5 пострілів, 6 радіус невизначеності, 7 азимут стрільби,
                 8 час доби]

                Час доби окремо від часу місії: перший потрібен оператору
                на екрані, другий — для віку засічки. Вивести один з
                одного не можна, бо прискорення часу розводить їх.
            */
            _log pushBack [_n, _fix, _cal, _speed, time, 1, _err, _fireAz, daytime, _hits];
            if (count _log > CBR_ACQ_MAX) then { _log deleteAt 0 };
        };

        _radar setVariable ["cbr_acq", _log, true];
    }, [_radar, _pos, _cal, _speed, _fireAz, _base, _impact], _radar getVariable ["cbr_delay", CBR_DELAY]] call CBA_fnc_waitAndExecute;
} forEach _seen;
