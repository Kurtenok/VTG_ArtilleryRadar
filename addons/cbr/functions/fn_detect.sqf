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

private _need = _radar getVariable ["cbr_delay", CBR_DELAY];

private _apex = 0;
private _hi = -1e10;
{
    if ((_x select 2) > _hi) then {
        _hi = _x select 2;
        _apex = _forEachIndex;
    };
} forEach _arc;

if (((_apex * CBR_ARC_DT) min _tOut) - _tIn < _need) exitWith {};

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
    Засічка лягає в журнал не раніше, ніж набрано супровід: станція
    веде снаряд від входу в промінь і лише потім рахує назад.
*/
private _wait = (_t0 + _tIn + _need) - time;

// де снаряд буде, коли супровід набереться: якщо станцію на той час
// відвернуть, рахувати назад не буде з чого
private _mid = _arc select (((round ((_tIn + _need) / CBR_ARC_DT)) max 0) min ((count _arc) - 1));

[{
    params ["_radar", "_pos", "_cal", "_speed", "_fireAz", "_base", "_mid", "_floor"];
    if (isNull _radar) exitWith {};

    // сектор питається аж ТУТ: за час супроводу оператор міг довернути
    // станцію, і тоді засічки не буде — вести стало нічим
    private _sector = _radar getVariable ["cbr_sector", CBR_SECTOR];
    private _seen = true;
    if (_sector < 360) then {
        private _d = _mid vectorDiff (getPosASL _radar);
        private _az = (_d select 0) atan2 (_d select 1);
        private _bear = _radar getVariable ["cbr_bearing", getDir _radar];
        _seen = abs (((_az - _bear + 540) mod 360) - 180) <= _sector / 2;
    };
    if (!_seen) exitWith {};

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

        Межа тут не стала: за пізнє захоплення вона піднята разом із
        самим колом, тож обстріл із-за гори до десяти метрів не звузити.
    */
    private _rounds = 1;
    if (_idx > -1) then { _rounds = ((_log select _idx) select 5) + 1 };

    private _t = ((_rounds - 1) / ((CBR_ERROR_SHOTS - 1) max 1)) min 1;
    private _err = (_floor + (_base - _floor) * ((1 - _t) ^ 2)) min _base;

    // засічка зміщена всередині кола випадково, тож на індикаторі
    // знаряддя опиниться не в центрі, а будь-де в ньому
    private _fnc_blur = {
        params ["_p", "_radius"];
        private _r = _radius * sqrt (random 1);
        private _a = random 360;
        [(_p select 0) + _r * sin _a, (_p select 1) + _r * cos _a, 0]
    };

    private _fix = [_pos, _err] call _fnc_blur;

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
}, [_radar, _pos, _cal, _speed, _fireAz, _base, _mid, _floor], _wait max 0] call CBA_fnc_waitAndExecute;
