#include "defines.h"

/*
    Function: cbr_fnc_record
    Кладе засічку в журнал станції. Журнал публічний: його бачить будь-хто
    з екіпажу, він переживає пересадку оператора, і мережею йде один
    запис на постріл.
*/

params ["_radar", "_pos", "_cal", "_speed", "_fireAz", "_base", "_floor"];
if (isNull _radar) exitWith {};

private _log = _radar getVariable ["cbr_acq", []];
private _old = time - CBR_ACQ_LIFE;
_log = _log select { (_x select 4) > _old };

/*
    Постріли з тієї самої позиції — одна вогнева. Але «та сама» це ще й
    той самий снаряд: танк і гаубиця з одного двору дають різні заміри.

    Поріг РОЗСУВАЄТЬСЯ на власну неточність станції, і без цього мод
    ламався на грубих радарах: у журналі лежить розмита точка, а шукаємо
    ми по справжньому стволу, і коли коло ширше за поріг, кожен постріл
    заводив новий запис — коло не звужувалось ніколи.
*/
private _idx = _log findIf {
    (_x select 1) distance2D _pos < (CBR_MERGE + (_x select 6) + _base)
    && {(_x select 2) == _cal}
    && {abs ((_x select 3) - _speed) < CBR_SAME_SPEED * ((_x select 3) max _speed)}
};

// Коло звужується з кожним заміром, доходячи до межі на тому пострілі,
// який заданий станції. min _base — щоб точність не ПОГІРШУВАЛАСЬ від
// замірів на ближній цілі, де базова похибка й так менша за межу
private _rounds = 1;
if (_idx > -1) then { _rounds = ((_log select _idx) select 5) + 1 };

private _shots = _radar getVariable ["cbr_shots", CBR_ERROR_SHOTS];
private _t = ((_rounds - 1) / ((_shots - 1) max 1)) min 1;
private _err = (_floor + (_base - _floor) * ((1 - _t) ^ 2)) min _base;

/*
    Зсув рівномірний по РАДІУСУ, а не по площі. Рівномірність по площі
    статистично чесніша, але в кільця площа росте з радіусом, і знаряддя
    тоді майже завжди опинялось скраю: ближче за пів радіуса — лише
    чверть випадків. Тут половина, і центр кола стає осмисленою здогадкою.
*/
private _fnc_blur = {
    params ["_p", "_radius"];
    private _r = _radius * random 1;
    private _a = random 360;
    [(_p select 0) + _r * sin _a, (_p select 1) + _r * cos _a, 0]
};

private _fix = [_pos, _err] call _fnc_blur;

if (_idx > -1) then {
    // заміри йдуть від СВІЖОГО пострілу: азимут змінюється, коли батарея
    // переносить вогонь, і лишався б від найпершого
    private _acq = _log select _idx;
    _acq set [1, _fix];
    _acq set [3, _speed];
    _acq set [4, time];
    _acq set [5, _rounds];
    _acq set [6, _err];
    _acq set [7, _fireAz];
} else {
    private _n = (_radar getVariable ["cbr_acqId", 0]) + 1;
    _radar setVariable ["cbr_acqId", _n];

    // [номер, точка, калібр, швидкість, час місії, пострілів, радіус,
    //  азимут стрільби, час доби]. Час доби окремо від часу місії:
    //  прискорення часу розводить їх, а вивести одне з одного не можна
    _log pushBack [_n, _fix, _cal, _speed, time, 1, _err, _fireAz, daytime];
    if (count _log > CBR_ACQ_MAX) then { _log deleteAt 0 };
};

_radar setVariable ["cbr_acq", _log, true];
