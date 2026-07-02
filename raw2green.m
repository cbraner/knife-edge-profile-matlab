function greenImage = raw2green(nef)
    % פונקציה להמרת תמונת RAW (NEF) לתמונת Green
    % Input: nef - נתיב לקובץ NEF
    % Output: greenImage - מטריצת התמונה הירוקה (ממוצע G1 ו-G2)
    
    % קריאת RAW מלא
    raw = double(rawread(nef));
    
    % RGGB: Green1 = שורות זוגיות, עמודות אי-זוגיות
    %       Green2 = שורות אי-זוגיות, עמודות זוגיות
    g1 = raw(1:2:end, 2:2:end);
    g2 = raw(2:2:end, 1:2:end);
    
    % גזירה למכנה משותף וחיבור (Green1+Green2)/2
    M = min(size(g1,1), size(g2,1));
    N = min(size(g1,2), size(g2,2));
    greenImage = (g1(1:M,1:N) + g2(1:M,1:N))/2;