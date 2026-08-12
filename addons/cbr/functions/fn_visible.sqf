#include "defines.h"

/*
    Function: cbr_fnc_visible
    Чи бачила станція цей постріл: [_radar, _arc] -> Bool.

    Реєструється не гармата, а сам снаряд, тож питання не «де стоїть
    знаряддя», а «чи зайшла дуга в промінь і чи видно її звідти».
    Досить однієї такої точки: далі станція вже веде ціль.

    Вогнева позиція від цього не залежить — її станція рахує назад по
    дузі, і лягти вона може й за межами сектора. Так працює й справжня
    контрбатарейна: бачить снаряд, а показує знаряддя.
*/

params ["_radar", "_arc"];
if (_arc isEqualTo []) exitWith { false };

// антена стоїть над корпусом, і це не дрібниця: із неї видно за
// найближчий пагорб
private _eye = (getPosASL _radar) vectorAdd [0, 0, CBR_MAST];

private _range = _radar getVariable ["cbr_range", CBR_RANGE];
private _sector = _radar getVariable ["cbr_sector", CBR_SECTOR];
private _bear = _radar getVariable ["cbr_bearing", getDir _radar];
private _half = _sector / 2;

// найвищі точки дуги перевіряємо першими: майже завжди відповідь дає
// вже перша, і профіль рельєфу читається один раз замість двох десятків
private _ordered = [_arc, [], { -(_x select 2) }, "ASCEND"] call BIS_fnc_sortBy;

private _seen = false;
private _i = 0;

while { !_seen && {_i < count _ordered} } do {
    private _d = (_ordered select _i) vectorDiff _eye;
    _i = _i + 1;

    private _dist = vectorMagnitude _d;
    private _inBeam = _dist <= _range;

    // напрямок сектора веде оператор із пульта; 360 = круговий огляд
    if (_inBeam && {_sector < 360}) then {
        private _az = (_d select 0) atan2 (_d select 1);
        _inBeam = abs (((_az - _bear + 540) mod 360) - 180) <= _half;
    };

    if (_inBeam) then {
        private _steps = (ceil (_dist / CBR_LOS_STEP)) max CBR_LOS_MIN;
        private _blocked = false;
        private _k = 1;

        while { !_blocked && {_k < _steps} } do {
            private _s = _eye vectorAdd (_d vectorMultiply (_k / _steps));
            _blocked = (getTerrainHeightASL [_s select 0, _s select 1]) > (_s select 2);
            _k = _k + 1;
        };

        _seen = !_blocked;
    };
};

_seen
