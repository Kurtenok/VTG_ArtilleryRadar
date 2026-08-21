#include "defines.h"

/*
    Function: cbr_fnc_detect
    Постріл по ОДНІЙ станції, на машині її оператора. Тут дві різні
    задачі:

        снаряд   — відмітка на індикаторі, пишеться завжди;
        знаряддя — засічка в журналі, для неї снаряд треба ще й ВЕСТИ.
*/

// _pos це дуло — з нього рахується вогнева; _track це знятий стан
// снаряда на вільній ділянці дуги, з нього рахується сама дуга
params ["_radar", "_pos", "_track", "_ammo", "_speed", "_fireAz", "_t0"];
if (isNull _radar) exitWith {};

_track params ["_tPos", "_tVel"];
private _arc = [_tPos, _tVel, _ammo] call cbr_fnc_arc;

private _cal = [_ammo] call cbr_fnc_caliber;

// СНАРЯД. Пишеться незалежно від того, куди станція дивиться зараз:
// інакше доворот після пострілу нічого б не давав. Відлітали своє
// прибираються тут же, щоб не заводити окремий цикл
private _live = (_radar getVariable ["cbr_flight", []]) select {
    (time - (_x select 0)) < (((count (_x select 1)) - 1) * CBR_ARC_DT)
};
// номер потрібен пульту, щоб тримати видимість кожного снаряда окремо:
// список перебудовується щопострілу, а місце в ньому не стале
private _sid = (_radar getVariable ["cbr_shellId", 0]) + 1;
_radar setVariable ["cbr_shellId", _sid];

_live pushBack [_t0, _arc, _cal, _sid];
_radar setVariable ["cbr_flight", _live, true];

// ЗНАРЯДДЯ. Ділянка супроводу рахується з сектором на момент пострілу
private _win = [_radar, _arc] call cbr_fnc_track;
if (_win isEqualTo []) exitWith {};
_win params ["_tIn", "_tOut"];

// затримка ніколи не менша за супровід, інакше рахунок тривав би
// від'ємний час; модуль її теж підрізає
private _need = (_radar getVariable ["cbr_delay", CBR_DELAY]) max CBR_TRACK_MIN;

private _apex = 0;
private _hi = -1e10;
{
    if ((_x select 2) > _hi) then {
        _hi = _x select 2;
        _apex = _forEachIndex;
    };
} forEach _arc;

// вести треба лише CBR_TRACK_MIN секунд, і саме на висхідній гілці:
// спуск іде вже від вершини, екстраполяція через неї нічого не варта
if (((_apex * CBR_ARC_DT) min _tOut) - _tIn < CBR_TRACK_MIN) exitWith {};

// Як високо снаряд був, коли його взяли, — часткою від вершини. Це й є
// міра того, скільки підйому лишилось невидимим
private _h0 = (_arc select 0) select 2;
private _late = 0;
if (_hi - _h0 > 1) then {
    private _hAcq = (_arc select (((round (_tIn / CBR_ARC_DT)) max 0) min ((count _arc) - 1))) select 2;
    _late = ((_hAcq - _h0) / (_hi - _h0)) max 0 min 1;
};

private _sigma = _radar getVariable ["cbr_error", CBR_ERROR];
private _mult = 1 + CBR_ERROR_LATE * _late;

private _base = ((getPosASL _radar) distance _pos) * _sigma * _mult;

// межа звуження ходить за класом станції: десять метрів це для
// стандартної точності, вдвічі гірша впирається вдвічі далі
private _floor = CBR_ERROR_MIN * (_sigma / CBR_ERROR) * _mult;

/*
    Дві черги, і поділ між ними принциповий. ПЕРША — кінець супроводу:
    рівно тут вирішується, чи станція справді вела снаряд. ДРУГА —
    решта затримки, це вже РАХУНОК, і снаряд для нього не потрібен: він
    може давно вийти із зони чи впасти.
*/
private _mid = _arc select (((round ((_tIn + CBR_TRACK_MIN) / CBR_ARC_DT)) max 0) min ((count _arc) - 1));

[{
    params ["_radar", "_pos", "_cal", "_speed", "_fireAz", "_base", "_mid", "_floor", "_rest"];
    if (isNull _radar) exitWith {};

    // за час супроводу оператор міг довернути станцію — тоді вести
    // стало нічим, і засічки не буде
    private _sector = _radar getVariable ["cbr_sector", CBR_SECTOR];
    private _seen = true;
    if (_sector < 360) then {
        private _d = _mid vectorDiff (getPosASL _radar);
        private _az = (_d select 0) atan2 (_d select 1);
        private _bear = _radar getVariable ["cbr_bearing", getDir _radar];
        _seen = abs (((_az - _bear + 540) mod 360) - 180) <= _sector / 2;
    };
    if (!_seen) exitWith {};

    [
        { _this call cbr_fnc_record },
        [_radar, _pos, _cal, _speed, _fireAz, _base, _floor],
        _rest
    ] call CBA_fnc_waitAndExecute;
},
    [_radar, _pos, _cal, _speed, _fireAz, _base, _mid, _floor, _need - CBR_TRACK_MIN],
    ((_t0 + _tIn + CBR_TRACK_MIN) - time) max 0
] call CBA_fnc_waitAndExecute;
