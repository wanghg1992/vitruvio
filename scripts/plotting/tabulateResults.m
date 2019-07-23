% Example calling function from saved results data: tabulateResults(results.ANYmal, 'flyingTrot')
function [] = tabulateResults(data, task)

    robotClass             = data.(task).basicProperties.classSelection;
    EEnames                = data.(task).basicProperties.EEnames;
    base                   = data.(task).base; % base motion for each leg during its cycle
    base.fullTrajectory    = data.(task).fullTrajectory.base;
    legCount               = data.(task).basicProperties.legCount;
    linkCount              = data.(task).basicProperties.linkCount;
    linkNames              = data.(task).basicProperties.linkNames';
    jointActuationMethod   = data.(task).basicProperties.jointActuationType;
    transmissionMethod     = data.(task).basicProperties.transmissionMethod;
    optimizationProperties = data.(task).optimizationProperties;
    allowableExtension     = data.(task).optimizationProperties.allowableExtension;
    
    linkNames = strjoin(linkNames);
    jointNames = data.(task).basicProperties.jointNames(1,:);
    actuatorSelection = data.(task).actuatorProperties.actuatorSelection.(data.(task).basicProperties.jointNames(1,:));
    actuationMethod = jointActuationMethod.HAA;
    transmission = transmissionMethod.HAA;
     
    %% Basic properties table
    for i = 2:linkCount+1 % Fill out the rest of the list programatically
        jointNames = [jointNames, ' ', data.(task).basicProperties.jointNames(i,:)];
        actuatorSelection = [actuatorSelection, ' ', data.(task).actuatorProperties.actuatorSelection.(data.(task).basicProperties.jointNames(i,:))];  
        actuationMethod = [actuationMethod, ' ', jointActuationMethod.(data.(task).basicProperties.jointNames(i,:))];
        transmission = [transmission, ' ', transmissionMethod.(data.(task).basicProperties.jointNames(i,:))];
    end
    
    rowNames = {'Robot class',...
                'Task', ...
                'Leg quantity', ...
                'Link names', ...
                'Joint names', ...
                'Actuator selection', ...
                'Joint actuation method', ...
                'Transmission method'};

            
    Basic_Properties = [string(robotClass); ...
                        string(task); ...
                        legCount; ...
                        string(linkNames); ...
                        string(jointNames); ...
                        string(actuatorSelection); ...
                        string(actuationMethod); ...                        
                        string(transmission)];
                    
   T = table(Basic_Properties, 'RowNames', rowNames)
   
    %% Optimization settings table
    % Go through the penalty terms and add them to the list of imposed
    % terms if the value is 1, otherwise do not add them to the list.

           
    for i = 1:legCount
        EEselection = EEnames(i,:);
        
            optimizedLegs = [];
            rowNames = {'Optimized legs',...
                        'Number of generations', ...
                        'Population size', ...
                        'Allowable leg extension/Total possible leg extension'};
        
        if data.(task).basicProperties.optimizedLegs.(EEselection) 
            optimizedLegs = [optimizedLegs, ' ', EEselection];
            generationCount = data.(task).optimizationProperties.gaSettings.(EEselection).generations;
            populationSize = floor(data.(task).optimizationProperties.gaSettings.(EEselection).funccount/(1+generationCount));

    Optimization_Properties = [string(optimizedLegs); ...
                               string(generationCount); ...
                               string(populationSize); ... 
                               string(allowableExtension)];
                                                   
    softConstraintCount = 0;                       
    if optimizationProperties.imposeJointLimits.maxTorque
        softConstraintCount = softConstraintCount + 1;
        s1 = num2str(softConstraintCount);
        s = strcat('Constraint',s1);
        rowNames(end+1) = {s};
        Optimization_Properties(end+1) = {'Impose max actuator torque limit'};
    end
    
    if optimizationProperties.imposeJointLimits.maxqdot
        softConstraintCount = softConstraintCount + 1;
        s1 = num2str(softConstraintCount);
        s = strcat('Constraint',s1);
        rowNames(end+1) = {s};
        Optimization_Properties(end+1) = {'Impose max actuator speed limit'};        
    end

    if optimizationProperties.imposeJointLimits.maxPower
        softConstraintCount = softConstraintCount + 1;
        s1 = num2str(softConstraintCount);
        s = strcat('Constraint',s1);
        rowNames(end+1) = {s};     
        Optimization_Properties(end+1) = {'Impose max actuator power limit'};        
    end    
    
    penaltyMessage = {'Penalize total swing torque'; ...
                      'Penalize total stance torque'; ...
                      'Penalize total torque'; ...
                      'Penalize total HFE torque'; ...
                      'Penalize HFE swing torque'; ...
                      'Penalize total joint velocity'; ...
                      'Penalize total joint power'; ...
                      'Penalize total mechanical energy'; ...
                      'Penalize total electrical energy'; ...
                      'Penalize inverse of efficiency'; ...
                      'Penalize max torque'; ...
                      'Penalize max joint velocity'; ...
                      'Penalize max power'; ...
                      'Penalize antagonistic power'; ...
                      'Penalize leg extension beyond allowable limit'};
                      
    penaltyFields = fieldnames(optimizationProperties.penaltyWeight);
    costTermCount = 0;
    for i = 1:length(penaltyFields)      
        if optimizationProperties.penaltyWeight.(penaltyFields{i})
            costTermCount = costTermCount +1;
            c1 = num2str(costTermCount);
            c = strcat('Cost',c1);
            rowNames(end+1) = {c};
            Optimization_Properties(end+1) = penaltyMessage{i};         
        end  
    end
     
    T = table(Optimization_Properties, 'RowNames', rowNames)
      end
