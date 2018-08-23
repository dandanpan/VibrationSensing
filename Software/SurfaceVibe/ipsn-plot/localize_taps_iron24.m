% clear all
% close all
% clc

init();
s = Surface([40 40]);
s.addSensor(0,0);
s.addSensor(1,0);
s.addSensor(0,1);
s.addSensor(1,1);
tdoaCalc = FirstPeakTdoaCalculator();
% prepare renderer

GT{1} = [5,5];
GT{2} = [15,5];
GT{3} = [25,5];
GT{4} = [35,5];
GT{5} = [5,15];
GT{6} = [15,15];
GT{7} = [25,15];
GT{8} = [35,15];
GT{9} = [5,25];
GT{10} = [15,25];
GT{11} = [25,25];
GT{12} = [35,25];
GT{13} = [5,35];
GT{14} = [15,35];
GT{15} = [25,35];
GT{16} = [35,35];

evaIdx = 1;
for velocity = [10000, 15000] % 15000 for non-filter [6000, 30]
    localizer = PairLocalizer(s, [1,1,1,1,1,1].*velocity);
%       MPH = max(signals(:,minI))*0.5;
    for bandIdx = [24, 15] %
        estErr = [];
        
        
        load('datasets/iron24-tap.mat');
        for tapIdx = 0:15
            tapIdx
            bFilter = WaveletFilter();
            bFilter.noiseMaxScale=bandIdx;
            tdoas = [];
            points = [];
            for idx = 1 :length(events{tapIdx+1})
               e = events{tapIdx+1}(idx);
               if velocity ~= 15000 || bandIdx ~= 15
                    e.filter(bFilter);
               end
%                e.plot();
               [oneTdoa, oneTdoa2] = e.getTdoa(tdoaCalc);
               onePoint = localizer.resolve(oneTdoa);
               % check point location, if it is off too much, check the
               % second one, if both off, discard
               if sqrt(sum((onePoint - [20,20]).^2)) > 30
                   continue;
               end
               if onePoint(1) == 0 && onePoint(2) == 0
                   continue;
               end
               tdoas = [tdoas; oneTdoa];
               points = [points; onePoint];
            end
            tdoaAll{tapIdx+1} = tdoas;
            pointsAll{tapIdx+1} = points;
%             if size(points,1) >= 2
%                 renderer.addPoints(points);hold on;
%                 ptCenter = mean(points);
%                 if sum(isnan(ptCenter)) == 0
%                     plot([ptCenter(1),GT{tapIdx+1}(1)],[ptCenter(2),GT{tapIdx+1}(2)],'k');
%                     estErr = [estErr; sqrt(sum((ptCenter-GT{tapIdx+1}).^2))];
%                 end
%                 title([num2str(velocity) '-' num2str(bandIdx)]);
%             end
%             hold off;
        end
        
        
        renderer = SurfaceRenderer(s);
        renderer.plot();
        for tapIdx = 0:15
            if size(pointsAll{tapIdx+1},1) < 2
                continue;
            end
            renderer.addPoints(pointsAll{tapIdx+1});hold on;
            ptCenter = mean(pointsAll{tapIdx+1});
            if sum(isnan(ptCenter)) == 0
                plot([ptCenter(1),GT{tapIdx+1}(1)],[ptCenter(2),GT{tapIdx+1}(2)],'k');
                estErr = [estErr; sqrt(sum((ptCenter-GT{tapIdx+1}).^2))];
            end
            title([num2str(velocity) '-' num2str(bandIdx)]);
        end
        
        drawnow;
        evaluation{evaIdx} = struct('tdoa', tdoaAll, ...
                    'points', pointsAll, ...
                    'error', estErr, ...
                    'velocity', velocity, ...
                    'band', bandIdx);
        evaIdx = evaIdx + 1;
    end
end

% testTdoas = [];
% for tapIdx = 1:16
%     temp = mean(tdoaAll{tapIdx});
%     temp = temp-temp(1);
%     testTdoas = [testTdoas; temp];
% end

mean(estErr)
std(estErr)

save('iron24-tap-results-all.mat','evaluation');

