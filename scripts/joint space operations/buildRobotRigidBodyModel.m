%% Read in data for quadruped geometry
function robot = buildRobotRigidBodyModel(actuatorProperties, actuateJointDirectly, hipAttachmentOffset, linkCount, robotProperties, Leg, meanCyclicMotionHipEE, EEselection, numberOfStepsVisualized, viewVisualization, hipParalleltoBody, dataExtraction, optimized) 
    
    jointNames = ['HAA'; 'HFE'; 'KFE'; 'AFE'; 'DFE'];

    %% Get robot properties for selected end effector  
    if strcmp(EEselection, 'LF') || strcmp(EEselection, 'RF')
        selectFrontHind = 1;
        hipOffsetDirection = 1;
    else
        selectFrontHind = 2;
        hipOffsetDirection = -1;
    end

    % Initialize actuator mass
    actuatorMass.HAA = 0; actuatorMass.HFE = 0; actuatorMass.KFE = 0; actuatorMass.AFE = 0; actuatorMass.DFE = 0; 
    for i = 1:linkCount+1
        jointSelection = jointNames(i,:);
        actuatorMass.(jointSelection) = actuatorProperties.mass.(jointSelection);
    end

    % Offset from nominal stance EE position to HAA along body x
    hipAttachmentOffsetX = hipAttachmentOffset*cos(meanCyclicMotionHipEE.body.eulerAngles.(EEselection)(1,2)); 
    hipAttachmentOffsetZ = hipAttachmentOffset*sin(meanCyclicMotionHipEE.body.eulerAngles.(EEselection)(1,2));  

    l_hip   = robotProperties.hip(selectFrontHind).length; % offset from HAA to HFE
    l_thigh = robotProperties.thigh(selectFrontHind).length;
    l_shank = robotProperties.shank(selectFrontHind).length;
    l_foot  = robotProperties.foot(selectFrontHind).length;
    l_phalanges = robotProperties.phalanges(selectFrontHind).length;

    %% Build the rigid body model 
    % The transformations describe rotations and translations. These align the 
    % z axis of the coordinate system with the desired rotational axis of the 
    % joint and translations along the length of the link.

    % Rotation about x by -pi/2 to align z with inertial y. Rotation about this
    % z gives the angle of attack of the base 
    T_body = [1, 0, 0, hipAttachmentOffsetX;
              0, 0, 1,  0;
              0, -1, 0, hipAttachmentOffsetZ;
              0, 0, 0, 1];

    % rotation about y by pi/2 to align z with HAA rotation axis
    T_HAA =   [0, 0, 1, 0;
               0, 1, 0, 0;
              -1, 0, 0, 0;
               0, 0, 0, 1];

    % Rotation about y by -pi/2 to align z with HFE rotation axis 
    % and hip attachment to HFE translation
    if hipParalleltoBody
        T_HFEattachment = [0,  0, -1, 0;
                           0,  1, 0,  0;
                           1,  0, 0, hipOffsetDirection*l_hip;
                           0,  0, 0,  1];
        else
        T_HFEattachment = [0,  0, -1, 0;
                           0,  1, 0, -l_hip;
                           1,  0, 0,  0;
                           0,  0, 0,  1];
    end

    % HFE to KFE translation
    T_HFE =           [1, 0, 0, l_thigh;
                       0  1, 0, 0;
                       0, 0, 1, 0;
                       0, 0, 0, 1];

    % KFE to EE (or KFE to AFE for higher link counts) translation
    T_KFE =           [1, 0, 0, l_shank;
                       0, 1, 0, 0;
                       0, 0, 1, 0;
                       0, 0, 0, 1];

    if linkCount == 3 || linkCount == 4
        % AFE to EE (or AFE to DFE for higher link counts) translation
        T_AFE =           [1, 0, 0, l_foot;
                           0, 1, 0, 0;
                           0, 0, 1, 0;
                           0, 0, 0, 1];
    end
    
    if linkCount ==4
        % DFE to EE translation
        T_DFE =           [1, 0, 0, l_phalanges;
                           0, 1, 0, 0;
                           0, 0, 1, 0;
                           0, 0, 0, 1];
    end
    %% Create and assemble rigid bodies
    % Create a rigid body tree object to build the robot.
    robot = robotics.RigidBodyTree('DataFormat', 'row');

    % Create bodies and joints 
    body0 = robotics.RigidBody('body0');
    body1 = robotics.RigidBody('body1'); % hip
    body2 = robotics.RigidBody('body2'); % thigh
    body3 = robotics.RigidBody('body3'); % shank
    body4 = robotics.RigidBody('body4'); % EE or foot
    if (linkCount == 3)
           body5 = robotics.RigidBody('body5'); % EE
    elseif (linkCount == 4)
           body5 = robotics.RigidBody('body5'); % phalanges
           body6 = robotics.RigidBody('body6'); % EE
    end

    jnt0 = robotics.Joint('jnt0','revolute'); % body rotation about y in inertial frame
    jnt1 = robotics.Joint('jnt1','revolute'); % HAA
    jnt2 = robotics.Joint('jnt2','revolute'); % HFE
    jnt3 = robotics.Joint('jnt3','revolute'); % KFE
    jnt4 = robotics.Joint('jnt4','fixed');    % coordinate system at EE 
    if (linkCount == 3)
           jnt4 = robotics.Joint('jnt4','revolute'); % AFE
           jnt5 = robotics.Joint('jnt5','fixed');    % EE
    elseif (linkCount == 4)
           jnt4 = robotics.Joint('jnt4','revolute'); % AFE
           jnt5 = robotics.Joint('jnt5','revolute'); % DFE
           jnt6 = robotics.Joint('jnt6','fixed');    % EE
    end

    body0.Mass = 0;      
    body1.Mass = robotProperties.hip(selectFrontHind).mass;    % hip  
    body2.Mass = robotProperties.thigh(selectFrontHind).mass;  % thigh
    body3.Mass = robotProperties.shank(selectFrontHind).mass;  % shank
    body4.Mass = robotProperties.EE(selectFrontHind).mass;     % EE
    if (linkCount == 3)
        body4.Mass = robotProperties.foot(selectFrontHind).mass(selectFrontHind); % overwrite EE with foot
        body5.Mass = robotProperties.EE(selectFrontHind).mass(selectFrontHind);   % EE
    elseif (linkCount == 4)
        body4.Mass = robotProperties.foot(selectFrontHind).mass(selectFrontHind);      % overwrite EE with foot
        body5.Mass = robotProperties.phalanges(selectFrontHind).mass(selectFrontHind); % overwrite EE with phalanges
        body6.Mass = robotProperties.EE(selectFrontHind).mass(selectFrontHind);        % EE
    end 
    
    %% Compute inertia for each link and end effector
    % Links are constant density cylinders, actuators and end effectors are point masses
    % inertia = [Ixx Iyy Izz Iyz Ixz Ixy] relative to body frame in kg/m^2
    I_hip =   [0.00000001, 1/3*body1.Mass*l_hip^2,   1/3*body1.Mass*l_hip^2,   0, 0, 0];   
    I_thigh = [0.00000001, 1/3*body2.Mass*l_thigh^2, 1/3*body2.Mass*l_thigh^2, 0, 0, 0];      
    I_shank = [0.00000001, 1/3*body3.Mass*l_shank^2, 1/3*body3.Mass*l_shank^2, 0, 0, 0];      

    if linkCount == 2
        I_EE =    [0.00000001, body4.Mass*l_shank^2,     body4.Mass*l_shank^2,     0, 0, 0]; % Point mass at distance L from axis of rotation
    elseif linkCount == 3
        I_foot =  [0.00000001, 1/3*body4.Mass*l_foot^2,   1/3*body4.Mass*l_foot^2, 0, 0, 0];
        I_EE =    [0.00000001, body5.Mass*l_foot^2,      body5.Mass*l_foot^2,      0, 0, 0]; 
    elseif linkCount == 4
        I_foot =       [0.00000001, 1/3*body4.Mass*l_foot^2,      1/3*body4.Mass*l_foot^2,      0, 0, 0];
        I_phalanges =  [0.00000001, 1/3*body5.Mass*l_phalanges^2, 1/3*body5.Mass*l_phalanges^2, 0, 0, 0];
        I_EE =         [0.00000001, body6.Mass*l_phalanges^2,     body6.Mass*l_phalanges^2,     0, 0, 0]; 
    end

    %% Assign the inertia values to the inertia properties for the links and end effectors
    body0.Inertia = [0 0 0 0 0 0]; % base    
    body1.Inertia =  I_hip;     
    body2.Inertia =  I_thigh; 
    body3.Inertia =  I_shank;
    if linkCount == 2
        body4.Inertia = I_EE;
    elseif linkCount == 3
        body4.Inertia = I_foot;
        body5.Inertia = I_EE;
    elseif linkCount == 4
        body4.Inertia = I_foot;
        body5.Inertia = I_phalanges;
        body6.Inertia = I_EE;
    end

    %% Place an actuator point mass at the joint if it is directly actuated
    % Compute and assign the actuator mass and inertia properties
    if actuateJointDirectly.HAA
        body7  = robotics.RigidBody('body7');  % HAA
        body7.Mass  = actuatorMass.HAA; % HAA
        I_HAA = [0 0 0 0 0 0]; % HAA does not contribute an inertia   
        body7.Inertia  = I_HAA;
    end
    
    if actuateJointDirectly.HFE
        body8  = robotics.RigidBody('body8');  % HFE
        body8.Mass  = actuatorMass.HFE; % HFE        
        I_HFE = [0.00000001, body8.Mass*l_hip^2, body8.Mass*l_hip^2, 0, 0, 0]; 
        body8.Inertia  = I_HFE;        
    end
    
    if actuateJointDirectly.KFE    
        body9  = robotics.RigidBody('body9');  % KFE
        body9.Mass  = actuatorMass.KFE; % KFE   
        I_KFE = [0.00000001, body9.Mass*l_thigh^2, body9.Mass*l_thigh^2, 0, 0, 0]; 
        body9.Inertia = I_KFE;
    end
    
    if linkCount > 2 && actuateJointDirectly.AFE
        body10 = robotics.RigidBody('body10'); % AFE
        body10.Mass = actuatorMass.AFE; % AFE  
        I_AFE = [0.00000001, body10.Mass*l_foot^2, body10.Mass*l_foot^2, 0, 0, 0]; 
        body10.Inertia = I_AFE;
    end
    
    if linkCount == 4 && actuateJointDirectly.DFE
        body11 = robotics.RigidBody('body11'); % DFE
        body11.Mass = actuatorMass.DFE; % DFE     
        I_DFE = [0.00000001, body11.Mass*l_phalanges^2, body11.Mass*l_phalanges^2, 0, 0, 0]; 
        body11.Inertia = I_DFE;  
    end
    
    %% Reserved for ANYmal validation
    %         %% OVERWRITE INERTIA TERMS WITH THOSE FROM ANYMAL URDF
    %         % inertia = [Ixx Iyy Izz Iyz Ixz Ixy] relative to body frame in kg/m^2
    
                % EE inertia about it's own axis + parallel axis thm for
                % offset from knee joint
