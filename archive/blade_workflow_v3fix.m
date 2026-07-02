function blade_workflow_v3_fix()
    blade_length_mm = 61;
    winLeftX=2; winRightX=2; halfWinY=1;

    [f,p] = uigetfile({'*.NEF','Nikon RAW (*.NEF)'}, 'בחר קובץ NEF');
    if isequal(f,0); return; end
    nef = fullfile(p,f);

    % RAW → GREEN
    raw = double(rawread(nef));
    g1  = raw(1:2:end, 2:2:end);
    g2  = raw(2:2:end, 1:2:end);
    M = min(size(g1,1),size(g2,1)); N = min(size(g1,2),size(g2,2));
    green_full = (g1(1:M,1:N)+g2(1:M,1:N))/2;

  % לפני בחירת הנקודות: אפשר לאפשר זום/פאן כדי להתקרב:
fig = figure('Name','בחר 4 פינות מלבן הייחוס','NumberTitle','off');
imshow(green_full,[]); axis image; title('התקרב/הזז, ואז סמן 4 פינות (עם/נגד כיוון השעון)');
zoom(fig,'on'); pan(fig,'on');
uiwait(msgbox('התקרב/הזז כרצונך. לסיום לחץ OK ואז סמן את 4 הפינות.'));

zoom(fig,'off'); pan(fig,'off'); hold on;

% במקום ginput(4):
p1 = drawpoint('Color','y');      % נקודה 1
p2 = drawpoint('Color','y');      % נקודה 2
p3 = drawpoint('Color','y');      % נקודה 3
p4 = drawpoint('Color','y');      % נקודה 4
% (אפשר לגרור אותן למיקום מדויק לפני המשך)

src = [p1.Position; p2.Position; p3.Position; p4.Position];  % [x y] בכל שורה

    % יעד מלבני "ישר" (אפשר לחשב מהגבולות של src; כאן ניקח מעטפת הדוקה)
    minx=min(x4); maxx=max(x4); miny=min(y4); maxy=max(y4);
    dst = [minx miny; maxx miny; maxx maxy; minx maxy];

    tform = fitgeotrans(src, dst, 'projective');
    outRef = imref2d(size(green_full));  % אפשר גם imref2d(round([maxy-miny, maxx-minx]))
    green_rect = imwarp(green_full, tform, 'OutputView', outRef);

    % תקנון אחיד אחרי היישור: 90° ימינה ואז היפוך אופקי
    green_rot = imrotate(green_rect, -90, 'bilinear', 'loose');
    green_std = fliplr(green_rot);

    % בדיקת ביניים
    figure('Name','Rectify → Rotate → Flip','NumberTitle','off');
    subplot(1,3,1); imshow(green_rect,[]); title('אחרי Rectify');
    subplot(1,3,2); imshow(green_rot,[]);  title('ועוד 90° ימינה');
    subplot(1,3,3); imshow(green_std,[]);  title('ולבסוף היפוך אופקי');
% אחרי תצוגת GREEN (עם gamma להצגה בלבד):
fig2 = figure('Name','סמן קו לאורך הלהב','NumberTitle','off');
imshow(g_disp,[]); axis image; title('צייר קו לאורך הלהב (ניתן לגרור את הקצוות לפני אישור)');
hold on;

hL = drawline('Color','y','LineWidth',1.6);   % קו ROI צהוב וברור
% אפשר לכוונן: גרור את הקצוות עד דיוק פיקסל

wait(hL);                                     % ממתין עד שהמשתמש מאשר (דאבל-קליק על הקו או Esc לסיום)
P = hL.Position;                               % 2x2: [x1 y1; x2 y2]
P1 = P(1,:); P2 = P(2,:);
plot(P(:,1), P(:,2), 'yo', 'MarkerFaceColor','y');  % ציון נקודות הקצה

   
    % פרופיל
    [int_profile, x_mm] = bladeProfileAlongLine(green_std, P1, P2, ...
        'winLeftX',winLeftX,'winRightX',winRightX,'halfWinY',halfWinY, ...
        'bladeLengthMM',blade_length_mm);

    figure('Name','Blade Profile','NumberTitle','off');
    plot(x_mm, int_profile, 'k','LineWidth',1.3); grid on
    xlabel('מיקום לאורך הסכין [מ"מ]'); ylabel('Intensity (GREEN)');
    title(sprintf('Blade reflection profile – %s', f),'Interpreter','none');

    % שמירות
    outdir = fullfile(p,'profiles'); if ~exist(outdir,'dir'), mkdir(outdir); end
    base = erase(f,'.NEF');
    save(fullfile(outdir,[base '_profile.mat']), 'x_mm','int_profile','P1','P2',...
         'winLeftX','winRightX','halfWinY','blade_length_mm');
    exportgraphics(gcf, fullfile(outdir,[base '_profile.png']), 'Resolution', 200);

    % תמונה מסומנת
    figA = figure('Visible','off'); imshow(g_disp,[]); hold on;
    plot([P1(1) P2(1)],[P1(2) P2(2)],'y-','LineWidth',1.5);
    exportgraphics(gca, fullfile(outdir,[base '_annotated.jpg']), 'Resolution', 200);
    close(figA);
end
