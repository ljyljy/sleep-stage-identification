function [result, startTime, endTime] = PSOforELM(MAX_ITERATIONS, nParticles, nFeatures, trainingData, testingData, W, c1, c2, Wa, Wf)
%% INPUT PARAMETER INITIALIZATION
%MAX_ITERATIONS = 100;
%nParticles = 20;
%nFeatures = 18; % total all features to be selected
%trainingData = matrix nTrainingSamples X nFeatures
%testingData = matrix nTestingSamples X nFeatures
% update velocity parameter 
%W = 0.6;
%c1 = 1.2;
%c2 = 1.2;
% fitness parameter
%Wa = 0.95;
%Wf = 0.05;
% END OF INPUT PARAMETER INITIALIZATION

nClasses = length(unique([trainingData(:, end); testingData(:, end)]));
fprintf('Running PSO-ELM for %d classes...\n', nClasses);
%fprintf('Start at %s\n', datestr(clock));
startTime = clock;

%% PSO PARAMETER PREPARATION
nHiddenBits = length(decToBin(size(trainingData, 1)));

% Population Initialization: [FeatureMask HiddenNode]
population_position = rand(nParticles, nFeatures+nHiddenBits) > 0.5;
% check and re-random if the value is invalid:
for i=1:nParticles
    while binToDec(population_position(i, nFeatures+1:end)) < nFeatures || ...
          binToDec(population_position(i, nFeatures+1:end)) > size(trainingData, 1) || ...
          sum(population_position(i, 1:nFeatures)) == 0
        population_position(i, :) = rand(1, nFeatures+nHiddenBits) > 0.5;
    end
end
population_fitness = zeros(nParticles, 1);
population_velocity = int64(zeros(nParticles, 1)); % in decimal value

pBest_position = zeros(nParticles, nFeatures+nHiddenBits);
pBest_fitness = repmat(-1000000, nParticles, 1); % max fitness value

gBest.position = zeros(1, nFeatures+nHiddenBits); 
gBest.fitness = -1000000; % max fitness value all particle all iteration
% END OF PSO PARAMETER PREPARATION

%% INITIALIZATION STEP
% save result to struct - part 1
result(1).iteration = 0;
result(1).nParticles = nParticles;

