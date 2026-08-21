#include "defines.h"

/*
    Function: cbr_fnc_track
    Ділянка дуги, на якій снаряд у промені станції: [ввійшов, вийшов] у
    секундах польоту, або [], якщо не входив.

    Береться ПЕРШИЙ суцільний проміжок: другий захід — це вже кінець
    падіння, і користі з нього станції немає.
*/

params ["_radar", "_arc"];

// з щогли видно за найближчий пагорб
private _eye = (getPosASL _radar) vectorAdd [0, 0, CBR_MAST];

private _range = _radar getVariable ["cbr_range", CBR_RANGE];
private _sector = _radar getVariable ["cbr_sector", CBR_SECTOR];
private _bear = _radar getVariable ["cbr_bearing", getDir _radar];
private _half = _sector / 2;

// рельєф читається картою висот, а не променем: на двадцять кілометрів
// той коштував би непорівнянно дорожче
private _fnc_clear = {
    params ["_d", "_dist"];

    private _steps = (ceil (_dist / CBR_LOS_STEP)) max CBR_LOS_MIN;
    private _blocked = false;
    private _k = 1;

    while { !_blocked && {_k < _steps} } do {
        private _s = _eye vectorAdd (_d vectorMultiply (_k / _steps));
        _blocked = (getTerrainHeightASL [_s select 0, _s select 1]) > (_s select 2);
        _k = _k + 1;
    };

    !_blocked
};

// Поставлене поруч — дах, склепіння бункера: карта висот про нього не
// знає нічого. Промінь іде від МАШИНИ, а не від щогли: підняті чотири
// метри вивели б початок вище даху одноповерхового будинку
private _fnc_open = {
    params ["_d", "_dist"];

    private _from = getPosASL _radar;
    private _end = _from vectorAdd (_d vectorMultiply ((CBR_CLEAR min _dist) / _dist));
    lineIntersectsSurfaces [_from, _end, _radar, objNull, true, 1] isEqualTo []
};

private _in = -1;
private _out = -1;
private _i = 0;

while { _out < 0 && {_i < count _arc} } do {
    private _d = (_arc select _i) vectorDiff _eye;
    private _dist = vectorMagnitude _d;

    // порядок за ціною: геометрія це кілька множень, профіль рельєфу —
    // сотня звернень до карти висот
    private _ok = _dist <= _range;

    // нижче кута променя снаряд ще не піднявся
    if (_ok) then {
        private _flat = sqrt (((_d select 0) ^ 2) + ((_d select 1) ^ 2));
        _ok = ((_d select 2) atan2 _flat) >= CBR_BEAM_MIN;
    };

    // напрямок сектора веде оператор; 360 = круговий огляд
    if (_ok && {_sector < 360}) then {
        private _az = (_d select 0) atan2 (_d select 1);
        _ok = abs (((_az - _bear + 540) mod 360) - 180) <= _half;
    };

    if (_ok) then { _ok = [_d, _dist] call _fnc_clear };
    if (_ok) then { _ok = [_d, _dist] call _fnc_open };

    if (_ok) then {
        if (_in < 0) then { _in = _i };
    } else {
        if (_in > -1) then { _out = _i - 1 };
    };

    _i = _i + 1;
};

if (_in < 0) exitWith { [] };

// не вийшов до самого падіння — значить вів його до кінця
if (_out < 0) then { _out = (count _arc) - 1 };

[_in * CBR_ARC_DT, _out * CBR_ARC_DT]
