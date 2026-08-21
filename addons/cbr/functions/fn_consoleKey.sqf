#include "defines.h"

// Керування пультом. Клавіші перехоплюються, щоб гравець не бігав і не
// крутив башту, поки сидить за індикатором

params ["_display", "_key"];

private _veh = uiNamespace getVariable ["cbr_veh", objNull];
if (isNull _veh) exitWith { false };

private _log = uiNamespace getVariable ["cbr_log", []];
private _sel = uiNamespace getVariable ["cbr_sel", 0];
private _n = count _log;

// вибір по колу: упиратися в край нема сенсу
private _fnc_step = {
    params ["_delta"];
    if (_n < 1) exitWith {};
    uiNamespace setVariable ["cbr_sel", (_sel + _delta + _n) mod _n];
};

switch (_key) do {
    // A / D і стрілки — доворот сектора
    case 30; case 203: {
        [_veh, -CBR_SLEW_STEP] call cbr_fnc_slew;
    };
    case 32; case 205: {
        [_veh, CBR_SLEW_STEP] call cbr_fnc_slew;
    };

    // W / S і стрілки — вибір засічки, по колу
    case 17; case 200: { [-1] call _fnc_step };
    case 31; case 208: { [1] call _fnc_step };

    // вивести засічку на карту
    case 28; case 156; case 57: {
        [_veh, _sel] call cbr_fnc_transmit;
    };

    // прибрати обрану засічку з журналу
    case 211: {
        [_veh, _sel] call cbr_fnc_erase;
    };

    default { false };
};

[] call cbr_fnc_consoleUpdate;

// Esc лишаємо рушію — ним пульт і закривається
_key != 1
