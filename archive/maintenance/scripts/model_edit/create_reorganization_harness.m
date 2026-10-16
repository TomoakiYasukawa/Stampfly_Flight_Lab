function result=create_reorganization_harness(sids,name)
%CREATE_REORGANIZATION_HARNESS Execute archived and edited blocks side by side.
root=stampfly_project_root();
snapshot=load(fullfile(root,'tests','model_reorganization_before.mat')).snapshot;
[~,baseline]=fileparts(snapshot.BeforeFile);open_system(snapshot.BeforeFile);
model=snapshot.Model;
if nargin<2,name='GraphicalSupervisorEquivalence400';end
if bdIsLoaded(name),close_system(name,0);end
new_system(name);open_system(name);
operations={reorg.configure(['config:' name],struct('Solver','FixedStepDiscrete', ...
    'FixedStep','.0025','StopTime','1','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset'))};
result=struct('Model',name,'SIDs',sids,'Inputs',{{}},'OutputCounts',[]);
inputOffset=0;outputOffset=0;
for s=1:numel(sids)
    item=snapshot.Charts([snapshot.Charts.SID]==sids(s));
    oldRef=['old' num2str(s)];newRef=['new' num2str(s)];
    operations{end+1}=reorg.add(reorg.path(baseline,['blk_' num2str(item.SID)]),['Original' item.Name],oldRef);
    operations{end+1}=reorg.add(reorg.path(model,['blk_' num2str(item.SID)]),['Graphical' item.Name],newRef);
    for k=1:numel(item.InputNames)
        ref=sprintf('i%d',inputOffset+k);
        dim=inputDimension(item.SID,k);
        operations{end+1}=reorg.add('Inport',[item.Name '_' item.InputNames{k}],ref, ...
            struct('Port',num2str(inputOffset+k),'OutDataTypeStr',item.InputTypes{k}, ...
            'PortDimensions',num2str(dim),'SampleTime','.0025'));
        operations=[operations,{reorg.wire(['#' ref '.y1'],sprintf('#%s.u%d',oldRef,k)), ...
            reorg.wire(['#' ref '.y1'],sprintf('#%s.u%d',newRef,k))}];
        result.Inputs{end+1}=struct('Name',item.InputNames{k},'Type',item.InputTypes{k},'Dimension',dim);
    end
    for k=1:numel(item.OutputNames)
        oldPort=outputOffset+2*k-1;newPort=outputOffset+2*k;
        oldOut=sprintf('o%d',oldPort);newOut=sprintf('o%d',newPort);
        operations=[operations,{reorg.add('Outport',['Old' item.Name '_' item.OutputNames{k}],oldOut,struct('Port',num2str(oldPort))), ...
            reorg.add('Outport',['New' item.Name '_' item.OutputNames{k}],newOut,struct('Port',num2str(newPort))), ...
            reorg.wire(sprintf('#%s.y%d',oldRef,k),['#' oldOut '.u1']), ...
            reorg.wire(sprintf('#%s.y%d',newRef,k),['#' newOut '.u1'])}];
    end
    inputOffset=inputOffset+numel(item.InputNames);
    outputOffset=outputOffset+2*numel(item.OutputNames);
    result.OutputCounts(end+1)=numel(item.OutputNames);
end
reorg.edit(name,'root',operations,'full');
disp(model_check(name,'root','["all"]'));
save_system(name,stampfly_model_file(name));
save(fullfile(root,'tests',[name '_interface.mat']),'result');
end
function dimension=inputDimension(sid,port)
dimension=1;
if sid==530 && port==4,dimension=3;end
if sid==531 && port==5,dimension=3;end
if sid==126 && port==1,dimension=6;end
end
