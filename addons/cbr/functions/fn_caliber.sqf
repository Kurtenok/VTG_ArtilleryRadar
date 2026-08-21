#include "defines.h"

/*
    Function: cbr_fnc_caliber
    Калібр боєприпасу в міліметрах, або 0, якщо визначити не вдалось.

    Береться з ІМЕНІ класу: Sh_155mm_AMOS. Поля з калібром у CfgAmmo
    немає — caliber там це коефіцієнт пробиття, а не міліметри.

    По батьках НЕ ходимо: RHS будує артилерію від ванільних класів чужого
    калібру, і Град вийшов би 230 мм замість 122. Краще порожньо, ніж
    чуже число — оператор повірить йому.
*/

params ["_ammo"];

private _cache = missionNamespace getVariable "cbr_calCache";
if (isNil "_cache") then {
    _cache = createHashMap;
    missionNamespace setVariable ["cbr_calCache", _cache];
};

private _hit = _cache get _ammo;
if (!isNil "_hit") exitWith { _hit };

private _chars = toArray (toLowerANSI _ammo);
private _digits = [];
private _cal = 0;

// САМЕ цифра перед «mm», а не перше входження «mm»: інакше в класі
// rhs_ammo_... збігом стало б слово «ammo»
{
    if (_cal == 0) then {
        if (_x >= 48 && {_x <= 57}) then {          // цифра
            _digits pushBack _x;
        } else {
            // 109 — «m»: два підряд одразу за цифрами й дають калібр
            if (
                _digits isNotEqualTo []
                && {_x == 109}
                && {(_chars param [_forEachIndex + 1, 0]) == 109}
            ) then {
                _cal = parseNumber (toString _digits);
            };
            _digits = [];
        };
    };
} forEach _chars;

_cache set [_ammo, _cal];
_cal
