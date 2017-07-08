function extractresults(path)
    % Name Format: 'slp01a_PSOELM_result.mat'
    header = {'Experiment', 'gBestFitness', 'TrainAcc', 'TestAcc', 'HiddenNodes', 'SelectedFeatures'};
    AllClassesResult = loadmatobject(fileName, 1);
    fileName = strsplit(path, '/');
    folderName = cell2mat(fileName(1));
    fileName = cell2mat(fileName(end));
    recName = strsplit(fileName, '.');
    recName = cell2mat(recName(1));
    mkdir(recName);
    nClasses = length(AllClassesResult);
    nExperiments = length(AllClassesResult(1).experimentResult);
    
    for iClass=1:nClasses
        totalClass = AllClassesResult(iClass).totalClass;
        %fprintf('%5s %5s %15s %15s %15s %15s %15s\n', 'Class', 'Exp', 'gBestFitness', 'TrainAcc', 'TestAcc', 'HiddenNodes', 'SelectedFeatures');
        temp = zeros(nExperiments, length(header)-1);
        tempCell = cell(nExperiments, 1);
        for iExp=1:nExperiments
            result = AllClassesResult(iClass).experimentResult(iExp);
            whichIteration = result.iteration(end).gBest.whichIteration;
            whichParticle = result.iteration(end).gBest.whichParticle;
            
            gBestFitness = result.iteration(end).gBest.fitness;
            trainAcc = result.iteration(whichIteration+1).trainingAccuracy(whichParticle);
            testAcc = result.iteration(whichIteration+1).testingAccuracy(whichParticle);
            nHiddenNodes = result.iteration(whichIteration+1).nHiddenNodes(whichParticle);
            selectedFeatures = result.iteration(whichIteration+1).selectedFeatures(whichParticle);
            
            temp(iExp, 1) = iExp;
            temp(iExp, 2) = gBestFitness;
            temp(iExp, 3) = trainAcc;
            temp(iExp, 4) = testAcc;
            temp(iExp, 5) = nHiddenNodes;
            tempCell(iExp, 1) = selectedFeatures;
            %fprintf('%5d %5d %15d %15d %15d %15d %15s\n', totalClass, iExp, gBestFitness, trainAcc, testAcc, nHiddenNodes, cell2mat(selectedFeatures));
        end
        
        xlswrite(sprintf('%s/%s.xlsx', folderName, fileName), header, sprintf('%d classes', totalClass), 'A1');
        xlswrite(sprintf('%s/%s.xlsx', folderName, fileName), temp, sprintf('%d classes', totalClass), 'A2');
        xlswrite(sprintf('%s/%s.xlsx', folderName, fileName), tempCell, sprintf('%d classes', totalClass), 'F2');
        
        bestIdx = -1;
        found = find(temp(:, 2) == max(temp(:, 2)));
        if length(found) > 1
            found2 = find(temp(found, 4) == max(temp(found, 4)));
            if length(found2) > 1
                found3 = find(temp(found2, 3) == max(temp(found2, 3)));
                if length(found3) > 1
                    found4 = find(temp(found3, 5) == min(temp(found3, 5)));
                    if length(found4) > 1
                        minLength = length(tempCell{found4(1)});
                        bestIdx = found4(1);
                        for i=2:length(found4)
                            if length(tempCell{found4(i)}) < minLength
                                minLength = length(tempCell{found4(i)});
                                bestIdx = found4(i);
                            end
                        end
                        
                    else
                        bestIdx = found4;
                    end
                else
                    bestIdx = found3;
                end
            else
                bestIdx = found2;
            end
        else
            bestIdx = found;
        end
        
        %to-do: plot the best index
        xlswrite(strcat(recName, '.xlsx'), {'best experiment'}, sprintf('%d classes', totalClass), sprintf('G%d', bestIdx+1));

        nIterations = length(AllClassesResult(iClass).experimentResult(bestIdx).iteration)-1;
        gBest = zeros();
        for iItr=1:nIterations
            gBest(iItr) = AllClassesResult(iClass).experimentResult(bestIdx).iteration(iItr).gBest.fitness;
        end
        
        % save graphics
        fName = strsplit(recName, '_');
        f = figure;
        plot(1:nIterations, gBest);
        ylabel('gBest Fitness'); xlabel('Iteration');
        title(sprintf('[%s] Best Experiment of %s (%d classes)', cell2mat(fName(1)), cell2mat(fName(2)), totalClass));
        saveas(f, sprintf('%s/[%s] gBest of %s (%d classes).png', recName, cell2mat(fName(1)), cell2mat(fName(2)), totalClass));
        close all;
        %fprintf('\n');
    end
end