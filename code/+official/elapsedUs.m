function y=elapsedUs(now,previous)
%ELAPSEDUS Unsigned modular subtraction; MATLAB integer arithmetic saturates.
%#codegen
y=uint32(bitand(uint64(now)+uint64(4294967296)-uint64(previous),uint64(4294967295)));
end
