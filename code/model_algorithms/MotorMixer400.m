function [duty,counts,before]=stepFn(thrust,rollTorque,pitchTorque,yawTorque,run,reset,overG,mode,dt)
% 日本語の説明はブロック注釈とDescriptionを参照。
%#codegen
persistent Filter;
if isempty(Filter)
Filter=zeros(4,1,'single');
end
            duty=zeros(4,1,'single');counts=zeros(4,1,'uint8');before=zeros(4,1,'single');
            if mode==3 || reset,Filter(:)=single(0);end
            if run
                torque=[rollTorque;pitchTorque;yawTorque];mix=single([-1 1 1;1 1 -1;-1 -1 -1;1 -1 1]);
                for j=1:4
                    combination=mix(j,1)*torque(1)+mix(j,2)*torque(2)+mix(j,3)*torque(3);
                    before(j)=single(double(thrust+combination*single(.25))/3.7);
                    Filter(j)=filterStep(before(j),dt,single(0.003),Filter(j));
                end
                duty=min(max(Filter,single(0)),single(0.95));if overG~=0,duty(:)=single(0);end
                counts=uint8(floor(single(255)*duty));
            end
end

function s = filterStep(u,h,T,s)
%FILTERSTEP Exact Filter::update, including operation ordering.
%#codegen
s = s*T/(T+h) + u*h/(T+h);
end
