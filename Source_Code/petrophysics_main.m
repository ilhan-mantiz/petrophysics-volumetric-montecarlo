%% PORTFOLIO_MAIN  Petrofisika sumur -> net pay -> volumetrik Monte Carlo
clear; clc; close all;
addpath('Source_Code');
if ~isfolder('hasil'), mkdir('hasil'); end

%% 1. PENGATURAN (ubah bagian ini)
file_las  = 'data/sumur.las';   % <-- ganti ke 'data/sumur_asli.las' nanti
zone_top  = 2990;                        % batas atas zona yang dianalisis
zone_bot  = 3700;                        % batas bawah zona
depth_ft  = false;                       % true jika kedalaman dalam FEET

% Parameter petrofisika (tulis sumber/alasannya di README!)
rho_ma = 2.65;     % densitas matriks batupasir (g/cc)
rho_fl = 1.00;     % densitas fluida (g/cc)
Rw     = 0.05;     % resistivitas air formasi (ohm.m)  
a = 1; m = 2; n_sat = 2;                 % parameter Archie
tvt_factor = 1.0;   % ketebalan vertikal / ketebalan sepanjang lubang (1.0 = lurus vertikal)

% Cutoff net pay
cut_vsh = 0.40;    % Vsh maksimum
cut_phi = 0.10;    % porositas minimum
cut_sw  = 0.60;    % Sw maksimum

% Monte Carlo
nsim = 10000;
rng(42);           % supaya hasil bisa diulang

% Nama kurva alternatif 
cand.depth = {'DEPT','DEPTH','DEPTH_MD','MD'};
cand.gr    = {'GR','GRC','SGR','GR_1','GAMN'};
cand.rt    = {'RT','RDEP','ILD','LLD','AT90','RD','RLA5','RILD'};
cand.rhob  = {'RHOB','RHOZ','DEN','DENS'};
cand.nphi  = {'NPHI','TNPH','NPOR','NPHI_1','NEU'};

%% 2. BACA DATA
fprintf('Membaca %s ...\n', file_las);
T     = read_las(file_las);
depth = find_curve(T, cand.depth, 'DEPTH');
GR    = find_curve(T, cand.gr,    'GR');
RT    = find_curve(T, cand.rt,    'Rt');
RHOB  = find_curve(T, cand.rhob,  'RHOB');
NPHI  = find_curve(T, cand.nphi,  'NPHI');

% Penjaga satuan otomatis
if max(NPHI, [], 'omitnan') > 1.5, NPHI = NPHI / 100;  disp('  NPHI dikonversi % -> v/v'); end
if max(RHOB, [], 'omitnan') > 10,  RHOB = RHOB / 1000; disp('  RHOB dikonversi kg/m3 -> g/cc'); end
RT(RT > 1000) = 1000;   % nilai 5000 kemungkinan batas alat, bukan nilai fisik

if depth_ft, uf = 0.3048; else, uf = 1; end   % faktor konversi ke meter
dz      = median(abs(diff(depth))) * uf * tvt_factor;       % langkah sampling (m)
H_gross = (zone_bot - zone_top) * uf * tvt_factor;          % tebal kotor (m)
z       = depth >= zone_top & depth <= zone_bot;

%% 3. PLOT LOG MENTAH
fig1 = figure('Position', [100 100 1000 700], 'Color', 'w');
tr = {GR, RT, RHOB, NPHI};
tt = {'GR (API)', 'Rt (ohm.m)', 'RHOB (g/cc)', 'NPHI (v/v)'};
for k = 1:4
    ax(k) = subplot(1, 4, k);
    plot(tr{k}, depth, 'k'); set(gca, 'YDir', 'reverse'); grid on;
    title(tt{k});
    if k == 2, set(gca, 'XScale', 'log'); xlim([0.1 1000]); end
    if k > 1, set(gca, 'YTickLabel', []); end
end
linkaxes(ax, 'y'); ylim(ax(1), [zone_top zone_bot]);
ylabel(ax(1), 'Kedalaman');
sgtitle('Log mentah');
exportgraphics(fig1, 'hasil/01_log_mentah.png', 'Resolution', 200);

%% 4. PETROFISIKA

