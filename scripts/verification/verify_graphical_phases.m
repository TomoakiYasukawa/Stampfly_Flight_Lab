function report=verify_graphical_phases(sid)
%VERIFY_GRAPHICAL_PHASES Compare archived native calls and graphical phases.
root=stampfly_project_root();name=['PhaseEquivalence' num2str(sid)];
create_reorganization_harness(sid,name);
n=9000;t=(0:n-1)'*.0025;
mode=zeros(n,1,'uint8');mode(2:802)=1;mode(803:1050)=3;mode(1051:3500)=2;
mode(3501:4140)=6;mode(4141:4500)=2;mode(4501:4900)=5;mode(4901:5100)=3;
mode(5101:6400)=2;mode(6401:6650)=6;mode(6651:6800)=3;mode(6801:7100)=2;
mode(7101:7850)=6;mode(7851:8300)=5;mode(8301:end)=3;
voltage=single(4.1-.00008*(1:n)');
if sid==531
    button=zeros(n,1,'uint8');button(1200:1220)=1;button(4130:4160)=1;button(5650:5750)=1;
    reset=false(n,1);reset([6650 7300])=true;
    rate=single([sin(t),cos(t),.2*sin(3*t)]);
    values={button,mode,voltage,reset,rate};outputs=8;
elseif sid==126
    stick=zeros(n,6,'single');stick(:,6)=4;stick(2600:2750,4)=.5;stick(3000:3300,4)=-.6;
    stick(5600:5800,6)=5;stick(5600:5800,4)=.3;stick(5600:5800,5)=1;
    height=single(.5+.15*sin(t));height(4800:4900)=.08;
    range=zeros(n,1,'uint8');range(2850:2900)=20;range(5900:5920)=20;
    phase=zeros(n,1,'uint8');phase(3501:3680)=1;phase(3681:3720)=2;
    phase(3721:3760)=3;phase(3761:3800)=4;phase(3801:3840)=5;phase(3841:3850)=6;
    done=false(n,1);done([4140 6650 7850])=true;
    values={stick,height,voltage,range,mode,phase,done};outputs=7;
else
    pre=mode;pre(3501:4500)=5;
    height=single(.5+.4*sin(4*t));height(4700:4800)=.09;height(8000:8050)=.1;
    start=false(n,1);start([1500 3501 4000 7101])=true;
    done=false(n,1);done([3850 4140 7350])=true;
    over=zeros(n,1,'uint8');over([1500 3850 4140 4750 7350])=1;
    values={mode,pre,height,start,done,over};outputs=1;
end
dataset=Simulink.SimulationData.Dataset;
for k=1:numel(values)
    ts=timeseries(values{k},t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');dataset=dataset.addElement(ts);
end
in=Simulink.SimulationInput(name);in=in.setVariable('inf',builtin('inf'));in=in.setExternalInput(dataset);
in=in.setModelParameter('StopTime',num2str(t(end),17));out=sim(in);
report=struct('SID',sid,'Samples',n,'MismatchCounts',zeros(1,outputs),'MaxErrors',zeros(1,outputs));
for k=1:outputs
    a=out.yout{2*k-1}.Values.Data;b=out.yout{2*k}.Values.Data;
    assert(strcmp(class(a),class(b)) && isequal(size(a),size(b)));
    report.MismatchCounts(k)=nnz(a~=b);report.MaxErrors(k)=max(abs(double(a)-double(b)),[],'all');
end
save(fullfile(root,'tests',['phase_equivalence_' num2str(sid) '.mat']),'report','out','values','t');disp(report);
assert(all(report.MismatchCounts==0),'official:PhaseNotEquivalent','Graphical chart %d differs.',sid);
end
