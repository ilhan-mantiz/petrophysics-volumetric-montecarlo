function p = pctl(x, q)
% PCTL  Persentil sederhana (q dalam persen, 0-100), mengabaikan NaN.
    xs = sort(x(~isnan(x(:))));
    n  = numel(xs);
    i  = max(1, min(n, round(q / 100 * n)));
    p  = xs(i);
end