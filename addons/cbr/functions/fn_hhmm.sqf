// Час доби (години дробовим числом) як ГГ:ХХ

params ["_hours"];

private _h = floor _hours;
private _m = floor ((_hours - _h) * 60);

format ["%1:%2", [_h, 2] call CBA_fnc_formatNumber, [_m, 2] call CBA_fnc_formatNumber]
