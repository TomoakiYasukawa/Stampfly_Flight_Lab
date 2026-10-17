function values=horizontal_codegen_step(flow,inertial,range,context,manual,control,motorSaturated)
%HORIZONTAL_CODEGEN_STEP 水平補助の実クラスを生成コードと同じ境界で実行。
% 物理I/Oのない比較用入口です。並びはログ先頭24値＋観測16値です。
%#codegen
persistent observer command regulator selector
if isempty(observer)
    observer=horizontal.FlowMotion;command=horizontal.Command;
    regulator=horizontal.VelocityPI;selector=horizontal.SelectAttitude;
end
[p,v,yaw,height,status,diag]=observer(flow,inertial,range,context);
motion=struct('Position',p,'Velocity',v,'Heading',yaw,'Height',height,'Status',status,'Diagnostics',diag);
[target,enabled,state,hold]=command(motion,manual,control);
[acceleration,integral,saturated]=regulator(target,motion,enabled,motorSaturated);
[angles,blend]=selector(manual,acceleration,motion,enabled,control);
values=single([p;v;target;hold;acceleration;integral;angles;blend;single(state); ...
    single(enabled);single(saturated);height;yaw;status([1 4 5 7]);status;diag]);
end
