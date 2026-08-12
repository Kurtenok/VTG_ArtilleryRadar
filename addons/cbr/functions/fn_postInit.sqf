#include "defines.h"

/*
    Точка входу. Циклів немає жодного: постріл ловиться там, де снаряд
    створено, і в спокої мод не коштує нічого.

    Через обробник іде КОЖНА куля місії, тому перевірки вишикувані від
    найдешевшої до найдорожчої, а найперша з них — чи сидить за пультом
    хоч хтось. Без оператора не рахується нічого й ніде.
*/

if (isNil "cbr_radars") then { cbr_radars = [] };
if (isNil "cbr_active") then { cbr_active = [] };

// балістичність класу боєприпасу й час роботи двигуна: питається в
// конфіга раз на клас і далі береться з кеша
if (isNil "cbr_ballistic") then { cbr_ballistic = createHashMap };

// штатні радари зі списку класів; наступним кадром — модулі Едему
// мають відпрацювати першими
[{ [] call cbr_fnc_stock }] call CBA_fnc_execNextFrame;
["CBA_settingsInitialized", { [] call cbr_fnc_stock }] call CBA_fnc_addEventHandler;
["CBA_SettingChanged", { [] call cbr_fnc_stock }] call CBA_fnc_addEventHandler;

/*
    Хто сів за пульт, а хто вийшов. Стежить сам клієнт: подія CBA ловить
    будь-яку зміну машини, зокрема й посадку скриптом, тоді як подіями
    на самій станції довелося б покладатися на її локальність.

    Сервера турбуємо лише коли зачеплено саму станцію — а не щоразу,
    коли хтось сідає в буханку.
*/
if (hasInterface) then {
    ["vehicle", {
        params ["_unit", "_veh"];

        private _in = cbr_radars findIf { _x isEqualTo _veh } > -1;
        if (!_in && {!(missionNamespace getVariable ["cbr_wasIn", false])}) exitWith {};

        cbr_wasIn = _in;
        [] remoteExecCall ["cbr_fnc_manned", 2];
    }] call CBA_fnc_addPlayerEventHandler;
};

// вихід гравця з гри посадку не знімає, тож перелік оновлюємо й тут
if (isServer) then {
    addMissionEventHandler ["HandleDisconnect", { [] call cbr_fnc_manned; false }];
};

addMissionEventHandler ["ProjectileCreated", {
    params ["_proj"];

    // без діючої станції постріл коштує одного порівняння
    if (cbr_active isEqualTo []) exitWith {};

    // грубий відсів; головна перевірка нижче, по стрільцеві
    if (!local _proj) exitWith {};

    /*
        Балістичність це чи ні — властивість КЛАСУ, а не снаряда, тож
        питаємо конфіг раз на клас: isKindOf ходить по дереву
        спадкування, а куль за бій летять тисячі.

        Кероване не рахується: радар шукає балістику, а ПТУР і ЗУР
        летять своїм двигуном і своєю логікою.
    */
    private _type = typeOf _proj;
    private _info = cbr_ballistic get _type;
    if (isNil "_info") then {
        private _rocket = _proj isKindOf "RocketCore" && {!(_proj isKindOf "MissileCore")};

        /*
            Скільки горить двигун — питаємо ЛИШЕ в ракет. У снарядів
            thrust успадковується від рушійного класу движка, тіла
            якого в конфігах немає, тож значення там непередбачуване.
            Наявність двигуна визначає саме дерево класів, а не поле.
        */
        private _burn = 0;
        if (_rocket) then {
            private _cfg = configFile >> "CfgAmmo" >> _type;
            _burn = getNumber (_cfg >> "initTime") + getNumber (_cfg >> "thrustTime");
        };

        _info = [_rocket || {_proj isKindOf "ShellCore"}, _burn];
        cbr_ballistic set [_type, _info];
    };
    _info params ["_ballistic", "_burn"];
    if (!_ballistic) exitWith {};

    private _vel = velocity _proj;
    private _speed = vectorMagnitude _vel;
    if (_speed < CBR_MIN_SPEED) exitWith {};

    // Настильна траєкторія над променем не піднімається; перевірка до
    // мережі, бо більшість пострілів у бою саме настильні
    private _elev = asin (((_vel select 2) / _speed) max -1 min 1);
    if (_elev < CBR_MIN_ELEV) exitWith {};

    // сторона стрільця: наводчик, а якщо його немає — сама установка
    (getShotParents _proj) params ["_srcVeh", "_srcMan"];
    private _src = [_srcVeh, _srcMan] select (!isNull _srcMan);
    if (isNull _src) exitWith {};

    // Доповідає лише машина стрільця: юніт локальний рівно на одній,
    // а копію снаряда симулює кожен клієнт — звідси й подвійний рахунок
    if (!local _src) exitWith {};

    /*
        Кому летить доповідь. Це ГРУБИЙ відсів, щоб не гнати мережею
        постріли з іншого кінця карти: чи бачила станція снаряд, вона
        вирішує сама, прорахувавши дугу.

        Дальність до ЗНАРЯДДЯ тут не годиться: батарея може стояти поза
        зоною, а снаряди залітати в неї. Тому межа рахується по тому,
        куди снаряд узагалі здатен долетіти, — а це не більше за v²/g,
        і далі за цю суму станції нема чого чекати.
    */
    private _pos = getPosASL _proj;
    private _side = side _src;
    private _reach = _speed * _speed / 9.81;
    private _to = [];

    {
        _x params ["_radar", "_op"];

        // свій вогонь станція теж бачить, доповідати про нього нема сенсу
        if (([_radar] call cbr_fnc_side) getFriend _side >= 0.6) then { continue };

        if ((getPosASL _radar) distance _pos > (_radar getVariable ["cbr_range", CBR_RANGE]) + _reach) then { continue };

        _to pushBack [_radar, _op];
    } forEach cbr_active;

    if (_to isEqualTo []) exitWith {};

    // азимут пострілу каже, КОГО накривають, чого з самої позиції не видно
    private _fireAz = (round ((_vel select 0) atan2 (_vel select 1)) + 360) mod 360;

    /*
        Реактивний снаряд рахувати від дула не можна: доки працює
        двигун, дуга не балістична, а напрямок тяги йде за корпусом і
        зі сторони не відтворюється. Тому чекаємо вигоряння й знімаємо
        стан із самого снаряда — далі він летить уже вільно.
    */
    private _fnc_report = {
        params ["_proj", "_to", "_pos", "_vel", "_type", "_speed", "_fireAz"];

        /*
            Замір після вигоряння лише УТОЧНЮЄ дугу. Сама засічка від
            нього не залежить, тож якщо снаряд до цієї миті не дожив,
            доповідь однаково йде — по дульних даних.
        */
        private _track = [_pos, _vel];
        if (!isNull _proj) then {
            private _now = velocity _proj;
            _track = [getPosASL _proj, _now];

            // у реактивного швидкість на старті ще не набрана, і в
            // доповідь пішло б заниження
            _speed = round (vectorMagnitude _now);
        };

        {
            _x params ["_radar", "_op"];
            [_radar, _pos, _track, _type, _speed, _fireAz, time]
                remoteExec ["cbr_fnc_detect", _op];
        } forEach _to;
    };

    private _args = [_proj, _to, _pos, _vel, _type, round _speed, _fireAz];

    // двигун є в одиниць боєприпасів; артилерія, міномети й танки
    // доповідають одразу
    if (_burn <= 0) exitWith { _args call _fnc_report };

    [_fnc_report, _args, _burn] call CBA_fnc_waitAndExecute;
}];
