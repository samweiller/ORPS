%% PnP Localizer
%  TO DO
%  -Add options flag. (mat file name, screen max or min, etc.)
%  -Add COV maker
%  -print number of voxels?
function [FOSS] = runLocalizer3c(sub, cbl, acq)
%% Start me up
clc
FOSS.curDir = cd;
if ~exist('sub', 'var'); FOSS.subID = input('\nPlease Enter Your Participant Code #: ', 's'); else FOSS.subID = sub; end;
if ~exist('cbl', 'var'); FOSS.cbl =  input('\nPlease Enter The CBL #: ', 's'); else  FOSS.cbl = cbl; end;
if ~exist('acq', 'var'); FOSS.acq =  input('\nPlease Enter The Aquisition #: ', 's'); else  FOSS.acq = acq; end;
PATH = fullfile(FOSS.curDir, sprintf('FOSS_S%d_C%d_A%d.mat', FOSS.subID, FOSS.cbl, FOSS.acq));
save(PATH);
if ~exist(PATH, 'file');
    [Path, File] = uigetfile('*.mat', 'Select .MAT with data');
    PATH = fullfile(Path, File);
end
load(PATH);

pause(.8);
fprintf('Scene Localizer, v3\n');
pause(.7);
fprintf('  Version 3.30\n');
fprintf('  Jun. 3, 2014\n');
pause(.4);
fprintf('Sam Weiller\n');
pause(.5);
clc

%% Control Panel
STIMS = [];

stimuliMatFileName = 'localizerStimuli.mat';

fprintf('Looking for stimuli...\n')
if exist(stimuliMatFileName, 'file')
    load(stimuliMatFileName);
    fprintf('Stimuli loaded!\n');
else
    fprintf('Please run makeStims first.\n');
    return;
end;

designs = [...
    0 1 2 3 4 0 3 1 4 2 0 2 4 1 3 0 4 3 2 1 0;
    0 2 1 4 3 0 1 2 4 3 0 3 4 2 1 0 3 4 1 2 0;
    0 3 4 2 1 0 2 3 1 4 0 4 1 3 2 0 1 2 4 3 0;
    0 4 1 3 2 0 4 2 3 1 0 1 3 2 4 0 2 3 1 4 0;
    ];

fixCovariate = max(max(designs)) + 1; % Defines a non-zero covariate number for fixation covariate files.
numBlocks = max(max(size(designs)));
numStimSets = size(STIMS,2);
imgsPerSet = size(STIMS{1},2);
imagesPerBlock = 20;
numberOfTargets = 2;
fixationTime = 16;
KbName('UnifyKeyNames');
targetKey = KbName('b');
escapeKey = KbName('p');
triggerKey = KbName('t');
screens = Screen('Screens');
screenNumber = max(screens);
screenWidth = 412.75;
viewingDistance = 920.75;
visualAngle = 8;

stimPresentTime = .3;
ISItime = .5;
trialLength = stimPresentTime + ISItime;

UserAns = [];
conditionOrder = designs(cbl, :);

res = Screen('Resolution', screenNumber);
resWidth = res.width;

PPD = tand(.5).*2.*viewingDistance.*(resWidth./screenWidth);
visualAngle = PPD*visualAngle;
stimSize = visualAngle;

%% PTB Setup
Screen('Preference', 'SkipSyncTests', 2);
[w, rect, xMid, yMid] = startPTB(screenNumber, 1, [128 128 128]);
ifi = Screen('GetFlipInterval', w);
HideCursor;

%% Create Stimuli & Preallocate
tex = cell(numStimSets, 1);
ANSMAT = cell(numBlocks, 1);

for set = 1:numStimSets
    for img = 1:imgsPerSet
        %Making the cell array
        tex{set}{img} = Screen('MakeTexture', w, STIMS{set}{img});
    end;
end;

DrawFormattedText(w, 'Waiting for trigger...', 'center', 'center');
Screen('Flip', w);
trigger(triggerKey);
Screen('Flip', w);

%% Main Loop
expStart = GetSecs;

cpuTimeExpected = expStart;
realTimeExpected = 0;

