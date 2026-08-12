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
    private _ballistic = cbr_ballistic get _type;
    if (isNil "_ballistic") then {
        _ballistic = _proj isKindOf "ShellCore"
            || {_proj isKindOf "RocketCore" && {!(_proj isKindOf "MissileCore")}};
        cbr_ballistic set [_type, _ballistic];
    };
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
    // дульна швидкість, а вже що це за система — справа розрахунку
    // азимут пострілу: куди саме било знаряддя. Станція рахує і точку
    // старту, і точку падіння, тож напрямок стрільби вона знає — а він
    // каже, КОГО накривають, чого з самої позиції не видно
    private _az = (_vel select 0) atan2 (_vel select 1);

    [_pos, _vel, _type, round _speed, (round _az + 360) mod 360, side _src]
        remoteExec ["cbr_fnc_detect", 2];
}];