win  = 11;   % jendela median ~1,7 m (langkah sampling 0,15 m)
GR   = movmedian(GR,   win, 'omitnan');
RT   = movmedian(RT,   win, 'omitnan');
RHOB = movmedian(RHOB, win, 'omitnan');
NPHI = movmedian(NPHI, win, 'omitnan');

% 4.1 Volume lempung (Larionov, batuan tua) dari indeks GR
GRc = pctl(GR(z), 5);      % garis dasar pasir bersih
GRs = pctl(GR(z), 95);     % garis dasar lempung
IGR = min(max((GR - GRc) ./ (GRs - GRc), 0), 1);
Vsh = 0.33 * (2.^(2 * IGR) - 1);
fprintf('  GR clean = %.1f | GR shale = %.1f\n', GRc, GRs);

% 4.2 Porositas densitas-neutron
PHID = min(max((rho_ma - RHOB) ./ (rho_ma - rho_fl), 0), 0.6);
PHIN = min(max(NPHI, 0), 0.6);
PHIT = sqrt((PHID.^2 + PHIN.^2) / 2);
PHIE = PHIT .* (1 - Vsh);              % porositas efektif (disederhanakan)

% 4.3 Saturasi air (Archie)
Sw = ((a * Rw) ./ (PHIE.^m .* RT)).^(1 / n_sat);
Sw(PHIE < 0.01) = 1;
Sw = min(max(Sw, 0), 1);

%% 5. CUTOFF, NET PAY, NTG
valid     = z & ~isnan(Vsh) & ~isnan(PHIE) & ~isnan(Sw);
reservoir = valid & Vsh <= cut_vsh & PHIE >= cut_phi;
pay       = reservoir & Sw <= cut_sw;

if ~any(pay)
    error('Tidak ada interval yang lolos cutoff. Cek zona, Rw, atau cutoff.');
end

H_res   = sum(reservoir) * dz;
H_net   = sum(pay) * dz;
NTG     = H_net / H_gross;
phi_avg = mean(PHIE(pay));
sw_avg  = mean(Sw(pay));

fprintf('\n=== RINGKASAN PETROFISIKA ===\n');
fprintf('Gross  : %.1f m\nNet res: %.1f m\nNet pay: %.1f m\nNTG    : %.2f\n', H_gross, H_res, H_net, NTG);
fprintf('phi rata-rata (pay): %.3f\nSw rata-rata (pay) : %.3f\n', phi_avg, sw_avg);

%% 6. PLOT HASIL INTERPRETASI
fig2 = figure('Position', [100 100 1000 700], 'Color', 'w');
tr2 = {Vsh, PHIE, Sw, double(pay)};
tt2 = {'Vsh', 'PHIE', 'Sw', 'Net pay (1=ya)'};
for k = 1:4
    bx(k) = subplot(1, 4, k);
    plot(tr2{k}, depth, 'k'); hold on;
    if k == 2 || k == 3
        plot(tr2{k}(pay), depth(pay), 'r.');     % titik merah = interval pay
    end
    set(gca, 'YDir', 'reverse'); grid on; title(tt2{k});
        if k < 4, xlim([0 1]); else, xlim([-0.2 1.2]); end
    if k > 1, set(gca, 'YTickLabel', []); end
end
linkaxes(bx, 'y'); ylim(bx(1), [zone_top zone_bot]);
ylabel(bx(1), 'Kedalaman');
sgtitle(sprintf('Hasil interpretasi (merah = pay) | Net pay %.1f m, NTG %.2f', H_net, NTG));
exportgraphics(fig2, 'hasil/02_interpretasi.png', 'Resolution', 200);

%% 7. MONTE CARLO VOLUMETRIK
% Rumus: STOIIP (MMstb per km2) = A[km2] * h[m] * NTG * phi * (1-Sw) / Bo * 6.2898
% (km2 x m = juta m3; x 6.2898 = juta barel)
% ASUMSI: area & Bo tidak berasal dari log. Isi dengan alasan yang masuk akal
%         dan TULIS di README.
%          nama            min          mode        max
PAR = { 'Area (km2)',     1,           1,          1;
        'Tebal gross (m)', 0.9*H_gross, H_gross,    1.1*H_gross;
        'NTG',            0.85*NTG,    NTG,        min(1, 1.15*NTG);
        'Porositas',      0.90*phi_avg, phi_avg,   1.10*phi_avg;
        'Sw',             0.85*sw_avg, sw_avg,     min(1, 1.15*sw_avg);
        'Bo (rb/stb)',    1.1,         1.2,        1.3 };
