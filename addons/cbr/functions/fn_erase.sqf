#include "defines.h"

/*
    Function: cbr_fnc_erase
    Оператор прибирає засічку: і клавішею по обраній, і кнопкою в рядку
    журналу. Сам запис видаляє сервер — тут лише номер і звук.
*/

params ["_veh", "_idx"];

private _log = uiNamespace getVariable ["cbr_log", []];
if (_idx < 0 || {_idx >= count _log}) exitWith {};

// мітку на карті не чіпаємо: вона користувацька, і прибрати її з
// карти може будь-хто сам
[_veh, (_log select _idx) select 0] remoteExec ["cbr_fnc_drop", 2];

// прибираємо і зі свого списку одразу: журнал приїде з мережі із
// затримкою, а пульт має відгукуватись на натискання миттєво
_log deleteAt _idx;
uiNamespace setVariable ["cbr_log", _log];
uiNamespace setVariable ["cbr_sel", _idx min (((count _log) - 1) max 0)];

playSound "3DEN_notificationDefault";
