function x = tri_inv(u, lo, mode, hi)
% TRI_INV  Invers CDF distribusi segitiga (min, mode, max).
%   u = bilangan acak seragam 0..1 (boleh vektor).
    if hi <= lo
        x = lo * ones(size(u));
        return;
    end
    Fc   = (mode - lo) / (hi - lo);
    x    = zeros(size(u));
    left = u < Fc;
    x(left)  = lo + sqrt(u(left)  .* (hi - lo) .* (mode - lo));
    x(~left) = hi - sqrt((1 - u(~left)) .* (hi - lo) .* (hi - mode));
end