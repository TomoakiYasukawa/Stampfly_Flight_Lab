function report=verify_pid_block400()
%VERIFY_PID_BLOCK400 Check arithmetic, variable Dt, reset/hold and saturation.
% PID専用ブロックの最も近い設定を実際の7組のゲインで比較する。
root=stampfly_project_root();m='PIDBlockComparison400';
load_system(stampfly_model_file(m));
metadata=fullfile(root,'tests','pid_comparison_metadata.mat');
assert(isfile(metadata),'official:PIDMetadata','Run create_pid_comparison400 first.');
ids=load(metadata,'result').result;
gains=ids.GainSets;
names=fieldnames(gains);cases={'FixedDt','VariableDt','ResetEnabled', ...
    'ResetWhileDisabled','PreviousErrorReset','IntegralSaturation'};
report=struct('Model',stampfly_model_file(m),'AbsoluteTolerance',0, ...
    'Candidate','Ideal PID, trapezoidal I/D, external Dt, single, integral limit +/-30000', ...
    'ProductionChanged',false,'GainSets',gains);
for g=1:numel(names)
    gain=gains.(names{g});
    original=reorg.path(m,ids.OriginalID);ops={};
    for parameter={'Kp','Ti','Td','Eta'}
        blk=find_system(original,'SearchDepth',1,'Name',parameter{1});assert(numel(blk)==1);
        ops{end+1}=reorg.configure(reorg.id(blk{1}),struct('Value',singleLiteral(gain.(parameter{1})))); %#ok<AGROW>
    end
    reorg.edit(m,ids.OriginalID,ops);
    mapped=struct('P',singleLiteral(gain.Kp),'I',['single(1)/' singleLiteral(gain.Ti)], ...
        'D',singleLiteral(gain.Td),'N',['single(1)/(' singleLiteral(gain.Eta) '*' singleLiteral(gain.Td) ')']);
    reorg.edit(m,ids.EnabledID,{reorg.configure(ids.PIDID,mapped)});
    for c=1:numel(cases)
        [values,t]=testInput(cases{c});dataset=Simulink.SimulationData.Dataset;
        for k=1:numel(values)
            ts=timeseries(values{k},t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');
            dataset=dataset.addElement(ts);
        end
        in=Simulink.SimulationInput(m);in=in.setExternalInput(dataset);
        in=in.setModelParameter('StopTime',num2str(t(end),17));out=sim(in);
        a=out.yout{1}.Values.Data;b=out.yout{2}.Values.Data;
        result=struct('Samples',numel(t),'MismatchCount',nnz(a~=b), ...
            'MaxAbsoluteError',max(abs(double(a)-double(b)),[],'all'), ...
            'RMSDifference',sqrt(mean((double(a)-double(b)).^2,'all')), ...
            'TypesMatch',strcmp(class(a),class(b)),'OriginalType',class(a),'CandidateType',class(b));
        report.Results.(names{g}).(cases{c})=result;
        fprintf('PID_BLOCK_CHECK %s / %s: mismatch=%d, max=%g\n', ...
            names{g},cases{c},result.MismatchCount,result.MaxAbsoluteError);
        save(fullfile(root,'build','tests',['pid_' names{g} '_' cases{c} '.mat']),'values','t','out','result');
    end
end
report.Completed=true;
save(fullfile(root,'tests','pid_block_comparison.mat'),'report');
fid=fopen(fullfile(root,'docs','pid_block_comparison.json'),'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
% Store the reusable candidate with the altitude gain set shown by default.
gain=gains.AltitudePID;ops={};
for parameter={'Kp','Ti','Td','Eta'}
    blk=find_system(original,'SearchDepth',1,'Name',parameter{1});
    ops{end+1}=reorg.configure(reorg.id(blk{1}),struct('Value',singleLiteral(gain.(parameter{1})))); %#ok<AGROW>
end
reorg.edit(m,ids.OriginalID,ops);
reorg.edit(m,ids.EnabledID,{reorg.configure(ids.PIDID,struct('P',singleLiteral(gain.Kp), ...
    'I',['single(1)/' singleLiteral(gain.Ti)],'D',singleLiteral(gain.Td), ...
    'N',['single(1)/(' singleLiteral(gain.Eta) '*' singleLiteral(gain.Td) ')']))});
save_system(m,stampfly_model_file(m));
end

function result=singleLiteral(value)
result=sprintf('single(%.17g)',double(value));
end

function [values,t]=testInput(name)
n=800;t=(0:n-1)'*.0025;
e=single(.3*sin(2*pi*.8*t)+.2*(t>=.15));dt=repmat(single(.0025),n,1);
enabled=true(n,1);reset=false(n,1);previous=zeros(n,1,'single');
switch name
    case 'VariableDt'
        dt=single(.0025*(1+.16*sin(2*pi*2.3*t)));
    case 'ResetEnabled'
        reset([240 400 401 560])=true;
    case 'ResetWhileDisabled'
        enabled(240:400)=false;reset(300)=true;
    case 'PreviousErrorReset'
        reset([240 400])=true;previous(reset)=single(.7);
    case 'IntegralSaturation'
        e(:)=single(200000);e(401:end)=single(-200000);
end
values={e,dt,enabled,reset,previous};
end
