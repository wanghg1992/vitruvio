 function jointPositions = inverseKinematics(desiredPositionHipEE, quadruped, EEselection, taskSelection, configSelection)
  % Input: desired end-effector position, desired end-effector orientation (rotation matrix), 
  %        initial guess for joint angles, threshold for the stopping-criterion
  % Output: joint angles which match desired end-effector position and orientation
  
  %% Setup
  tol = 0.0001;
  it = 0;
  r_H_HEE_des = desiredPositionHipEE;
 
  % Set the maximum number of iterations.
  max_it = 1000;

  %% get initial guess q0 for desired configuration

  q0 = getInitialJointAnglesForDesiredConfig(taskSelection, EEselection, configSelection);
  
  % Initialize the solution with the initial guess.
  q = q0';  
  jointPositions = zeros(length(desiredPositionHipEE(:,1)),4);

  % Damping factor.
  lambda = 0.001;
  
  % Initialize error - only position because we don't have orientation data
  [J_P, C_HEE, r_H_HEE, T_H1, T_12, T_23, T_34] = jointToPosJac(q, quadruped, EEselection);
    
  %% Iterative inverse kinematics
  
  % Iterate until terminating condition.
  for i = 1:length(desiredPositionHipEE(:,1))
        it = 0; % reset iteration count
        dr = r_H_HEE_des(i,:)' - r_H_HEE;
        
      while (norm(dr)>tol && it < max_it)
         [J_P, C_HEE, r_H_HEE] = jointToPosJac(q, quadruped, EEselection);
         dr = r_H_HEE_des(i,:)' - r_H_HEE;
         dq = pinv(J_P, lambda)*dr;
         q = q + 0.5*dq;
         it = it+1;
         
      end
      
%       fprintf('Inverse kinematics terminated after %d iterations.\n',it);
%       fprintf('Position error: %e.\n',norm(dr));
      jointPositions(i,:) = q';
  end
%% get smallest positive q that is equivalent to the one calculated by IK 
     for i = 1:length(jointPositions(:,1))
         for j = 1:length(jointPositions(1,:))
             if jointPositions(i,j) > 0
                  while jointPositions(i,j) > 2*pi
                      jointPositions(i,j) = jointPositions(i,j) - 2*pi;
                  end
              else
                  while jointPositions(i,j) < 0
                      jointPositions(i,j) = jointPositions(i,j) + 2*pi;
                  end
             end            
         end
     end
     
% prevent jumps of about 2pi between timesteps
for i = 1:length(jointPositions(:,1))-1
     for j = 1:length(jointPositions(1,:))
         if jointPositions(i,j)-jointPositions(i+1,j) > pi % step down
             jointPositions(i+1,j) = jointPositions(i+1,j) + 2*pi; 
         end  
      end
end

% HAA always around zero but jumping between 0 and 2pi
% this is kind of sloppy but seems to work
for i = 1:length(jointPositions(:,1))
    if jointPositions(i,1) > 6
       jointPositions(i,1) = jointPositions(i,1) - 2*pi;
    end
end

       
       