np = size(PAR, 1);
f  = @(x) x(:,1) .* x(:,2) .* x(:,3) .* x(:,4) .* (1 - x(:,5)) ./ x(:,6) * 6.2898;

X = zeros(nsim, np);
for j = 1:np
    X(:, j) = tri_inv(rand(nsim, 1), PAR{j,2}, PAR{j,3}, PAR{j,4});
end
S = f(X);

P90 = pctl(S, 10);  P50 = pctl(S, 50);  P10 = pctl(S, 90);  mu = mean(S);
fprintf('\n=== STOIIP (MMstb per km2), %d iterasi ===\n', nsim);
fprintf('P90 = %.1f | P50 = %.1f | P10 = %.1f | Mean = %.1f\n', P90, P50, P10, mu);

fig3 = figure('Position', [100 100 1000 420], 'Color', 'w');
subplot(1, 2, 1);
histogram(S, 50, 'Normalization', 'pdf', 'FaceColor', [0.3 0.5 0.8]); hold on;
xline(P90, '--r', 'P90'); xline(P50, '--k', 'P50'); xline(P10, '--g', 'P10');
xlabel('STOIIP (MMstb per km2)'); ylabel('Densitas probabilitas'); title('Distribusi STOIIP'); grid on;
subplot(1, 2, 2);
Ss = sort(S);
plot(Ss, 100 * (1 - (1:nsim)' / nsim), 'b', 'LineWidth', 1.5); hold on;
xline(P90, '--r'); xline(P50, '--k'); xline(P10, '--g');
xlabel('STOIIP (MMstb per km2)'); ylabel('Peluang terlampaui (%)');
title('Kurva eksedensi'); grid on;
exportgraphics(fig3, 'hasil/03_monte_carlo.png', 'Resolution', 200);

%% 8. TORNADO (analisis sensitivitas satu-per-satu)
base = zeros(1, np); lo_v = base; hi_v = base;
for j = 1:np
    base(j) = tri_inv(0.5, PAR{j,2}, PAR{j,3}, PAR{j,4});
    lo_v(j) = tri_inv(0.1, PAR{j,2}, PAR{j,3}, PAR{j,4});
    hi_v(j) = tri_inv(0.9, PAR{j,2}, PAR{j,3}, PAR{j,4});
end
S0 = f(base);
d_neg = zeros(np, 1); d_pos = zeros(np, 1);
for j = 1:np
    xa = base; xa(j) = lo_v(j);
    xb = base; xb(j) = hi_v(j);
    oa = f(xa); ob = f(xb);
    d_neg(j) = min(oa, ob) - S0;
    d_pos(j) = max(oa, ob) - S0;
end
[~, ord] = sort(d_pos - d_neg, 'ascend');   % terbesar di atas
ord = ord((d_pos(ord) - d_neg(ord)) > 0);
nk  = numel(ord);

fig4 = figure('Position', [100 100 800 450], 'Color', 'w');
barh(1:nk, d_neg(ord), 'FaceColor', [0.85 0.33 0.10]); hold on;
barh(1:nk, d_pos(ord), 'FaceColor', [0.20 0.60 0.30]);
yticks(1:nk); yticklabels(PAR(ord, 1));
xlabel(sprintf('Perubahan STOIIP (MMstb per km2) terhadap kasus dasar (%.1f)', S0));
title('Tornado chart: setiap parameter digeser dari P10 ke P90'); grid on;
exportgraphics(fig4, 'hasil/04_tornado.png', 'Resolution', 200);

%% 9. SIMPAN TABEL HASIL
writetable(table(depth, GR, RT, RHOB, NPHI, Vsh, PHIE, Sw, pay), 'hasil/log_interpretasi.csv');
writetable(table(P90, P50, P10, mu, H_net, NTG, phi_avg, sw_avg), 'hasil/ringkasan.csv');
disp('Selesai. Cek folder hasil/');