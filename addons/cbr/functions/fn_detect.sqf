#include "defines.h"

/*
    Function: cbr_fnc_detect
    Постріл проти всіх радарів місії. Тільки на сервері: рішення про
    засічку не має розходитись, а машина стрільця не мусить знати, хто
    саме її бачить.

    Лінія візування до самого знаряддя НЕ перевіряється, і це не
    спрощення. Радар бачить не гармату, а снаряд у верхній частині дуги —
    а вона в артилерії йде за кілометр і вище, де рельєфу вже немає.
    Через це контрбатарейний радар і працює по цілях за хребтом.

    Засічка одна на СТОРОНУ, а не на радар: два радари, що побачили той
    самий постріл, не мусять малювати дві позначки. З них береться
    ближчий — у нього менша похибка.
*/

params ["_pos", "_cal", "_speed", "_fireAz", "_side"];

// засічки лягають у журнал КОЖНОЇ станції, що побачила постріл: карту
// вони не чіпають, поки оператор не передасть їх сам
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

    // сектор відлічується від носа машини: розвернули радар — змінився
    // й сектор. 360 означає круговий огляд
    // напрямок сектора веде ОПЕРАТОР із консолі; поки її не відкривали,
    // сектор дивиться туди ж, куди й машина
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
        params ["_radar", "_pos", "_cal", "_speed", "_fireAz", "_base"];
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
        private _r = _err * sqrt (random 1);
        private _a = random 360;
        private _fix = [(_pos select 0) + _r * sin _a, (_pos select 1) + _r * cos _a, 0];

        if (_idx > -1) then {
            private _acq = _log select _idx;
            _acq set [1, _fix];      // уточнена позиція
            _acq set [4, time];
            _acq set [5, _rounds];
            _acq set [6, _err];      // і звужене коло
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
            _log pushBack [_n, _fix, _cal, _speed, time, 1, _err, _fireAz, daytime];
            if (count _log > CBR_ACQ_MAX) then { _log deleteAt 0 };
        };

        _radar setVariable ["cbr_acq", _log, true];
    }, [_radar, _pos, _cal, _speed, _fireAz, _base], _radar getVariable ["cbr_delay", CBR_DELAY]] call CBA_fnc_waitAndExecute;
} forEach _seen;