end

    %% Nominal results of simulation
   for i = 1:legCount
       EEselection = EEnames(i,:);
       
       rowNames = {'Leg'
                   'Link lengths [m]'; ...
                   'Link mass [kg]'; ...
                   'Maximum torque [Nm]'; ...
                   'Maximum speed [Nm]'; ...
                   'Maximum mechanical power [W]'; ...
                   'Mechanical energy consumption [J/cycle]'; ...
                   'Cost of transport'; ...
                   'Power quality'; ...
                   'Joint angle range [rad]'; ...
                   'Transmission gear ratio'};

      Nominal_Leg =  [string(EEselection); ...
                      strjoin(string(data.(task).(EEselection).linkLengths(1,:))); ...
                      strjoin(string(data.(task).(EEselection).linkMass(1,2:end))); ...
                      strjoin(string(data.(task).metaParameters.jointTorqueMax.(EEselection)(1,:))); ...
                      strjoin(string(data.(task).metaParameters.qdotMax.(EEselection)(1,:))); ...
                      strjoin(string(data.(task).metaParameters.jointPowerMax.(EEselection)(1,:))); ...
                      strjoin(string(data.(task).metaParameters.mechEnergyPerCycle.(EEselection)(1,:))); ... 
                      data.(task).metaParameters.CoT.(EEselection); ...
                      strjoin(string(data.(task).metaParameters.powerQuality.(EEselection)(1,:))); ...
                      strjoin(string(data.(task).metaParameters.deltaqMax.(EEselection)(1,:))); ...
                      strjoin(string(data.(task).(EEselection).transmissionGearRatio))];
   
     if data.(task).basicProperties.optimizedLegs.(EEselection) 
        Optimized_Leg =  [string(EEselection); ...
                      strjoin(string(data.(task).(EEselection).linkLengthsOpt(1,:))); ...
                      strjoin(string(data.(task).(EEselection).linkMassOpt(1,2:end))); ...
                      strjoin(string(data.(task).metaParameters.jointTorqueMaxOpt.(EEselection)(1,:))); ...
                      strjoin(string(data.(task).metaParameters.qdotMaxOpt.(EEselection)(1,:))); ...
                      strjoin(string(data.(task).metaParameters.jointPowerMaxOpt.(EEselection)(1,:))); ...
                      strjoin(string(data.(task).metaParameters.mechEnergyPerCycleOpt.(EEselection)(1,:))); ... 
                      data.(task).metaParameters.CoTOpt.(EEselection); ...
                      strjoin(string(data.(task).metaParameters.powerQualityOpt.(EEselection)(1,:))); ...
                      strjoin(string(data.(task).metaParameters.deltaqMaxOpt.(EEselection)(1,:))); ...
                      strjoin(string(data.(task).(EEselection).transmissionGearRatioOpt))];   
                  
        T = table(Nominal_Leg, Optimized_Leg, 'RowNames', rowNames)
     else 
        T = table(Nominal_Leg, 'RowNames', rowNames)
     end          
end