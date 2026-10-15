function id=note(model,scope,text,position)
%NOTE Visible Japanese explanations stored within the Simulink model.
if nargin<4,position=[40 20 1050 115];end
params=struct('Description',text,'Mask','on','MaskDisplay', ...
    ['disp(''' char(strrep(strrep(text,"'","''"),newline,'\n')) ''')'], ...
    'MaskIconOpaque','opaque','MaskIconFrame','off','ShowName','off', ...
    'Position',position,'FontSize','11','BackgroundColor','white');
reply=reorg.edit(model,scope,{reorg.add('SubSystem','JapaneseExplanation','note',params)});
id=reorg.created(reply,'note');
end
