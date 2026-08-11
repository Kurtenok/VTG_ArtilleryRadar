#include "functions\defines.h"

class CfgPatches {
    class vtgcbr_cbr {
        name = "VTG Counter-battery radar";
        units[] = {"cbr_module"};
        weapons[] = {};
        requiredVersion = 2.10;
        requiredAddons[] = {"A3_Modules_F", "cba_common"};
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
            class RangeMortar {
                displayName = "$STR_cbr_arg_mortar";
                description = "$STR_cbr_arg_mortar_desc";
                typeName = "NUMBER";
                defaultValue = CBR_RANGE_MORTAR;
            };
            class RangeGun {
                displayName = "$STR_cbr_arg_gun";
                description = "$STR_cbr_arg_gun_desc";
                typeName = "NUMBER";
                defaultValue = CBR_RANGE_GUN;
            };
            class RangeRocket {
                displayName = "$STR_cbr_arg_rocket";
                description = "$STR_cbr_arg_rocket_desc";
                typeName = "NUMBER";
                defaultValue = CBR_RANGE_ROCKET;
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
        };
    };
};

class CfgFunctions {
    class cbr {
        class radar {
            file = "\z\vtgcbr\addons\cbr\functions";
            class addRadar {};
            class caliber {};
            class detect {};
            class expire {};
            class initModule {};
            class label {};
            class preInit { preInit = 1; };
            class postInit { postInit = 1; };
            class report {};
            class side {};
            class stock {};
            class stockApply {};
        };
    };
};

// що дозволено викликати по мережі
class CfgRemoteExec {
    class Functions {
        mode = 2;
        class cbr_fnc_detect { allowedTargets = 0; };    // машина стрільця -> сервер
        class cbr_fnc_report { allowedTargets = 0; };    // сервер -> клієнти сторони
        class cbr_fnc_addRadar { allowedTargets = 0; };  // підключення з Zeus + JIP
    };
};
