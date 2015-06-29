function double_pendulum_main_final

%%% In this file, a PD controller is developed on S^2 x S^2 to 
%%% enable an under-actuated double spherical pendulum (pendubot) to track
%%% any desired trajectory. 

% Download the toolbox from here and addpath: https://github.com/sir-avinash/Geometry-Toolbox
% addpath('.\Geometry_Toolbox'); %%%%% 

%%%%%%%%%% Inputting Constant Values %%%%%%%%%%%%
data.g = 9.8;
data.e3 = [0 0 1]';
data.m = 1;
data.l = 0.2;
data.theta = -20*(pi/180); % Pitch := Rotation about Y-axis; Start with some negative deflection
data.phi = -10*(pi/180); % Roll := Rotation about X-axis; Start with some positive displacement

%%%%%%%%%% Defining Initial Conditions %%%%%%%%%
q10 = Rx(data.theta)*Ry(data.phi)*data.e3;
w10 = [0 2.5 0]';

%%%% applying a transport map on w10 w.r.t. q10, to maintain normality condition
w10 = trans_map(q10,w10); 

%%%% Choose by how much you wish to rotate q2 away from q2d. Default is q2d. 
perturb_q2 = Rx(0*pi/180)*Ry(0*pi/180);  
[q20,w20]=double_pendulum_perturbation(q10,w10,perturb_q2);
x0 = [q10;q20;w10;w20];

%%%%%%%%% Simulating the Dynamics %%%%%%%%%%%%%%%

options = odeset('Events',@events,'RelTol',1e-9,'AbsTol',1e-12); 

[T,X]=ode45(@double_pendulum_dynamics,[0 1],x0,options,data);
Fs=120;   %% sampling rate. 
% [T,X] = even_sample(T,X,Fs);


%%%%%%%%% Animation  %%%%%%%%%%%%%%%%%%%%%
figure
    for i = 1:size(X,1)
    q1 = X(i,1:3)';
    q2 = X(i,4:6)';
    w1 = X(i,7:9)';
    w2 = X(i,10:12)';

    hplot = plot3(0,0,0,'r-o');
    set(hplot,'XDATA',[0,q1(1),NaN,q1(1),q1(1)+q2(1),NaN],'YDATA',[0,q1(2),NaN,q1(2),q1(2)+q2(2),NaN],'ZDATA',[0,q1(3),NaN,q1(3),q1(3)+q2(3),NaN]); 
    hold on
    q2d=double_pendulum_constraints(q1,w1);
    hplot2 = plot3(0,0,0,'b-x');
    set(hplot2,'XDATA',[0,q1(1),NaN,q1(1),q1(1)+q2d(1),NaN],'YDATA',[0,q1(2),NaN,q1(2),q1(2)+q2d(2),NaN],'ZDATA',[0,q1(3),NaN,q1(3),q1(3)+q2d(3),NaN]); 
    hold off 
    view(-45,45)
    axis([-2 2 -2 2 -2 2])

    drawnow

    %%%% Storing data to plot error dynamics %%%
    
    [J,C,G,B]=double_pendulum_model(q1,q2,w1,w2,data);
    dq2=hat(w2)*q2;
    [u,eq2c,ew2c] = double_pendulum_controller(q1,q2,dq2,w1,w2,J,G,C,B);
    eq2(:,i) = eq2c;
    ew2(:,i) = ew2c;

    normeq(i) = norm(eq2(:,i));
    normew(i) = norm(ew2(:,i));
    doteq(i) = dot(eq2(:,i),q2);
    dotew(i) = dot(ew2(:,i),q2);
    end

%%%%%%%%%% Error Dynamics Plots for (eq) and (ew)  %%%%%%%%%%%%%

figure(3)
% plot(T',eq2')
plot(T,normeq,T,doteq);
axis([0 1 -1 1])
 axis('tight');
xlabel('time');
ylabel('eq2');
% legend('X','Y','Z');
legend('norm(eq_2)','dot(q_2,eq_2)');
%%%% Omega error plots for swing leg (ew2) and trunk (ew3)
figure(5)
% plot(T',ew2')
plot(T,normew,T,dotew);
axis([0 1 -1 1])
axis('tight');
xlabel('time');
ylabel('ew2');
% legend('X','Y','Z');
legend('norm(ew_2)','dot(q_2,ew_2)');

end


%%%% Dynamics File

function dx = double_pendulum_dynamics(t,x,data)

q1 = x(1:3);
q2 = x(4:6);
w1 = x(7:9);
w2 = x(10:12);

dq1 = cross2(w1,q1);
dq2 = cross2(w2,q2);

