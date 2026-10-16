function [height,velocity,bias]=KF400FlightOutputs(state,run,parkingReset)
%KF400FLIGHTOUTPUTS Reset only public output, retaining the private state.
%#codegen
persistent heldOutput
if isempty(heldOutput),heldOutput=zeros(3,1,'single');end
if parkingReset,heldOutput(:)=single(0);end
if run,heldOutput=single(state(:));end
height=heldOutput(2);
velocity=heldOutput(1);
bias=heldOutput(3);
end
