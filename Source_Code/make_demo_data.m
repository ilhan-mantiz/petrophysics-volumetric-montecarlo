% MAKE_DEMO_DATA  Membuat file LAS sintetis untuk menguji alur kerja.
% PENTING: data ini buatan. Jangan dipakai sebagai hasil di portofolio!
rng(1);
if ~exist('data', 'dir'), mkdir('data'); end

depth = (2000:0.5:2100)';
N     = numel(depth);
sand  = false(N, 1);
RT    = 2 * ones(N, 1);
iv    = [2020 2040; 2055 2075; 2085 2095];   % 3 lapisan pasir
rtv   = [40; 1; 15];                          % minyak, air, minyak (lebih tipis)

for k = 1:3
    idx      = depth >= iv(k,1) & depth <= iv(k,2);
    sand     = sand | idx;
    RT(idx)  = rtv(k);
end

GR        = 110 * ones(N, 1);  GR(sand) = 40;
phi       = 0.06 * ones(N, 1); phi(sand) = 0.22;
RHOB      = 2.65 - 1.65 * phi;
NPHI      = phi + 0.02;        NPHI(~sand) = 0.35;

GR   = GR   + 4    * randn(N, 1);
RHOB = RHOB + 0.01 * randn(N, 1);
NPHI = NPHI + 0.01 * randn(N, 1);
RT   = RT .* exp(0.1 * randn(N, 1));

fid = fopen('data/demo_synthetic.las', 'w');
fprintf(fid, '~VERSION INFORMATION\n VERS. 2.0 : CWLS LOG ASCII STANDARD\n WRAP. NO : ONE LINE PER DEPTH STEP\n');
fprintf(fid, '~WELL INFORMATION\n STRT.M %.2f : START\n STOP.M %.2f : STOP\n STEP.M 0.5 : STEP\n NULL. -999.25 : NULL VALUE\n WELL. DEMO-SINTETIK : WELL\n', depth(1), depth(end));
fprintf(fid, '~CURVE INFORMATION\n DEPT.M : DEPTH\n GR.GAPI : GAMMA RAY\n RT.OHMM : DEEP RESISTIVITY\n RHOB.G/CC : BULK DENSITY\n NPHI.V/V : NEUTRON POROSITY\n');
fprintf(fid, '~A  DEPT GR RT RHOB NPHI\n');
fprintf(fid, '%10.2f %10.3f %10.3f %10.4f %10.4f\n', [depth GR RT RHOB NPHI]');
fclose(fid);
disp('Selesai: data/demo_synthetic.las dibuat.');