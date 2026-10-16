function report=verify_graphical_supervisor()
%VERIFY_GRAPHICAL_SUPERVISOR Compare each tick, including arbitrary branch input.
root=stampfly_project_root();
model='GraphicalSupervisorEquivalence400';
create_reorganization_harness(530,model);
n=10000;t=(0:n-1)'*.0025;
mode=zeros(n,1,'uint8');mode(2:802)=1;mode(803:1300)=3;mode(1301:3500)=2;
mode(3501:4200)=6;mode(4201:4500)=5;mode(4501:5000)=3;mode(5001:7600)=2;
mode(7601:8500)=5;mode(8501:9000)=3;mode(9001:end)=6;
button=zeros(n,1,'uint8');button(850:890)=1;button(1600:1650)=1;button(4400:4450)=1;
button(6200:6500)=1;button(8700:8730)=1;
packet=uint8(mod((1:n)',8)==0);packet(2100:2200)=0;packet(7100:7300)=0;
flags=zeros(n,3,'uint8');flags([3000 3850 7100 9500],1)=1;
ahrs=zeros(n,1,'uint8');ahrs(1100:1200)=1;ahrs(4600:4750)=1;
values={mode,button,packet,flags,ahrs};
dataset=Simulink.SimulationData.Dataset;
for k=1:numel(values)
    ts=timeseries(values{k},t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');
    dataset=dataset.addElement(ts);
end
in=Simulink.SimulationInput(model);in=in.setVariable('inf',builtin('inf'));
in=in.setExternalInput(dataset);in=in.setModelParameter('StopTime',num2str(t(end),17));
out=sim(in);
report=struct('Samples',n,'MismatchCounts',zeros(1,5),'MaxErrors',zeros(1,5));
for k=1:5
    a=out.yout{2*k-1}.Values.Data;b=out.yout{2*k}.Values.Data;
    report.MismatchCounts(k)=nnz(a~=b);report.MaxErrors(k)=max(abs(double(a)-double(b)),[],'all');
end
save(fullfile(root,'tests','graphical_supervisor_equivalence.mat'),'report','out','values','t');
disp(report);
assert(all(report.MismatchCounts==0),'official:SupervisorNotEquivalent','Supervisor differs from the archived implementation.');
end
