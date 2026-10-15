function values=stepFn(t,dt,a,r,cd,accel,voltage,duty,z,sd,v)
% 公式120byteテレメトリの27個のfloat。バイト送信は専用IOブロック。
%#codegen
values=zeros(27,1,'single');values(1:2)=[t;dt];values(3:8)=[a;r]*single(180/pi);
values(9:13)=cd(6:10)*single(180/pi);values(14)=single(double(cd(5))/3.7);
values(15)=voltage;values(16:18)=accel([2 1 3])/single(9.80665);values(18)=-values(18);
values(19:20)=[v;cd(4)];values(21:22)=duty(2:3);
values(23:27)=[cd(1);z;sd(3);sd(1:2)];
end
