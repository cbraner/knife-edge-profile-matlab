clear; clc; close all;

%% ===================== הגדרות התחלה =====================

startFolder = "C:\Users\HAIM\Documents\KnifeImages\תמונות מיקרוסקופ לאורך הסכין";

defaultPxPerMm = 1185;   % ברירת מחדל, אפשר לשנות
bgGray = 235;             % 255 = לבן, 235 = אפור בהיר מאוד, 220 = אפור כהה יותר

%% ===================== ריצה ראשית =====================

pxPerMm = askScale(defaultPxPerMm);

[I, folderName, fileName] = chooseImage(startFolder);
[~, imageBaseName, ~] = fileparts(fileName);   % שם הקובץ בלי סיומת

%[xFull, yFull] = detectBladeEdge(I);
[xFull, yFull] = detectBladeEdge(I);

% חיתוך קצות הפרופיל כדי להתעלם מאזורים בעייתיים בקצוות התמונה
% ברירת מחדל: 0 משמאל, 150 מימין
[xFull, yFull] = trimProfileEndsInteractive(I, xFull, yFull, 0, 150);

[yBase, depth_px, depth_mm, x_mm, idxMax, maxDepth_mm, maxDepth_px, xMax_mm] = ...
    chooseBaselineAndCalculateDepth(I, xFull, yFull, pxPerMm);

% תיקון בליטות מדומות מעל קו הבסיס, למשל בגלל תאורה ורודה בצד התמונה
[yFull, depth_px, depth_mm, x_mm, idxMax, maxDepth_mm, maxDepth_px, xMax_mm] = ...
    removeAboveBaselineArtifacts(xFull, yFull, yBase, pxPerMm);

% בתמונת ההדפסה מחליפים לאפור את כל הרקע שמעל קו הבסיס,
% גם באזורים שנחתכו מהפרופיל לצורך החישוב
IgrayBackground = makeLightGrayBackgroundMixed(I, xFull, yFull, yBase, bgGray);
figColor = showColorResult(I, xFull, yFull, yBase, idxMax, maxDepth_mm, pxPerMm, imageBaseName);

figPrint = showGrayPrintResult(IgrayBackground, xFull, yFull, yBase, idxMax, maxDepth_mm, pxPerMm, imageBaseName);
saveResults(folderName, fileName, figColor, figPrint, ...
    xFull, yFull, yBase, x_mm, depth_px, depth_mm);

fprintf("\n--- תוצאות ---\n");
fprintf("Calibration = %.4f pixels/mm\n", pxPerMm);
fprintf("Maximum depth = %.4f mm\n", maxDepth_mm);
fprintf("Maximum depth = %.2f pixels\n", maxDepth_px);
fprintf("Location x = %.4f mm from start of ROI\n", xMax_mm);


%% =========================================================
%% ======================== פונקציות ========================
%% =========================================================

function pxPerMm = askScale(defaultPxPerMm)

    answer = inputdlg( ...
        {"הכנס קנה מידה: כמה פיקסלים יש ב-1 מ״מ?"}, ...
        "קנה מידה", ...
        1, ...
        {num2str(defaultPxPerMm)});

    if isempty(answer)
        error("לא הוכנס קנה מידה.");
    end

    txt = strrep(answer{1}, ",", ".");
    pxPerMm = str2double(txt);

    if isnan(pxPerMm) || pxPerMm <= 0
        error("קנה המידה אינו תקין. צריך מספר חיובי, למשל 115.6");
    end
end


function [I, folderName, fileName] = chooseImage(startFolder)

    [fileName, folderName] = uigetfile( ...
        {'*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp', 'Image files'}, ...
        'בחר את תמונת הלהב', ...
        startFolder);

    if isequal(fileName, 0)
        error("לא נבחר קובץ.");
    end

    imgPath = fullfile(folderName, fileName);
    I = imread(imgPath);

    if size(I,3) == 1
        I = repmat(I, 1, 1, 3);
    end
end

