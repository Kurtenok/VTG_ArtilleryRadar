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

params ["_pos", "_kind", "_cal", "_speed", "_fireAz", "_side"];

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
    if (_dist > ((_radar getVariable ["cbr_ranges", [CBR_RANGE_MORTAR, CBR_RANGE_GUN, CBR_RANGE_ROCKET]]) select _kind)) then { continue };

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

    /*
        Похибка зворотної екстраполяції. Рівномірно по КРУГУ радіусом
        error*дальність: sqrt від рівномірного числа не дає точкам
        збиватися до центра, тобто промах чесний по всій площі.
    */
    // РАДІУС невизначеності: у ньому десь і стоїть знаряддя
    private _err = _dist * (_radar getVariable ["cbr_error", CBR_ERROR]);

    // сама засічка зміщена всередині цього кола випадково, тож на
    // індикаторі знаряддя опиниться не в центрі, а будь-де в ньому
    private _r = _err * sqrt (random 1);
    private _a = random 360;
    private _fix = [(_pos select 0) + _r * sin _a, (_pos select 1) + _r * cos _a, 0];

    /*
        Журнал живе на самій станції й публічний: його бачить будь-хто з
        екіпажу, він переживає пересадку оператора, і мережею йде один
        запис на постріл, а не розсилка на всю сторону.
    */
    private _log = _radar getVariable ["cbr_acq", []];
    private _old = time - CBR_ACQ_LIFE;
    _log = _log select { (_x select 4) > _old };

    // постріли з тієї самої позиції — одна вогнева, а не десяток записів
    private _idx = _log findIf { (_x select 1) distance2D _fix < CBR_MERGE };
    if (_idx > -1) then {
        private _acq = _log select _idx;
        _acq set [4, time];
        _acq set [5, (_acq select 5) + 1];
    } else {
        private _n = (_radar getVariable ["cbr_acqId", 0]) + 1;
        _radar setVariable ["cbr_acqId", _n];

        // [0 номер, 1 точка, 2 калібр, 3 швидкість, 4 час, 5 пострілів,
        //  6 передано, 7 радіус невизначеності, 8 азимут стрільби]
        _log pushBack [_n, _fix, _cal, _speed, time, 1, false, _err, _fireAz];
        if (count _log > CBR_ACQ_MAX) then { _log deleteAt 0 };
    };

    _radar setVariable ["cbr_acq", _log, true];
} forEach _seen;
