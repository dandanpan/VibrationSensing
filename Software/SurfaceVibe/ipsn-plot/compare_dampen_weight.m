clear all
close all
clc

init();

filename{1} = 'data/drive/dataset/wood24-bar1-dampened-swipe.mat';
filename{2} = 'data/drive/dataset/wood24-bar2-dampened-swipe.mat';
filename{3} = 'data/drive/dataset/wood24-bar3-dampened-swipe.mat';
filename{4} = 'data/drive/dataset/wood24-bar4-dampened-swipe.mat';
selectedScale{1} = 5;
selectedScale{2} = 5;
selectedScale{3} = 5;
selectedScale{4} = 5;

selectedVelocity{1} = 22000;
selectedVelocity{2} = 22000;
selectedVelocity{3} = 22000;
selectedVelocity{4} = 22000;

lines{1} = [20 30; 20 10];
lines{2} = [20-10/sqrt(2) 20+10/sqrt(2); 20+10/sqrt(2) 20-10/sqrt(2)];
lines{3} = [10 20; 30 20];
lines{4} = [20-10/sqrt(2) 20-10/sqrt(2); 20+10/sqrt(2) 20+10/sqrt(2)];
lines{5} = [20 10; 20 30];
lines{6} = [20+10/sqrt(2) 20-10/sqrt(2); 20-10/sqrt(2) 20+10/sqrt(2)];
lines{7} = [30 20; 10 20];
lines{8} = [20+10/sqrt(2) 20+10/sqrt(2); 20-10/sqrt(2) 20-10/sqrt(2)];

for fileIdx = 1:4
    fileIdx
    load(filename{fileIdx});
    scaleFrq = scal2frq(1:1024,'mexh',1/25000);
    selectedFrq = scaleFrq(selectedScale{fileIdx});
    bFilter = GainVaryingFilter(Fs);
    bFilter.addBand(selectedFrq-1,selectedFrq+1,2,1);
    bFilter.addBand(2*selectedFrq-1,2*selectedFrq+1,3,0.75);
    
    wFilter = WaveletFilter();
    wFilter.noiseMaxScale=selectedScale{fileIdx};
    
    s = Surface([40 40]);
    s.addSensor(0,0);
    s.addSensor(1,0);
    s.addSensor(0,1);
    s.addSensor(1,1);
    localizer = Localizer(s, [1,1,1,1].*selectedVelocity{fileIdx});

    % Base frequency
    P = 1/selectedFrq;
    Ps = floor(P*Fs);
    wSize = 500;
    dirIdxSet = 1:8;
    for dirIdx = dirIdxSet
        dirIdx
        line = lines{dirIdx};
        ep1 = line(1,:);
        ep2 = line(2,:);
        for eIdx = 1:length(events{dirIdx})
            h = figure;
            subplot(4,4,[2 3 4]);
            e = events{dirIdx}(eIdx);
            
            [ initLoc, initIdx, e ] = initPartExtract( e, Fs, wFilter, localizer );
            
            e.plot(0,h);
            axis tight;
            
