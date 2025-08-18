function text_cleaner_app_batch
% TEXT_CLEANER_APP_BATCH
% Multi-file text cleaner: load 1+ .txt files, define find/replace rules,
% preview per-file, apply to one or all, and save all (to a folder or overwrite).
%
% Default behavior is NON-destructive: "Save All..." asks for an output folder.
% Check "Overwrite originals" to write back to the source files.

    % ---------- UI ----------
    f = uifigure('Name','Text Cleaner (Batch)','Position',[100 100 1200 680]);

    % Top controls
    btnLoad  = uibutton(f,'Text','Load .txt files...','Position',[20 635 140 28],...
        'ButtonPushedFcn',@onLoad);
    btnSaveAll = uibutton(f,'Text','Save All...','Position',[170 635 100 28],...
        'Enable','off','ButtonPushedFcn',@onSaveAll);

    cbCase   = uicheckbox(f,'Text','Case sensitive','Position',[290 637 120 24],'Value',false);
    cbWord   = uicheckbox(f,'Text','Whole word only','Position',[420 637 130 24],'Value',false);
    cbOverwrite = uicheckbox(f,'Text','Overwrite originals','Position',[570 637 160 24],'Value',false,...
        'Tooltip','If checked, "Save All..." will write back to the source files.');

    btnApplySel = uibutton(f,'Text','Apply to Selected','Position',[760 635 140 28],...
        'Enable','off','ButtonPushedFcn',@onApplySelected);
    btnApplyAll = uibutton(f,'Text','Apply to All','Position',[910 635 110 28],...
        'Enable','off','ButtonPushedFcn',@onApplyAll);

    lblStatus = uilabel(f,'Text','Load files to begin.','Position',[1040 637 150 22],...
        'HorizontalAlignment','right');

    % Left: file list
    uilabel(f,'Text','Files','Position',[20 610 60 20],'FontWeight','bold');
    lbFiles = uilistbox(f,'Position',[20 370 300 230],...
        'Items',{},'ValueChangedFcn',@onSelectFile);

    % Middle: rules
    uilabel(f,'Text','Find/Replace Rules','Position',[340 610 200 20],'FontWeight','bold');
    ruleTable = uitable(f,'Position',[340 430 520 170],...
        'ColumnName',{'Find','Replace'},...
        'ColumnEditable',[true true],...
        'ColumnWidth',{250,250},...
        'Data', {'Head cleaning','head_cleaning'});

    btnAddRow = uibutton(f,'Text','+ Row','Position',[870 565 70 28],...
        'ButtonPushedFcn',@(s,e) addRow(1));
    btnDelRow = uibutton(f,'Text','– Row','Position',[870 530 70 28],...
        'ButtonPushedFcn',@(s,e) addRow(-1));
    btnSnake  = uibutton(f,'Text','SnakeCase selected "Find" → "Replace"',...
    'Position',[960 565 220 28],...   % <— shifted to the right
    'Tooltip','Lowercase and replace non-alnum with underscores',...
    'ButtonPushedFcn',@onSnakeCase);
    
    % Bottom: original vs preview (for the selected file)
    uilabel(f,'Text','Original (selected file)','Position',[340 410 200 20]);
    uilabel(f,'Text','Preview (after rules)','Position',[880 410 200 20]);

    taOrig = uitextarea(f,'Position',[340 20 520 390],'Editable','off');
    taPrev = uitextarea(f,'Position',[880 20 300 390],'Editable','off');

    % ---------- State ----------
    S.files = struct('path',{},'name',{},'textOriginal',{},'textPreview',{},'isDirty',{});
    S.activeIdx = []; % index in S.files for list selection

    % ---------- Callbacks ----------
    function onLoad(~,~)
        [fn,fp] = uigetfile({'*.txt','Text files (*.txt)';'*.*','All files'}, ...
                             'Select one or more text files','MultiSelect','on');
        if isequal(fn,0), return; end
        if ischar(fn), fn = {fn}; end

        newFiles = struct('path',{},'name',{},'textOriginal',{},'textPreview',{},'isDirty',{});
        for i = 1:numel(fn)
            full = fullfile(fp,fn{i});
            try
                txt = fileread(full);
            catch ME
                uialert(f, sprintf('Failed: %s\n%s', fn{i}, ME.message), 'Read error');
                continue;
            end
            newFiles(end+1).path = full; %#ok<AGROW>
            newFiles(end).name = fn{i};
            newFiles(end).textOriginal = string(txt);
            newFiles(end).textPreview  = string(txt);
            newFiles(end).isDirty = false;
        end

        if isempty(newFiles), return; end
        S.files = newFiles;
        lbFiles.Items = {S.files.name};
        lbFiles.Value = lbFiles.Items{1};
        S.activeIdx = 1;

        % show first file
        taOrig.Value = splitlines(S.files(1).textOriginal);
        taPrev.Value = splitlines(S.files(1).textPreview);

        btnApplySel.Enable = 'on';
        btnApplyAll.Enable = 'on';
        btnSaveAll.Enable  = 'on';
        lblStatus.Text = sprintf('Loaded %d file(s).', numel(S.files));
    end

    function onSelectFile(~,~)
        if isempty(S.files), return; end
        idx = find(strcmp(lbFiles.Value, lbFiles.Items),1);
        if isempty(idx), return; end
        S.activeIdx = idx;
        taOrig.Value = splitlines(S.files(idx).textOriginal);
        taPrev.Value = splitlines(S.files(idx).textPreview);
    end

    function onApplySelected(~,~)
        if isempty(S.activeIdx), return; end
        applyRulesToIndex(S.activeIdx);
        lblStatus.Text = sprintf('Applied rules to "%s".', S.files(S.activeIdx).name);
    end

    function onApplyAll(~,~)
        if isempty(S.files), return; end
        for i = 1:numel(S.files)
            applyRulesToIndex(i);
        end
        % refresh preview if selection exists
        if ~isempty(S.activeIdx)
            taPrev.Value = splitlines(S.files(S.activeIdx).textPreview);
        end
        lblStatus.Text = 'Applied rules to all files.';
    end

    function onSaveAll(~,~)
        if isempty(S.files), return; end

        if cbOverwrite.Value
            % Confirm overwrite
            choice = uiconfirm(f,'This will overwrite the original files. Continue?',...
                'Overwrite originals','Options',{'Cancel','Overwrite'},'DefaultOption',2,'CancelOption',1);
            if ~strcmp(choice,'Overwrite'), return; end
            errs = 0;
            for i = 1:numel(S.files)
                ok = saveOne(S.files(i).path, S.files(i).textPreview);
                errs = errs + ~ok;
            end
            if errs==0
                lblStatus.Text = 'Saved (overwrote) all files.';
            else
                lblStatus.Text = sprintf('Saved with %d error(s).',errs);
            end
            return;
        end

        % Choose output folder (non-destructive)
        outdir = uigetdir(pwd,'Choose output folder');
        if isequal(outdir,0), return; end
        errs = 0;
        for i = 1:numel(S.files)
            tgt = fullfile(outdir, S.files(i).name);
            ok = saveOne(tgt, S.files(i).textPreview);
            errs = errs + ~ok;
        end
        if errs==0
            lblStatus.Text = sprintf('Saved all to: %s', outdir);
        else
            lblStatus.Text = sprintf('Saved with %d error(s).',errs);
        end
    end

    function onSnakeCase(~,~)
        sel = ruleTable.Selection;
        if isempty(sel)
            uialert(f,'Select at least one row in the rules table.','No selection');
            return;
        end
        data = ruleTable.Data;
        rows = unique(sel(:,1));
        for r = rows.'
            findStr = string(data{r,1});
            data{r,2} = to_snake(findStr);
        end
        ruleTable.Data = data;
        lblStatus.Text = 'Snake_case suggestions added.';
    end

    function addRow(delta)
        data = ruleTable.Data;
        if isempty(data), data = cell(0,2); end
        if delta>0
            data(end+1,:) = {'' ''}; %#ok<AGROW>
        else
            sel = ruleTable.Selection;
            if ~isempty(sel)
                rows = unique(sel(:,1));
                data(rows,:) = [];
            elseif ~isempty(data)
                data(end,:) = [];
            end
        end
        ruleTable.Data = data;
    end

    % ---------- Helpers ----------
    function applyRulesToIndex(i)
        rules = ruleTable.Data;
        if isempty(rules), return; end
        txt = S.files(i).textOriginal;
        cs  = cbCase.Value;
        ww  = cbWord.Value;
        for k = 1:size(rules,1)
            pat = string(rules{k,1});
            rep = string(rules{k,2});
            if strlength(strtrim(pat))==0, continue; end
            txt = safeReplace(txt, pat, rep, cs, ww);
        end
        S.files(i).textPreview = txt;
        S.files(i).isDirty = true;

        if ~isempty(S.activeIdx) && i==S.activeIdx
            taPrev.Value = splitlines(txt);
        end
    end

    function ok = saveOne(pathOut, txt)
        ok = true;
        try
            fid = fopen(pathOut,'w');
            if fid<0, error('Could not open file for writing.'); end
            fwrite(fid, txt, 'char');
            fclose(fid);
        catch
            ok = false;
        end
    end

    function out = safeReplace(in, findStr, replStr, caseSensitive, wholeWord)
        lit = regexptranslate('escape', char(findStr));
        if wholeWord
            lit = ['(?<!\w)' lit '(?!\w)'];
        end
        if ~caseSensitive
            lit = ['(?i)' lit];
        end
        out = regexprep(in, lit, replStr); % replace ALL occurrences
    end

    function s = to_snake(strIn)
        s = char(strIn);
        s = lower(strtrim(s));
        s = regexprep(s,'[^a-z0-9]+','_');
        s = regexprep(s,'_+','_');
        s = regexprep(s,'^_|_$','');
    end
end
