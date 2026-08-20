#include "defines.h"

/*
    Function: cbr_fnc_stockApply
    Підключення однієї штатної машини.

    Реєструє лише сервер, а пункт меню будує кожен у себе — інакше на
    виділеному сервері пульта не було б ні в кого.
*/

params ["_veh"];

if (isNull _veh) exitWith {};
if ((cbr_stockList findIf { _veh isKindOf _x }) < 0) exitWith {};

// модуль Едему старший: машину, яку він уже налаштував, штатний список
// не чіпає
if (isServer && {!(_veh getVariable ["cbr_initDone", false])}) then {
    [_veh, []] call cbr_fnc_addRadar;
};

/*
    Меню будується НЕЗАЛЕЖНО від реєстрації: та приходить публічною
    змінною із запізненням, і чекати на неї означало б знову ловити ту
    саму мережеву щілину. Сама дія все одно показується лише тоді, коли
    станція налаштована, — це вирішує cbr_fnc_canUse.
*/
if (hasInterface) then { [_veh] call cbr_fnc_createAceMenu };
