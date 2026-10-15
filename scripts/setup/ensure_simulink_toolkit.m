function ensure_simulink_toolkit()
%ENSURE_SIMULINK_TOOLKIT Initialize the installed SATK in this MATLAB session.
% The MCP server exposes tool names even before their MATLAB paths are added.
if ~isempty(which('model_edit')) && ~isempty(which('model_read')) && ...
        ~isempty(which('library.settingsLookup'))
    return
end
toolkit = fullfile(getenv('USERPROFILE'),'.matlab','agentic-toolkits','simulink');
assert(isfile(fullfile(toolkit,'satk_initialize.p')) || ...
    isfile(fullfile(toolkit,'satk_initialize.m')), ...
    'official:MissingSATK','Installed Simulink Agentic Toolkit not found: %s',toolkit);
addpath(toolkit);
satk_initialize;
assert(~isempty(which('model_edit')) && ~isempty(which('model_read')) && ...
    ~isempty(which('library.settingsLookup')), ...
    'official:SATKInitialization','Simulink Agentic Toolkit initialization did not expose the required tools.');
end
