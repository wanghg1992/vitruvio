clear;
close all;

%% Data extraction
% if averageStepsForCyclicalMotion is true, the motion is segmented into individual steps which are averaged
% to create an average cycle. This works well when the motion is very cyclical.
% If false the individual steps are not averaged. This should be selected
% when the generated motion is irregular and highly cyclical.
dataExtraction.averageStepsForCyclicalMotion = true; 
dataExtraction.allowableDeviation = 0.05; % [m] Deviation between neighbouring points. If the deviation is larger, additional points are interpolated.

%% Toggle leg properties: leg count, link count, configuration, direct/remote joint actuation, spider/serial leg
legCount  = 4;                  % Accepts values from 1 to 4.
linkCount = 2;                  % Accepts values from 2 to 4. [thigh, shank, foot, phalanges]. Hip link connects HAA and HFE but is not included in link count.
configSelection = 'X';          % X or M

% If true, actuators are positioned in the joint which contributes to leg
% mass and inertia. If false, there is no actuator mass at joints, the 
% actuator is assumed to be in the body.
actuateJointDirectly.HAA = false; 
actuateJointDirectly.HFE = false; 
actuateJointDirectly.KFE = false;
actuateJointDirectly.AFE = true;
actuateJointDirectly.DFE = true;

%% Select actuators for each joint
% Select from: {ANYdrive, Neo, RobotDrive, other} or add a new actuator in
% getActuatorProperties
actuatorSelection.HAA = 'ANYdrive'; 
actuatorSelection.HFE = 'ANYdrive'; 
actuatorSelection.KFE = 'ANYdrive';
actuatorSelection.AFE = 'ANYdrive'; 
actuatorSelection.DFE = 'ANYdrive'; 

% If joints are remotely actuated, specify the transmission method to
% compute an additional mass and inertia along all links connecting that
% joint to the body.
% Possible methods are: 'chain', 'cable', 'belt'
% The density of the chain/cable/belt is hardcoded in
% getTransmissionProperties
transmissionMethod.HAA = 'belt'; 
transmissionMethod.HFE = 'belt'; % Along hip link
transmissionMethod.KFE = 'chain'; % Along thigh link
transmissionMethod.AFE = 'cable'; % Along shank link
transmissionMethod.DFE = 'cable'; % Along foot link

% Specify hip orientation
% if true: Serial configuration. Offset from HAA to HFE parallel to the body as with ANYmal 
% if false: Spider configuration. Hip link is perpendicular to body length.
hipParalleltoBody = true;

%% AFE and DFE heuristics (for 3 and 4 link legs)
% The heuristic computes the final joint angle (AFE or DFE) as a 
% deformation proportional to torque. For a four link leg, the thigh and
% foot are maintained parallel.
heuristic.torqueAngle.apply = true; % Choose whether to apply the heuristic.
heuristic.torqueAngle.thetaLiftoff_des = pi/3; % Specify desired angle between final link and horizonal at liftoff. If the desired angle is impossible for the given link lengths, the closest feasible angle is obtained.
heuristic.torqueAngle.kTorsionalSpring = 20; % Spring constant for torsional spring at final joint [Nm/rad]

%% Toggle trajectory plots and initial design viz
viewVisualization            = false; % initial leg design tracking trajectory plan
numberOfStepsVisualized      = 1;     % number of steps visualized for leg motion
viewPlots.motionData         = false;  % CoM position, speed. EE position and forces. Trajectory to be tracked.
viewPlots.rangeOfMotionPlots = false; % range of motion of leg for given link lengths and angle limits
viewPlots.efficiencyMap      = false; % actuator operating efficiency map
viewPlots.jointDataPlot      = true; % angle, speed, torque, power, energy data
viewPlots.metaParameterPlot  = false; % design parameters and key results plotted as pie charts
% Optimization visualization
optimizationProperties.viz.viewVisualization = false;
optimizationProperties.viz.numberOfCyclesVisualized = 1;
optimizationProperties.viz.displayBestCurrentDesign = true; % display chart of current best leg design parameters while running ga

%% Select a .mat trajectory data file to be simulated and optimized
% Select from the below options or import a new data .mat set using the
% importMotionData script

%%% Add your trajectory data file here %%%
yourTrajectoryData = false;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

