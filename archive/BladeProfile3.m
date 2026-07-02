%% נתוני הסכינים (כפי שסיפקת)
knifeData = table( ...
    {'DSC_1918','DSC_1919','DSC_1920','DSC_1921','DSC_1922'}', ... % Pic Num
    (0:4)', ...                           % Knife Num
    [2719, 2718, 2726, 2738, 2703]', ...  % X up
    [1349, 1358, 1372, 1395, 1397]', ...  % Y up
    [2696, 2669, 2644, 2655, 2654]', ...  % X down
    [3208, 3256, 3334, 3344, 3293]', ...  % Y down
    'VariableNames', {'PicNum','KnifeNum','Xup','Yup','Xdown','Ydown'} ...
);

%% פרמטרים גלובליים
blade_length_mm = 61;   % אורך הלהב הפיזי
winLeftX  = 1;          % חלון דגימה שמאלה (פיקסלים ב-GREEN)
winRightX = 3;          % חלון דגימה ימינה
halfWinY  = 0;          % חלון סימטרי על ציר Y (0 = רק השורה עצמה)

% תיקיית יצוא (אם לא קיימת – נוצרת)
outDir = "profiles";
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% ריצה על כל הסכינים
for k = 1:height(knifeData)
    % --- שליפת שורה ---
    row = knifeData(k,:);
    nef = [row.PicNum{1} '.NEF'];              % שם קובץ ה-RAW

    % --- קריאת RAW מלא ---
    raw = double(rawread(nef));                % מטריצת RAW (Bayer)

    % --- הפקת תמונת GREEN מלאה (ממוצע Green1+Green2) ---
    G1 = raw(1:2:end, 2:2:end);                % Green1: שורות זוגיות, עמודות אי-זוגיות
    G2 = raw(2:2:end, 1:2:end);                % Green2: שורות אי-זוגיות, עמודות זוגיות
    M = min(size(G1,1), size(G2,1));
    N = min(size(G1,2), size(G2,2));
    green_full = (G1(1:M,1:N) + G2(1:M,1:N)) / 2;

    % --- נקודות להב בקואורדינטות RAW ---
    bladeP1_raw = [row.Xup,   row.Yup  ];
    bladeP2_raw = [row.Xdown, row.Ydown];

    % --- מיפוי RAW -> GREEN (חצי רזולוציה בכל ציר) ---
    mapRAW2G = @(p) [ floor(p(1)/2), floor(p(2)/2) ];
    bp1g = mapRAW2G(bladeP1_raw);
    bp2g = mapRAW2G(bladeP2_raw);

    % --- יצירת דגימות לאורך הלהב (X משתנה לינארית עם Y) ---
    numSamples = abs(bp2g(2) - bp1g(2)) + 1;
    yg = round(linspace(bp1g(2), bp2g(2), numSamples)).';  % שורות ב-GREEN
    xg = round(linspace(bp1g(1), bp2g(1), numSamples)).';  % עמודות ב-GREEN

    % --- דגימת עוצמה עם חלון X לא-סימטרי ו-Y סימטרי ---
    H = size(green_full,1);
    W = size(green_full,2);
    int_profile = zeros(numSamples,1);

    for i = 1:numSamples
        y0 = min(max(yg(i),1), H);
        x0 = min(max(xg(i),1), W);

        xs = max(1, x0 - winLeftX)  :  min(W, x0 + winRightX);
        ys = max(1, y0 - halfWinY)  :  min(H, y0 + halfWinY);

        int_profile(i) = mean(green_full(ys, xs), 'all');
    end

    % --- ציר X במילימטרים ---
    scale_mm = blade_length_mm / (numSamples - 1);
    x_mm = (0:numSamples-1) * scale_mm;

    % --- ציור גרף (נשאר פתוח) ---
    fig = figure('Name', sprintf('Blade Profile – Knife %d', row.KnifeNum), ...
                 'NumberTitle','off');
    plot(x_mm, int_profile, 'k','LineWidth',1.3); grid on
    xlabel('מיקום לאורך הסכין [מ"מ]');
    ylabel('Intensity (GREEN raw units)');
    title(sprintf('Blade reflection profile – Knife %d (%s)', ...
          row.KnifeNum, nef), 'Interpreter','none');

    % --- שמירה כ-FIG וכ-PNG ---
    savefig(fig, fullfile(outDir, sprintf('profile_knife%d_%s.fig', row.KnifeNum, row.PicNum{1})));
    exportgraphics(fig, fullfile(outDir, sprintf('profile_knife%d_%s.png', row.KnifeNum, row.PicNum{1})));
end

disp('סיימתי: כל הגרפים נשמרו בתיקייה "profiles" ונשארו פתוחים.');
