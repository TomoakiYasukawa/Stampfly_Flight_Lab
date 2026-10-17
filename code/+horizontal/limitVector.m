function y=limitVector(x,limit)
%LIMITVECTOR 概要：2軸ベクトルの方向を保ち、合成値を上限に制限します。
%#codegen
y=single(x);n2=sum(y.*y);bound=single(limit);
if n2>bound*bound,y=y*(bound/horizontal.mathSingle('sqrt',n2));end
end
