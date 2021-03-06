% PREPROCESSDATA2
% Creates a data structure from many data files and preprocesses it to make
% it ready for wavelet analysis
% Updated: 14-Mar-2014 19:57:52
% Author: AP

%% NOTES
% 1) First run 'comparedata.m' to load slightly processed .abf files into
%    matlab. Allow loading multiples files at once.

%% Extracting Basic File Information
fNames = fieldnames(dataStruct); % Converting to 'char' type variable for ease of size indexing
nFiles = size(char(fNames),1);

%% Minor Options
stopband =[58 62];
denoise = 'y'; % 'y' = removes 60Hz by stopbanding b/w values specified in "stopband"; 'n' = no fitering;
threshdenoising ='n'; %%%% 'y' = gives the option of setting threshold for artifact truncation; 'n' =  no option;

peakStringency = 1;
yShift = 25;

%% Checking Sampling Interval Consistency
sichck = diff(samplingInts); 
if any(sichck ~= 0) % Given the code in createdatastructure.m, I am not sure that this will ever be true.
    errordlg('Signals Sampled at Different Intervals!')
    break
else
    samplingInt = samplingInts(1);
end

%% Comparing Signal Lengths to Determine the Smallest Permissible Common Signal Length
minMat=[]; maxMat =[]; loopCounter = 0;

for fileNum = 1:nFiles
    data = dataStruct.(fNames{fileNum,:});
    timeAxis = timeAxisStruct.(fNames{fileNum,:});
    if loopCounter < 1 % This is to prevent asking for artifact detection mode repeatedly by applying the first detection mode to all the files
        [data,timeAxis,tStimArts,selection] = artifactalign(data,timeAxis);
    else
        [data,timeAxis] = artifactalign(data,timeAxis,selection);
    end
    eval(['data' num2str(fileNum) '= data;']);
    eval(['time' num2str(fileNum) '= timeAxis;']);
    
    minMat =[minMat; eval(['time' num2str(fileNum) '(1);'])];
    maxMat =[maxMat; eval(['time' num2str(fileNum) '(end);'])];
    loopCounter = loopCounter+1;
end


%% Setting the Default Values for Processing Parameters to Last Stored Values

if ~exist('ch')
    ch = ['1 2 3 4'];
end

if ~exist('hpf')
      hpf = 50;
end

if ~exist('lpf')
     lpf = 2;
end
if ~exist('firstCommonTime')
    firstCommonTime = max(minMat); % Starting point for common time vector
end

if ~exist('lastCommonTime')
   lastCommonTime = min(maxMat); % End point for common time vector
end

if ~exist('freqRange')
   freqRange = [0.1 4]; 
end

if ~exist('stringency')
   stringency = 1; 
end

if ~exist('isoThresh')
   isoThresh = 0.5; 
end

if ~exist('phaseType')
   phaseType = 'All'; 
end

if ~exist('traceType')
   traceType = 'Smooth'; 
end

%% Inputting Processing Paramters
maxFr = floor(0.5*(1/samplingInt));
minFr = 2*(1/(min(maxMat)-max(minMat)));
trPrompt = ['Time Range (in sec): Permissible Range = [' num2str(max(minMat)) '    '  num2str(min(maxMat)) ' ]'];
frPrompt =  ['Freq Range (in Hz): Permissible Range = [' num2str(minFr) '    '  num2str(maxFr) ' ]'];
prompts = {'Channel Pairs to Analyze', 'Highpass Before Rectification (If < 20, no rectification)',...
    'Lowpass after Rectification', trPrompt, frPrompt, 'Statistical Stringency (1 = 95% CI, 2 > 95% CI )',...
    'Isoline Threshold (Threshold for Contour Line Plotted on the Avg XW Spectrum Such That Half the Power is Below this Line)',...
    'Phase Filtering ("Alt" = Alternation, "Synch" = Only Synchronous, "All" = No Phase Filtering)'...
    'Trace type for plotting ("Raw" or "Smooth")'};
dlgTitle = 'Processing Parameters';
numLines = 1;
defaults = {num2str(ch),num2str(hpf),num2str(lpf),num2str([max(minMat) min(maxMat)]),...
    num2str(freqRange),num2str(stringency),num2str(isoThresh), phaseType,traceType};
answers = inputdlg(prompts,dlgTitle,numLines,defaults);

[ch,hpf,lpf] = deal(str2num(answers{1}),str2num(answers{2}),str2num(answers{3}));
[timeRange,freqRange,stringency,isoThresh] = deal(str2num(answers{4}),str2num(answers{5}),str2num(answers{6}),str2num(answers{7}));
[phaseType,traceType] = deal(answers{8},answers{9});

%%% Channel Number Check
if numel(ch)<2
    errordlg('Select at least two channels to compare! Enter channel number twice for autowavelet')
    break
