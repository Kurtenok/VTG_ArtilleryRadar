#include "defines.h"

/*
    Function: cbr_fnc_console
    Консоль оператора станції.

    Діалог, а не шар поверх екрана: оператор саме СИДИТЬ за пультом, і
    керування машиною на цей час йому не належить. Так само працює
    будь-який робочий пост — поки ти на індикаторі, ти не за кермом.

    Основа — картографічний контрол. Сучасні станції (TPQ-53, ARTHUR)
    так і показують обстановку: сектор і засічки поверх місцевості, бо
    оператору однаково доводиться називати квадрат. Малюємо поверх
    нього самі: сектор, дуги дальності, розгортку й самі засічки.

    Контроли будуються тут, а не в конфізі: розкладка рахується від
    safeZone, і в конфізі її довелося б дублювати числами.
*/

if (!hasInterface) exitWith { false };

private _veh = vehicle player;
if (!([_veh] call cbr_fnc_canUse)) exitWith { false };

if (!(createDialog "cbr_console")) exitWith { false };

private _display = findDisplay CBR_IDD;
if (isNull _display) exitWith { false };

uiNamespace setVariable ["cbr_veh", _veh];
uiNamespace setVariable ["cbr_sel", 0];

private _x0 = safeZoneX;
private _y0 = safeZoneY;
private _w = safeZoneW;
private _h = safeZoneH;

// права колонка — журнал засічок, решта під індикатор
private _logW = 720 * CBR_PXU;
private _barH = 62 * CBR_LU;

private _fnc_text = {
    params ["_display", "_pos", "_size", "_color", ["_align", "left"], ["_class", "RscStructuredText"]];
    private _c = _display ctrlCreate [_class, -1];
    _c ctrlSetPosition _pos;
    _c ctrlSetFontHeight _size;
    _c ctrlSetTextColor _color;
    _c ctrlCommit 0;
    _c
};

// --- підкладка ---
private _bg = _display ctrlCreate ["RscText", -1];
_bg ctrlSetPosition [_x0, _y0, _w, _h];
_bg ctrlSetBackgroundColor CBR_COL_BG;
_bg ctrlCommit 0;

// --- індикатор ---
private _map = _display ctrlCreate ["cbr_map", -1];
_map ctrlSetPosition [_x0, _y0 + _barH, _w - _logW, _h - 2 * _barH];
_map ctrlCommit 0;
_map ctrlAddEventHandler ["Draw", { _this call cbr_fnc_consoleDraw }];

/*
    Станція в центрі індикатора. Масштаб не вгадуємо числом: ставимо
    будь-який, міряємо, скільки метрів вийшло по ширині, і одним кроком
    перераховуємо під потрібний обхват. Так сектор влізе цілком за
    будь-якої роздільної здатності й дальності станції.
*/
private _mapW = _w - _logW;
private _want = 2.2 * (_veh getVariable ["cbr_range", CBR_RANGE]);

_map ctrlMapAnimAdd [0, 1, getPosATL _veh];
ctrlMapAnimCommit _map;

[{
    params ["_map", "_veh", "_mapW", "_want"];
    if (isNull _map) exitWith {};

    private _cy = safeZoneY + safeZoneH / 2;
    private _span = (_map ctrlMapScreenToWorld [safeZoneX, _cy])
        distance2D (_map ctrlMapScreenToWorld [safeZoneX + _mapW, _cy]);

    if (_span > 1) then {
        _map ctrlMapAnimAdd [0, _want / _span, getPosATL _veh];
        ctrlMapAnimCommit _map;
    };
}, [_map, _veh, _mapW, _want]] call CBA_fnc_execNextFrame;

uiNamespace setVariable ["cbr_map", _map];

// --- верхній рядок стану ---
private _status = [_display, [_x0 + 20 * CBR_PXU, _y0 + 12 * CBR_LU, _w - 40 * CBR_PXU, 40 * CBR_LU], 30 * CBR_PH, CBR_COL_MAIN] call _fnc_text;
uiNamespace setVariable ["cbr_status", _status];

// --- журнал ---
private _logX = _x0 + _w - _logW + 16 * CBR_PXU;
private _logW2 = _logW - 32 * CBR_PXU;

private _head = [_display, [_logX, _y0 + _barH + 8 * CBR_LU, _logW2, 30 * CBR_LU], 24 * CBR_PH, CBR_COL_DIM] call _fnc_text;
_head ctrlSetStructuredText parseText (localize "STR_cbr_ui_head");
_head ctrlCommit 0;

// вузька колонка праворуч під кнопки прибирання
private _delW = 40 * CBR_PXU;
private _rowW = _logW2 - _delW - 8 * CBR_PXU;

private _rows = [];
private _dels = [];
for "_i" from 0 to (CBR_UI_ROWS - 1) do {
    private _y = _y0 + _barH + (44 + _i * CBR_UI_ROW_H) * CBR_LU;

    _rows pushBack ([
        _display,
        [_logX, _y, _rowW, CBR_UI_ROW_H * CBR_LU],
        26 * CBR_PH, CBR_COL_MAIN
    ] call _fnc_text);

    /*
        Кнопка, а не клікабельний текст: у кнопки клік ловиться напевно.
        Фон прозорий, тож на пульті вона виглядає тим самим написом.
    */
    private _b = _display ctrlCreate ["RscButton", -1];
    _b ctrlSetPosition [_logX + _logW2 - _delW, _y, _delW, CBR_UI_ROW_H * CBR_LU];
    _b ctrlSetBackgroundColor [0, 0, 0, 0];
    _b ctrlSetTextColor CBR_COL_DIM;
    _b ctrlSetFontHeight (24 * CBR_PH);
    _b ctrlSetText "X";
    _b setVariable ["cbr_row", _i];
    _b ctrlAddEventHandler ["ButtonClick", {
        params ["_ctrl"];
        [uiNamespace getVariable ["cbr_veh", objNull], _ctrl getVariable ["cbr_row", -1]] call cbr_fnc_erase;
        [] call cbr_fnc_consoleUpdate;
    }];
    _b ctrlShow false;
    _b ctrlCommit 0;
    _dels pushBack _b;
};
uiNamespace setVariable ["cbr_rows", _rows];
uiNamespace setVariable ["cbr_dels", _dels];

// --- нижня підказка ---
private _hint = [_display, [_x0 + 20 * CBR_PXU, _y0 + _h - 46 * CBR_LU, _w - 40 * CBR_PXU, 34 * CBR_LU], 24 * CBR_PH, CBR_COL_DIM] call _fnc_text;
_hint ctrlSetStructuredText parseText (localize "STR_cbr_ui_keys");
_hint ctrlCommit 0;

_display displayAddEventHandler ["KeyDown", { _this call cbr_fnc_consoleKey }];
_display displayAddEventHandler ["Unload", {
    private _h = uiNamespace getVariable ["cbr_pfh", -1];
    if (_h > -1) then { [_h] call CBA_fnc_removePerFrameHandler };
    uiNamespace setVariable ["cbr_pfh", -1];
}];

// журнал і рядок стану оновлюються рідко: цифри там міняються
// подіями, а не щокадру. Розгортку веде обробник малювання
uiNamespace setVariable ["cbr_pfh", [{ [] call cbr_fnc_consoleUpdate }, 0.25] call CBA_fnc_addPerFrameHandler];
[] call cbr_fnc_consoleUpdate;

true
