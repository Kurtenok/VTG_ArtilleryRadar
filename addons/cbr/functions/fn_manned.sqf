#include "defines.h"

/*
    Function: cbr_fnc_manned
    Перелік ДІЮЧИХ станцій: [станція, оператор]. Веде сервер, знають усі.
    Поки він порожній, мод не коштує майже нічого — обробник пострілу
    виходить на першому ж порівнянні.

    Оператор один на станцію навмисно: двоє рахували б той самий постріл
    двічі, і обстріл у журналі подвоївся б.
*/

if (!isServer) exitWith {};

private _now = [];
{
    if (!alive _x) then { continue };

    private _ops = (crew _x) select { isPlayer _x };
    if (_ops isNotEqualTo []) then { _now pushBack [_x, _ops select 0] };
} forEach cbr_radars;

if (_now isEqualTo (missionNamespace getVariable ["cbr_active", []])) exitWith {};

cbr_active = _now;
publicVariable "cbr_active";