function [xFull, yFull] = detectBladeEdge(I)

    figure;
    imshow(I);
    title("סמן מלבן סביב שפת הלהב והפגם. חשוב לכלול רקע נקי מעל הלהב");

    roi = drawrectangle("Color", "y");
    wait(roi);
    pos = round(roi.Position);   % [x y width height]

    Ic = imcrop(I, pos);

    [nRows, nCols, ~] = size(Ic);

    %% בניית מודל צבע של הרקע מתוך החלק העליון של המלבן
    % ההנחה: החלק העליון של המלבן שסימנת הוא רקע, לא סכין.
    topFrac = 0.20;   % 20% עליונים של המלבן משמשים ללימוד צבע הרקע
    topRows = 1:max(8, round(topFrac * nRows));

    Lab = rgb2lab(Ic);
    A = Lab(:,:,2);
    B = Lab(:,:,3);

    % צבע הרקע בכל עמודה לפי החלק העליון
    aBg = median(A(topRows, :), 1);
    bBg = median(B(topRows, :), 1);

    % החלקה אופקית של צבע הרקע, כדי להתמודד עם שינוי צהוב/ורוד
    smoothColorWindow = 51;
    if nCols < smoothColorWindow
        smoothColorWindow = max(5, 2*floor(nCols/10)+1);
    end

    aBg = smoothdata(aBg, "movmedian", smoothColorWindow);
    bBg = smoothdata(bBg, "movmedian", smoothColorWindow);

    % מרחק צבע של כל פיקסל מצבע הרקע המקומי באותה עמודה
    colorDist = hypot(A - aBg, B - bBg);

    % סף התאמה לרקע
    % אם הקו נכנס לתוך הסכין - הקטן ל-22 או 20
    % אם הוא מפספס רקע אמיתי ליד השפה - הגדל ל-30 או 35
    colorThresh = 26;

    BG = colorDist < colorThresh;

    %% ניקוי מסכת הרקע
    BG = imclose(BG, strel("disk", 3));
    BG = imfill(BG, "holes");
    BG = bwareaopen(BG, 200);

    % משאירים רק את הרקע שמחובר לחלק העליון של המלבן
    marker = false(size(BG));
    marker(1,:) = BG(1,:);
    BG = imreconstruct(marker, BG);

    %% חלון בדיקה למסכת הרקע
    % לבן = מה שהתוכנה מזהה כרקע
    % שחור = מה שהתוכנה מזהה כסכין/לא רקע
    figure;
    imshow(BG);
    title("בדיקה: לבן = רקע מזוהה, שחור = סכין/לא רקע");

    %% מציאת קו השפה
    % מחפשים מעבר ראשון מלמעלה לרצף של פיקסלים שאינם רקע.
    yEdge = nan(1, nCols);

    minMetalRun = 8;
    % אם עדיין יש נפילה לתוך הסכין, נסה 12 או 15.
    % אם הוא מפספס פגם חד אמיתי, נסה 5 או 6.

    for x = 1:nCols
        col = BG(:,x);

        metalCandidate = ~col;

        runCount = movsum(double(metalCandidate), [0 minMetalRun-1]);

        y = find(runCount >= minMetalRun, 1, "first");

        if ~isempty(y)
            yEdge(x) = y;
        end
    end

    %% מילוי והחלקה עדינה
    yEdge = fillmissing(yEdge, "linear", "EndValues", "nearest");

    % תיקון קפיצות נקודתיות בלבד
    yMed = movmedian(yEdge, 9);
    jumpLimit = 25;

    bad = abs(yEdge - yMed) > jumpLimit;
    yEdge(bad) = yMed(bad);

    % החלקה עדינה של הקו
    smoothWindow = 5;
    if smoothWindow > 1
        yEdge = movmedian(yEdge, smoothWindow);
    end

    %% החזרה לקואורדינטות של התמונה המקורית
    xLocal = 1:nCols;

    xFull = xLocal + pos(1) - 1;
    yFull = yEdge + pos(2) - 1;

    figure;
    imshow(I);
    hold on;
    plot(xFull, yFull, "r", "LineWidth", 1.5);
    title("קו שפת הלהב שנמצא");
end