%             e.filter(bFilter);
            sig = e.getSignals();
            g=figure; e.plot(0,g);

            time = e.getTime();
            timeIdxs = [];

            startIdxs = 1:(wSize):(length(sig)-1);
            startIdxs = startIdxs(1:end-2);
                
            % number of detected windows
            n = length(startIdxs);

            tdoas = zeros(n,3);
            conf = zeros(n,3);
            energy = zeros(n,4);
            energyProfile = zeros(n,1);
            
            % use sensor1 signal as reference
            sRef =sig(:,1);
            % get the energy profile of the entire window array 
            for idx = 1:n
                wStartIdx = startIdxs(idx);
                windowE = zeros(1,4);
                for sIdx = 1:size(sig,2)
                    sWindow = sig(wStartIdx:wStartIdx + wSize,sIdx);
                    sE = sqrt(sum(sWindow.*sWindow));
                    windowE(sIdx) = sE;
                end
                energyProfile(idx) = sum(windowE);
            end

            % get the tdoa of the window array and filter by xcorr and energy 
            for idx = 1:n
                wStartIdx = startIdxs(idx);
                refWindow = sRef(wStartIdx:wStartIdx + wSize);
                refE = sum(refWindow.*refWindow);
                refS = SignalNormalization(refWindow);
                energy(idx,1) = refE;
                for sIdx = 2:size(sig,2)
                    sWindow = sig(wStartIdx:wStartIdx + wSize,sIdx);
                    sE = sum(sWindow.*sWindow);
                    energy(idx,sIdx) = sE;
                    sNorm = SignalNormalization(sWindow);
                    % this is only used for filtered signals
                    [ lagDiff, lagVal, candidateDiff, candidateVal  ] = TDoAMinShift( refS, sNorm );
                    tdoas(idx,sIdx-1) = lagDiff/Fs;
                    conf(idx,sIdx-1) = lagVal;
                    tdoaCandidates{idx,sIdx-1} = [candidateDiff; candidateVal'];
                end

                if sum(energy(idx,:)) < prctile(energyProfile,0.2) || min(conf(idx,:)) < 0.2
                    tdoas(idx,:) = [NaN NaN NaN];
                else
                    timeIdxs = [timeIdxs wStartIdx];
                end
            end

            % moving average filter
            t = downsample(tdoas,2);
            figure(h);
            timePoints = time(timeIdxs) - time(1);
            subplot(4,4,1);
            e.plot(0,h);
            subplot(4,4,[2 3 4]);
            hold on;
            scatter(timePoints , zeros(size(timePoints)), [], linspace(1,10,length(timePoints)));
            axis tight;
            figure(h);
            subplot(4,4,5);
            plot([0 length(t)], [0 0]);
            axis tight;
            hold on;
            plot(t);
            axis tight;
            subplot(4,4,9);
            plot(conf);
            axis tight;
            subplot(4,4,13);
            plot(energy);
            axis tight;

            stdoas = zeros(size(t,1), 4);
            stdoas(:,2) = t(:,1);
            stdoas(:,3) = t(:,2);
            stdoas(:,4) = t(:,3);
            points = localizer.resolve(stdoas);

            % plot the points
            renderer = SurfaceRenderer(s);
            pIdxs = 1:16;
            pIdxs([1 2 3 4 5 9 13]) = [];
            subplot(4,4,pIdxs);
            renderer.plot(gcf);
            renderer.addPoints(initLoc);
            title(['scenario: ' num2str(fileIdx) ', #points:' num2str(length(points))]);
            validPoints = points(~isnan(points(:,1)),:);
            validConf = conf(~isnan(points(:,1)),:);
            validConf = validConf(validPoints(:,1)< 40 & validPoints(:,1)> 0,:);
            validPoints = validPoints(validPoints(:,1)< 40 & validPoints(:,1)> 0,:);
            validConf = validConf(validPoints(:,2)< 40 & validPoints(:,2)> 0,:);
            validPoints = validPoints(validPoints(:,2)< 40 & validPoints(:,2)> 0,:);
            % build the gaussian mixture model to remove outliers
            if size(validPoints,1) > 5
                obj = gmdistribution.fit(validPoints,1);
                pointDist = mahal(obj,validPoints);
                % 5 is selected based on the grid size
                validPoints = validPoints(pointDist < 3,:);
                validConf = validConf(pointDist < 3,:);
                validPoints = distanceFilter( validPoints, validConf );
                % filter based on distance from the highest validConf
                if size(validPoints,1) > 20
                    evaluation{fileIdx, dirIdx, eIdx} = evaluateSwipeWInit(validPoints, initLoc, [ep1; ep2], s);
                end
            end
            
            % add the high confidence point part
            renderer.addPoints(validPoints,true);
        end
        close all;
    end
end
save('compare_weight.mat','evaluation')