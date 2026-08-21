#include "defines.h"

/*
    Function: cbr_fnc_consoleLos
    Чи видно снаряд ЗАРАЗ — у реальному часі, а не з моменту пострілу:
    інакше доворот після пострілу нічого не міняв би, а снаряд, що вийшов
    із зони й повернувся, більше не з'являвся.

    За кадр РІВНО ОДИН промінь, по колу: пачка разом дала б смикання саме
    тоді, коли по оператору працює батарея.
*/

private _veh = uiNamespace getVariable ["cbr_veh", objNull];
if (isNull _veh) exitWith {};

private _live = _veh getVariable ["cbr_flight", []];
private _n = count _live;

private _los = uiNamespace getVariable "cbr_los";
if (isNil "_los") then {
    _los = createHashMap;
    uiNamespace setVariable ["cbr_los", _los];
};

// між нальотами список порожній — саме тоді й прибираємо за собою
if (_n == 0) exitWith {
    if (count _los > 0) then { uiNamespace setVariable ["cbr_los", createHashMap] };
};

private _eye = (getPosASL _veh) vectorAdd [0, 0, CBR_MAST];
private _from = getPosASL _veh;

private _range = _veh getVariable ["cbr_range", CBR_RANGE];
private _sector = _veh getVariable ["cbr_sector", CBR_SECTOR];
private _bear = _veh getVariable ["cbr_bearing", getDir _veh];

private _now = time;
private _at = uiNamespace getVariable ["cbr_losAt", -1];

private _done = false;
private _k = 0;

// Перший снаряд, якому час перепитатись; коло замикається за один
// прохід. Тіло вкладеними умовами, а не з continue: у while прецеденту
// тому немає ні в ACE, ні в CBA, ні в ваніліті
while { !_done && {_k < _n} } do {
    _k = _k + 1;
    _at = (_at + 1) mod _n;

    (_live select _at) params ["_t0", "_arc", "", "_id"];

    private _last = (count _arc) - 1;
    private _t = _now - _t0;

    // ще не вилетів, уже впав, або черга до нього ще не настала
    private _was = _los get _id;
    private _due = _last > 0
        && {_t >= 0}
        && {_t <= _last * CBR_ARC_DT}
        && {isNil "_was" || {_now - (_was select 1) >= CBR_LOS_EVERY}};

    if (_due) then {
        // відліки дуги рівні за часом, тож досить підстановки
        private _u = ((_t / CBR_ARC_DT) max 0) min _last;
        private _i = floor _u;
        private _p = _arc select _i;
        if (_i < _last) then {
            _p = _p vectorAdd (((_arc select (_i + 1)) vectorDiff _p) vectorMultiply (_u - _i));
        };

        private _d = _p vectorDiff _eye;
        private _dist = vectorMagnitude _d;
        private _seen = _dist <= _range;

        // нижче кута променя снаряд ще не піднявся
        if (_seen) then {
            private _flat = sqrt (((_d select 0) ^ 2) + ((_d select 1) ^ 2));
            _seen = ((_d select 2) atan2 _flat) >= CBR_BEAM_MIN;
        };

        // сектор питається ЗАРАЗ: оператор міг довернути станцію
        if (_seen && {_sector < 360}) then {
            private _az = (_d select 0) atan2 (_d select 1);
            _seen = abs (((_az - _bear + 540) mod 360) - 180) <= _sector / 2;
        };

        // рельєф: відліками карти висот, без променя
        if (_seen) then {
            private _steps = (ceil (_dist / CBR_LOS_STEP)) max CBR_LOS_MIN;
            private _blocked = false;
            private _j = 1;

            while { !_blocked && {_j < _steps} } do {
                private _s = _eye vectorAdd (_d vectorMultiply (_j / _steps));
                _blocked = (getTerrainHeightASL [_s select 0, _s select 1]) > (_s select 2);
                _j = _j + 1;
            };

            _seen = !_blocked;
        };

        // поставлені об'єкти: сама станція виключена, інакше затуляла б себе
        if (_seen) then {
            _seen = lineIntersectsSurfaces [_from, _p, _veh, objNull, true, 1] isEqualTo [];
        };

        _los set [_id, [_seen, _now]];
        _done = true;
    };
};

uiNamespace setVariable ["cbr_losAt", _at];