function [yBase, depth_px, depth_mm, x_mm, idxMax, maxDepth_mm, maxDepth_px, xMax_mm] = ...
    chooseBaselineAndCalculateDepth(I, xFull, yFull, pxPerMm)

    figure;
    imshow(I);
    hold on;
    plot(xFull, yFull, "r", "LineWidth", 1.5);
    title("סמן מלבן קטן על שפה ישרה משמאל לפגם, ואז לחץ פעמיים");

    roiLeft = drawrectangle("Color", "g");
    wait(roiLeft);
    posLeft = roiLeft.Position;

    title("עכשיו סמן מלבן קטן על שפה ישרה מימין לפגם, ואז לחץ פעמיים");

    roiRight = drawrectangle("Color", "g");
    wait(roiRight);
    posRight = roiRight.Position;

    inLeft = ...
        xFull >= posLeft(1) & xFull <= posLeft(1)+posLeft(3) & ...
        yFull >= posLeft(2) & yFull <= posLeft(2)+posLeft(4);

    inRight = ...
        xFull >= posRight(1) & xFull <= posRight(1)+posRight(3) & ...
        yFull >= posRight(2) & yFull <= posRight(2)+posRight(4);

    baseIdx = inLeft | inRight;

    if sum(baseIdx) < 5
        error("נבחרו מעט מדי נקודות לקו הבסיס. סמן מלבנים שכוללים חלק מהקו האדום.");
    end

    % התאמת קו ישר לשני הקטעים הישרים
    p = polyfit(xFull(baseIdx), yFull(baseIdx), 1);
    yBase = polyval(p, xFull);

    % עומק בפיקסלים ובמילימטרים
    depth_px = yFull - yBase;
    depth_mm = depth_px / pxPerMm;

    % ציר x במ״מ מתחילת אזור המדידה
    x_mm = (xFull - xFull(1)) / pxPerMm;

    [maxDepth_mm, idxMax] = max(depth_mm);
    maxDepth_px = depth_px(idxMax);
    xMax_mm = x_mm(idxMax);
end

function Iout = makeLightGrayBackgroundMixed(I, xFull, yFull, yBase, bgGray)

    Iout = I;

    if size(Iout,3) == 1
        Iout = repmat(Iout, 1, 1, 3);
    end

    [imgH, imgW, ~] = size(Iout);

    xq = 1:imgW;

    % קו בסיס לכל רוחב התמונה, כולל אקסטרפולציה ימינה ושמאלה
    yBaseAll = interp1( ...
        double(xFull), ...
        double(yBase), ...
        double(xq), ...
        "linear", ...
        "extrap");

    % מתחילים מכך שמחוץ לאזור המדידה נשתמש בקו הבסיס
    yMaskLine = yBaseAll;

    % בתוך אזור המדידה נשתמש בקו שפת הלהב האמיתי
    inMeasuredRange = xq >= min(xFull) & xq <= max(xFull);

    yEdgeMeasured = interp1( ...
        double(xFull), ...
        double(yFull), ...
        double(xq(inMeasuredRange)), ...
        "linear", ...
        "extrap");

    yMaskLine(inMeasuredRange) = yEdgeMeasured;

    % יצירת מסכה: כל מה שמעל הקו יהיה רקע אפור בהיר
    maskBG = false(imgH, imgW);

    for i = 1:numel(xq)
        x = xq(i);

        yLimit = round(yMaskLine(i)) - 2;  % לא לדרוס את קו השפה עצמו

        if yLimit > 1
            yLimit = min(yLimit, imgH);
            maskBG(1:yLimit, x) = true;
        end
    end

    bgGray = uint8(bgGray);

    for c = 1:3
        channel = Iout(:,:,c);
        channel(maskBG) = bgGray;
        Iout(:,:,c) = channel;
   
    
    
    end
end

function fig = showColorResult(I, xFull, yFull, yBase, idxMax, maxDepth_mm, pxPerMm, imageBaseName)
    fig = figure("Name", "Color result");
    imshow(I);
    hold on;

    [imgH, imgW, ~] = size(I);

    hEdge = plot(xFull, yFull, "r-", "LineWidth", 2.0);
    hBase = plot(xFull, yBase, "g-", "LineWidth", 1.5);

    hDepth = plot( ...
        [xFull(idxMax), xFull(idxMax)], ...
        [yBase(idxMax), yFull(idxMax)], ...
        "c-", "LineWidth", 2.0);

    plot( ...
        xFull(idxMax), yFull(idxMax), ...
        "bo", ...
        "MarkerSize", 8, ...
        "LineWidth", 2.0);

    addScaleBar(xFull, yFull, pxPerMm, imgW, "k", 1.2, "black");

    addDepthText(imgW, imgH, maxDepth_mm, "cyan", "black");

    legend([hEdge, hBase, hDepth], ...
        "קו שפת הלהב", ...
        "קו בסיס ישר", ...
        "עומק מרבי", ...
        "Location", "northeast");

%    title("פרופיל הלהב, עומק מרבי וקנה מידה");
title( ...
    {"פרופיל הלהב, עומק מרבי וקנה מידה"; imageBaseName}, ...
    "Interpreter", "none");
end


