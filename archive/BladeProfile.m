nef = 'DSC_1921.NEF';                % שנה לקובץ הרצוי
raw = double(rawread(nef));          % מטריצת RAW (Bayer)

% RGGB: Green1 = שורות זוגיות, עמודות אי-זוגיות | Green2 = שורות אי-זוגיות, עמודות זוגיות
g1 = raw(1:2:end, 2:2:end);
g2 = raw(2:2:end, 1:2:end);

% גזירה למכנה משותף וחיבור (Green1+Green2)/2
M = min(size(g1,1), size(g2,1));
N = min(size(g1,2), size(g2,2));
green_full = (g1(1:M,1:N) + g2(1:M,1:N))/2;   % תמונת Green של כל הפריים



% 3) פרופיל לאורך הלהב על כל התמונה (GREEN)
% הכנס שני קצוות להב בקואורדינטות RAW (עמודה=X, שורה=Y):
bladeP1_raw = [2732, 1384];   % קצה להב ראשון
bladeP2_raw = [2650, 3332];   % קצה להב שני

% ממפים ל-GREEN (חצי רזולוציה בכל ציר):
mapRAW2G = @(p) [ floor(p(1)/2), floor(p(2)/2) ];
bp1g = mapRAW2G(bladeP1_raw);
bp2g = mapRAW2G(bladeP2_raw);

% בונים קו לאורך Y עם X משתנה לינארית
numSamples = abs(bp2g(2)-bp1g(2))+1;
yg = round(linspace(bp1g(2), bp2g(2), numSamples)).';  % אינדקסי שורות ב-GREEN
xg = round(linspace(bp1g(1), bp2g(1), numSamples)).';  % אינדקסי עמודות ב-GREEN

% דגימה עם חלון לא-סימטרי ב-X וסימטרי ב-Y (כעת halfWinY=0 → רק השורה)
winLeftX  = 2;   % פיקסלים שמאלה
winRightX = 3;   % פיקסלים ימינה
halfWinY  = 3;   % פיקסלים למעלה/למטה (סימטרי)

int_profile = zeros(numSamples,1);

H = size(green_full,1);
W = size(green_full,2);

for i = 1:numSamples
    % שמירה בגבולות התמונה
    y0 = min(max(yg(i),1), H);
    x0 = min(max(xg(i),1), W);

    % טווח אופקי (אסימטרי)
    xs = max(1, x0 - winLeftX) : min(W, x0 + winRightX);
    % טווח אנכי (סימטרי)
    ys = max(1, y0 - halfWinY) : min(H, y0 + halfWinY);

    % ממוצע על חלון הבחינה
    int_profile(i) = mean( green_full(ys, xs), 'all' );
end

% נניח שיש לך שם קובץ/מזהה לריצה (לא חובה, רק לשם החלון)
runTag = datestr(now,'yyyymmdd_HHMMSS');  % חותמת זמן ייחודית

% חישוב סקייל ממ"מ
blade_length_mm = 61;  % אורך הלהב במילימטרים
scale_mm = blade_length_mm / (numSamples - 1);
x_mm = (0:numSamples-1) * scale_mm;

% גרף פרופיל (בחלון חדש)
figure('Name','Blade Profile','NumberTitle','off');
plot(x_mm, int_profile, 'k', 'LineWidth', 1.3); grid on
xlabel('מיקום לאורך הסכין [מ"מ]');
ylabel('Intensity (GREEN, raw units)');
title(sprintf('Blade reflection profile – full-frame GREEN\n%s', nef), 'Interpreter', 'none');

% תצוגה (להתרשמות; לא משנה נתונים)
%figure; imagesc(raw); axis image off; colormap gray
%title('Full-frame RAW (RGGB)');

% תצוגה (להתרשמות; לא משנה נתונים)
%figure; imagesc(green_full); axis image off; colormap gray
%title('Full-frame GREEN (from RAW, RGGB)');
