function blade_workflow_v2()
% =========================================================
% blade_workflow_v2.m
% זרימה:
% 1) בחירת NEF → הפקת GREEN מלאה (ממוצע G1,G2)
% 2) יישור פרספקטיבה על כל הפריים (בחירת 4 נקודות על GREEN)
% 3) הצגת GREEN המיושר, THEN שאלת סיבוב (אם צריך)
% 4) תצוגת Gamma/CLAHE למסך מלא + בחירת 2 קצות להב
% 5) פרופיל לאורך 61 מ״מ
% =========================================================

%% (1) בחירת NEF ויצירת GREEN
[fn, fp] = uigetfile({'*.NEF','Nikon RAW (*.NEF)'}, 'בחר קובץ NEF');
assert(ischar(fn) || isstring(fn), 'לא נבחר קובץ');
nef = fullfile(fp, fn);
green = read_green_full(nef);   % יחידות RAW, חצי רזולוציה בכל ציר

%% (2) יישור פרספקטיבה על GREEN (בחירת 4 נקודות)
fig1 = fullscreenFigure('בחירת 4 נקודות ליישור (על GREEN)');
imshow(mat2gray(green), 'InitialMagnification','fit'); axis on; impixelinfo
title({'בחר 4 נקודות (פינות מלבן) על GREEN – Enter/דאבל-קליק לסיום', ...
       'הסדר לא קריטי (נסדר אוטומטית)'});
[x4,y4] = getpts;  assert(numel(x4)>=4,'נדרשות לפחות 4 נקודות');
pts = [x4(1:4) y4(1:4)]; hold on
plot(pts(:,1), pts(:,2), 'ro','MarkerSize',8,'LineWidth',1.5);
hold off

P = orderCorners(pts);
[w,h] = rectSizeFromCorners(P);
fixed = [1 1; w 1; w h; 1 h];
tform = fitgeotrans(P, fixed, 'projective');

% מחושב OutputView כך שכל הפריים המיושר ייכנס
RAg = imref2d(size(green));
[xLimOut, yLimOut] = outputLimits(tform, [1 RAg.ImageSize(2)], [1 RAg.ImageSize(1)]);
outW = ceil(xLimOut(2)-xLimOut(1));
outH = ceil(yLimOut(2)-yLimOut(1));
RoutG = imref2d([outH outW], xLimOut, yLimOut);

green_warp = imwarp(green, tform, 'OutputView', RoutG);

%% (3) מציגים את GREEN המיושר, ורק אז שואלים על סיבוב
fig2 = fullscreenFigure('GREEN אחרי יישור – לבדיקה');
imshow(mat2gray(green_warp), 'InitialMagnification','fit'); axis on; impixelinfo
title('GREEN אחרי יישור (לפני סיבוב אופציונלי)');

ansRot = questdlg('לסובב את התמונה המיושרת?', 'כיוון', ...
                  'לא','ימינה 90°','שמאלה 90°','לא');
switch ansRot
    case 'ימינה 90°',  green_warp = imrotate(green_warp, -90);
    case 'שמאלה 90°',  green_warp = imrotate(green_warp,  90);
end

%% (4) תצוגת Gamma/CLAHE על GREEN המיושר + בחירת 2 קצות להב
gamma = 0.5;  % 0.5–0.8
disp_gamma = imadjust(mat2gray(green_warp), [], [], gamma);
disp_clahe = adapthisteq(mat2gray(green_warp), 'NumTiles',[8 8], 'ClipLimit',0.01);

fig3 = fullscreenFigure('בחר קצות להב (בחר מצב תצוגה)');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
ax1 = nexttile; imshow(disp_gamma, 'InitialMagnification','fit'); title('Gamma')
ax2 = nexttile; imshow(disp_clahe, 'InitialMagnification','fit'); title('CLAHE')
impixelinfo
sgtitle('בחר מצב (Gamma/CLAHE), הקלק בתוך אותו חלון 2 נקודות, ואז Enter','FontSize',12)

modeSel = questdlg('על איזה מצב לבחור נקודות?', 'בחירת מצב', ...
                   'Gamma','CLAHE','Gamma');
if strcmp(modeSel,'Gamma')
    axes(ax1);
else
    axes(ax2);
end
[xb,yb] = getpts;  assert(numel(xb)>=2,'נדרשות 2 נקודות לפחות');
bp1 = [round(xb(1)), round(yb(1))];
bp2 = [round(xb(2)), round(yb(2))];

%% (5) פרופיל לאורך 61 מ״מ
winLeftX  = 1;   % פיקסלים שמאלה (ב-GREEN המיושר)
winRightX = 3;   % פיקסלים ימינה
halfWinY  = 0;   % ממוצע סימטרי בציר Y

numSamples = abs(bp2(2)-bp1(2)) + 1;
yg = round(linspace(bp1(2), bp2(2), numSamples)).';
xg = round(linspace(bp1(1), bp2(1), numSamples)).';

H = size(green_warp,1); W = size(green_warp,2);
int_profile = zeros(numSamples,1);
for i = 1:numSamples
    y0 = min(max(yg(i),1), H);
    x0 = min(max(xg(i),1), W);
    xs = max(1, x0 - winLeftX) : min(W, x0 + winRightX);
    ys = max(1, y0 - halfWinY) : min(H, y0 + halfWinY);
    int_profile(i) = mean(green_warp(ys, xs), 'all');
end

blade_len_mm = 61;
x_mm = linspace(0, blade_len_mm, numSamples);

fig4 = figure('Name','Blade Profile','NumberTitle','off');
plot(x_mm, int_profile, 'k','LineWidth',1.4); grid on
xlabel('מיקום לאורך הסכין [מ״מ]'); ylabel('Intensity (GREEN raw units)');
title(sprintf('Blade reflection profile – %s', fn), 'Interpreter','none');

disp('סיום: יישור על GREEN, סיבוב אחרי תצוגה, בחירה על Gamma/CLAHE, פרופיל 61 מ״מ');
end

% ===== פונקציות עזר =====
function green = read_green_full(nef)
    raw = double(rawread(nef));
    G1 = raw(1:2:end, 2:2:end);
    G2 = raw(2:2:end, 1:2:end);
    M  = min(size(G1,1), size(G2,1));
    N  = min(size(G1,2), size(G2,2));
    green = (G1(1:M,1:N) + G2(1:M,1:N))/2;
end

function f = fullscreenFigure(nameStr)
    f = figure('Name',nameStr,'NumberTitle','off');
    try, set(f,'WindowState','maximized'); catch
        set(f,'Units','normalized','OuterPosition',[0 0 1 1]);
    end
end

function P = orderCorners(pts)
% TL,TR,BR,BL (לא תלוי סדר ההקלקה)
    s = pts(:,1) + pts(:,2);
    d = pts(:,1) - pts(:,2);
    [~, iTL] = min(s);
    [~, iBR] = max(s);
    [~, iTR] = min(d);
    [~, iBL] = max(d);
    P = [pts(iTL,:); pts(iTR,:); pts(iBR,:); pts(iBL,:)];
end

function [w,h] = rectSizeFromCorners(P)
% ממוצע אורכי צלעות מקבילות ליעד יציב
    w = round(mean([norm(P(2,:)-P(1,:)), norm(P(3,:)-P(4,:))]));
    h = round(mean([norm(P(4,:)-P(1,:)), norm(P(3,:)-P(2,:))]));
    w = max(w,10); h = max(h,10);
end
