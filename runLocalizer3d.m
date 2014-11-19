%% FOSS_ET
%  FOSS Localizer with eye tracking.
function [FOSS] = runLocalizer3d(sub, cbl, acq)
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

%% Eyelink Params
ET = 1;
pref_eye = 1; % 0 is left, 1 is right, 2 is both
dummymode = 0;

valid = 0;

while ~valid
    prompt = {'Enter tracker EDF file name (1 to 8 letters or numbers)'};
    dlg_title = 'Create EDF File';
    num_lines = 1;
    def = {'DEMO'};
    answer = inputdlg(prompt, dlg_title, num_lines, def);
    edfFile = answer{1};
    if max(size(edfFile)) <= 8
        valid = 1;
        fprintf('EDFFile: %s\n', edfFile);
    end;
end;


%% PTB Setup
Screen('Preference', 'SkipSyncTests', 2);
[w, rect, xMid, yMid] = startPTB(screenNumber, 1, [128 128 128]);
ifi = Screen('GetFlipInterval', w);
HideCursor;

%% Eyelink Setup

el = EyelinkInitDefaults(w);

if ~EyelinkInit(dummymode)
    fprintf('Eyelink Init Aborted.\n');
    Eyelink('Shutdown');
    return;
end;

[v, vs] = Eyelink('GetTrackerVersion');
fprintf('Running Experiment on a "%s" tracker.\n', vs);


i = Eyelink('Openfile', edfFile);

if i ~=0
    fprintf('Cannot create EDF file "%s"', edffilename);
    Eyelink('Shutdown');
    return;
end;

Eyelink('command', 'add_file_preamble_text "Recorded by EyelinkToolbox. Script by SKW"');

[width, height] = Screen('WindowSize', w);

Eyelink('command', 'screen_pixel_coords = %ld %ld %ld %ld', 0, 0, width-1, height-1);
Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, width-1, height-1);

Eyelink('command', 'calibration_type = HV9');
Eyelink('command', 'saccade_velocity_threshold = 35');
Eyelink('command', 'saccade_acceleration_threshold = 9500');

Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
Eyelink('command', 'file_sample_data = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS');
Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
Eyelink('command', 'link_sample_data = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');

if ( Eyelink('IsConnected') ~= 1 && ~dummymode )
    Eyelink('Shutdown');
    return;
end;

moveOn = 0;

el.backgroundcolour = [128 128 128];
el.foregroundcolour = [0 0 0];

EyelinkDoTrackerSetup(el);

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
Eyelink('Command', 'set_idle_mode');
Eyelink('Command', 'clear_screen 0')

WaitSecs(0.05);  
Eyelink('StartRecording');    
WaitSecs(0.1);

eyeLinkTrial = 1;

expStart = GetSecs;

cpuTimeExpected = expStart;
realTimeExpected = 0;

