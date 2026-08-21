#include "defines.h"

/*
    Function: cbr_fnc_arc
    Дуга снаряда: точки через CBR_ARC_DT секунд польоту. Рівний крок за
    часом дає положення простою підстановкою, без повторного рахунку.

    Опір повітря в Армі рахується ДВОМА різними законами, і знак
    airFriction каже, яким саме:
        k < 0   снаряди й кулі:   a = k * |v| * v   (квадратичний)
        k > 0   ракети й бомби:   a = -k * v        (лінійний)

    Переплутати не можна: 0.45 у ПГ-9В за квадратичним законом дає
    220 000 м/с2, і рахунок за два кроки йде в нескінченність. Знак
    перевірено по всіх класах гри й RHS: винятків немає.
*/

params ["_pos", "_vel", "_ammo"];

private _cache = missionNamespace getVariable "cbr_ammoDrag";
if (isNil "_cache") then {
    _cache = createHashMap;
    missionNamespace setVariable ["cbr_ammoDrag", _cache];
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

// опір завжди проти руху, тяжіння донизу
private _fnc_acc = {
    private _f = -_drag;
    if (_quad) then { _f = _f * (vectorMagnitude _this) };

    [(_this select 0) * _f, (_this select 1) * _f, (_this select 2) * _f + _g]
};

// крок міряється силою опору: за один крок швидкість не має падати
// більш ніж на два відсотки, інакше дуга зрізається
private _dt = CBR_SIM_DT;
private _s0 = vectorMagnitude _vel;
if (_drag > 0 && {_s0 > 0}) then {
    private _a0 = _drag * _s0;
    if (_quad) then { _a0 = _a0 * _s0 };

    _dt = ((0.02 * _s0 / _a0) max 0.01) min CBR_SIM_DT;
};

private _every = (round (CBR_ARC_DT / _dt)) max 1;

private _p = +_pos;
private _v = +_vel;
private _arc = [+_pos];
private _steps = 0;
private _down = false;

// умова в самому циклі, а не exitWith усередині: той вийшов би лише з
// ітерації, і снаряд падав би далі під землю
while { !_down && {_steps < CBR_SIM_STEPS} } do {
    _steps = _steps + 1;

    // прискорення у СЕРЕДИНІ кроку: на прямому Ейлері дуга 120-мм
    // снаряда їде на півсотні метрів, так — на півметра
    private _a = _v call _fnc_acc;
    private _am = (_v vectorAdd (_a vectorMultiply (_dt * 0.5))) call _fnc_acc;

    private _next = _p
        vectorAdd (_v vectorMultiply _dt)
        vectorAdd (_am vectorMultiply (0.5 * _dt * _dt));

    // над водою рельєф іде під нуль, а снаряд рветься об поверхню
    private _ground = (getTerrainHeightASL [_next select 0, _next select 1]) max 0;
    if ((_next select 2) <= _ground) then {
        _down = true;

        // останнім відліком іде сама земля, інакше блип гаснув би за
        // крок до падіння
        private _drop = (_p select 2) - (_next select 2);
        private _f = 0;
        if (_drop > 0.001) then { _f = (((_p select 2) - _ground) / _drop) max 0 min 1 };

        _arc pushBack (_p vectorAdd ((_next vectorDiff _p) vectorMultiply _f));
    } else {
        _v = _v vectorAdd (_am vectorMultiply _dt);
        _p = _next;

        if (_steps mod _every == 0) then { _arc pushBack _p };
    };
};

_arc
