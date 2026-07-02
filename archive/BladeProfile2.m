%% נתוני הסכינים (כפי שזיהית)
knifeData = table( ...
    {'DSC_1918', 'DSC_1919', 'DSC_1920', 'DSC_1921', 'DSC_1922'}', ... % Pic Num
    (0:4)', ...             % Knife Num
    [2719, 2718, 2726, 2738, 2703]', ...  % X up
    [1349, 1358, 1372, 1395, 1397]', ...  % Y up
    [2696, 2669, 2644, 2655, 2654]', ...  % X down
    [3208, 3256, 3334, 3344, 3293]', ...  % Y down
    'VariableNames', {'PicNum','KnifeNum','Xup','Yup','Xdown','Ydown'} ...
);

%% בחירת סכין
knifeSel = input('הכנס מספר סכין (0-4): ');

% שליפת הנתונים המתאימים
row = knifeData(knifeData.KnifeNum == knifeSel, :);

nefFile = [row.PicNum{1} '.NEF'];  % שם קובץ NEF
bladeP1_raw = [row.Xup, row.Yup];
bladeP2_raw = [row.Xdown, row.Ydown];

fprintf('טוען תמונה: %s\n', nefFile);

%% קריאת קובץ RAW (NEF)
raw_full = rawread(nefFile);  % נדרש Image Processing Toolbox ותמיכה ב-NEF

%% הפקה של ערוץ GREEN מלא
G1 = raw_full(1:2:end, 2:2:end);
G2 = raw_full(2:2:end, 1:2:end);
green_full = (G1(1:end-1,1:end-1) + G2(1:end-1,1:end-1)) / 2;

%% מיפוי קואורדינטות RAW -> GREEN
mapRAW2G = @(p) [ floor(p(1)/2), floor(p(2)/2) ];
bp1g = mapRAW2G(bladeP1_raw);
bp2g = mapRAW2G(bladeP2_raw);

%% חישוב פרופיל
numSamples = abs(bp2g(2)-bp1g(2))+1;
yg = round(linspace(bp1g(2), bp2g(2), numSamples)).';
xg = round(linspace(bp1g(1), bp2g(1), numSamples)).';

winLeftX  = 2;  % פיקסלים שמאלה
winRightX = 2;  % פיקסלים ימינה
halfWinY  = 1;  % פיקסלים למעלה/למטה

int_profile = zeros(numSamples,1);
H = size(green_full,1);
W = size(green_full,2);

for i = 1:numSamples
    y0 = min(max(yg(i),1), H);
    x0 = min(max(xg(i),1), W);
    xs = max(1, x0 - winLeftX) : min(W, x0 + winRightX);
    ys = max(1, y0 - halfWinY) : min(H, y0 + halfWinY);
    int_profile(i) = mean( green_full(ys, xs), 'all' );
end

%% המרת X למ"מ
bladeLength_mm = 61; % אורך להב בפועל
x_mm = linspace(0, bladeLength_mm, numSamples);

%% גרף
figure('Name','Blade Profile','NumberTitle','off');
plot(x_mm, int_profile, 'k','LineWidth',1.3);
grid on
xlabel('Blade length [mm]');
ylabel('Intensity (GREEN raw units)');
title(sprintf('Blade reflection profile – Knife %d (%s)', knifeSel, row.PicNum{1}));
