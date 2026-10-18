function result=verify_logger_packets()
%VERIFY_LOGGER_PACKETS Compare the complete copied SFI2..8 byte streams.
root=fileparts(fileparts(mfilename('fullpath')));folder=fullfile(root,'build','history','models');if ~isfolder(fullfile(folder,'archive','logger_packers')),mkdir(folder);unzip(fullfile(root,'archive','model_history.zip'),folder);end;addpath(fullfile(folder,'archive','logger_packers'));
common={uint16(37),single(1.25),single([1;2;9.8]),single([.1;-.2;.3]), ...
 uint8(1),single(.35),uint8(1),uint8(0),single([NaN;NaN]),uint8(0), ...
 uint8(0),uint16(0),single([NaN;NaN]),uint8(0)};
names={'packTelemetryFrame','packAttitudeFrame','packHeightFrame','packMotorFrame', ...
 'packFlightFrame','packFlightDiagnosticsFrame','packFlightTuningFrame'};
arguments=common;
for k=1:numel(names)
 switch k
  case 2,arguments=[arguments,{single([NaN;NaN;NaN]),uint8(0),single([.99;.02;.03;.04]),uint8(1)}];
  case 3,arguments=[arguments,{single(.32),uint8(1),single([NaN;NaN])}];
  case 4,arguments=[arguments,{single([42;120;239;255]),uint8(1)}];
  case 5,arguments=[arguments,{uint8(2),uint16(57)}];
  case 6,arguments=[arguments,{single([NaN;(-15:15)']),uint32(1401)}];
  case 7,arguments=[arguments,{single([.4;.2]),uint16(82),uint8(0)}];
 end
 old=str2func(['legacyframe.' names{k}]);current=str2func(['imu.' names{k}]);
 assert(isequal(old(arguments{:}),current(arguments{:})),'official:PacketChanged','%s bytes differ.',names{k});
 payload=current(arguments{:},true);full=current(arguments{:});
 assert(isequal(payload(1:end-2),full(1:end-2)));
end
result=struct('FormatsCompared',7,'ByteIdentical',true);
save(fullfile(reference_mex_folder(),'logger_packet_verification.mat'),'result');disp(result);
end
