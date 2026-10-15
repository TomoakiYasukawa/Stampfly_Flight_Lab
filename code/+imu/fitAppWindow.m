function fitAppWindow(fig)
%FITAPPWINDOW Place the logger within the primary monitor with a margin.
monitors = get(groot,'MonitorPositions');
if isempty(monitors)
    return
end
screen = monitors(1,:);
margin = min(40,floor(min(screen(3:4))/10));
width = max(1,screen(3)-2*margin);
height = max(1,screen(4)-2*margin);
fig.WindowState = 'normal';
fig.Position = [screen(1)+margin screen(2)+margin width height];
end
