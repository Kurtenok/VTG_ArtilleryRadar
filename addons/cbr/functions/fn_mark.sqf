#include "defines.h"

/*
    Function: cbr_fnc_mark
    Вогнева позиція на карті. Позначка локальна: її бачить лише той, кому
    оператор її вивів, і мережі вона не коштує нічого.

    Не гасне сама. Прибирає її оператор із пульта — там же, де й ставив.

    Ім'я складається з машини й номера засічки, тож у всіх воно однакове:
    за ним потім і видаляють. Заразом повторний вивід тієї самої засічки
    оновлює ту саму позначку, а не плодить другу поверх першої.
*/

params ["_veh", "_id", "_pos", "_text"];

if (!hasInterface) exitWith {};

private _name = format ["cbr_%1_%2", netId _veh, _id];
deleteMarkerLocal _name;

createMarkerLocal [_name, _pos];
_name setMarkerTypeLocal CBR_MARKER_TYPE;
_name setMarkerColorLocal "ColorRed";
_name setMarkerTextLocal _text;
