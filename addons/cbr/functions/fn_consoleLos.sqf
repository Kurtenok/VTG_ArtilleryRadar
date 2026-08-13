#include "defines.h"

/*
    Function: cbr_fnc_consoleLos
    Пряма видимість до снарядів у польоті: промінь від станції до самого
    снаряда. Рельєф тут ні до чого, його вже врахувала ділянка супроводу
    — цей промінь шукає те, чого карта висот не знає взагалі: будівлі,
    ангари, склепіння.

    За кадр іде РІВНО ОДИН промінь, по колу. Пачка променів разом дала б
    оператору смикання рівно тоді, коли по ньому працює батарея, а так
    навантаження рівне, скільки б снарядів не летіло: десяток облітається
    за шосту частину секунди, три десятки — за півсекунди.

    Кожен снаряд перепитується не частіше, ніж раз на CBR_LOS_EVERY: за
    пів секунди снаряд не зайде за будинок і не вийде з-за нього.
*/

private _veh = uiNamespace getVariable ["cbr_veh", objNull];
if (isNull _veh) exitWith {};

private _live = _veh getVariable ["cbr_flight", []];
private _n = count _live;

private _los = uiNamespace getVariable "cbr_los";
if (isNil "_los") then {
    _los = createHashMap;
    uiNamespace setVariable ["cbr_los", _los];
};

// між нальотами список порожній — саме тоді й прибираємо за собою
if (_n == 0) exitWith {
    if (count _los > 0) then { uiNamespace setVariable ["cbr_los", createHashMap] };
};

private _from = getPosASL _veh;
private _now = time;
private _at = uiNamespace getVariable ["cbr_losAt", -1];

private _done = false;
private _k = 0;

// шукаємо перший снаряд, якому час перепитатись; коло замикається за
// один прохід, тож зайвої роботи не буде навіть коли перевіряти нема кого
while { !_done && {_k < _n} } do {
    _k = _k + 1;
    _at = (_at + 1) mod _n;

    (_live select _at) params ["_t0", "_arc", "", "_tIn", "_tOut", "_id"];

    private _t = _now - _t0;
    if (_t >= _tIn && {_t <= _tOut}) then {
        private _was = _los getOrDefault [_id, [true, -1e10]];

        if (_now - (_was select 1) >= CBR_LOS_EVERY) then {
            // положення за часом: відліки дуги рівні, тож досить підстановки
            private _last = (count _arc) - 1;
            private _u = ((_t / CBR_ARC_DT) max 0) min _last;
            private _i = floor _u;
            private _p = _arc select _i;
            if (_i < _last) then {
                _p = _p vectorAdd (((_arc select (_i + 1)) vectorDiff _p) vectorMultiply (_u - _i));
            };

            // сама станція з розрахунку виключена, інакше затуляла б себе
            _los set [_id, [
                lineIntersectsSurfaces [_from, _p, _veh, objNull, true, 1] isEqualTo [],
                _now
            ]];

            _done = true;
        };
    };
};

uiNamespace setVariable ["cbr_losAt", _at];
