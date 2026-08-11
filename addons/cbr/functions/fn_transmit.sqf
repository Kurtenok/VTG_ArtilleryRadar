#include "defines.h"

/*
    Function: cbr_fnc_transmit
    Оператор виводить засічку на карту своєї сторони. Саме це й робить
    станцію потрібною: виявляє вона сама, але поки за пультом нікого
    немає, засічки лежать у журналі й нікому не допомагають.

    Вивід не автоматичний навмисно: у журналі десятки записів, а на
    карту потрібні не всі — батарея, що б'є по своїх, і поодинокий
    міномет осторонь мають різну ціну, і вирішує це людина.
*/

params ["_veh", "_idx"];

private _log = uiNamespace getVariable ["cbr_log", []];
if (_idx < 0 || {_idx >= count _log}) exitWith {};

(_log select _idx) params ["_id", "_pos", "_cal", "_speed", "", "_rounds", "", "", ["_when", 0]];

/*
    Куди лягає позначка, вирішує рація. Без довгохвильової сторона тебе
    не чує — засічка йде тільки своїй групі, і далі її передають голосом.
    З ДВ (ранцевою або тією, що стоїть у самій машині) — на всю сторону.

    Перевірка через TFAR_fnc_haveLRRadio, а не через власний перебір
    спорядження: правила «що вважати ДВ» належать радіомоду, і дублювати
    їх у себе означало б розійтися з ним при першому ж оновленні.
*/
private _lr = true;
if (!isNil "TFAR_fnc_haveLRRadio") then { _lr = call TFAR_fnc_haveLRRadio };

private _target = [group player, [_veh] call cbr_fnc_side] select _lr;

// Повторний вивід не блокуємо: мітку міг хтось стерти з карти, і
// оператор мусить мати змогу поставити її знову скільки завгодно разів

private _text = if (_cal > 0) then {
    format [localize "STR_cbr_label", _cal, _speed]
} else {
    format [localize "STR_cbr_label_nocal", _speed]
};
if (_rounds > 1) then { _text = format ["%1 x%2", _text, _rounds] };

// час на самій мітці: без нього на карті не зрозуміти, це щойно чи
// півгодини тому
_text = format ["%1  %2", _text, [_when] call cbr_fnc_hhmm];

[_veh, _id, _pos, _text] remoteExec ["cbr_fnc_mark", _target];

playSound "3DEN_notificationDefault";
