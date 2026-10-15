function s = filterStep(u,h,T,s)
%FILTERSTEP Exact Filter::update, including operation ordering.
%#codegen
s = s*T/(T+h) + u*h/(T+h);
end
