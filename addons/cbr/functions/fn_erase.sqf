#include "defines.h"

/*
    Function: cbr_fnc_erase
    Оператор прибирає засічку: і клавішею по обраній, і кнопкою в рядку
    журналу. Сам запис видаляє машина оператора — та, що веде журнал; тут
    лише номер і звук.
*/

params ["_veh", "_idx"];

private _log = uiNamespace getVariable ["cbr_log", []];
if (_idx < 0 || {_idx >= count _log}) exitWith {};

// Мітку на карті не чіпаємо: вона користувацька, і прибрати її з
// карти може будь-хто сам. Сам запис прибирає той, хто веде журнал
private _i = cbr_active findIf { (_x select 0) isEqualTo _veh };
if (_i < 0) exitWith {};

[_veh, (_log select _idx) select 0] remoteExec ["cbr_fnc_drop", (cbr_active select _i) select 1];

// прибираємо і зі свого списку одразу: журнал приїде з мережі із
// затримкою, а пульт має відгукуватись на натискання миттєво
_log deleteAt _idx;
uiNamespace setVariable ["cbr_log", _log];
uiNamespace setVariable ["cbr_sel", _idx min (((count _log) - 1) max 0)];

// підписи індикатора лежать окремим списком у тому ж порядку — інакше
// вони поїдуть на один запис і підпишуть чужу засічку
private _labels = uiNamespace getVariable ["cbr_labels", []];
if (_idx < count _labels) then {
    _labels deleteAt _idx;
    uiNamespace setVariable ["cbr_labels", _labels];
};

playSound "3DEN_notificationDefault";
