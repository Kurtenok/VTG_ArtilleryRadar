#include "defines.h"

/*
    Function: cbr_fnc_caliber
    Калібр боєприпасу в міліметрах, або 0, якщо визначити не вдалось.

    Береться з імені класу снаряда: Sh_155mm_AMOS, Sh_82mm_AMOS,
    R_230mm_HE. RHS для артилерії використовує ванільні класи (магазин
    rhs_mag_155mm_m795_28 стріляє Sh_155mm_AMOS), тож працює і там.

    Шукається САМЕ цифра перед «mm», а не перше входження «mm» у рядку:
    інакше в класі rhs_ammo_... збігом стало б слово «ammo».

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
