function mode=stepFn(branch,preMode,height,flipStart,flipDone,overG)
% loop分岐の途中で変わるMode。get_commandは分岐途中でもFlipに変更できる。
%#codegen
mode=preMode;
if branch==5 && height<.1,mode=uint8(3);end
if flipStart && (branch==2 || branch==6),mode=uint8(6);end
if branch==6 && flipDone,mode=uint8(2);end
if (branch==2 || branch==5 || branch==6) && overG==1,mode=uint8(3);end
end
