clear;
close all;

%% Toggle visualization and optimization functions
% Toggle trajectory data plots and initial leg design visualization 
viewVisualization = false; 
numberOfLoopRepetitions = 1;
viewTrajectoryPlots = false;

% number of links from 2 to 4. [thigh, shank, foot, phalanges]
linkCount = 2;

% Toggle optimization and set optimization properties
runOptimization = true;
viewOptimizedLegPlot = true;
optimizeLF = true; 
optimizeLH = false; 
optimizeRF = false; 
optimizeRH = false;

optimizationProperties.bounds.upperBoundMultiplier = [1, 3, 3]; % [hip thigh shank]
optimizationProperties.bounds.lowerBoundMultiplier = [1, 0.5, 0.5]; % [hip thigh shank]

if linkCount == 3
    optimizationProperties.bounds.upperBoundMultiplier = [3, 3, 3, 3]; % [hip thigh shank]
    optimizationProperties.bounds.lowerBoundMultiplier = [0.3, 0.5, 0.5, 0.5]; % [hip thigh shank]
end

if linkCount == 4
    optimizationProperties.bounds.upperBoundMultiplier = [3, 3, 3, 3, 3]; % [hip thigh shank]
    optimizationProperties.bounds.lowerBoundMultiplier = [0.3, 0.5, 0.5, 0.5, 0.5]; % [hip thigh shank]
end

optimizationProperties.viz.viewVisualization = false;
optimizationProperties.viz.displayBestCurrentLinkLengths = false; % display chart while running ga

optimizationProperties.options.maxGenerations = 20;
optimizationProperties.options.populationSize = 20;

optimizationProperties.penaltyWeight.totalTorque =   1;
optimizationProperties.penaltyWeight.totalqdot =     0;
optimizationProperties.penaltyWeight.totalPower =    0;
optimizationProperties.penaltyWeight.maxTorque =     0;
optimizationProperties.penaltyWeight.maxqdot =       0;
optimizationProperties.penaltyWeight.maxPower =      0;
optimizationProperties.penaltyWeight.trackingError = 100000;

%% Load task
% Select task and robot to be loaded
taskSelection = 'speedyGallop'; % universalTrot, universalStairs, speedyGallop, speedyStairs, massivoWalk, massivoStairs, centaurWalk, centaurStairs, miniPronk
robotSelection = 'speedy'; %universal, speedy, mini, massivo, centaur
configSelection = 'M'; % X, M

EEnames = ['LF'; 'RF'; 'LH'; 'RH'];
fprintf('Loading data for task %s.\n', taskSelection);

% Get suggested removal ratio for cropping motion data to useful steady state motion
[removalRatioStart, removalRatioEnd] = getSuggestedRemovalRatios(taskSelection);

% Load motion and force data from .mat file
load(taskSelection);

%% Load corresponding robot parameters
fprintf('Loading quadruped properties for %s.\n', robotSelection);
quadruped = getQuadrupedProperties(robotSelection);

%% Get the relative motion of the end effectors to the hips
fprintf('Computing motion of end effectors relative to hip attachment points \n');
[relativeMotionHipEE, IF_hip, C_IBody] = getRelativeMotionEEHips(quat, quadruped, base, EE, dt);

%% Get the liftoff and touchdown timings for each end effector
dt = t(2) - t(1);
fprintf('Computing end effector liftoff and touchdown timings \n');
[tLiftoff, tTouchdown, minStepCount] = getEELiftoffTouchdownTimings(t, EE);

%% Get the mean cyclic position and forces for each end effector
fprintf('Computing average relative motion of end effectors over one step \n');
[meanCyclicMotionHipEE, cyclicMotionHipEE, meanCyclicC_IBody, samplingStart, samplingEnd, meanTouchdownIndex] = getHipEECyclicData(quadruped, tLiftoff, relativeMotionHipEE, EE, removalRatioStart, removalRatioEnd, dt, minStepCount, C_IBody, EEnames);
meanCyclicMotionHipEE.body.eulerAngles = zeros(length(meanCyclicMotionHipEE.body.eulerAngles),3);
%% Get reachable positions for link lengths and joint limits
fprintf('Computing range of motion dependent on link lengths and joint limits \n');
reachablePositions = getRangeofMotion(quadruped);

%% Plot trajectory data
if viewTrajectoryPlots
    fprintf('Plotting data. \n');
    plotMotionData;
end

%% Inverse kinematics to calculate joint angles for each leg joint
fprintf('Computing joint angles using inverse kinematics. \n');
for i = 1:4
    EEselection = EEnames(i,:);
    [Leg.(EEselection).q, Leg.(EEselection).r.EE]  = inverseKinematics(linkCount, meanCyclicMotionHipEE, quadruped, EEselection, taskSelection, configSelection);
