function T = read_las(filename)
% READ_LAS  Membaca file LAS (versi 1.2 / 2.0) menjadi table MATLAB.
%   Nilai NULL otomatis diganti NaN.

    txt   = fileread(filename);
    lines = splitlines(txt);

    section = '';
    names   = {};
    nullval = -999.25;
    dataTxt = {};

    for i = 1:numel(lines)
        ln = strtrim(lines{i});
        if isempty(ln) || ln(1) == '#', continue; end

        if ln(1) == '~'                       % penanda awal bagian baru
            section = upper(ln(2));
            continue;
        end

        switch section
            case 'W'                          % WELL: cari nilai NULL
                tok = regexp(ln, '^NULL\s*\.\S*\s+([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)', ...
                             'tokens', 'once', 'ignorecase');
                if ~isempty(tok), nullval = str2double(tok{1}); end
            case 'C'                          % CURVE: ambil nama kurva
                tok = regexp(ln, '^([^\s\.:]+)\s*\.', 'tokens', 'once');
                if ~isempty(tok), names{end+1} = tok{1}; end %#ok<AGROW>
            case 'A'                          % ASCII: data angka
                dataTxt{end+1} = ln; %#ok<AGROW>
        end
    end

    if isempty(names)
        error('Bagian ~CURVE tidak ditemukan. Cek isi file LAS-mu.');
    end

    vals = sscanf(strjoin(dataTxt, ' '), '%f');
    nc   = numel(names);
    if mod(numel(vals), nc) ~= 0
        error('Jumlah angka (%d) tidak habis dibagi jumlah kurva (%d). Cek format LAS.', ...
              numel(vals), nc);
    end

    M = reshape(vals, nc, [])';
    M(abs(M - nullval) < 1e-6) = NaN;

    names = matlab.lang.makeValidName(names);
    for k = 2:nc                              % pastikan nama unik
        c = sum(strcmp(names(1:k-1), names{k}));
        if c > 0, names{k} = sprintf('%s_%d', names{k}, c + 1); end
    end

    T = array2table(M, 'VariableNames', names);
end