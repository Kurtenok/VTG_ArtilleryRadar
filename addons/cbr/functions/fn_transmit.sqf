#include "defines.h"

/*
    Function: cbr_fnc_transmit
    Оператор передає засічку в штаб. Саме це й робить станцію
    потрібною: виявляє вона сама, але на карту вогнева позиція
    потрапляє лише коли людина за пультом її оцінила й відправила.
*/

params ["_veh", "_idx"];

private _log = uiNamespace getVariable ["cbr_log", []];
if (_idx < 0 || {_idx >= count _log}) exitWith {};

(_log select _idx) params ["_id", "_pos", "_cal", "_speed", "", "_rounds", ["_sent", false]];
if (_sent) exitWith {};

// позначка вже передана — щоб не слати ту саму двічі
[_veh, _id] remoteExec ["cbr_fnc_markSent", 2];

private _text = if (_cal > 0) then {
    format [localize "STR_cbr_label", _cal, _speed]
} else {
    format [localize "STR_cbr_label_nocal", _speed]
};
if (_rounds > 1) then { _text = format ["%1 x%2", _text, _rounds] };

[_pos, _text] remoteExec ["cbr_fnc_mark", [_veh] call cbr_fnc_side];

playSound "3DEN_notificationDefault";
