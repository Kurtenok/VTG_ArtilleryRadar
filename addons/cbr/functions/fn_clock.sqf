/*
    Function: cbr_fnc_clock
    Ігровий час засічки як ГГ:ХХ. Береться зі зсуву від поточного
    часу місії, бо в журналі лежить саме time.
*/

params ["_at"];

private _ago = time - _at;
private _now = dateToNumber date;
private _then = numberToDate [date select 0, _now - _ago / (365 * 24 * 3600)];

format ["%1:%2", [_then select 3, 2] call CBA_fnc_formatNumber, [_then select 4, 2] call CBA_fnc_formatNumber]
