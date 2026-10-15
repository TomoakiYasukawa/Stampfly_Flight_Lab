function length=frameLength(header)
%FRAMELENGTH Known byte-stream frames; zero means an unknown header.
length=0;
header=uint8(header(:));
if numel(header)~=4 || ~isequal(header(1:3),uint8('SFI').'),return;end
versions=uint8('12345678XY');sizes=[37 63 93 106 111 114 182 190 190 246];
index=find(versions==uint8(header(4)),1);
if ~isempty(index),length=sizes(index);end
end
