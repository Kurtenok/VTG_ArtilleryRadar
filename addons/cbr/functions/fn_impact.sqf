#include "defines.h"

/*
    Function: cbr_fnc_impact
    Куди впаде снаряд: точка ASL або [], якщо рахувати нема сенсу.

    Рахується ЧИСТА балістика, без опору повітря — і це не спрощення.
    Артилерія, міномети й реактивні снаряди в Армі летять із
    airFriction = 0, тобто рівно по параболі, тож для всього, що радар
    узагалі бачить, розрахунок точний.

    Боєприпасу з ненульовим опором точку падіння НЕ показуємо. Модель
    польоту в нього інша, передбачити її цією формулою не можна, а
    показати навмання гірше, ніж не показати: оператор повірить числу.
    Сама вогнева позиція від цього не залежить і лишається.

    Крок точний для сталого прискорення, тож дрібнити його нема сенсу.
*/

params ["_pos", "_vel", "_ammo"];

private _drag = missionNamespace getVariable "cbr_dragCache";
if (isNil "_drag") then {
    _drag = createHashMap;
    missionNamespace setVariable ["cbr_dragCache", _drag];
};

private _k = _drag get _ammo;
if (isNil "_k") then {
    _k = getNumber (configFile >> "CfgAmmo" >> _ammo >> "airFriction");
    _drag set [_ammo, _k];
};

if (_k != 0) exitWith { [] };

private _p = +_pos;
private _v = +_vel;
private _hit = [];
private _steps = 0;

// умова в самому циклі, а не exitWith усередині: той вийшов би лише з
// ітерації, і снаряд «падав» би далі під землю всі решту кроків
while { _hit isEqualTo [] && {_steps < CBR_IMPACT_STEPS} } do {
    _steps = _steps + 1;

    private _next = _p
        vectorAdd (_v vectorMultiply CBR_IMPACT_DT)
        vectorAdd ([0, 0, -9.81 * 0.5 * CBR_IMPACT_DT * CBR_IMPACT_DT]);

    private _ground = getTerrainHeightASL [_next select 0, _next select 1];
    if ((_next select 2) <= _ground) then {
        // уточнюємо точку падіння лінійно всередині останнього кроку
        private _drop = (_p select 2) - (_next select 2);
        private _f = 0;
        if (_drop > 0.001) then { _f = (((_p select 2) - _ground) / _drop) max 0 min 1 };

        _hit = _p vectorAdd ((_next vectorDiff _p) vectorMultiply _f);
    } else {
        _v set [2, (_v select 2) - 9.81 * CBR_IMPACT_DT];
        _p = _next;
    };
};

_hit
