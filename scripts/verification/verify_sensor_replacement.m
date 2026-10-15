function result = verify_sensor_replacement()
%VERIFY_SENSOR_REPLACEMENT Run old and new sensor subsystems on identical inputs.
% 全7出力を比較。初回FLIGHT、校正、待機再進入、reset、ToF外れ値、Dt変化。
root=stampfly_project_root(); snapshot=load(fullfile(root,'tests','sensor_processing_before.mat'));
[~,referenceModel]=fileparts(snapshot.sensorRefFile);
open_system(snapshot.sensorRefFile);
model='SensorProcessingEquivalence400';
if bdIsLoaded(model),close_system(model,0);end
new_system(model);open_system(model);
inputNames={'AccelMps2','GyroRps','ToFmm','ToFNew','Voltage','PreviousMode', ...
    'AltFlag','Dt','AHRSReset','ParkingReset','FlipFlag'};
types={'single','single','int16','uint8','single','uint8','uint8','single','boolean','boolean','uint8'};
dims=[3 3 1 1 1 1 1 1 1 1 1];
outputNames={'Attitude3','Rates3','Altitude','Velocity','Flags3','Quaternion4','Diagnostics8'};
ops={cfg(['config:' model],struct('Solver','FixedStepDiscrete','FixedStep','.0025', ...
    'StopTime','1','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset')), ...
    add(Simulink.ID.getFullName([referenceModel ':72']),'OriginalSensors','old',struct), ...
    add(Simulink.ID.getFullName('StampFly_Official_FlightTest400:72'),'ReplacedSensors','new',struct)};
for k=1:numel(inputNames)
    ref=['i' num2str(k)];
    ops{end+1}=add('Inport',inputNames{k},ref,struct('Port',num2str(k), ...
        'OutDataTypeStr',types{k},'PortDimensions',num2str(dims(k)),'SampleTime','.0025'));
    ops=[ops,{wire(['#' ref '.y1'],sprintf('#old.u%d',k)),wire(['#' ref '.y1'],sprintf('#new.u%d',k))}];
end
for k=1:7
    oldRef=['o' num2str(k)];newRef=['n' num2str(k)];
    ops=[ops,{add('Outport',['Old' outputNames{k}],oldRef,struct('Port',num2str(k))), ...
        add('Outport',['New' outputNames{k}],newRef,struct('Port',num2str(k+7))), ...
        wire(sprintf('#old.y%d',k),['#' oldRef '.u1']),wire(sprintf('#new.y%d',k),['#' newRef '.u1'])}];
end
model_read(model,'root','0');reply=char(model_edit(model,'root',jsonencode(ops),'full'));
assert(startsWith(strtrim(reply),'status: ok'),'%s',reply);
disp(model_check(model,'root','["all"]'));
save_system(model,stampfly_model_file(model));

cases={'BootTakeoffResets','StartInFlight','TimingAndRangeEdges'};
result=struct;
for c=1:numel(cases)
    [inputs,time]=testInputs(c);
    dataset=Simulink.SimulationData.Dataset;
    for k=1:numel(inputs)
        ts=timeseries(inputs{k},time,'Name',inputNames{k});
        ts.DataInfo.Interpolation=tsdata.interpolation('zoh');
        dataset=dataset.addElement(ts,inputNames{k});
    end
    in=Simulink.SimulationInput(model);
    % Base workspace may contain a task variable named inf. Override locally.
    in=in.setVariable('inf',builtin('inf'));
    in=in.setExternalInput(dataset);
    in=in.setModelParameter('StopTime',num2str(time(end),17));
    out=sim(in);
    report=struct('Samples',numel(time),'MaxErrors',zeros(1,7),'MismatchCounts',zeros(1,7), ...
        'OutputTypesMatch',true,'OutputSizesMatch',true);
    for k=1:7
        expected=out.yout{k}.Values.Data;
        actual=out.yout{k+7}.Values.Data;
        report.OutputTypesMatch=report.OutputTypesMatch && strcmp(class(actual),class(expected));
        report.OutputSizesMatch=report.OutputSizesMatch && isequal(size(actual),size(expected));
        assert(isequal(size(actual),size(expected)),'official:SensorSize','%s size mismatch',outputNames{k});
        report.MaxErrors(k)=max(abs(double(actual)-double(expected)),[],'all');
        report.MismatchCounts(k)=nnz(actual~=expected & ~(isnan(actual)&isnan(expected)));
    end
    result.(cases{c})=report;
    save(fullfile(root,'tests',['sensor_equivalence_' cases{c} '.mat']),'out','report');
    disp(cases{c});disp(report);
    assert(report.OutputTypesMatch,'official:SensorType','Output types changed');
    assert(all(report.MismatchCounts==0),'official:SensorNotEquivalent', ...
        '%s differs; saved per-output errors and simulation data in tests.',cases{c});
end
result.TotalSamples=3*6000;
result.OutputNames=outputNames;
save(fullfile(root,'tests','sensor_equivalence_summary.mat'),'result');
end

function [inputs,t]=testInputs(whichCase)
n=6000;t=(0:n-1)'*.0025;
a=single([.15*sin(3*t), .12*cos(2*t), 9.80665+.25*sin(5*t)]);
g=single([.025*sin(4*t), .02*cos(3*t), .015*sin(2*t)]);
mm=int16(500+100*sin(t)); fresh=uint8(mod((0:n-1)',16)==0);
voltage=single(4.05-.05*t);
mode=zeros(n,1,'uint8');mode(2:801)=1;mode(802:1000)=3;mode(1001:2800)=2;
mode(2801:3200)=5;mode(3201:3500)=3;mode(3501:4600)=2;mode(4601:5000)=6;
mode(5001:5400)=3;mode(5401:end)=2;
alt=uint8(mode==2);dt=repmat(single(.0025),n,1);
ahrs=false(n,1);ahrs([1001 3501 5001 5401])=true;
parking=mode==3;flip=uint8(mode==6);
if whichCase==2
    mode(:)=2;mode(1000:1050)=0;mode(1051:1100)=1;mode(2500:2700)=3;mode(4000:4100)=5;
    parking=mode==3;alt=uint8(mode==2);flip(:)=0;ahrs([1 2000 2500 4200])=true;
elseif whichCase==3
    dt=single(.0025+.00035*sin(17*t));
    mm(1300:1320)=1900;mm(1700:1750)=0;mm(2200:2210)=int16(10);
    mm(3800:3900)=int16(2800);mm(4300:4400)=int16(-1);
    fresh(1300:1320)=1;fresh(3800:3900)=1;
    a(4200:4210,:)=single([25 0 9.80665])+zeros(11,3,'single');
    voltage(4700:end)=single(3.2);
    parking([1100 2400 4100])=true;
end
inputs={a,g,mm,fresh,voltage,mode,alt,dt,ahrs,parking,flip};
end
function op=add(type,name,ref,params),op=struct('op','add_block','type',type,'name',name,'ref',ref,'params',params);end
function op=wire(a,b),op=struct('op','connect','target',[a ' -> ' b]);end
function op=cfg(target,params),op=struct('op','configure','target',target,'params',params);end
