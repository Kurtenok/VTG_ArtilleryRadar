#include "defines.h"

/*
    Function: cbr_fnc_mark
    Вогнева позиція на карті. Позначка КОРИСТУВАЦЬКА: ім'я виду
    "_USER_DEFINED #власник/номер/канал" рушій розбирає як поставлену
    людиною — і дозволяє її прибрати, чого зі скриптовою не вийде.

    Кому вона дістанеться, вирішує адресат розсилки з fn_transmit, а не
    канал в імені.
*/

params ["_name", "_pos", "_text"];

if (!hasInterface) exitWith {};

// повторний вивід оновлює ту саму позначку, а не кладе другу поверх
deleteMarkerLocal _name;

createMarkerLocal [_name, _pos];
_name setMarkerTypeLocal CBR_MARKER_TYPE;
_name setMarkerColorLocal "ColorRed";
_name setMarkerTextLocal _text;