%             I_EE = [0.00008308641, 0.00008286021, 0.000081948124, 0.000000417, 0.000000399, -0.0000003457] + 0.1923*0.33^2;
%        
%             body0.Inertia = [0 0 0 0 0 0]; % base    
%             body1.Inertia = [0.002318  0.002060 0.002439 -0.000001 0.000009  0.000333];  % Hip   
%             body2.Inertia = [0.013479 0.013250 0.002229 -0.000003 0.000038 -0.001623]; % Thigh
%             body3.Inertia = [0.003769371790899 0.004004464676349 0.000418471691904 -0.000077334500762 -0.000152069372983 -0.000321835608300] + I_EE; % Shank + end effector
%             if linkCount == 2
%                 body4.Inertia = [0 0 0 0 0 0]; % We bundle the end effector with shank so body 4 has zero inertia
%             end
%             % Actuator inertias are bundled in with link inertias so we set
%             % the following inertia terms to zero.
%             body7.Inertia  = [0 0 0 0 0 0];
%             body8.Inertia  = [0 0 0 0 0 0];
%             body9.Inertia  = [0 0 0 0 0 0];
%             if linkCount == 3
%                 body10.Inertia = [0 0 0 0 0 0];
%             elseif linkCount == 4
%                 body10.Inertia = [0 0 0 0 0 0];
%                 body11.Inertia = [0 0 0 0 0 0];
%             end
    
    %% Compute link center of mass
    % Center of mass and mass terms do not affect inertia but are used 
    % to compute torque due to gravitational force. Default is [0 0 0] when not
    % specified. As such it is left default for actuators and end effectors
    body1.CenterOfMass = [0.5*l_hip   0 0];
    body2.CenterOfMass = [0.5*l_thigh 0 0];
    body3.CenterOfMass = [0.5*l_shank 0 0]; 
    if linkCount == 3
        body4.CenterOfMass = [0.5*l_foot 0 0];
    elseif linkCount == 4
        body4.CenterOfMass = [0.5*l_foot 0 0];
        body5.CenterOfMass = [0.5*l_phalanges 0 0];
    end

    %% Set joint transforms
    % joint transforms these are only translations and rotations to align rotation
    % z with joint rotation axis. The joint positions are specified in the config array.   
    setFixedTransform(jnt0, T_body);
    setFixedTransform(jnt1, T_HAA);
    setFixedTransform(jnt2, T_HFEattachment);
    setFixedTransform(jnt3, T_HFE);
    setFixedTransform(jnt4, T_KFE); 
    if (linkCount == 3)
        setFixedTransform(jnt5, T_AFE);    
    elseif (linkCount == 4)
        setFixedTransform(jnt5, T_AFE);    
        setFixedTransform(jnt6, T_DFE);            
    end

    body0.Joint = jnt0;
    body1.Joint = jnt1;
    body2.Joint = jnt2;
    body3.Joint = jnt3;
    body4.Joint = jnt4;
    if (linkCount == 3)
        body5.Joint = jnt5;
    elseif (linkCount == 4)
        body5.Joint = jnt5;
        body6.Joint = jnt6;
    end

    %% Specify connections between bodies
    addBody(robot, body0,'base');
    addBody(robot, body1,'body0');
    addBody(robot, body2,'body1');
    addBody(robot, body3,'body2');
    addBody(robot, body4,'body3');
    if (linkCount == 3)
        addBody(robot, body5,'body4');
    elseif (linkCount == 4)
        addBody(robot, body5,'body4');
        addBody(robot, body6,'body5');
    end

    if actuateJointDirectly.HAA
        addBody(robot, body7,'body1');
    end
    
    if actuateJointDirectly.HFE
        addBody(robot, body8,'body2');
    end
    
    if actuateJointDirectly.KFE
        addBody(robot, body9,'body3');
    end
     
    if linkCount == 3 && actuateJointDirectly.AFE
        addBody(robot, body10,'body4');
    elseif linkCount == 4 && actuateJointDirectly.DFE
        addBody(robot, body10,'body4');
        addBody(robot, body11,'body5');
    end

    robot.Gravity = [0 0 -9.8];

    %% Visualization of robot tracking motion.
    if viewVisualization

        % Save the joint positions into an array containing the robot configuration 
        % If we average the steps to create a cyclical motion, we plot the robot up
        % until the last point - 2. This is because we added two points to the end
        % of the cycle for the finite dynamics. If the motion is NOT averaged into
        % cycles, we plot the full length of q.

        if dataExtraction.averageStepsForCyclicalMotion
            finalPlottingIndex = length(Leg.(EEselection).q) - 2;
        else
            finalPlottingIndex = length(Leg.(EEselection).q);
        end

        for i = 1:finalPlottingIndex
            if (linkCount == 2)
                config(i,:) = [-meanCyclicMotionHipEE.body.eulerAngles.(EEselection)(i,2), ... %body rotation about inertial y
                               Leg.(EEselection).q(i,1), ... % HAA
                               Leg.(EEselection).q(i,2), ... % HFE
                               Leg.(EEselection).q(i,3)]; % KFE
            elseif (linkCount == 3)
                config(i,:) = [-meanCyclicMotionHipEE.body.eulerAngles.(EEselection)(i,2), ... %body rotation about inertial y
                               Leg.(EEselection).q(i,1), ... % HAA
                               Leg.(EEselection).q(i,2), ... % HFE
                               Leg.(EEselection).q(i,3), ... % KFE
                               Leg.(EEselection).q(i,4)];    % AFE    
            elseif (linkCount == 4)
                config(i,:) = [-meanCyclicMotionHipEE.body.eulerAngles.(EEselection)(i,2), ... %body rotation about inertial y
                               Leg.(EEselection).q(i,1), ... % HAA
                               Leg.(EEselection).q(i,2), ... % HFE
                               Leg.(EEselection).q(i,3), ... % KFE
                               Leg.(EEselection).q(i,4), ... % AFE
                               Leg.(EEselection).q(i,5)];    % DFE
            end
        end

    %% Display robot visualization
    % this part of the code
        % define patch shift which allows for body visualization
        bodyLength = 2*robotProperties.xNom(1);
        bodyWidth = 2*robotProperties.yNom(1);
        if strcmp(EEselection, 'LF')
            patchShift = [0 0 0];
        elseif strcmp(EEselection, 'LH')
            patchShift = [bodyLength 0 0];
        elseif strcmp(EEselection, 'RF')
            patchShift = [0 bodyWidth 0];
        elseif strcmp(EEselection, 'RH')
            patchShift = [bodyLength bodyWidth 0];
        end

        groundCoordinatesX = [0.2 0.2 -0.2 -0.2] + meanCyclicMotionHipEE.(EEselection).position(:,1); % ground centered at EE position
        groundCoordinatesY = [0.2 -0.2 -0.2 0.2] + meanCyclicMotionHipEE.(EEselection).position(:,2);
        groundCoordinatesZ = -Leg.base.position.(EEselection)(:,3)*[1 1 1 1] - robotProperties.nomHipPos.(EEselection)(3);

        f1 = figure('units','normalized','outerposition',[0 0 1 1]); 
        set(gcf,'color','w')
        for j = 1: numberOfStepsVisualized
            for i = 1:finalPlottingIndex
