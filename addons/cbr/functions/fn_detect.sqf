#include "defines.h"

/*
    Function: cbr_fnc_detect
    Постріл по ОДНІЙ станції, на машині її оператора. Рахує той, хто
    станцією користується: сервер із цього не робить нічого.

    Тут дві РІЗНІ задачі, і плутати їх не можна:

        снаряд   — відмітка на індикаторі. Записується завжди, а видно
                   її чи ні, вирішує пульт у реальному часі;
        знаряддя — засічка в журналі. Щоб порахувати назад до вогневої,
                   станції треба ще й ВЕСТИ снаряд якийсь час.

    Звідси й наслідки. Батарея за межами зони, чиї снаряди залітають у
    промінь, дає відмітки й засічку — станція бачить не гармату, а
    снаряд. Снаряд, що лише черкнув край зони, дасть відмітку, але
    засічки з нього не вийде. А доворот уже після пострілу покаже
    снаряд, але вогневої по ньому не дасть.

    Сторону вже перевірила машина стрільця; уся геометрія — тут, бо для
    неї треба прорахувати дугу.
*/

// _pos це дуло — з нього рахується вогнева; _track це знятий стан
// снаряда на вільній ділянці дуги, з нього рахується сама дуга
params ["_radar", "_pos", "_track", "_ammo", "_speed", "_fireAz", "_t0"];
if (isNull _radar) exitWith {};

_track params ["_tPos", "_tVel"];
private _arc = [_tPos, _tVel, _ammo] call cbr_fnc_arc;

private _cal = [_ammo] call cbr_fnc_caliber;

/*
    СНАРЯД. Записується ЗАВЖДИ, без огляду на те, чи дивиться станція
    зараз у той бік: видимість вирішується в реальному часі на пульті.
    Інакше доворот уже після пострілу нічого б не давав — снаряда для
    станції просто не існувало б.

    Відлітали своє прибираються тут же, за новим пострілом, щоб не
    заводити окремий цикл на прибирання.
*/
private _live = (_radar getVariable ["cbr_flight", []]) select {
    (time - (_x select 0)) < (((count (_x select 1)) - 1) * CBR_ARC_DT)
};
// номер потрібен, щоб пульт міг тримати видимість кожного снаряда
// окремо: список перебудовується щопострілу, а місце в ньому не стале
private _sid = (_radar getVariable ["cbr_shellId", 0]) + 1;
_radar setVariable ["cbr_shellId", _sid];

_live pushBack [_t0, _arc, _cal, _sid];
_radar setVariable ["cbr_flight", _live, true];

/*
    ЗНАРЯДДЯ. Тут мало бачити — треба ВЕСТИ, і саме на підйомі: назад до
    вогневої станція рахує по висхідній гілці, а спуск іде вже від
    вершини, і екстраполяція через неї нічого не варта.

    Тому ділянка супроводу рахується окремо й із сектором на момент
    пострілу: побачити снаряд заднім числом, довернувшись пізніше, для
    відмітки досить, а для засічки — ні.

    Саме тому станція, відвернута від батареї, бачить її снаряди, але
    самої батареї не показує.
*/
private _win = [_radar, _arc] call cbr_fnc_track;
if (_win isEqualTo []) exitWith {};
_win params ["_tIn", "_tOut"];

/*
    Затримка ніколи не менша за супровід: інакше «рахунок» тривав би
    від'ємний час. Модуль її теж підрізає, це друга лінія оборони.
*/
private _need = (_radar getVariable ["cbr_delay", CBR_DELAY]) max CBR_TRACK_MIN;

private _apex = 0;
private _hi = -1e10;
{
    if ((_x select 2) > _hi) then {
        _hi = _x select 2;
        _apex = _forEachIndex;
    };
} forEach _arc;

// вести треба CBR_TRACK_MIN секунд, не всю затримку: решта її —
// рахунок, і снаряд для нього вже не потрібен
if (((_apex * CBR_ARC_DT) min _tOut) - _tIn < CBR_TRACK_MIN) exitWith {};

/*
    Як високо снаряд був, коли його взяли, — часткою від вершини. Це і
    є міра того, скільки підйому лишилось невидимим: за хребтом станція
    ловить його вже високо, і назад іти доводиться наосліп.
*/
private _h0 = (_arc select 0) select 2;
private _late = 0;
if (_hi - _h0 > 1) then {
    private _hAcq = (_arc select (((round (_tIn / CBR_ARC_DT)) max 0) min ((count _arc) - 1))) select 2;
    _late = ((_hAcq - _h0) / (_hi - _h0)) max 0 min 1;
};

// базова похибка зворотної екстраполяції: дальність, клас станції й
// штраф за те, що взяли пізно
private _sigma = _radar getVariable ["cbr_error", CBR_ERROR];
private _mult = 1 + CBR_ERROR_LATE * _late;

private _base = ((getPosASL _radar) distance _pos) * _sigma * _mult;

// межа звуження ходить за класом станції: десять метрів — це для
// стандартної точності, вдвічі гірша впирається вдвічі далі
private _floor = CBR_ERROR_MIN * (_sigma / CBR_ERROR) * _mult;

/*
    Дві черги, і поділ між ними принциповий.

    ПЕРША — кінець супроводу. Станції треба провести снаряд CBR_TRACK_MIN
    секунд, і рівно тут вирішується, чи вона його справді вела: сектор
    питається на ту мить, коли супровід добігав кінця.

    ДРУГА — решта затримки. Це вже РАХУНОК, і снаряд для нього не
    потрібен: він може давно вийти із зони чи впасти. Раніше видимість
    вимагалась усю затримку цілком, і швидкий снаряд, що прошивав зону
    за кілька секунд, не давав вогневої взагалі.
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
