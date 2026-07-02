clear; clc; close all;

%% בחירת קובץ session או profile
[fileName, folderName] = uigetfile( ...
    {'*.mat','MAT files (*.mat)'}, ...
    'בחר קובץ session_correct_tform או profile');

if isequal(fileName,0)
    error("לא נבחר קובץ.");
end

matPath = fullfile(folderName, fileName);
S = load(matPath);

%% אם נבחר session
if isfield(S, "session")
    sess = S.session;
    sessionPath = matPath;

%% אם נבחר profile, נטען את ה-session מתוכו
elseif isfield(S, "sessionFile") && isfile(S.sessionFile)
    sessionPath = S.sessionFile;
    tmp = load(sessionPath, "session");
    sess = tmp.session;

else
    error("הקובץ אינו session, וגם אינו profile עם sessionFile תקין.");
end

%% התמונה הירוקה המקורית
green = double(sess.green_full);

%% מיקום קו הלהב במערכת המיושרת
[x1r, y1r] = transformPointsForward(sess.tform, sess.P1_orig(1), sess.P1_orig(2));
[x2r, y2r] = transformPointsForward(sess.tform, sess.P2_orig(1), sess.P2_orig(2));

%% גבולות מלבן הכיול במערכת המיושרת
rectX = [1 sess.targetW sess.targetW 1 1];
rectY = [1 1 sess.targetH sess.targetH 1];

%% בניית OutputView מורחב שכולל גם את המלבן וגם את קו הלהב
margin = 30;   % פיקסלים מיושרים

xMin = floor(min([rectX(:); x1r; x2r]) - margin);
xMax = ceil( max([rectX(:); x1r; x2r]) + margin);

yMin = floor(min([rectY(:); y1r; y2r]) - margin);
yMax = ceil( max([rectY(:); y1r; y2r]) + margin);

nCols = max(2, round(xMax - xMin + 1));
nRows = max(2, round(yMax - yMin + 1));

Rext = imref2d( ...
    [nRows nCols], ...
    [xMin xMax], ...
    [yMin yMax]);

greenRectExt = imwarp( ...
    green, ...
    sess.tform, ...
    "OutputView", Rext, ...
    "FillValues", 0);

%% הצגה בצירים של מ"מ
xLimits_mm = (Rext.XWorldLimits - 1) * sess.mm_per_pix;
yLimits_mm = (Rext.YWorldLimits - 1) * sess.mm_per_pix;

figure("Name","Rectified green image - extended","NumberTitle","off");

imagesc(xLimits_mm, yLimits_mm, greenRectExt);
colormap gray;
axis image;
set(gca, "YDir", "reverse");
colorbar;

xlabel("x [mm]");
ylabel("y [mm]");
title("התמונה הירוקה המיושרת - תצוגה מורחבת", "Interpreter","none");

hold on;

%% ציור מלבן הכיול
plot( ...
    (rectX - 1) * sess.mm_per_pix, ...
    (rectY - 1) * sess.mm_per_pix, ...
    "b--", ...
    "LineWidth", 1.2);

%% ציור קו הלהב
plot( ...
    ([x1r x2r] - 1) * sess.mm_per_pix, ...
    ([y1r y2r] - 1) * sess.mm_per_pix, ...
    "r-", ...
    "LineWidth", 1.8);

legend("מלבן הכיול", "קו הלהב", "Location", "best");

%% שמירה
[sessionFolder, sessionBase, ~] = fileparts(sessionPath);
outPng = fullfile(sessionFolder, sessionBase + "_rectified_green_extended.png");

exportgraphics(gcf, outPng, "Resolution", 300);

fprintf("\nנשמרה תמונה מיושרת מורחבת:\n%s\n", outPng);
fprintf("Blade line rectified x range: %.3f to %.3f mm\n", ...
    (x1r-1)*sess.mm_per_pix, (x2r-1)*sess.mm_per_pix);
fprintf("Calibration rectangle x range: %.3f to %.3f mm\n", ...
    0, (sess.targetW-1)*sess.mm_per_pix);