#include "defines.h"

// Кому доповідає радар. Порожня машина числиться цивільною, тому
// сторону беремо з екіпажу; лишилась цивільна — радар нічий

params ["_radar"];

private _side = side _radar;
if (_side isEqualTo civilian) then {
    private _crew = crew _radar;
    if (_crew isNotEqualTo []) then { _side = side (_crew select 0) };
};

_side