end

if (max(minMat)-timeRange(1))> samplingInt
    error_msg = {'Time range out of bounds! First value of the variable "timeRange" must at least equal' num2str(max(minMat))};
    errordlg(error_msg,'Time Range Out of Bounds!')
    break
elseif (timeRange(2)-min(maxMat))> samplingInt;
    error_msg = {'Time range out of bounds! Second value of the variable "timeRange" cannot exceed' num2str(min(maxMat))};
    errordlg(error_msg,'Time Range Out of Bounds!')
    break
else
    firstCommonTime = timeRange(1);
    lastCommonTime = timeRange(end);
end

time = firstCommonTime:samplingInt:lastCommonTime-10*samplingInt; %%% Creates a common time vector. Subtracting a few sampling
%%% intervals is important for eliminating certain errors that may occur
%%% because of unequal sampling of all the data files
lenTime =length(time);


%% Truncating Data to Common Time Portion
artChk = questdlg('Auto-remove Stimulus Artifacts?');
for fileNum = 1:nFiles
    [fpt,lpt] = deal([]);
    fstr = num2str(fileNum);
    eval(['blah = time' fstr ';']);
    dtime = diff(time);
    if any(dtime<=0)
        errordlg('Time Axis Vector Inconsistent: Please Make Sure Time Axis in Each File Has Evenly Spaced Ascending Values;')
    end
%     eval(['fpt = min(find(time' fstr '>= firstCommonTime));'])
%     eval(['fpt = find(time' fstr '>= firstCommonTime,1);']);
    eval(['fpt = find(blah >= firstCommonTime,1);']);
    lpt = fpt + lenTime;
%     eval(['lpt = min(find(time' fstr '>= lastCommonTime));'])
    commonPts = fpt:lpt;
    lenDiff = length(time) - length(commonPts);
    lpt = lpt+lenDiff;
    commonPts = fpt:lpt;
    eval(['data' fstr '= data' fstr '(commonPts,ch);']);
    %       eval(['temp' fstr ' = [];'])
    %       eval(['signal' fstr ' = [];'])
    eval(['temp' fstr ' = chebfilt(data' fstr ',samplingInt,hpf,''high'');']);
    
    if strcmpi(artChk,'yes')
        eval(['temp' fstr ' = autoartremove(temp' fstr ',time);']);
    end
    
    %%%% Filtfilt.m Error Message
    blah = eval(['temp' fstr ';']);
    if any(isnan(blah(:)))
        errordlg('Signal Filtering Error! Please re-specify the time range')
    end
    
    if lower(threshdenoising) == 'y';
        eval(['temp' fstr ' = chebfilt(overthreshremove(temp' fstr...
            ',time),samplingInt,hpf,''high'');']); % Manually chops
        %         % ... off stim artifacts that were not properly removed.
    end
        %%%% Filtfilt.m Error Message
        blah = eval(['temp' fstr ';']);
        if any(isnan(blah(:)))
            errordlg('Signal Filtering Error! Please re-specify the time range')
        end
        
        if denoise =='y'
            eval(['temp' fstr ' = double(temp' fstr ');']);
            eval(['temp' fstr '=chebfilt(temp' fstr...
                ',samplingInt,stopband,''stop'');']) %%%%% Stopbands
            %%%% Filtfilt.m Error Message
            blah = eval(['temp' fstr ';']);
            if any(isnan(blah(:)))
                errordlg('Signal Filtering Error! Please re-specify the time range')
            end
        end
        
        eval(['signal' fstr '=temp' fstr ';'])
        %%%% Filtfilt.m Error Message
        blah = eval(['temp' fstr ';']);
        if any(isnan(blah(:)))
            errordlg('Signal Filtering Error! Please re-specify the time range')
        end
        
        if hpf >= 20 % Rectification only when signal is highpassed over 20Hz
            eval(['f = signal' fstr '<0;'])
            eval(['signal' fstr '(f)=0;'])
        end
        
        eval(['signal' fstr '=chebfilt(signal' fstr...
            ',samplingInt,lpf,''low'');']) %%%%% Lowpasses
        %%%% Filtfilt.m Error Message
        blah = eval(['signal' fstr ';']);
        if any(isnan(blah(:)))
            errordlg('Signal Filtering Error! Please re-specify the time range')
        end  
end

%% Choice of Removing Light Artifacts

% ques = questdlg('Automatically remove light artifacts?','LIGHT ARTIFACT REMOVAL','Yes','No','No');
% if strcmpi(ques,'yes')
%     dataStruct_mod = slowartifactremove(dataStruct,samplingInt);
% else
%     dataStruct_mod = dataStruct;
% end

%% Running Follow Up Code
% xwplotmd