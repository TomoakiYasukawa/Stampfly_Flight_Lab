function data=readExtendedTelemetry(filePath)
%READEXTENDEDTELEMETRY 指令・センサー補足を通常50 Hz表へキーで結合する。
% 無線で補足フレームが欠落した行はNaNを維持し、別の時刻を使わない。
arguments
    filePath (1,1) string
end
variables=whos('-file',filePath);
requested={'info','telemetry'};
if ismember('extensionTelemetry',{variables.name})
    requested{end+1}='extensionTelemetry';
end
saved=load(filePath,requested{:});
data=array2table(saved.telemetry,'VariableNames',saved.info.Columns);
if ~isfield(saved,'extensionTelemetry') || isempty(saved.extensionTelemetry),return;end
extra=saved.extensionTelemetry;names=saved.info.ExtensionColumns(6:end);
values=nan(height(data),numel(names));revision=nan(height(data),1);sensorRevision=revision;
keys=[data.Sequence,data.TimeSeconds,data.BuildID];
for kind=1:3
    if kind==3&&numel(names)<161,continue;end % 旧記録の列数を維持します。
    selected=extra(:,1)==kind;
    [matched,index]=ismember(keys,extra(selected,2:4),'rows');
    if kind==1,fields=1:53;elseif kind==2,fields=54:121;else,fields=122:161;end
    subset=extra(selected,:);
    values(matched,fields)=subset(index(matched),5+fields);
    revision(matched)=subset(index(matched),5);
    if kind==2,sensorRevision(matched)=subset(index(matched),5);end
end
% Use explicit names when a legacy field already exists in the standard table.
for k=1:numel(names)
    name=names{k};
    if ismember(name,data.Properties.VariableNames),name=['Extended' name];end
    data.(name)=values(:,k);
end
data.FirmwareRevision=revision;
if ismember('Reserved',data.Properties.VariableNames)
    data.ResetReason=nan(height(data),1);
    validRevision=sensorRevision>=1802;
    data.ResetReason(validRevision)=data.Reserved(validRevision);
end
end
