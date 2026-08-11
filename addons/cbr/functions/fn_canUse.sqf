/*
    Function: cbr_fnc_canUse
    Чи можна відкрити пульт: це має бути справний радар, і гравець —
    у ньому. За пультом сидять, а не бігають поруч.
*/

params ["_veh"];

!isNull _veh
    && {alive _veh}
    && {!isNil { _veh getVariable "cbr_range" }}
    && {player in crew _veh}
