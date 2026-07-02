function blade_workflow_v3_roi()
% ---------------------------------------------------------------
% זרימת עבודה (ללא סיבוב/היפוך לאחר Rectify):
% 1) בחירת קובץ NEF
% 2) RAW -> GREEN (ממוצע G1/G2)
% 3) יישור ע"י 4 נקודות ROI (drawpoint) → projective (Rectify)
% 4) בחירת שתי נקודות קצה לאורך הלהב עם drawpoint (ללא קו)
% 5) חישוב פרופיל לאורך הקטע בין הנקודות (על GREEN לאחר Rectify)
% 6) שמירה: MAT + PNG + תמונה מסומנת (רק שתי נקודות)
% ---------------------------------------------------------------

    % פרמטרים כלליים
    blade_length_mm = 61;   % אורך הלהב במילימטרים
    winLeftX  = 2;          % חלון ממוצע שמאלה
    winRightX = 2;          % חלון ממוצע ימינה
    halfWinY  = 1;          % חלון ממוצע למעלה/למטה (סימטרי)

    % בחירת קובץ
    [f,p] = uigetfile({'.NEF','Nikon RAW (.NEF)'}, 'בחר קובץ NEF');
    if isequal(f,0); disp('בוטל.'); return; end
    nef = fullfile(p,f);

    % --- קריאת RAW והפקת GREEN ---
    raw = double(rawread(nef));      % Bayer (RGGB)
    g1  = raw(1:2:end, 2:2:end);     % Green1
    g2  = raw(2:2:end, 1:2:end);     % Green2
    M   = min(size(g1,1), size(g2,1));
    N   = min(size(g1,2), size(g2,2));
    green_full = (g1(1:M,1:N) + g2(1:M,1:N))/2;

    % --- יישור באמצעות 4 נקודות ROI ---
    figRect = figure('Name','יישור: בחר 4 פינות מלבן ייחוס','NumberTitle','off');
    set(figRect,'Units','normalized','Position',[0.05 0.05 0.9 0.85]);
    imshow(green_full,[]); axis image; hold on;
    title({'בחר 4 פינות מלבן ייחוס (עם/נגד כיוון השעון)', ...
           'ניתן לגרור את הנקודות לפני אישור (דאבל־קליק על נקודה לסיום גרירה)'});

    p1 = drawpoint('Color','y'); wait(p1);
    p2 = drawpoint('Color','y'); wait(p2);
    p3 = drawpoint('Color','y'); wait(p3);
    p4 = drawpoint('Color','y'); wait(p4);

    uiwait(msgbox('כוון/גרור את כל 4 הנקודות עד דיוק פיקסל, ואז לחץ OK להמשך.','סיום סימון','modal'));

    src = [p1.Position; p2.Position; p3.Position; p4.Position]; % [x y] בכל שורה

    % יעד מלבני "ישר" לפי מעטפת המקור (שומר קנה מידה מקורב)
    minx=min(src(:,1)); maxx=max(src(:,1));
    miny=min(src(:,2)); maxy=max(src(:,2));
    dst = [minx miny;  maxx miny;  maxx maxy;  minx maxy];

    % טרנספורמציה פרספקטיבית
    tform = fitgeotrans(src, dst, 'projective');

    % OutputView: גודל התמונה המקורית לנוחות (אפשר להתאים אם תרצה)
    outRef = imref2d(size(green_full));
    green_rect = imwarp(green_full, tform, 'OutputView', outRef);

    % --- בחירת שתי נקודות קצה לאורך הלהב (ללא קו) ---
    % תצוגה עם gamma רק לשיפור נראות (החישוב על green_rect)
    g_disp = im2double(green_rect).^0.5;

    figPts = figure('Name','בחר שתי נקודות קצה לאורך הלהב','NumberTitle','off');
    set(figPts,'Units','normalized','Position',[0.05 0.05 0.9 0.85]);
    imshow(g_disp, []); axis image; hold on;
    title({'סמן שתי נקודות קצה לאורך הלהב (מלמעלה למטה)', ...
           'ניתן לגרור כל נקודה לפני אישור'});

    pA = drawpoint('Color',[1 1 0]); wait(pA);
    pB = drawpoint('Color',[1 1 0]); wait(pB);

    uiwait(msgbox('כוון/גרור את שתי הנקודות עד דיוק פיקסל, לחץ OK להמשך.','אישור','modal'));

    P1 = pA.Position;   % [x y]
    P2 = pB.Position;   % [x y]

    % (לא מציירים קו כדי לא להסתיר – רק נקודות קטנות כברירת מחדל)

    % --- חישוב פרופיל לאורך הקטע בין P1 ל-P2 (על green_rect) ---
    [int_profile, x_mm] = bladeProfileAlongLine(green_rect, P1, P2, ...
        'winLeftX', winLeftX, 'winRightX', winRightX, ...
        'halfWinY', halfWinY, 'bladeLengthMM', blade_length_mm);

    % --- גרף פרופיל ---
    figProf = figure('Name','Blade Profile','NumberTitle','off');
    plot(x_mm, int_profile, 'k', 'LineWidth', 1.3); grid on
    xlabel('מיקום לאורך הסכין [מ"מ]'); ylabel('Intensity (GREEN, raw units)');
    title(sprintf('Blade reflection profile – %s', f), 'Interpreter','none');

    % --- שמירה ---
    outdir = fullfile(p, 'profiles'); 
    if ~exist(outdir, 'dir'); mkdir(outdir); end
    base = erase(f, '.NEF');

    matPath = fullfile(outdir, [base '_profile.mat']);
    pngPath = fullfile(outdir, [base '_profile.png']);
    jpgAnno = fullfile(outdir, [base '_annotated_points.jpg']);

    save(matPath, 'x_mm','int_profile','P1','P2','winLeftX','winRightX','halfWinY','blade_length_mm');
    exportgraphics(figProf, pngPath, 'Resolution', 200);

    % תמונה מסומנת – רק שתי נקודות (ללא קו), כדי לא להסתיר את הלהב
    figA = figure('Visible','off'); imshow(g_disp,[]); hold on;
    scatter([P1(1) P2(1)], [P1(2) P2(2)], 28, ...
            'Marker','o', ...
            'MarkerEdgeColor',[1 1 0], 'MarkerFaceColor',[1 1 0], ...
            'MarkerEdgeAlpha',0.85, 'MarkerFaceAlpha',0.65);
    exportgraphics(gca, jpgAnno, 'Resolution', 200);
    close(figA);

    fprintf('\nנשמרו קבצים אל: %s\n- %s\n- %s\n- %s\n', outdir, matPath, pngPath, jpgAnno);