end

 %% Forward kinematics to get joint positions relative to hip attachment point
% later come back to this and use Jacobian to get position of each joint
% for now we only need EE position

% fprintf('Computing joint positions relative to the hip attachment point using forward kinematics. \n');
% jointCount = 4; % [HAA HFE KFE EE] not yet able to handle AFE joint
% for i = 1:4
%     EEselection = EEnames(i,:);
%     Leg.(EEselection).r = getJointPositions(quadruped, Leg, jointCount, EEselection, meanCyclicMotionHipEE);
% end

%% Build robot rigid body model
fprintf('Creating robot rigid body model. \n');
for i = 1:4
    EEselection = EEnames(i,:);
    Leg.(EEselection).rigidBodyModel = buildRobotRigidBodyModel(linkCount, quadruped, Leg, meanCyclicMotionHipEE, EEselection, numberOfLoopRepetitions, viewVisualization);
end

%% Get joint velocities with inverse(Jacobian)* EE.velocity
% the joint accelerations are then computed using finite difference
fprintf('Computing joint velocities and accelerations. \n');
for i = 1:4
    EEselection = EEnames(i,:);
    [Leg.(EEselection).qdot, Leg.(EEselection).qdotdot] = getJointVelocitiesUsingJacobian(linkCount, EEselection, meanCyclicMotionHipEE, Leg, quadruped, dt);
end

%% Get joint torques using inverse dynamics
fprintf('Computing joint torques using inverse dynamics \n');
for i = 1:4
    EEselection = EEnames(i,:);
    Leg.(EEselection).jointTorque = inverseDynamics(EEselection, Leg, meanCyclicMotionHipEE, linkCount);
end

%% Optimize selected legs
if runOptimization
    if optimizeLF
        EEselection = 'LF';
        fprintf('\nInitiating optimization of link lengths for %s\n', EEselection);
        [Leg.(EEselection).jointTorqueOpt, Leg.(EEselection).qOpt, Leg.(EEselection).qdotOpt, Leg.(EEselection).qdotdotOpt] = evolveAndVisualizeOptimalLeg(linkCount, optimizationProperties, EEselection, meanCyclicMotionHipEE, quadruped, configSelection, dt, taskSelection);
    end 
    if optimizeLH
        EEselection = 'LH';
        fprintf('\nInitiating optimization of link lengths for %s\n', EEselection);
        [Leg.(EEselection).jointTorqueOpt, Leg.(EEselection).qOpt, Leg.(EEselection).qdotOpt, Leg.(EEselection).qdotdotOpt] = evolveAndVisualizeOptimalLeg(linkCount, optimizationProperties, EEselection, meanCyclicMotionHipEE, quadruped, configSelection, dt, taskSelection);
    end
    if optimizeRF
        EEselection = 'RF';
        fprintf('\nInitiating optimization of link lengths for %s\n', EEselection);
        [Leg.(EEselection).jointTorqueOpt, Leg.(EEselection).qOpt, Leg.(EEselection).qdotOpt, Leg.(EEselection).qdotdotOpt] = evolveAndVisualizeOptimalLeg(linkCount, optimizationProperties, EEselection, meanCyclicMotionHipEE, quadruped, configSelection, dt, taskSelection);
    end
    if optimizeRH
        EEselection = 'RH';
        fprintf('\nInitiating optimization of link lengths for %s\n', EEselection);
        [Leg.(EEselection).jointTorqueOpt, Leg.(EEselection).qOpt, Leg.(EEselection).qdotOpt, Leg.(EEselection).qdotdotOpt] = evolveAndVisualizeOptimalLeg(linkCount, optimizationProperties, EEselection, meanCyclicMotionHipEE, quadruped, configSelection, dt, taskSelection);
    end  
%% plot joint torque and speed for initial and optimized design
    if viewOptimizedLegPlot
        fprintf('Plotting joint data for initial and optimized leg designs \n');
        if optimizeLF
            EEselection = 'LF';
            plotOptimizedJointTorque(Leg, EEselection, dt, meanTouchdownIndex)
        end
        if optimizeLH
            EEselection = 'LH';
            plotOptimizedJointTorque(Leg, EEselection, dt, meanTouchdownIndex)
        end
        if optimizeRF
            EEselection = 'RF';
            plotOptimizedJointTorque(Leg, EEselection, dt, meanTouchdownIndex)
        end
        if optimizeRH
            EEselection = 'RH';
            plotOptimizedJointTorque(Leg, EEselection, dt, meanTouchdownIndex)
        end
    end
end
