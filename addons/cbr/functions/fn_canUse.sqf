// Чи можна відкрити пульт: справний радар, і гравець у ньому — за
// пультом сидять, а не бігають поруч

params ["_veh"];

!isNull _veh
    && {alive _veh}
    && {!isNil { _veh getVariable "cbr_range" }}
    && {player in crew _veh}
