function delta=counterDelta(current,previous)
%COUNTERDELTA 概要：32 bitカウンターの差を、折返しを含めて求めます。
% MATLABのuint32減算は飽和するため、大小関係で分けて差を取ります。
% 各演算の中間値を32 bit以内に保ち、0xffffffff→0の差も1です。
% 倍精度のmodを毎周期呼ばず、取得番号・時刻・累積countを同じ定義で扱います。
%#codegen
if current>=previous
    delta=current-previous;
else
    delta=(uint32(4294967295)-previous)+current+uint32(1);
end
end
