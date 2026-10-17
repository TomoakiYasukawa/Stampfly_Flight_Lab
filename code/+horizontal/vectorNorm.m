function magnitude=vectorNorm(vector)
%VECTORNORM 概要：水平処理の短いベクトルの大きさを単精度で求めます。
% 呼出し側は有限性と使用上限を確認します。過大な入力の二乗がInfでも
% 上限外として棄却されます。MATLABでは元のnormと同じ計算を使います。
%#codegen
coder.inline('always');
if coder.target('MATLAB')
    magnitude=norm(vector);
else
    vector=single(vector);magnitude=horizontal.mathSingle('sqrt',sum(vector.*vector));
end
end
