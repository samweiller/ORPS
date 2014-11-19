%% MakeStims Function
%  This function generates a stimuli .mat file organized by category.
%  Written by Sam Weiller, 2013

function makeStims2(numImages)

disp('Please press return and choose the directory with your stim set.');
stimSetDir = uigetdir;

eval(['cd ' num2str(stimSetDir)]);
[zz1 zz2] = unix('ls -d */ | tee dirs.txt');
fileIO = fopen('dirs.txt');
stimDirs = textscan(fileIO, '%s');

numStimSets = size(stimDirs{1},1);
for dirInd = 1:numStimSets
    stimDirs{1}{dirInd} = stimDirs{1}{dirInd}(1:end-1);
end;

fprintf('It looks like you have %d sets of stimuli with the following names:\n', numStimSets)
disp(stimDirs{1});
moveOn = input('Is this correct (y/n)? ', 's');

if moveOn == 'n'
    fprintf('Please check your stim folders and try again.');
    return;
end;

disp('Please indicate the file format of your images:')
disp('1. jpg');
disp('2. png');
disp('3. tiff');
disp('4. gif');
disp('5. bmp');
imgFormat = input('? ');


for set = 1:numStimSets
    eval(['cd ' num2str(stimSetDir) '/' num2str(stimDirs{1}{set})]);
    switch imgFormat
        case 1
            [zz1 zz2] = unix('ls *.jpg | tee filenames.txt');
        case 2
            [zz1 zz2] = unix('ls *.png | tee filenames.txt');
        case 3
            [zz1 zz2] = unix('ls *.tiff | tee filenames.txt');
        case 4
            [zz1 zz2] = unix('ls *.gif | tee filenames.txt');
        case 5
            [zz1 zz2] = unix('ls *.bmp | tee filenames.txt');
    end;
    
    fileIO = fopen('filenames.txt');
    chosenImages = textscan(fileIO, '%s', 'Delimiter', {'\n'});
%     chosenImagesIndex = randsample(size(imgNames{1},1), numImages);
%     for i = 1:size(chosenImagesIndex, 1)
        
%     end;
    
    for imNo = 1:numImages
        fprintf('Reading %s...\n', chosenImages{1}{imNo});
        STIMNAMES{set}{imNo} = chosenImages{1}{imNo};
        STIMS{set}{imNo} = imread(chosenImages{1}{imNo});
    end;
end;

cd /Users/fkamps/Dropbox/Freddy/VNA

fprintf('Stimuli have been imported! Now saving as .MAT file for later use...\n')
save VNAstims.mat STIMS stimDirs STIMNAMES
fprintf('Stimuli successfully saved!\n')



