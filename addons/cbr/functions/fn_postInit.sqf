#include "defines.h"

// Точка входу. Через ProjectileCreated іде КОЖНА куля місії, тому
// перевірки вишикувані від найдешевшої до найдорожчої.

if (isNil "cbr_radars") then { cbr_radars = [] };
if (isNil "cbr_active") then { cbr_active = [] };
if (isNil "cbr_ballistic") then { cbr_ballistic = createHashMap };

// наступним кадром: модулі Едему мають відпрацювати першими
[{ [] call cbr_fnc_stock }] call CBA_fnc_execNextFrame;
["CBA_settingsInitialized", { [] call cbr_fnc_stock }] call CBA_fnc_addEventHandler;
["CBA_SettingChanged", { [] call cbr_fnc_stock }] call CBA_fnc_addEventHandler;

// Сервер повідомляється ЗАВЖДИ, без перевірки «чи станція це»: перелік
// станцій приїжджає публічною змінною із запізненням, і посадка в цей
// проміжок лишала б радар мовчазним до кінця місії
if (hasInterface) then {
    ["vehicle", { [] remoteExecCall ["cbr_fnc_manned", 2] }] call CBA_fnc_addPlayerEventHandler;
};

if (isServer) then {
    // вихід гравця з гри посадку не знімає
    addMissionEventHandler ["HandleDisconnect", { [] call cbr_fnc_manned; false }];

    // страховка: гравець може опинитись у станції ще до її реєстрації,
    // і тоді події вже не буде
    [{ [] call cbr_fnc_manned }, CBR_MANNED_EVERY] call CBA_fnc_addPerFrameHandler;
};

addMissionEventHandler ["ProjectileCreated", {
    params ["_proj"];

    if (cbr_active isEqualTo []) exitWith {};
    if (!local _proj) exitWith {};

    // балістичність — властивість КЛАСУ, а isKindOf ходить по дереву
    // спадкування; куль за бій летять тисячі
    private _type = typeOf _proj;
    private _info = cbr_ballistic get _type;
    if (isNil "_info") then {
        // кероване не рахується: ПТУР і ЗУР летять своїм двигуном
        private _rocket = _proj isKindOf "RocketCore" && {!(_proj isKindOf "MissileCore")};

        // thrust питається лише в ракет: у снарядів він успадкований від
        // рушійного класу движка й непередбачуваний
        private _burn = 0;
        if (_rocket) then {
            private _cfg = configFile >> "CfgAmmo" >> _type;
            _burn = getNumber (_cfg >> "initTime") + getNumber (_cfg >> "thrustTime");
        };

        /*
            Реактивна артилерія — це SubmunitionCore, а не снаряд і не
            ракета. Град, MLRS і ATACMS усі ростуть від ванільного
            R_230mm_HE: він сам летить усю дугу, а за triggerDistance до
            цілі стає бойовою частиною R_230mm_fly. Отже саме носій і є
            та дуга, яку веде станція, — без нього реактивний вогонь для
            радара не існував узагалі.

            Бойова частина другим слідом не піде: вона з'являється вже
            за півкілометра до цілі, на падінні, і її відсіває кут
            кидання. Так само відсіваються й касетні уламки.
        */
        private _sub = _proj isKindOf "SubmunitionCore";

        _info = [_rocket || {_proj isKindOf "ShellCore"} || _sub, _burn, _sub];
        cbr_ballistic set [_type, _info];
    };
    _info params ["_ballistic", "_burn", "_sub"];
    if (!_ballistic) exitWith {};

    private _vel = velocity _proj;
    private _speed = vectorMagnitude _vel;
    if (_speed < CBR_MIN_SPEED) exitWith {};

    /*
        Настильна над променем не піднімається; відсів до мережі, бо
        більшість пострілів у бою саме настильні.

        Реактивну артилерію кут кидання НЕ судить. В Армі R_230mm_HE
        летить без опору повітря, тож 690 м/с несуть його на 48 км, а
        установка вище 65 градусів не піднімається — і обчислювач на
        будь-яку робочу дальність бере пологе рішення: 6 градусів на
        10 км там, де справжній Град кидає під 30-50. Кут тут артефакт
        конфіга, а не форма траєкторії, тож вирішує вже cbr_fnc_track
        по самій дузі.
    */
    private _elev = asin (((_vel select 2) / _speed) max -1 min 1);
    if (_elev < CBR_MIN_ELEV && {!_sub}) exitWith {};

    (getShotParents _proj) params ["_srcVeh", "_srcMan"];
    private _src = [_srcVeh, _srcMan] select (!isNull _srcMan);
    if (isNull _src) exitWith {};

    // доповідає лише машина стрільця: копію снаряда симулює кожен клієнт
    if (!local _src) exitWith {};

    // Грубий відсів, щоб не гнати мережею постріли з іншого кінця карти.
    // Міряється не до знаряддя, а по тому, куди снаряд здатен долетіти:
    // батарея може стояти поза зоною, а снаряди залітати в неї
    private _pos = getPosASL _proj;
    private _reach = _speed * _speed / 9.81;
    private _to = [];

    {
        _x params ["_radar", "_op"];

        // сторона стрільця не питається: чий постріл — не справа станції
        if ((getPosASL _radar) distance _pos > (_radar getVariable ["cbr_range", CBR_RANGE]) + _reach) then { continue };

        _to pushBack [_radar, _op];
    } forEach cbr_active;

    if (_to isEqualTo []) exitWith {};

    // азимут пострілу каже, КОГО накривають
    private _fireAz = (round ((_vel select 0) atan2 (_vel select 1)) + 360) mod 360;

    // Реактивний від дула не рахується: доки працює двигун, дуга не
    // балістична. Чекаємо вигоряння й знімаємо стан із самого снаряда
    private _fnc_report = {
        params ["_proj", "_to", "_pos", "_vel", "_type", "_speed", "_fireAz"];

        // замір після вигоряння лише УТОЧНЮЄ дугу: не дожив — доповідь
        // однаково йде, по дульних даних
        private _track = [_pos, _vel];
        if (!isNull _proj) then {
            private _now = velocity _proj;
            _track = [getPosASL _proj, _now];

            // у реактивного на старті швидкість ще не набрана
            _speed = round (vectorMagnitude _now);
        };

        {
            _x params ["_radar", "_op"];
            [_radar, _pos, _track, _type, _speed, _fireAz, time]
                remoteExec ["cbr_fnc_detect", _op];
        } forEach _to;
    };

    private _args = [_proj, _to, _pos, _vel, _type, round _speed, _fireAz];

    // двигун є в одиниць боєприпасів; решта доповідає одразу
    if (_burn <= 0) exitWith { _args call _fnc_report };

    [_fnc_report, _args, _burn] call CBA_fnc_waitAndExecute;
}];