%fprintf('%8s %15s %15s %15s %15s %15s %20s\n', 'Particle', 'nHiddenNode', 'pBest', 'Time', 'TrainAcc', 'TestAcc', 'SelectedFeatures');
for i=1:nParticles
    tic;
    %fprintf('%8d %15d ', i, binToDec(population(i, nFeatures+1:end)));
    % TRAINING
    maskedTrainingFeature = featuremasking(trainingData, population_position(i, 1:nFeatures)); % remove unselected features
    trainingTarget = full(ind2vec(trainingData(:,end)'))'; % prepare the target data (transformation from 4 into [0 0 0 1 0 0])
    [elmModel, trainAcc] = trainELM(maskedTrainingFeature, trainingTarget, binToDec(population_position(i, nFeatures+1:end)));
    
    % TESTING
    maskedTestingFeature = featuremasking(testingData, population_position(i, 1:nFeatures)); % remove unselected features
    testingTarget = full(ind2vec(testingData(:,end)'))'; % prepare the target data (transformation from 4 into [0 0 0 1 0 0])
    testAcc = testELM(maskedTestingFeature, testingTarget, elmModel);
    
    population_fitness(i, 1) = fitness(Wa, Wf, testAcc, population_position(i, 1:nFeatures));
    
    % pBest Update
    if population_fitness(i, 1) > pBest_fitness(i, 1)
        pBest_fitness(i, 1) = population_fitness(i, 1);
        pBest_position(i, :) = population_position(i, :);
    end
    endT = toc;
    
    % print result
    %fprintf('%15d %15d %15d %15d %4s', pBest_fitness(i, 1), endTime, elmModel.trainingAccuracy, elmModel.testingAccuracy, ' ');
    %fprintf('%s\n', binToStringOrder(population(i, 1:nFeatures)));
    
    % save result to struct - part 2
    result(1).nHiddenNodes(i) = binToDec(population_position(i, nFeatures+1:end));
    result(1).selectedFeatures(i) = {binToStringOrder(population_position(i, 1:nFeatures))};    
    result(1).pBest(i) = pBest_fitness(i, 1);
    result(1).time(i) = endT;
    result(1).trainingAccuracy(i) = trainAcc;
    result(1).testingAccuracy(i) = testAcc;
    result(1).elmModel(i) = elmModel;
end

% gBest Update
if max(population_fitness) > gBest.fitness
    found = find(population_fitness == max(population_fitness));
    if length(found) > 1 % if have the same gBest fitness value, get the max of testAcc
        maxTestAcc = max(result(1).testingAccuracy(found));
        found2 = find(result(1).testingAccuracy(found) == maxTestAcc);
        if length(found2) > 1 % if have the same testAcc, get the max of trainAcc
            maxTrainAcc = max(result(1).trainingAccuracy(found));
            found3 = find(result(1).trainingAccuracy(found) == maxTrainAcc);
            if length(found3) > 1 % if have the same trainAcc, get the first particle
                found = found(1);
            else
                found = found(found3);
            end
        else
            found = found(found2);
        end
    end
    gBest.fitness = max(population_fitness);
    gBest.position = population_position(found, :);
    gBest.iterationOrigin = 0;
    gBest.particleOrigin = found;
end
%fprintf('gBest = %d\n', gBest.fitness);
% save result to struct - part 3
result(1).gBest = gBest;
% END OF INITIALIZATION STEP

%% PSO ITERATION
for iteration=1:MAX_ITERATIONS
    %fprintf('\nIteration %d of %d\n', iteration, MAX_ITERATIONS);
    % save result to struct - part 1
    result(iteration+1).iteration = iteration;
    result(iteration+1).nParticles = nParticles;
    % Update Velocity
    r1 = rand();
    r2 = rand();
    for i=1:nParticles
        % calculate velocity value
        positionDec = int64(binToDec(population_position(i, :)));
        population_velocity(i, 1) = W * population_velocity(i, 1) + ...
            c1 * r1 * (binToDec(pBest_position(i, :)) - positionDec) + ...
            c2 * r2 * (binToDec(gBest.position) - positionDec);
        
        % update particle position
        newPosDec = abs(int64(positionDec + population_velocity(i, 1)));
        newPosBin = decToBin(newPosDec);
        
        % if the total bits is lower than nFeatures + nHiddenBits, add zeros in front
        if size(newPosBin, 2) < (nFeatures + nHiddenBits)
            newPosBin = [zeros(1, (nFeatures + nHiddenBits)-size(newPosBin, 2)) newPosBin];
        end
        
        % if the number of hidden node is more than the number of samples
        if binToDec(newPosBin(1, nFeatures+1:end)) > size(trainingData, 1) ...
                || size(newPosBin(1, nFeatures+1:end), 2) > nHiddenBits
            newPosBin = [newPosBin(1, 1:nFeatures) decToBin(size(trainingData, 1))];
        end
        
        % if the number of selected features is 0
        while sum(newPosBin(1, 1:nFeatures)) == 0
            newPosBin(1, 1:nFeatures) = rand(1, nFeatures) > 0.5;
        end
        
        % set the value
        population_position(i, :) = newPosBin;
    end
    
    % Calculate Fitness Value
    %fprintf('%8s %15s %15s %15s %15s %15s %20s\n', 'Particle', 'nHiddenNode', 'pBest', 'Time', 'TrainAcc', 'TestAcc', 'SelectedFeatures');
    for i=1:nParticles
        tic;
        %fprintf('%8d %15d ', i, binToDec(population(i, nFeatures+1:end)));
        % TRAINING
        maskedTrainingFeature = featuremasking(trainingData, population_position(i, 1:nFeatures)); % remove unselected features
        trainingTarget = full(ind2vec(trainingData(:,end)'))'; % prepare the target data (transformation from 4 into [0 0 0 1 0 0])
        [elmModel, trainAcc] = trainELM(maskedTrainingFeature, trainingTarget, binToDec(population_position(i, nFeatures+1:end)));

        % TESTING
        maskedTestingFeature = featuremasking(testingData, population_position(i, 1:nFeatures)); % remove unselected features
        testingTarget = full(ind2vec(testingData(:,end)'))'; % prepare the target data (transformation from 4 into [0 0 0 1 0 0])
        testAcc = testELM(maskedTestingFeature, testingTarget, elmModel);
        
        population_fitness(i, 1) = fitness(Wa, Wf, testAcc, population_position(i, 1:nFeatures));

        % pBest Update
        if population_fitness(i, 1) > pBest_fitness(i, 1)
            pBest_fitness(i, 1) = population_fitness(i, 1);
            pBest_position(i, :) = population_position(i, :);
        end
        endT = toc;
        
        %fprintf('%15d %15d %15d %15d %4s', pBest_fitness(i, 1), endTime, elmModel.trainingAccuracy, elmModel.testingAccuracy, ' ');
        %fprintf('%s\n', binToStringOrder(population(i, 1:nFeatures)));
        % save result to struct - part 2    
        result(iteration+1).nHiddenNodes(i) = binToDec(population_position(i, nFeatures+1:end));
        result(iteration+1).selectedFeatures(i) = {binToStringOrder(population_position(i, 1:nFeatures))};
        result(iteration+1).pBest(i) = pBest_fitness(i, 1);
        result(iteration+1).time(i) = endT;
        result(iteration+1).trainingAccuracy(i) = trainAcc;
        result(iteration+1).testingAccuracy(i) = testAcc;
        result(iteration+1).elmModel(i) = elmModel;
        
    end

    % gBest Update
    if max(population_fitness) > gBest.fitness
        found = find(population_fitness == max(population_fitness));
        if length(found) > 1 % if have the same gBest fitness value, get the max of testAcc
            maxTestAcc = max(result(iteration+1).testingAccuracy(found));
            found2 = find(result(iteration+1).testingAccuracy(found) == maxTestAcc);
            if length(found2) > 1 % if have the same testAcc, get the max of trainAcc
                maxTrainAcc = max(result(iteration+1).trainingAccuracy(found));
                found3 = find(result(iteration+1).trainingAccuracy(found) == maxTrainAcc);
                if length(found3) > 1 % if have the same trainAcc, get the first particle
                    found = found(1);
                else
                    found = found(found3);
                end
            else
                found = found(found2);
            end
        end
        gBest.fitness = max(population_fitness);
        gBest.position = population_position(found, :);
        gBest.whichIteration = iteration;
        gBest.whichParticle = found;
    end
    
    % fprintf('gBest = %d\n', gBest.fitness);
    % save result to struct - part 3
    result(iteration+1).gBest = gBest;
    
end
% END OF PSO ITERATION

%fprintf('Selected Feature = %s\n', binToStringOrder(gBest.position(1, 1:nFeatures)));
%fprintf('n Hidden Node = %d\n', binToDec(gBest.position(1, nFeatures+1:end)));

%fprintf('Finish at %s\n', datestr(clock));
endTime = clock;
end