for blocks = 1:numBlocks
    blockStart = GetSecs;
    timeLogger.block(blocks).blockStart = GetSecs - expStart;
    if conditionOrder(blocks) == 0
        correctionTime = GetSecs - cpuTimeExpected;
        realTimeExpected = realTimeExpected + fixationTime + correctionTime;
        cpuTimeExpected = cpuTimeExpected + fixationTime + correctionTime;
        
        fixate(w);
        Screen('Flip', w, cpuTimeExpected - (ifi/2));
    else
        tLstart = GetSecs;
        imageMatrix = randsample(imgsPerSet, imagesPerBlock);
        moveon = 0;
        while moveon ~= 1
            targets = randsample(imagesPerBlock-1, numberOfTargets);
            if abs(targets(1) - targets(2)) > 1
                moveon = 1;
            end;
        end;
        
        for ind = 1:size(targets,1)
            imageMatrix(targets(ind)+1) = imageMatrix(targets(ind)); %plants target for 1-back at a random
        end;
        
        
        for trials = 1:imagesPerBlock
            touch = 0;
            
            timeLogger.block(blocks).trial(trials).start = GetSecs-tLstart;
            loggingIsDone = 0;            
            
            trialStart = GetSecs;
            correctionTime = GetSecs - cpuTimeExpected;
            stimEnd = trialStart + stimPresentTime + correctionTime;
            realTimeExpected = realTimeExpected + trialLength + correctionTime;
            cpuTimeExpected = cpuTimeExpected + trialLength + correctionTime;
            
            
            %Draw cell array
            Screen('DrawTexture', w, tex{conditionOrder(blocks)}{imageMatrix(trials)}, [], [xMid-(stimSize/2) yMid-(stimSize/2) xMid+(stimSize/2) yMid+(stimSize/2)]);
            Screen('Flip', w);
            
            while GetSecs <= stimEnd   %checks for keypress during stim presentation
                [touch, ~, keyCode] = KbCheck(-1);
                if touch && ~keyCode(triggerKey)
                    UserAns = find(keyCode);
                    break;
                end;
            end;
            
            while GetSecs <= stimEnd
                % Wait remaining time
            end;
            
            Screen('Flip', w);
            timeLogger.block(blocks).trial(trials).imageEnd = GetSecs-tLstart;
            
            if touch == 0
                while GetSecs < cpuTimeExpected-.05   %checks for keypress in fixation immediately following stim pres up until next stim pres.
                    [touch, ~, keyCode] = KbCheck(-1);
                    if touch && ~keyCode(triggerKey)
                        UserAns = find(keyCode);
                        break;
                    end;
                end;
            end;
            
            while GetSecs <= cpuTimeExpected
                if ~loggingIsDone
                    ANSMAT{blocks}(trials,1) = conditionOrder(blocks); %condition number
                    ANSMAT{blocks}(trials,2) = imageMatrix(trials); %trial number
                    ANSMAT{blocks}(trials,3) = ~isempty(find(targets == (trials-1), 1)); %is it a target
                    
                    if UserAns == targetKey
                        ANSMAT{blocks}(trials,4) = 1; %did they respond?
                    elseif UserAns == escapeKey;
                        FOSS.ANSMAT = ANSMAT;
                        save(PATH, 'FOSS', 'timeLogger');
                        Screen('CloseAll');
                        return;
                    else
                        ANSMAT{blocks}(trials,4) = 0;
                    end;
                    
                    if ANSMAT{blocks}(trials,3) == ANSMAT{blocks}(trials,4)
                        ANSMAT{blocks}(trials,5) = 1; %correct?
                    else
                        ANSMAT{blocks}(trials,5) = 0;
                    end;
                    
                    UserAns = 0;
                    loggingIsDone = 1;
                end;
            end;
            
            timeLogger.block(blocks).trial(trials).end = GetSecs-tLstart;
            timeLogger.block(blocks).trial(trials).imageLength = timeLogger.block(blocks).trial(trials).imageEnd - timeLogger.block(blocks).trial(trials).start;
            timeLogger.block(blocks).trial(trials).blankLength = timeLogger.block(blocks).trial(trials).end - timeLogger.block(blocks).trial(trials).imageEnd;
            timeLogger.block(blocks).trial(trials).trialLength = timeLogger.block(blocks).trial(trials).end - timeLogger.block(blocks).trial(trials).start;
        end;
    end;
    
    FOSS.ANSMAT = ANSMAT;
    timeLogger.block(blocks).blockLength = GetSecs - blockStart;
    timeLogger.block(blocks).blockEnd = realTimeExpected;
    fprintf('Block Time: %1.4f\n', timeLogger.block(blocks).blockLength);    
    save(PATH, 'FOSS', 'timeLogger');
end;
totalTime = GetSecs - expStart;
fprintf('\n\nTotal Experiment Time: %1.4f\n\n', totalTime);
fixate(w);
Screen('Flip', w);

%% Logging & Cleanup
FOSS.ANSMAT = ANSMAT;
save(PATH, 'FOSS', 'timeLogger');

% Create Covariate Files
% cnt = [1 1 1 1 1];
% 
% for i = 1:numBlocks
%     
%     switch TIME_MAT(i, 1) %condition no
%         case 1 % Faces
%             COVAR{1}(cnt(1), :) = TIME_MAT(i, 2:4);
%             cnt(1) = cnt(1) + 1;
%         case 2 % Objects
%             COVAR{2}(cnt(2), :) = TIME_MAT(i, 2:4);
%             cnt(2) = cnt(2) + 1;
%         case 3 % ObjectsScram
%             COVAR{3}(cnt(3), :) = TIME_MAT(i, 2:4);
%             cnt(3) = cnt(3) + 1;
%         case 4 % Places
%             COVAR{4}(cnt(4), :) = TIME_MAT(i, 2:4);
%             cnt(4) = cnt(4) + 1;
%         case 5 % Fixation
%             COVAR{5}(cnt(5), :) = TIME_MAT(i, 2:4);
%             cnt(5) = cnt(5) + 1;
%     end;
% end
% 
% for j = 1:5
%     dlmwrite(sprintf('FOSS_Sub0%d_Run%d_Cov%d.txt', sub, cbl, j), COVAR{j}, 'delimiter', '\t', 'precision', 4);
% end;

%% Shutdown Procedures
ShowCursor;
Screen('CloseAll');

function [w, rect, xc, yc] = startPTB(screenNumber, oGl, color)

if nargin == 0
    oGl = 0;
    color = [0 0 0];
elseif nargin == 1;
    color = [0 0 0];
end;

[w, rect] = Screen('OpenWindow', screenNumber, color);
xc = rect(3)/2;
yc = rect(4)/2;

if oGl == 1
    AssertOpenGL;
    Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, [1 1 1 1]);
end;

function fixate(w)
Screen('TextSize', w, 40);
DrawFormattedText(w, '+', 'center', 'center', [200 200 200]);
Screen('TextSize', w, 25);
Screen('Flip', w);

function trigger(triggerKey)
KbName('UnifyKeyNames');

go = 0;
while go == 0
    [touch, ~, keyCode] = KbCheck(-1);
    WaitSecs(.0001);
    if touch && keyCode(triggerKey)
        go = 1;
    end;
end;