[J,C,G,B]=double_pendulum_model(q1,q2,w1,w2,data);
u = double_pendulum_controller(q1,q2,dq2,w1,w2,J,G,C,B);
dw = J\(B*u-G-C);

dx =[dq1;dq2;dw];
end


%%%% ODE Events Function 

function [value,isterminal,direction] = events(t,x,data)
q1=x(1:3);
current_theta = -asin(q1(1));
value = current_theta + data.theta;
isterminal=1;
direction=0;
end


%%%% This is the Controller Function. It can be used to generate inputs and
%%%% error functions eq2 and ew2 

function [u,eq2,ew2] = double_pendulum_controller(q1,q2,dq2,w1,w2,J,G,C,B)
dq1=hat(w1)*q1;

Fq = J\(-C-G);
Gq = J\B;

Fq1 = Fq(1:3); Fq2 = Fq(4:6); 
Gq1 = Gq(1:3,:); Gq2 = Gq(4:6,:);

%%%%%% Defining error dynamics
tmp=-hat(q2)^2;   %%% Transport Map %%%%
eps = 0.15;
kq2 = 10/eps^2;
kw2 = 10.1/eps;
[q2d,w2d,R]=double_pendulum_constraints(q1,w1);
eq2 = cross2(q2d,q2);      %% Position error on S^2 %%%
ew2 = w2 - tmp*w2d;        %% Velocity error on S^2 %%%

v=-kq2*eq2-kw2*ew2;

%% note the plus sign is because 'tmp' stores the negative sign
Lf2h = Fq2 + tmp*R*hat(q1)^2*Fq1 + tmp*R*hat(q1)*hat(dq1)*w1 + 0*hat(dq2)*hat(q2)*w2d + hat(q2)*hat(dq2)*w2d ;
LgLfh = Gq2 + tmp*R*hat(q1)^2*Gq1 ;
u = pinv(LgLfh)*(0*v-Lf2h);
end


%%%% This function can be used to perturb q2 to start from a point outside
%%%% the zero dynamics manifold, to test the stability of the PD controller

function [q20,w20]=double_pendulum_perturbation(q10,w10,perturb_q2,perturb_w2)
if nargin<4
    perturb_w2 = eye(3);
end
[q20,w20,R]=double_pendulum_constraints(q10,w10);
q20=perturb_q2*q20;
w20=perturb_w2*w20;
w20 = trans_map(q20,w20);
end



%%%% This function defines the kinematic constraint imposed on q2, as a
%%%% function of q1 using a suitable Rotation Matrix, R

function [q2d,w2d,R]=double_pendulum_constraints(q1,w1)
% R = [1 0 0;0 1 0;0 0 -1];  %% Its not valid. Its an improper rotation

theta = -asin(q1(1)); %% current pitch angle
phi = atan2(-q1(2),q1(3)); %% current roll angle
%%%% Testing other valid rotation matrices  %%%%%
R = Rx((180-2*phi)*(pi/180))*Ry((-180+2*theta)*(pi/180));

dq1 = cross2(w1,q1);
q2d = (R*q1);
dq2d = R*dq1; 
w2d = cross2(q2d,dq2d);
% w2d = R*w1;
end



%%%% This function calculates the Inertia Matrix(J(q)),
%%%% Coriolis(C(q,w)), Gravity(G(q)), and Input(B) vectors
%%%% given q and w

function [J,C,G,B]=double_pendulum_model(q1,q2,w1,w2,data)
m1 = data.m;
m2 = data.m;
l1 = data.l;
l2 = data.l;
g=data.g;
e3=data.e3;
J = [(m1+m2)*l1^2*eye(3) -m2*l1*l2*hat(q1)*hat(q2);-m2*l1*l2*hat(q2)*hat(q1) m2*l2^2*eye(3)];
C = [-m2*l1*l2*norm(w2)^2*hat(q1)*q2;-m2*l1*l2*norm(w1)^2*hat(q2)*q1];
G = [(m1+m2)*g*l1*hat(q1)*e3;m2*g*l1*hat(q2)*e3];
B =  [zeros(3);eye(3)]; 
end



%%% To evenly sample the data obtainded from ode45

function [Et, Ex] = even_sample(t, x, Fs)

% Obtain the process related parameters
N = size(x, 2);    % number of signals to be interpolated
M = size(t, 1);    % Number of samples provided
t0 = t(1,1);       % Initial time
tf = t(M,1);       % Final time
EM = (tf-t0)*Fs;   % Number of samples in the evenly sampled case with
% the specified sampling frequency
Et = linspace(t0, tf, EM)';

% Using linear interpolation (used to be cubic spline interpolation)
% and re-sample each signal to obtain the evenly sampled forms
for s = 1:N,
	Ex(:,s) = interp1(t(:,1), x(:,s), Et(:,1));
end
end