function fig = showGrayPrintResult(IgrayBackground, xFull, yFull, yBase, idxMax, maxDepth_mm, pxPerMm, imageBaseName)
    % המרה אמיתית לגווני אפור, אבל נשאר בפורמט RGB כדי שגרפיקת MATLAB תופיע יפה
    Ig = rgb2gray(IgrayBackground);
    Ishow = repmat(Ig, 1, 1, 3);

    fig = figure("Name", "Grayscale print result");
    imshow(Ishow);
    hold on;

    [imgH, imgW, ~] = size(Ishow);

    % קו שפת הלהב - שחור עבה
    hEdge = plot(xFull, yFull, "k-", "LineWidth", 3.0);

    % קו בסיס - שחור מקווקו
    hBase = plot(xFull, yBase, "k--", "LineWidth", 1.2);

    % קו עומק - שחור מנוקד
    hDepth = plot( ...
        [xFull(idxMax), xFull(idxMax)], ...
        [yBase(idxMax), yFull(idxMax)], ...
        "k:", "LineWidth", 1.8);

    % נקודת עומק מרבי
    plot( ...
        xFull(idxMax), yFull(idxMax), ...
        "ko", ...
        "MarkerSize", 8, ...
        "LineWidth", 1.8, ...
        "MarkerFaceColor", "white");

    addScaleBar(xFull, yFull, pxPerMm, imgW, "k", 1.0, "black");

    addDepthText(imgW, imgH, maxDepth_mm, "black", "white");

    legend([hEdge, hBase, hDepth], ...
        "קו שפת הלהב", ...
        "קו בסיס ישר", ...
        "עומק מרבי", ...
        "Location", "northeast");

title( ...
    {"פרופיל הלהב, עומק מרבי וקנה מידה - גווני אפור"; imageBaseName}, ...
    "Interpreter", "none");
end


function addScaleBar(xFull, yFull, pxPerMm, imgW, lineColor, lineWidth, textColor)

    scaleLength_px = pxPerMm/2;   % 1 mm

    % מיקום קרוב לשמאל של אזור המדידה
    xScale1 = xFull(1) + 20;
    xScale2 = xScale1 + scaleLength_px;

    % מניעת יציאה מהתמונה
    if xScale2 > imgW - 10
        xScale2 = imgW - 10;
        xScale1 = xScale2 - scaleLength_px;
    end

    % מעל הלהב
    yScale = min(yFull) - 35;

    if yScale < 35
        yScale = 35;
    end

    % קו אופקי
    plot([xScale1, xScale2], [yScale, yScale], ...
        "-", ...
        "Color", lineColor, ...
        "LineWidth", lineWidth, ...
        "HandleVisibility", "off");

    % פסים אנכיים
    numDivisions = 5;        % כל 0.2 מ״מ
    tickHeightSmall = 10;
    tickHeightEnd = 22;

    for k = 0:numDivisions
        xTick = xScale1 + k * scaleLength_px / numDivisions;

        if k == 0 || k == numDivisions
            tickHeight = tickHeightEnd;
            tickLineWidth = lineWidth + 0.4;
        else
            tickHeight = tickHeightSmall;
            tickLineWidth = lineWidth;
        end

        plot( ...
            [xTick, xTick], ...
            [yScale - tickHeight/2, yScale + tickHeight/2], ...
            "-", ...
            "Color", lineColor, ...
            "LineWidth", tickLineWidth, ...
            "HandleVisibility", "off");
    end

    % כיתוב קנה המידה
    text( ...
        (xScale1 + xScale2)/2, ...
        yScale - 40, ...
        "0.5 mm", ...
        "Color", textColor, ...
        "FontSize", 12, ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "center", ...
        "BackgroundColor", "white", ...
        "Margin", 2, ...
        "HandleVisibility", "off");
end


function addDepthText(imgW, imgH, maxDepth_mm, textColor, backgroundColor)

    txtDepth = sprintf("Max depth = %.4f mm", maxDepth_mm);

    text( ...
        imgW/2, ...
        imgH - 25, ...
        txtDepth, ...
        "Color", textColor, ...
        "FontSize", 14, ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "center", ...
        "BackgroundColor", backgroundColor, ...
        "Margin", 4, ...
        "HandleVisibility", "off");
end


