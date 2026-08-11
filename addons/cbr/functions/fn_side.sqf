#include "defines.h"

/*
    Function: cbr_fnc_side
    Кому доповідає цей радар. У машини з екіпажем сторона своя, порожня
    ж числиться цивільною — тоді беремо сторону з екіпажу, якщо він є.
    Лишилась цивільна — радар нічий і мовчить.
*/

params ["_radar"];

private _side = side _radar;
if (_side isEqualTo civilian) then {
    private _crew = crew _radar;
    if (_crew isNotEqualTo []) then { _side = side (_crew select 0) };
};

_side
