function [utraj,xtraj]=runPSM(p)

if (nargin<1)
  p = GliderPlant();
end

N=21;


% use N=75 to see an example of PS method failing
% the method will be able set up the NLP solver and solve for the 75 knot points values correctly,
% but the utraj or xtraj plot will have zig-zag near the end of the trajectory or the entire trajectory looks weird
% and the glider will fly off and not end up at the goal! 

% things go south at the reconstrunction stage, and it is due to the Runge phenomenon. 
% PS method reconstructs the entire trajectory by Lagrange interpolating these 75 knot points, and
% despite the effort of choosing knot points at Gauss quadrature (strongest immunity to Runge phenomenon), 
% 75 knot points are by nature too clustering and Runge phenomenon is unavoidable. One good sign of Runge
% phenomenon happening is 'polyfit' giving 'bad conditioned' warning.

% be alert that similar disastrous result can happen to other plants when
% using very high N, it might be wise to stay away from PS method when in doubt. 



x0 = getInitialState(p);
x0 = [-3.5 0.1 0 0 7 0 0]';
tf0 = 1.0;
xf = p.xd;

options.ps_method=PseudoSpectralMethodTrajOpt.LGL;
%default choice of LGL_PS method, can be omitted

% options.ps_method=PseudoSpectralMethodTrajOpt.CGL;
% set the CGL_PS method option

prog = PseudoSpectralMethodTrajOpt(p,N,[0 2],options);
% prog = prog.setCheckGrad(true);

prog = prog.addStateConstraint(BoundingBoxConstraint([-4,-1,-pi/2,p.phi_lo_limit,-inf,-inf,-inf]',[1,1,pi/2,p.phi_up_limit,inf,inf,inf]'),1:N);
prog = prog.addStateConstraint(ConstantConstraint(x0),1);
prog = prog.addStateConstraint(BoundingBoxConstraint([ 0, 0, pi/6 -inf, -2, -2, -inf]',[ 0, 0, 1, inf, 2, 2, inf]'),N);
prog = prog.addRunningCost(@cost);
prog = prog.addFinalCost(@(t,x)finalCost(t,x,xf));

prog = prog.addTrajectoryDisplayFunction(@plotPsmTraj);

for i=1:5
  tic
  [xtraj,utraj,z,F,info,infeasible_constraint_name] = prog.solveTraj(tf0);
  toc
  if info==1, break; end
end


if info~=1, error('Failed to find a trajectory'); end

if (nargout<1)
  figure(1)
  fnplt(xtraj)
  
  figure(2)
  fnplt(utraj)
  figure(3)
  fnplt(xtraj,4)
  
  fnplt(xtraj,3)
  
%  save('glider_trajs','xtraj','utraj');
  
  v = GliderVisualizer(p);
  v.playback(xtraj);
end
end

      function [g,dg] = cost(dt,x,u)
        R = 100;
        g = u'*R*u;
        if (nargout>1)
          dg = [0,zeros(1,length(x)),2*u'*R];
        end
      end

      function [h,dh] = finalCost(t,x,xd)
        xerr = x-xd;

        Qf = diag([10 10 1 10 1 1 1]);
        h = sum((Qf*xerr).*xerr,1);

        if (nargout>1)
          dh = [0,2*xerr'*Qf];
        end
      end

      function plotPsmTraj(t,x,u)
        figure(1)
        clf;
        hold on
        plot(x(1,:),x(2,:),'.-');
        hold off
        axis([-4 1 -1 1]);
        drawnow;
        %delete(h);
      end