end

% ---------------------------------------------------------------
% עזר: חישוב פרופיל לאורך קו עם ממוצע חלון קטן סביב כל נקודה
% ---------------------------------------------------------------
function [int_profile, x_mm] = bladeProfileAlongLine(img, P1, P2, varargin)
    p = inputParser;
    addParameter(p,'winLeftX',2,@isscalar);
    addParameter(p,'winRightX',2,@isscalar);
    addParameter(p,'halfWinY',1,@isscalar);
    addParameter(p,'bladeLengthMM',61,@isscalar);
    parse(p,varargin{:});

    wL = p.Results.winLeftX; 
    wR = p.Results.winRightX;
    hY = p.Results.halfWinY;
    Lmm = p.Results.bladeLengthMM;

    H = size(img,1);  W = size(img,2);
    % מספר דגימות לפי אורך הקטע בפיקסלים
    numSamples = max( round(hypot(P2(1)-P1(1), P2(2)-P1(2))) , 2 );
    xg = linspace(P1(1), P2(1), numSamples).';
    yg = linspace(P1(2), P2(2), numSamples).';

    int_profile = zeros(numSamples,1);
    for i = 1:numSamples
        y0 = min(max(round(yg(i)),1), H);
        x0 = min(max(round(xg(i)),1), W);
        xs = max(1, x0 - wL) : min(W, x0 + wR);
        ys = max(1, y0 - hY) : min(H, y0 + hY);
        int_profile(i) = mean( img(ys, xs), 'all' );
    end

    % ציר X במילימטרים לאורך הלהב
    x_mm = linspace(0, Lmm, numSamples).';
end
