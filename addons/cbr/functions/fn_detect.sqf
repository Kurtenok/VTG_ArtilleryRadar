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

params ["_pos", "_kind", "_cal", "_speed", "_side"];

// [сторона, дальність до ближчого радара, його похибка]
private _hits = [];

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
    private _sector = _radar getVariable ["cbr_sector", CBR_SECTOR];
    if (_sector < 360) then {
        private _to = _pos vectorDiff _rPos;
        private _az = (_to select 0) atan2 (_to select 1);
        if (abs (((_az - getDir _radar + 540) mod 360) - 180) > _sector / 2) then { continue };
    };

    private _idx = _hits findIf { (_x select 0) isEqualTo _rSide };
    if (_idx > -1) then {
        if (_dist < ((_hits select _idx) select 1)) then {
            _hits set [_idx, [_rSide, _dist, _radar getVariable ["cbr_error", CBR_ERROR]]];
        };
    } else {
        _hits pushBack [_rSide, _dist, _radar getVariable ["cbr_error", CBR_ERROR]];
    };
} forEach cbr_radars;

{
    _x params ["_rSide", "_dist", "_error"];

    /*
        Похибка зворотної екстраполяції. Рівномірно по КРУГУ радіусом
        error*дальність: sqrt від рівномірного числа не дає точкам
        збиватися до центра, тобто промах чесний по всій площі.
    */
    private _r = _dist * _error * sqrt (random 1);
    private _a = random 360;
    private _fix = [(_pos select 0) + _r * sin _a, (_pos select 1) + _r * cos _a, 0];

    [_fix, _cal, _speed] remoteExec ["cbr_fnc_report", _rSide];
} forEach _hits;