function saveResults(folderName, fileName, figColor, figPrint, ...
    xFull, yFull, yBase, x_mm, depth_px, depth_mm)

    [~, baseName, ~] = fileparts(fileName);
    baseName = string(baseName);

    outCsv = fullfile(folderName, baseName + "_profile_depth_mm.csv");
    outColorPng = fullfile(folderName, baseName + "_marked_color.png");
    outPrintPng = fullfile(folderName, baseName + "_marked_grayscale_print.png");

    T = table( ...
        xFull(:), ...
        yFull(:), ...
        yBase(:), ...
        x_mm(:), ...
        depth_px(:), ...
        depth_mm(:), ...
        'VariableNames', { ...
            'x_pixel', ...
            'edge_y_pixel', ...
            'baseline_y_pixel', ...
            'x_mm', ...
            'depth_pixels', ...
            'depth_mm'});

    writetable(T, outCsv);

    exportgraphics(figColor, outColorPng, "Resolution", 300);
    exportgraphics(figPrint, outPrintPng, "Resolution", 300);

    fprintf("\nSaved files:\n");
    fprintf("%s\n", outCsv);
    fprintf("%s\n", outColorPng);
    fprintf("%s\n", outPrintPng);
end

function [yClean, depth_px, depth_mm, x_mm, idxMax, maxDepth_mm, maxDepth_px, xMax_mm] = ...
    removeAboveBaselineArtifacts(xFull, yFull, yBase, pxPerMm)

    % בתמונה ציר y גדל כלפי מטה.
    % לכן נקודה "מעל" קו הבסיס היא נקודה שבה yFull קטן מ-yBase.
    %
    % במדידת עומק שקע, בליטות מעל קו הבסיס בדרך כלל נובעות מתאורה/צבע.
    % לכן נקודות שעולות מעל קו הבסיס ביותר מ-2 פיקסלים מוחזרות לקו הבסיס.

    aboveTolerance_px = 2;

    yClean = yFull;

    aboveBaseline = yClean < (yBase - aboveTolerance_px);

    yClean(aboveBaseline) = yBase(aboveBaseline);

    % חישוב עומק מחדש
    depth_px = yClean - yBase;

    % שלא יהיו עומקים שליליים
    depth_px(depth_px < 0) = 0;

    depth_mm = depth_px / pxPerMm;

    x_mm = (xFull - xFull(1)) / pxPerMm;

    [maxDepth_mm, idxMax] = max(depth_mm);
    maxDepth_px = depth_px(idxMax);
    xMax_mm = x_mm(idxMax);

    fprintf("Corrected %d above-baseline artifact points.\n", sum(aboveBaseline));
end

function [xTrim, yTrim] = trimProfileEndsInteractive(I, xFull, yFull, defaultLeftPx, defaultRightPx)

    answer = inputdlg( ...
        { ...
        "כמה פיקסלים להתעלם מצד שמאל של הפרופיל?", ...
        "כמה פיקסלים להתעלם מצד ימין של הפרופיל?" ...
        }, ...
        "חיתוך קצות הפרופיל", ...
        1, ...
        {num2str(defaultLeftPx), num2str(defaultRightPx)} );

    % אם סוגרים את החלון - משתמשים בברירת המחדל
    if isempty(answer)
        leftPx = defaultLeftPx;
        rightPx = defaultRightPx;
    else
        leftTxt = strrep(answer{1}, ",", ".");
        rightTxt = strrep(answer{2}, ",", ".");

        leftPx = str2double(leftTxt);
        rightPx = str2double(rightTxt);

        if isnan(leftPx) || leftPx < 0
            leftPx = 0;
        end

        if isnan(rightPx) || rightPx < 0
            rightPx = 0;
        end
    end

    leftPx = round(leftPx);
    rightPx = round(rightPx);

    xMinKeep = xFull(1) + leftPx;
    xMaxKeep = xFull(end) - rightPx;

    keep = xFull >= xMinKeep & xFull <= xMaxKeep;

    if sum(keep) < 20
        error("אחרי חיתוך הקצוות נשארו מעט מדי נקודות בפרופיל. הקטן את ערכי החיתוך.");
    end

    xTrim = xFull(keep);
    yTrim = yFull(keep);

    % תצוגת בדיקה אחרי החיתוך
    figure;
    imshow(I);
    hold on;

    plot(xFull, yFull, "Color", [0.8 0.8 0.8], "LineWidth", 1.0);
    plot(xTrim, yTrim, "r", "LineWidth", 1.8);

    xline(xMinKeep, "k--", "LineWidth", 1.2);
    xline(xMaxKeep, "k--", "LineWidth", 1.2);

    legend("הפרופיל המקורי", "הפרופיל שישמש לחישוב", "גבולות החיתוך", "Location", "best");
    title("בדיקה: חיתוך קצות הפרופיל");
end