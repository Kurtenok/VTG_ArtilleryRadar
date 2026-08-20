#include "functions\defines.h"

class CfgPatches {
    class vtgcbr_cbr {
        name = "Counter-battery radar";
        units[] = {"cbr_module"};
        weapons[] = {};
        requiredVersion = 2.10;
        requiredAddons[] = {"A3_Modules_F", "cba_common", "ace_interact_menu"};
        author = "Kurten";
        version = "0.1";
    };
};

class CfgFactionClasses {
    class cbr_modules {
        displayName = "$STR_cbr_cat";
        priority = 2;
        side = 7;
    };
};

class ArgumentsBaseUnits;
class CfgVehicles {
    class Module_F;

    class cbr_module: Module_F {
        scope = 2;
        scopeCurator = 2;      // доступний і в Zeus (кидати на техніку)
        author = "Kurten";
        displayName = "$STR_cbr_module";
        category = "cbr_modules";
        function = "cbr_fnc_initModule";
        isGlobal = 2;
        isTriggerActivated = 0;
        isDisposable = 0;

        class Arguments: ArgumentsBaseUnits {
            class Range {
                displayName = "$STR_cbr_arg_range";
                description = "$STR_cbr_arg_range_desc";
                typeName = "NUMBER";
                defaultValue = CBR_RANGE;
            };
            class Sector {
                displayName = "$STR_cbr_arg_sector";
                description = "$STR_cbr_arg_sector_desc";
                typeName = "NUMBER";
                defaultValue = CBR_SECTOR;
            };
            class Error {
                displayName = "$STR_cbr_arg_error";
                description = "$STR_cbr_arg_error_desc";
                typeName = "NUMBER";
                defaultValue = CBR_ERROR;
            };
            class Delay {
                displayName = "$STR_cbr_arg_delay";
                description = "$STR_cbr_arg_delay_desc";
                typeName = "NUMBER";
                defaultValue = CBR_DELAY;
            };
        };
    };
};

/*
    Індикатор станції. Основа — картографічний контрол: сучасні станції
    (TPQ-53, ARTHUR) саме так і показують обстановку, поверх місцевості,
    бо оператору однаково називати квадрат. Кольори збиті в один
    люмінофор, щоб це читалось як пульт, а не як розгорнута карта.

    Сектор, дуги, розгортку й засічки малює cbr_fnc_consoleDraw.
*/
class RscMapControl;
class cbr_map: RscMapControl {
    idc = -1;
    maxSatelliteAlpha = 0;
    alphaFadeStartScale = 1e11;
    alphaFadeEndScale = 1e11;
    colorBackground[] = {0.03, 0.06, 0.04, 1};
    colorSea[] = {0.02, 0.05, 0.05, 0.7};
    colorForest[] = {0.12, 0.26, 0.15, 0.45};
    colorForestBorder[] = {0, 0, 0, 0};
    colorRocks[] = {0.13, 0.24, 0.15, 0.4};
    colorRocksBorder[] = {0, 0, 0, 0};
    colorCountlines[] = {0.16, 0.38, 0.2, 0.5};
    colorMainCountlines[] = {0.22, 0.5, 0.27, 0.7};
    colorCountlinesWater[] = {0.12, 0.3, 0.3, 0.4};
    colorMainCountlinesWater[] = {0.16, 0.38, 0.38, 0.55};
    colorPowerLines[] = {0.1, 0.22, 0.12, 0.4};
    colorRailWay[] = {0.14, 0.3, 0.16, 0.5};
    colorNames[] = {0.4, 0.85, 0.5, 0.65};
    colorInactive[] = {0.4, 0.85, 0.5, 0.35};
    colorLevels[] = {0.18, 0.42, 0.22, 0.55};
    colorTracks[] = {0.14, 0.3, 0.16, 0.4};
    colorTracksFill[] = {0.14, 0.3, 0.16, 0.4};
    colorRoads[] = {0.18, 0.36, 0.2, 0.5};
    colorRoadsFill[] = {0.18, 0.36, 0.2, 0.5};
    colorMainRoads[] = {0.24, 0.46, 0.26, 0.6};
    colorMainRoadsFill[] = {0.24, 0.46, 0.26, 0.6};
    colorGrid[] = {0.3, 0.65, 0.36, 0.35};
    colorGridMap[] = {0.3, 0.65, 0.36, 0.35};
    scaleMin = 0.001;
    scaleMax = 1;
    scaleDefault = 0.2;
};

/*
    Пульт. Діалог, бо оператор саме сидить за ним: керування машиною на
    цей час йому не належить. Контроли будує cbr_fnc_console — розкладка
    рахується від safeZone, і в конфізі її довелося б дублювати числами.
*/
class cbr_console {
    idd = CBR_IDD;
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "uiNamespace setVariable ['cbr_display', _this select 0];";
    onUnload = "uiNamespace setVariable ['cbr_display', displayNull];";
    class controlsBackground {};
    class controls {};
};

class CfgFunctions {
    class cbr {
        class radar {
            file = "\z\vtgcbr\addons\cbr\functions";
            class addRadar {};
            class arc {};
            class caliber {};
            class canUse {};
            class console {};
            class consoleDraw {};
            class consoleKey {};
            class consoleLos {};
            class consoleUpdate {};
            class createAceMenu {};
            class detect {};
            class drop {};
            class erase {};
            class initModule {};
            class hhmm {};
            class manned {};
            class mark {};
            class preInit { preInit = 1; };
            class postInit { postInit = 1; };
            class side {};
            class stock {};
            class slew {};
            class stockApply {};
            class track {};
            class transmit {};
        };
    };
};

// що дозволено викликати по мережі
class CfgRemoteExec {
    class Functions {
        mode = 2;
        class cbr_fnc_detect { allowedTargets = 0; };     // стрілець -> оператор станції
        class cbr_fnc_manned { allowedTargets = 0; };     // клієнт -> сервер: хто за пультом
        class cbr_fnc_addRadar { allowedTargets = 0; };   // підключення з Zeus + JIP
        class cbr_fnc_mark { allowedTargets = 0; };       // позначка своїй стороні
        class cbr_fnc_drop { allowedTargets = 0; };       // прибрати засічку в оператора
    };
};
