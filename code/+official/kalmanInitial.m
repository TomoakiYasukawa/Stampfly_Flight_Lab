function s = kalmanInitial()
%#codegen
s = struct('x',zeros(3,1,'single'),'P',single(100)*eye(3,'single'), ...
    'output',zeros(3,1,'single'));
end
