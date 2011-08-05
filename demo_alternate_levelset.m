function demo_alternate_levelset(dims, cgo_iters, interval, savefile)
% Try:
%     demo_alternate_levelset([30 30], 1e4, 100, 'test.mat');

path(path, '~/c-go'); % Make sure we have access to c-go.
path(path, '~/level-set'); % Make sure we have access to level-set.
path(path, '~/lset-opt/matlab'); % Make sure we have access to level-set.

omega = 0.15; % Angular frequency of desired mode.


    %
    % Helper function for determining derivative matrices.
    % Also, helper global variables for prettier argument passing.
    %

global S_ D_ DIMS_ 

% Shortcut to form a derivative matrix.
S_ = @(sx, sy) shift_mirror(dims, -[sx sy]); % Mirror boundary conditions.

% Shortcut to make a sparse diagonal matrix.
D_ = @(x) spdiags(x(:), 0, numel(x), numel(x));

DIMS_ = dims;
N = prod(dims);


    %
    % Make the initial structure.
    %

lset_grid(dims);
phi = lset_union(lset_box([-dims(1)/2 0], [dims(1) 10]), ...
    lset_box([0, -dims(2)/2], [10 dims(2)]));
eta = lset_box([0 0], dims/2);
% phi2 = lset_union(phi, (eta)); % filled.
phi2 = lset_intersect(phi, lset_complement(eta));
phi = lset_complement(phi);
eta2 = lset_box([0 0], dims/2 + 2);
small_box = lset_box([0 0], dims/2 - 2);
phi2 = lset_union(phi2, lset_intersect(small_box, lset_checkered));
phi2 = lset_complement(phi2);

% Initialize phi, and create conversion functions.
[phi2p, phi2eps, phi_smooth] = setup_levelset(phi, 1.0, 12.25, 1e-3);


    %
    % Setup the constrained gradient optimization.
    %

% Objective function and its gradient.
[f, g] = em_physics_levelset(omega, phi2p); 


% This constraint function allows both variables to change.
c = @(v, dv, s) struct( 'x', v.x - s * (field_template .* dv.x), ...
    'phi', levelset_step(v.phi, (eta2 < 0) .* reshape(real(dv.phi), dims), s)); 

% c = @(v, dv, s) struct( 'x', v.x, ...
%     'phi', levelset_step(v.phi, (eta2 < 0) .* reshape(real(dv.phi), dims), s)); 
% Initial values.
[Ex, Ey, Hz] = setup_border_vals({'x-', 'y-'}, omega, phi2eps(phi));
v.x = [Ex(:); Ey(:); Hz(:)];
% randn('state', 1);
% v.x = randn(size(v.x));
v.phi = phi2;
% v.phi = signed_distance(v.phi, 1e-2); % Make phi more sdf-like.
% v.p = randn(N, 1);

% Get the field.
% [A, b, reinsert] = em_physics_direct('field', omega, field_template, v.x);
% v.x = reinsert(A(phi2p(v.phi)) \ b(phi2p(v.phi)));
% v.phi = phi2;

    %
    % Optimize using the c-go package.
    %

tic;
fval = [];
ss_hist = {[], []};
figure(1);
my_plot(v, phi2p, fval, ss_hist);

for k = 1 : ceil(cgo_iters/interval)
    [v, fval0, ss_hist0] = cgo_opt2(f, g, c, v, interval, 2.^[-20:20]); 
    % [v, fval0, ss_hist0] = opt(f, g, c, v, interval, 2.^[-20:20]); 
    fval = [fval, fval0];
    % ss_hist = [ss_hist, ss_hist0];
    ss_hist{1} = [ss_hist{1}, ss_hist0{1}];
    ss_hist{2} = [ss_hist{2}, ss_hist0{2}];
    my_plot(v, phi2p, fval, ss_hist);
    save(savefile, 'v', 'fval', 'ss_hist');
    fprintf('%d: %e\n', k*interval, fval(end));
end
fprintf('%e, ', f(v)); toc

% figure(2); cgo_visualize(fval, ss_hist);
figure(2); cgo_visualize(fval, ss_hist{1});
figure(3); cgo_visualize(fval, ss_hist{2});

function my_plot(v, phi2p, fval, ss_hist)
    
global DIMS_
dims = DIMS_;
N = prod(dims);
% figure(1); 
plot_fields(dims, ...
    {'|Hz|', abs(v.x(2*N+1:3*N))}, {'p', phi2p(v.phi)});


% figure(2); cgo_visualize(fval, ss_hist);

drawnow


