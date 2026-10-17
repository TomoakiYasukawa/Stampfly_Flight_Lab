function value=mathSingle(operation,x,y)
%MATHSINGLE 概要：水平補助の数学関数を単精度のまま実行します。
% 既存モデルのC89設定ではsingle入力も倍精度の数学関数へ変換されます。
% 水平補助だけsqrtf/sinf/cosf/atan2fを使い、既存PID・推定器は保ちます。
% operationは呼出しごとの固定文字列で、生成コードに選択処理は残りません。
%#codegen
coder.inline('always');
if nargin<3,y=single(0);end
x=single(x);y=single(y);value=single(0);
if coder.target('MATLAB')
    switch operation
        case 'sqrt',value=sqrt(x);
        case 'sin',value=sin(x);
        case 'cos',value=cos(x);
        case 'atan2',value=atan2(x,y);
    end
else
    coder.cinclude('math.h');
    switch operation
        case 'sqrt',value=coder.ceval('sqrtf',x);
        case 'sin',value=coder.ceval('sinf',x);
        case 'cos',value=coder.ceval('cosf',x);
        case 'atan2',value=coder.ceval('atan2f',x,y);
    end
end
end
