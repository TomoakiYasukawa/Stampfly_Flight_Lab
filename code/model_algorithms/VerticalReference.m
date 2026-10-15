function vRef=stepFn(zRef,mode,auto,flipFlag)
% Auto高度補正が優先。公式else-ifの順序を維持。
%#codegen
vRef=zRef;if ~(auto && flipFlag==0) && mode==5,vRef=single(-.15);end
end
