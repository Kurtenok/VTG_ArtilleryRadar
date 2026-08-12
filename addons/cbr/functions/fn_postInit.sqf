#include "defines.h"

/*
    Точка входу. Циклів немає жодного: постріл ловиться там, де снаряд
    створено, і в спокої мод не коштує нічого.

    Через обробник іде КОЖНА куля місії, тому перевірки вишикувані від
    найдешевшої до найдорожчої.
*/

if (isNil "cbr_radars") then { cbr_radars = [] };

// балістичність класу боєприпасу: питається в конфіга раз і лишається
if (isNil "cbr_ballistic") then { cbr_ballistic = createHashMap };

// штатні радари зі списку класів; наступним кадром — модулі Едему
// мають відпрацювати першими
[{ [] call cbr_fnc_stock }] call CBA_fnc_execNextFrame;
["CBA_settingsInitialized", { [] call cbr_fnc_stock }] call CBA_fnc_addEventHandler;
["CBA_SettingChanged", { [] call cbr_fnc_stock }] call CBA_fnc_addEventHandler;

addMissionEventHandler ["ProjectileCreated", {
    params ["_proj"];

    // без радарів у місії куля коштує одного порівняння
    if (cbr_radars isEqualTo []) exitWith {};

    // грубий відсів; головна перевірка нижче, по стрільцеві
    if (!local _proj) exitWith {};

    /*
        Балістика це чи ні — властивість КЛАСУ, а не снаряда, тож
        питаємо конфіг раз на клас і далі беремо з кеша: isKindOf ходить
        по дереву спадкування, а куль за бій летять тисячі.

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

    // Останній фільтр перед мережею: чи дотягується постріл хоч до
    // якогось радара — cbr_maxRange це найбільша дальність у місії
    private _pos = getPosASL _proj;
    private _max = missionNamespace getVariable ["cbr_maxRange", 0];
    if (cbr_radars findIf { !isNull _x && {(getPosASL _x) distance _pos < _max} } < 0) exitWith {};

    // сторона стрільця: наводчик, а якщо його немає — сама установка
    (getShotParents _proj) params ["_srcVeh", "_srcMan"];
    private _src = [_srcVeh, _srcMan] select (!isNull _srcMan);
    if (isNull _src) exitWith {};

    // Доповідає лише машина стрільця: юніт локальний рівно на одній,
    // а копію снаряда симулює кожен клієнт — звідси й подвійний рахунок
    if (!local _src) exitWith {};

    // на карту йдуть ЗАМІРИ, а не здогад про тип знаряддя: калібр і
    // дульна швидкість, а вже що це за система — справа розрахунку.
    // Азимут пострілу каже, КОГО накривають, чого з самої позиції не видно
    private _az = (_vel select 0) atan2 (_vel select 1);
    private _fireAz = (round _az + 360) mod 360;

    /*
        Реактивний снаряд рахувати від дула не можна: доки працює
        двигун, дуга не балістична, а напрямок тяги йде за корпусом і
        зі сторони не відтворюється. Тому чекаємо вигоряння й знімаємо
        стан із самого снаряда — далі він летить уже вільно.

        Двигун є в одиниць боєприпасів; артилерія, міномети й танки
        йдуть без затримки тим самим рядком, що й раніше.
    */
    if (_burn <= 0) exitWith {
        [_pos, [_pos, _vel], _type, round _speed, _fireAz, side _src]
            remoteExec ["cbr_fnc_detect", 2];
    };

    [{
        params ["_proj", "_pos", "_vel", "_type", "_speed", "_fireAz", "_side"];

        /*
            Замір після вигоряння лише УТОЧНЮЄ точку падіння. Сама
            засічка від нього не залежить, тож якщо снаряд до цієї миті
            не дожив, доповідь однаково йде — по дульних даних.
        */
        private _track = [_pos, _vel];
        if (!isNull _proj) then {
            private _now = velocity _proj;
            _track = [getPosASL _proj, _now];

            // швидкість беремо тут: у реактивного вона на старті ще не
            // набрана, і в доповідь пішло б заниження
            _speed = round (vectorMagnitude _now);
        };

        [_pos, _track, _type, _speed, _fireAz, _side] remoteExec ["cbr_fnc_detect", 2];
    }, [_proj, _pos, _vel, _type, round _speed, _fireAz, side _src], _burn] call CBA_fnc_waitAndExecute;
}];