universalTrot    = false;
universalStairs  = false;
speedyStairs     = false;
speedyGallop     = true;
massivoWalk      = false;
massivoStairs    = false;
centaurWalk      = false;
centaurStairs    = false;
miniPronk        = false;
ANYmalTrot       = false;
defaultHopperHop = false;
ANYmalSlowTrot2  = false;
ANYmalFlyingTrot = true;
ANYmalTrotVersatilityStep = true;
ANYmalSlowTrotAccurateMotion = false;

numberOfRepetitions = 0; % Number of times that leg is reoptimized. This allows for an easy check if the same optimal solution is found each time the optimization is run.

%% Toggle optimization for each leg
runOptimization = false; 
% select which legs are to be optimized
optimizeLeg.LF = true; 
optimizeLeg.RF = false; 
optimizeLeg.LH = false; 
optimizeLeg.RH = false;

%% Set optimization properties

% Set number of generations and population size
optimizationProperties.options.maxGenerations = 1;
optimizationProperties.options.populationSize = 5;

% Impose limits on maximum joint torque, speed and power
% the values are defined in getActuatorProperties. A penalty term is incurred
% for violations of these limits.
imposeJointLimits.maxTorque = false;
imposeJointLimits.maxqdot   = false;
imposeJointLimits.maxPower  = false;

% Set weights for fitness function terms. Total means summed over all
% joints in the leg.
optimizationProperties.penaltyWeight.totalSwingTorque  = 0;
optimizationProperties.penaltyWeight.totalStanceTorque = 0;
optimizationProperties.penaltyWeight.totalTorque       = 1;
optimizationProperties.penaltyWeight.totalTorqueHFE    = 0;
optimizationProperties.penaltyWeight.swingTorqueHFE    = 0;
optimizationProperties.penaltyWeight.totalqdot         = 0;
optimizationProperties.penaltyWeight.totalPower        = 0;     % only considers power terms > 0
optimizationProperties.penaltyWeight.totalMechEnergy   = 0;
optimizationProperties.penaltyWeight.totalElecEnergy   = 0;
optimizationProperties.penaltyWeight.averageEfficiency = 0;     % Maximizes average efficiency (even though this could increase overall energy use)
optimizationProperties.penaltyWeight.maxTorque         = 0;
optimizationProperties.penaltyWeight.maxqdot           = 0;
optimizationProperties.penaltyWeight.maxPower          = 0;     % only considers power terms > 0
optimizationProperties.penaltyWeight.antagonisticPower = 0;     % seeks to minimize antagonistic power which improves power quality
optimizationProperties.penaltyWeight.maximumExtension  = true;  % large penalty incurred if leg extends beyond allowable amount
optimizationProperties.allowableExtension              = 0.8;   % [0 1] penalize extension above this ratio of total possible extension

% Bounds are input as multipliers of nominal input value
optimizationProperties.bounds.upperBoundMultiplier.hipLength = 2;
optimizationProperties.bounds.lowerBoundMultiplier.hipLength = 0.5;

optimizationProperties.bounds.upperBoundMultiplier.thighLength = 2;
optimizationProperties.bounds.lowerBoundMultiplier.thighLength = 0.5;

optimizationProperties.bounds.upperBoundMultiplier.shankLength = 2;
optimizationProperties.bounds.lowerBoundMultiplier.shankLength = 0.5;

optimizationProperties.bounds.upperBoundMultiplier.footLength = 2;
optimizationProperties.bounds.lowerBoundMultiplier.footLength = 0.5;

optimizationProperties.bounds.upperBoundMultiplier.phalangesLength = 2;
optimizationProperties.bounds.lowerBoundMultiplier.phalangesLength = 0.5;

optimizationProperties.bounds.upperBoundMultiplier.hipOffset = 2;
optimizationProperties.bounds.lowerBoundMultiplier.hipOffset = 0.5;

optimizationProperties.bounds.upperBoundMultiplier.kTorsionalSpring = 10;
optimizationProperties.bounds.lowerBoundMultiplier.kTorsionalSpring = 0.5;

optimizationProperties.bounds.upperBoundMultiplier.thetaLiftoff_des = 1; % with initial value pi/4 this keeps the liftoff angle on [0,pi/2]
optimizationProperties.bounds.lowerBoundMultiplier.thetaLiftoff_des = 1;

%% run the simulation
if ~runOptimization % if optimization turned off, set values to zero.
    optimizeLeg.LF = 0; optimizeLeg.RF = 0; optimizeLeg.LH = 0; optimizeLeg.RH = 0;
end
simulateSelectedTasks;
fprintf('Done.\n');