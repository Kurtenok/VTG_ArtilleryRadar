#include "defines.h"

/*
    Function: cbr_fnc_slew
    Доворот сектора. Напрямок пише САМ оператор, одразу публічно: коли
    число йшло через сервер, на швидкому доворі сектор стрибав туди-сюди —
    серверне відлуння приходило застарілим і перетирало свіже.
*/

params ["_veh", "_delta"];

_veh setVariable [
    "cbr_bearing",
    ((_veh getVariable ["cbr_bearing", getDir _veh]) + _delta + 360) mod 360,
    true
];
