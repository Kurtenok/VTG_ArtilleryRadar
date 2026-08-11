#include "defines.h"

/*
    Точка входу.

    Циклів немає жодного — і це головне рішення мода. Постріл ловиться
    там, де снаряд СТВОРЕНО, тобто на машині стрільця, рівно один раз.
    Сервер нічого не сканує й не опитує: у спокої радар не коштує ані
    кадру, а під обстрілом — по одному повідомленню на постріл, та й то
    лише коли радар справді може його побачити.

    Порядок перевірок — від найдешевшої до найдорожчої, бо через цей
    обробник проходить КОЖНА куля в місії.
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

    /*
        Найдешевша перевірка — першою: без жодного радара в місії мод не
        робить нічого взагалі, і кожна куля коштує рівно одного
        порівняння порожнього масиву.
    */
    if (cbr_radars isEqualTo []) exitWith {};

    // дешевий відсів чужих снарядів; головна перевірка — нижче, по
    // стрільцеві, бо копію пострілу симулює кожна машина
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

    /*
        Кут кидання. Настильна траєкторія не піднімається над променем
        радара — саме тому танкові постріли й ПТУР для нього не існують.
        Перевірка стоїть до будь-якої мережі: більшість пострілів у бою
        якраз настильні.
    */
    private _elev = asin (((_vel select 2) / _speed) max -1 min 1);
    if (_elev < CBR_MIN_ELEV) exitWith {};

    /*
        Останній фільтр перед мережею: чи є взагалі радар, до якого
        постріл дотягується. cbr_maxRange — найбільша дальність серед
        усіх радарів місії, тож одне порівняння відсікає обстріли на
        іншому кінці карти.
    */
    private _pos = getPosASL _proj;
    private _max = missionNamespace getVariable ["cbr_maxRange", 0];
    if (cbr_radars findIf { !isNull _x && {(getPosASL _x) distance _pos < _max} } < 0) exitWith {};

    // сторона стрільця: наводчик, а якщо його немає — сама установка
    (getShotParents _proj) params ["_srcVeh", "_srcMan"];
    private _src = [_srcVeh, _srcMan] select (!isNull _srcMan);
    if (isNull _src) exitWith {};

    /*
        Доповідає лише машина, якій належить СТРІЛЕЦЬ. Юніт локальний
        рівно на одній машині — це гарантія, якої немає в снаряда:
        його копію симулює кожен клієнт, і «local» у неї своя в кожного.
        Без цієї перевірки один постріл рахувався стільки разів, скільки
        гравців його бачило.
    */
    if (!local _src) exitWith {};

    // на карту йдуть ЗАМІРИ, а не здогад про тип знаряддя: калібр і
    // дульна швидкість, а вже що це за система — справа розрахунку
    // азимут пострілу: куди саме било знаряддя. Станція рахує і точку
    // старту, і точку падіння, тож напрямок стрільби вона знає — а він
    // каже, КОГО накривають, чого з самої позиції не видно
    private _az = (_vel select 0) atan2 (_vel select 1);

    [_pos, [_type] call cbr_fnc_caliber, round _speed, (round _az + 360) mod 360, side _src]
        remoteExec ["cbr_fnc_detect", 2];
}];
