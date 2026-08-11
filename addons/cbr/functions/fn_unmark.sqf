/*
    Function: cbr_fnc_unmark
    Прибрати позначку засічки. Розсилається всім: позначка могла піти і
    стороні, і лише групі, а видалення неіснуючої нікому не шкодить.
*/

params ["_veh", "_id"];

if (!hasInterface || {isNull _veh}) exitWith {};

deleteMarkerLocal (format ["cbr_%1_%2", netId _veh, _id]);
