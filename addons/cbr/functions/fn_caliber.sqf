#include "defines.h"

/*
    Function: cbr_fnc_caliber
    Калібр боєприпасу в міліметрах, або 0, якщо визначити не вдалось.

    Береться з імені класу: Sh_155mm_AMOS, Sh_82mm_AMOS, R_230mm_HE.
    Поля з калібром у CfgAmmo немає — caliber там це коефіцієнт
    пробиття (34 у ShellBase, 10 у 120-мм), а не міліметри.

    По батьках НЕ ходимо навмисно. RHS будує свою артилерію від
    ванільних класів чужого калібру, і успадковане ім'я бреше: Град
    вийшов би 230 мм замість 122, а 2С1 — 155 замість 122. Краще
    порожньо, ніж чуже число: оператор повірить йому.

    Тому калібр показується лише там, де він є в самому імені, а це
    саме артилерія й міномети. Решті станція пише швидкість і азимут —
    те, що вона справді міряє.

    Кеш на клас: імена сталі, а обстріл — це десятки пострілів поспіль.
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

// Шукається САМЕ цифра перед «mm», а не перше входження «mm» у рядку:
// інакше в класі rhs_ammo_... збігом стало б слово «ammo»
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
