#include "defines.h"

/*
    Function: cbr_fnc_acquire
    Де станція взяла снаряд: [точка дуги, її номер] або [], якщо не
    взяла зовсім.

    Реєструється не гармата, а сам снаряд, тож питання не «де стоїть
    знаряддя», а «де дуга вперше зайшла в промінь і показалась з-за
    рельєфу». Саме ПЕРША така точка, а не найзручніша: станція бере
    ціль тоді, коли та піднялась, і від цієї миті веде її.

    Вогнева позиція від цього не залежить — її станція рахує назад по
    дузі, і лягти вона може й за межами сектора. Так працює й справжня
    контрбатарейна: бачить снаряд, а показує знаряддя.

    Профіль рельєфу читається відліками висот, без жодного променя:
    rayHits на двадцять кілометрів коштував би непорівнянно дорожче, а
    закриває станцію саме гора, не кущ.
*/

params ["_radar", "_arc"];

// антена стоїть над корпусом, і це не дрібниця: із неї видно за
// найближчий пагорб
private _eye = (getPosASL _radar) vectorAdd [0, 0, CBR_MAST];

private _range = _radar getVariable ["cbr_range", CBR_RANGE];
private _sector = _radar getVariable ["cbr_sector", CBR_SECTOR];
private _bear = _radar getVariable ["cbr_bearing", getDir _radar];
private _half = _sector / 2;

private _got = [];
private _i = 0;

while { _got isEqualTo [] && {_i < count _arc} } do {
    private _p = _arc select _i;
    private _d = _p vectorDiff _eye;
    private _dist = vectorMagnitude _d;

    private _inBeam = _dist <= _range;

    // нижче кута променя снаряд ще не піднявся
    if (_inBeam) then {
        private _flat = sqrt (((_d select 0) ^ 2) + ((_d select 1) ^ 2));
        _inBeam = ((_d select 2) atan2 _flat) >= CBR_BEAM_MIN;
    };

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

        if (!_blocked) then { _got = [_p, _i] };
    };

    _i = _i + 1;
};

_got
