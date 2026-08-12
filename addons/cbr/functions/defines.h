// Константи контрбатарейного радара. Числа з AN/TPQ-36: сектор 90
// градусів, 18 км по артилерії й 24 по ракетах

// Дальність одна на будь-який вогонь: три різні дуги на індикаторі
// довелося б або малювати, або усереднювати — і будь-яка збрехала б
#define CBR_RANGE 20000

#define CBR_SECTOR 90        // сектор огляду відносно носа машини, градусів

// Нижче цього кута кидання траєкторія настильна й над променем не
// піднімається — тому танки й ПТУР для радара не існують
#define CBR_MIN_ELEV 15

// Похибка зворотної екстраполяції, частка дальності: рахунок іде по
// короткій ділянці дуги, і кутова помилка росте в лінійну з відстанню
#define CBR_ERROR 0.004

/*
    Кожен постріл із тієї самої позиції — ще один замір, і коло
    звужується до межі на CBR_ERROR_SHOTS пострілі. Статистика дала б
    корінь із N, тобто сотню пострілів, а в Армі їх 20-30 на весь бій —
    тому крива стиснута під реальний наліт.
*/
#define CBR_ERROR_MIN 10
#define CBR_ERROR_SHOTS 5

#define CBR_DELAY 5          // супровід ділянки дуги до появи засічки, с

// Точка падіння. Похибка більша за похибку самої вогневої: назад
// станція рахує по відомій дузі, вперед — по ще не пройденій
#define CBR_IMPACT_ERR 1.5
#define CBR_IMPACT_LIFE 30   // скільки прильот тримається на індикаторі, с
#define CBR_IMPACT_MAX 16    // стеля списку прильотів однієї вогневої
#define CBR_IMPACT_DT 0.25   // крок інтегрування траєкторії, с
#define CBR_IMPACT_STEPS 1200

#define CBR_MERGE 250        // ближчі засічки — та сама вогнева позиція, м
#define CBR_ACQ_LIFE 900     // скільки засічка живе в журналі станції, с
#define CBR_ACQ_MAX 24       // глибина журналу: старіші витісняються
#define CBR_MIN_SPEED 40     // повільніше — не балістична ціль

#define CBR_MARKER_TYPE "mil_triangle"
#define CBR_ICO_FIX "\A3\ui_f\data\map\markers\military\triangle_CA.paa"
#define CBR_ICO_IMPACT "\A3\ui_f\data\map\markers\military\destroy_CA.paa"

// Чат, радіо й позначки мають спільну нумерацію каналів (Channel IDs)
#define CBR_CHAN_SIDE 1
#define CBR_CHAN_GROUP 3

// Розкладка пульта: макет 2560x1440 як частка safeZone
#define CBR_UI_SCALE 1
#define CBR_LU (safeZoneH / 1440)
#define CBR_PH (CBR_LU * CBR_UI_SCALE)
#define CBR_PW (CBR_PH * pixelW / pixelH)
#define CBR_PXU (safeZoneW / 2560)

#define CBR_IDD 8451

// Люмінофор: усе однією фарбою, як на справжньому індикаторі
#define CBR_COL_BG [0.02, 0.04, 0.03, 0.94]
#define CBR_COL_PANEL [0.05, 0.09, 0.06, 0.85]
#define CBR_COL_MAIN [0.35, 0.95, 0.5, 0.9]
#define CBR_COL_DIM [0.35, 0.95, 0.5, 0.28]
#define CBR_COL_FAINT [0.35, 0.95, 0.5, 0.12]

// Третього стану немає навмисно: час пострілу підписано біля кожної
// засічки, і зайвий колір лише сперечався б із кольором вибору
#define CBR_COL_FIX [1, 1, 1, 1]
#define CBR_COL_SEL [1, 0.6, 0.15, 1]

// Нова засічка сповіщає про себе кільцем, що розходиться: рух від
// центра око ловить навіть боковим зором, блимання на місці — ні
#define CBR_PING_FOR 3
#define CBR_PING_PERIOD 1.5
#define CBR_PING_GROW 2.6    // до скількох радіусів кола розходиться

#define CBR_SWEEP_PERIOD 2   // прохід розгортки по сектору, с

// Саме КРОК дуг, а не їх кількість: інакше ціна поділки їхала б за
// дальністю станції, і засічку не зміряти оком
#define CBR_RING_STEP 2500
#define CBR_ARC_STEP 5       // сегмент дуги, градусів
#define CBR_SLEW_STEP 5      // доворот сектора за одне натискання, градусів

#define CBR_UI_ROWS 12       // рядків у журналі
#define CBR_UI_ROW_H 34

// drawIcon міряє іконку й підпис у частках ЕКРАНА, а не в метрах, тож
// одиниці розмітки тут не годяться — вони на два порядки дрібніші.
// Ділення на getResolution#5 знімає вплив розміру інтерфейсу гравця
#define CBR_UI_COEF (getResolution select 5)
#define CBR_ICON_SIZE (0.034 / CBR_UI_COEF)
#define CBR_TEXT_SIZE (0.028 / CBR_UI_COEF)
#define CBR_RING_TEXT (0.022 / CBR_UI_COEF)
