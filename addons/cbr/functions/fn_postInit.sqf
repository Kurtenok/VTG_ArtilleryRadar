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

// штатні радари зі списку класів; наступним кадром — модулі Едему
// мають відпрацювати першими
[{ [] call cbr_fnc_stock }] call CBA_fnc_execNextFrame;
["CBA_settingsInitialized", { [] call cbr_fnc_stock }] call CBA_fnc_addEventHandler;
["CBA_SettingChanged", { [] call cbr_fnc_stock }] call CBA_fnc_addEventHandler;

addMissionEventHandler ["ProjectileCreated", {
    params ["_proj"];

    // не наш снаряд — його порахує машина того, хто стріляв
    if (!local _proj) exitWith {};

    // куля відсіюється двома перевірками типу й далі не йде
    private _kind = -1;
    if (_proj isKindOf "ShellCore") then {
        _kind = CBR_KIND_GUN;
    } else {
        // кероване не рахується: контрбатарейний радар шукає балістику,
        // а ПТУР і ЗУР летять своїм двигуном і своєю логікою
        if (_proj isKindOf "RocketCore" && {!(_proj isKindOf "MissileCore")}) then {
            _kind = CBR_KIND_ROCKET;
        };
    };
    if (_kind < 0) exitWith {};

    if (cbr_radars isEqualTo []) exitWith {};

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

    // міномет відрізняється дульною швидкістю, а не крутизною дуги:
    // по куту гаубиця на навісній траєкторії щоразу була б «мінометом»
    if (_kind == CBR_KIND_GUN && {_speed < CBR_MORTAR_SPEED}) then { _kind = CBR_KIND_MORTAR };

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

    // на карту йдуть ЗАМІРИ, а не здогад про тип знаряддя: калібр і
    // дульна швидкість, а вже що це за система — справа розрахунку
    [_pos, _kind, [typeOf _proj] call cbr_fnc_caliber, round _speed, side _src] remoteExec ["cbr_fnc_detect", 2];
}];
