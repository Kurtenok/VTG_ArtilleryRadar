#include "defines.h"

/*
    Function: cbr_fnc_mark
    Вогнева позиція на карті.

    Позначка звичайна КОРИСТУВАЦЬКА: ім'я виду
    "_USER_DEFINED #власник/номер/канал" рушій розбирає як мітку,
    поставлену людиною з карти, — і дозволяє прибрати її звідти будь-кому.
    Скриптову мітку гравець стерти не може, тому й імена такі.

    Кому вона дістанеться, вирішує НЕ рушій, а адресат розсилки з
    fn_transmit. Номер каналу в імені лишається правильним, але покладатися
    на нього як на єдиний фільтр не можна: помилка тут означала б, що
    засічки видно ворогу.
*/

params ["_name", "_pos", "_text"];

if (!hasInterface) exitWith {};

// повторний вивід оновлює ту саму позначку, а не кладе другу поверх
deleteMarkerLocal _name;

createMarkerLocal [_name, _pos];
_name setMarkerTypeLocal CBR_MARKER_TYPE;
_name setMarkerColorLocal "ColorRed";
_name setMarkerTextLocal _text;
