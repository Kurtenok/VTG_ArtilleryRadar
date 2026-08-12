#include "defines.h"

/*
    Function: cbr_fnc_impact
    Точка падіння снаряда (ASL) або [], якщо він не приземлився в межах
    ліміту кроків.

    Опір повітря в Армі рахується ДВОМА різними законами, і знак
    airFriction каже, яким саме:
        k < 0   снаряди й кулі:   a = k * |v| * v   (квадратичний)
        k > 0   ракети й бомби:   a = -k * v        (лінійний)

    Переплутати не можна: 0.45 у ПГ-9В за квадратичним законом дає
    220 000 м/с2, і рахунок за два кроки йде в нескінченність — саме
    цим і падала стрільба зі СПГ-9. Знак перевірено по всіх класах
    боєприпасів гри й RHS: винятків немає.

    Двигун тут не моделюється: клієнт знімає стан снаряда вже після
    вигоряння, тож сюди приходить вільний політ.
*/

params ["_pos", "_vel", "_ammo"];

private _cache = missionNamespace getVariable "cbr_ballistics";
if (isNil "_cache") then {
    _cache = createHashMap;
    missionNamespace setVariable ["cbr_ballistics", _cache];
};

private _data = _cache get _ammo;
if (isNil "_data") then {
    private _cfg = configFile >> "CfgAmmo" >> _ammo;
    private _k = getNumber (_cfg >> "airFriction");

    // трапляється в одиниць боєприпасів, але мовчки міняє всю дугу
    private _cg = 1;
    if (isNumber (_cfg >> "coefGravity")) then { _cg = getNumber (_cfg >> "coefGravity") };

    _data = [abs _k, _k < 0, -9.81 * _cg];
    _cache set [_ammo, _data];
};
_data params ["_drag", "_quad", "_g"];

private _fnc_acc = {
    private _s = vectorMagnitude _this;
    private _f = -_drag * ([1, _s] select _quad);
    [(_this select 0) * _f, (_this select 1) * _f, (_this select 2) * _f + _g]
};

/*
    Крок міряється силою опору: за один крок швидкість не має падати
    більш ніж на два відсотки, інакше дуга зрізається. Без опору крок
    максимальний — там рахунок точний за будь-якого.
*/
private _dt = CBR_IMPACT_DT;
private _s0 = vectorMagnitude _vel;
if (_drag > 0 && {_s0 > 0}) then {
    private _a0 = _drag * _s0 * ([1, _s0] select _quad);
    _dt = ((0.02 * _s0 / _a0) max 0.01) min CBR_IMPACT_DT;
};

private _p = +_pos;
private _v = +_vel;
private _hit = [];
private _steps = 0;

// умова в самому циклі, а не exitWith усередині: той вийшов би лише з
// ітерації, і снаряд «падав» би далі під землю решту кроків
while { _hit isEqualTo [] && {_steps < CBR_IMPACT_STEPS} } do {
    _steps = _steps + 1;

    // прискорення береться в СЕРЕДИНІ кроку: на прямому Ейлері дуга
    // 120-мм снаряда їде на півсотні метрів, так — на півметра
    private _a = _v call _fnc_acc;
    private _am = (_v vectorAdd (_a vectorMultiply (_dt * 0.5))) call _fnc_acc;

    private _next = _p
        vectorAdd (_v vectorMultiply _dt)
        vectorAdd (_am vectorMultiply (0.5 * _dt * _dt));

    // над водою рельєф іде під нуль, а снаряд рветься об поверхню
    private _ground = (getTerrainHeightASL [_next select 0, _next select 1]) max 0;
    if ((_next select 2) <= _ground) then {
        private _drop = (_p select 2) - (_next select 2);
        private _f = 0;
        if (_drop > 0.001) then { _f = (((_p select 2) - _ground) / _drop) max 0 min 1 };

        _hit = _p vectorAdd ((_next vectorDiff _p) vectorMultiply _f);
    } else {
        _v = _v vectorAdd (_am vectorMultiply _dt);
        _p = _next;
    };
};

_hit