for blocks = 1:numBlocks
    blockStart = GetSecs;
    timeLogger.block(blocks).blockStart = GetSecs - expStart;
    timeLogger.block(blocks).conditionN = conditionOrder(blocks);
    if conditionOrder(blocks) == 0
        Eyelink('message', 'TRIALID %d', eyeLinkTrial);
        correctionTime = GetSecs - cpuTimeExpected;
        realTimeExpected = realTimeExpected + fixationTime + correctionTime;
        cpuTimeExpected = cpuTimeExpected + fixationTime + correctionTime;
        
        fixate(w);
        Screen('Flip', w, cpuTimeExpected - (ifi/2));
        
        Eyelink('message', 'TRIAL_RESULT 0');
        eyeLinkTrial = eyeLinkTrial + 1;
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
            Eyelink('message', 'TRIALID %d', eyeLinkTrial);
            Eyelink('message', '!V CLEAR 128 128 128');
            Eyelink('command', 'record_status_message "TRIAL %d / %d"', eyeLinkTrial, ((numBlocks-1)/2)*(imagesPerBlock+1));
            WaitSecs(0.05);
            
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
            
            Eyelink('message', 'BEGIN IMAGE PRESENTATION');
            Eyelink('Message', '!V IMGLOAD CENTER ./images/%s %d %d %d %d', STIMNAMES{TRIMAT(imageMatrix(trials), 3)}{TRIMAT(imageMatrix(trials), 2)}, round(width/2), round(height/2), round(stimSize.horizontal), round(stimSize.vertical));
           
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
            
            Eyelink('message', 'BEGIN FIXATION TIME');
            
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
                    Eyelink('message', '!V TRIAL_VAR IMG_NAME %s', STIMNAMES{TRIMAT(imageMatrix(trial), 3)}{TRIMAT(imageMatrix(trial), 2)});
                    
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
            
            switch conditionOrder(blocks)
                case 1
                    Eyelink('message', '!V TRIAL_VAR CONDITION FACE');
                case 2
                    Eyelink('message', '!V TRIAL_VAR CONDITION OBJECT');
                case 3
                    Eyelink('message', '!V TRIAL_VAR CONDITION SCENE');
                case 4
                    Eyelink('message', '!V TRIAL_VAR CONDITION SCRAM');
            end;
            
            Eyelink('message', '!V IAREA RECTANGLE 2 %d %d %d %d IMAGE', width/2-(round(stimSize/2)), height/2-(round(stimSize/2)), width/2+(round(stimSize/2)), height/2+(round(stimSize/2)));
            Eyelink('message', '!V IAREA RECTANGLE 3 %d %d %d %d QUAD1', width/2, height/2-(round(stimSize/2)), width/2+(round(stimSize/2)), height/2);
            Eyelink('message', '!V IAREA RECTANGLE 4 %d %d %d %d QUAD2', width/2-(round(stimSize/2)), height/2-(round(stimSize/2)), width/2, height/2);
            Eyelink('message', '!V IAREA RECTANGLE 5 %d %d %d %d QUAD3', width/2-(round(stimSize/2)), height/2, width/2, height/2+(round(stimSize/2)));
            Eyelink('message', '!V IAREA RECTANGLE 6 %d %d %d %d QUAD4', width/2, height/2, width/2+(round(stimSize/2)), height/2+(round(stimSize/2)));
            Eyelink('message', '!V IAREA RECTANGLE 6 %d %d %d %d QUADC', (width/2)-(round(stimSize/4)), (height/2)-(round(stimSize/4)), (width/2)+(round(stimSize/4)), (height/2)+(round(stimSize/4)));
            
            Eyelink('message', 'TRIAL_RESULT 0');
            WaitSecs(.001);
            eyeLinkTrial = eyeLinkTrial + 1;
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

cov1Filename = sprintf('FOSS%02d_CBL%02d_Acq%02d_Cov1_conStr.txt', sub, cbl, acq);
cov2Filename = sprintf('FOSS%02d_CBL%02d_Acq%02d_Cov2_letter.txt', sub, cbl, acq);
cov3Filename = sprintf('FOSS%02d_CBL%02d_Acq%02d_Cov3_number.txt', sub, cbl, acq);
cov4Filename = sprintf('FOSS%02d_CBL%02d_Acq%02d_Cov4_numStr.txt', sub, cbl, acq);
cov5Filename = sprintf('FOSS%02d_CBL%02d_Acq%02d_Cov5_numWrd.txt', sub, cbl, acq);
cov6Filename = sprintf('FOSS%02d_CBL%02d_Acq%02d_Cov6_object.txt', sub, cbl, acq);
cov7Filename = sprintf('FOSS%02d_CBL%02d_Acq%02d_Cov7_numScr.txt', sub, cbl, acq);
cov8Filename = sprintf('FOSS%02d_CBL%02d_Acq%02d_Cov8_fixatn.txt', sub, cbl, acq);

for block = 1:numBlocks
    temp = [round(timeLogger.block(block).blockStart), round(timeLogger.block(block).blockLength), 1];
    
    if timeLogger.block(block).conditionN == 0
        dlmwrite(cov8Filename, temp, 'delimiter', '\t', '-append');
    else
        eval(sprintf('dlmwrite(cov%dFilename, temp, ''delimiter'', ''\t'', ''-append'');', timeLogger.block(block).conditionN));
    end;
end;

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