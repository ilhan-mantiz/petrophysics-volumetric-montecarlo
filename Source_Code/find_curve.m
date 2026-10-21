function v = find_curve(T, candidates, label)
% FIND_CURVE  Mencari kolom di table T berdasarkan daftar nama kandidat.
    vn = T.Properties.VariableNames;
    for k = 1:numel(candidates)
        idx = find(strcmpi(vn, candidates{k}), 1);
        if ~isempty(idx)
            v = T.(vn{idx});
            fprintf('  %-6s -> kurva "%s"\n', label, vn{idx});
            return;
        end
    end
    error(['Kurva %s tidak ditemukan.\nKurva yang ada: %s\n' ...
           'Tambahkan namanya ke daftar "cand" di portfolio_main.m'], ...
           label, strjoin(vn, ', '));
end