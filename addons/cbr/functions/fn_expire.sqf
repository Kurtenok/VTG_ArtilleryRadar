#include "defines.h"

/*
    Function: cbr_fnc_expire
    Строк позначки вийшов. Перевіряє, а не видаляє наосліп: по позиції
    могли вистрілити ще раз і продовжити строк — тоді таймер просто
    переставляється на залишок. Тож спрацювань на позначку рівно
    стільки, скільки разів по ній переставали стріляти.
*/

params ["_fix"];

private _left = (_fix select 3) - time;
if (_left > 0) exitWith {
    [{ _this call cbr_fnc_expire }, _this, _left] call CBA_fnc_waitAndExecute;
};

deleteMarkerLocal (_fix select 0);
cbr_fixes deleteAt (cbr_fixes find _fix);
