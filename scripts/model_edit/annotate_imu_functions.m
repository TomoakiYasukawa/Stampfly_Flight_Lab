function report=annotate_imu_functions()
%ANNOTATE_IMU_FUNCTIONS 組み込み関数へ概要と機能別の日本語コメントを追加。
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));
listeners=layout.LayoutListeners();disabler=listeners.getScopedLayoutListenerDisabler(m); %#ok<NASGU>
spec=jsondecode(fileread(fullfile(root,'scripts','model_edit','imu_function_documentation.json')));
charts=sfroot().find('-isa','Stateflow.EMChart');records=struct('ID',{},'Name',{},'Sections',{},'ComputationUnchanged',{});
for k=1:numel(charts)
    p=charts(k).Path;if ~startsWith(p,[m '/']),continue;end
    name=regexprep(get_param(p,'Name'),'400','');assert(isfield(spec,name),'cleanup:UndocumentedFunction','No description: %s',name);
    item=spec.(name);cfg=get_param(p,'MATLABFunctionConfiguration');before=cfg.FunctionScript;
    lines=splitlines(string(before));comments=startsWith(strtrim(lines),'%');
    directives=startsWith(strtrim(lines),'%#');lines=lines(~comments|directives);
    after=join(lines,newline);
    firstEnd=strfind(char(after),newline);assert(~isempty(firstEnd));
    after=extractBefore(after,firstEnd(1))+newline+"% 概要："+string(item.Overview)+newline+extractAfter(after,firstEnd(1));
    for j=1:numel(item.Sections)
        anchor=string(item.Sections(j).Anchor);positions=strfind(char(after),char(anchor));
        assert(isscalar(positions),'cleanup:CommentAnchor','Expected one anchor in %s: %s',name,anchor);
        index=positions(1);value=char(after);start=find(value(1:index-1)==newline,1,'last');
        if isempty(start),start=0;end
        after=string(value(1:start))+"% "+string(j)+". "+string(item.Sections(j).Text)+newline+string(value(start+1:end));
    end
    assert(isequal(computation(before),computation(after)),'cleanup:CommentChangedCode','Comments modified computation: %s',name);
    cfg.FunctionScript=char(after);
    chartID=reorg.id(p);parent=get_param(p,'Parent');scope='root';if ~strcmp(parent,m),scope=reorg.id(parent);end
    reorg.edit(m,scope,{reorg.configure(chartID,struct('Description',item.Overview))});
    records(end+1)=struct('ID',chartID,'Name',name,'Sections',numel(item.Sections),'ComputationUnchanged',true); %#ok<AGROW>
    if ismember(name,{'FilterInputs','FlightOutputs'})
        sources=struct('FilterInputs','IMUFilterInputs','FlightOutputs','IMUFlightOutputs');
        % The saved chart already uses the template's function name.
        source=char(after);
        assert(contains(source,[sources.(name) '(']));
        writeText(fullfile(root,'code','model_algorithms',[sources.(name) '.m']),source);
    end
end
assert(numel(records)==14);save_system(m);
report=struct('MATLABFunctionCount',numel(records),'Functions',records,'CommentsOnly',true);
writeText(fullfile(root,'docs','imu_function_documentation.json'),jsonencode(report,'PrettyPrint',true));
fprintf('IMU_FUNCTION_DOCUMENTATION_COMPLETE: %d functions\n',numel(records));
end
function value=computation(script)
lines=splitlines(string(script));lines=lines(~startsWith(strtrim(lines),'%'));
lines=strtrim(lines);value=lines(strlength(lines)>0);
end
function writeText(file,value)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',value);fclose(fid);
end
