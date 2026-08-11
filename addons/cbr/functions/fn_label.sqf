#include "defines.h"

/*
    Function: cbr_fnc_label
    Підпис засічки: калібр і дульна швидкість, тобто те, що станція
    справді МІРЯЄ. Назву системи не пишемо навмисно — визначити
    міномет це чи гаубиця по одних цифрах може й розрахунок, а мод не
    мусить вгадувати за нього.

    Калібр із імені класу дістається не завжди; тоді лишається сама
    швидкість, і це чесніше за вигаданий тип.
*/

params ["_fix"];
_fix params ["_marker", "", "_count", "", "_cal", "_speed"];

private _text = if (_cal > 0) then {
    format [localize "STR_cbr_label", _cal, _speed]
} else {
    format [localize "STR_cbr_label_nocal", _speed]
};

if (_count > 1) then { _text = format ["%1 x%2", _text, _count] };

_marker setMarkerTextLocal _text;