%                 set(gcf, 'Position', get(0, 'Screensize'));
                xlim([-0.75 0.75]);
                ylim([-0.5 0.5]);
                zlim([-1 0.4]);
                figure(f1);

                % Leg visualization
                show(robot,config(i,:));

                hold on
                % Plot desired trajectory to observe tracking
                plot3(meanCyclicMotionHipEE.(EEselection).position(1:end-2,1), ...
                      meanCyclicMotionHipEE.(EEselection).position(1:end-2,2), ...
                      meanCyclicMotionHipEE.(EEselection).position(1:end-2,3),'r', 'LineWidth', 3)
                if optimized
                    title(['Optimized ', EEselection])
                else
                    title(['Nominal ', EEselection])
                end

                % Define the vertices to show robot body
                vert = patchShift + ...
                       [0           0           -0.04;...
                       -bodyLength  0           -0.04;...
                       -bodyLength -bodyWidth   -0.04;...
                        0          -bodyWidth   -0.04;...
                        0           0            0.04;...
                       -bodyLength  0            0.04;...
                       -bodyLength -bodyWidth    0.04;...
                        0          -bodyWidth    0.04];

                % compute body rotation about y axis with elementary rotation matrix
                bodyRotation = [cos(-config(i,1)), 0, sin(-config(i,1));
                                0                  1, 0;
                                -sin(-config(i,1)), 0 cos(-config(i,1))];

                % apply body rotation to obtain new vertices
                vert = vert * bodyRotation;
                fac = [1 2 6 5;2 3 7 6;3 4 8 7;4 1 5 8;1 2 3 4;5 6 7 8];
                patch('Vertices',vert,'Faces',fac,'FaceColor','w', 'FaceAlpha', 0.8)

                % plot surface for ground visualization on the same figure
                patch(groundCoordinatesX(i,:), groundCoordinatesY(i,:), groundCoordinatesZ(i,:), 'k', 'FaceAlpha', 0.2)
                hold off          
            end
        end
        warning off % warning for transparency in figure
%         export_fig results.pdf -nocrop -append
    end
end