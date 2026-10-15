function result=id(path)
result=['blk_' extractAfter(Simulink.ID.getSID(path),':')];
end
