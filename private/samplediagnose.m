function [exitflag,R,Neff,tau] = samplediagnose(K,samples,sampleState,trace,options)
%SAMPLEDIAGNOSE Perform quick-and-dirty diagnosis of convergence.

% Author: Luigi Acerbi

N = size(samples,1);
exitflag = 0;

try        
    
    % Call Simo S�rkk� & Aki Vehtari's PSRF diagnostics function
    warning_orig = warning;
    warning('off','all');
    if K == 1
        [R,Neff,~,~,~,tau] = psrf(samples(1:floor(N/2),:), samples(floor(N/2)+(1:floor(N/2)),:));
    else
        % Split main chain into individual chains
        for k = 1:K; S{k} = samples(1:K:end,:); end
        siz = cellfun(@(X_) size(X_,1), S);
        minsiz = min(siz);
        for k = 1:K; S{k} = S{k}(1:minsiz,:); end
        [R,Neff,~,~,~,tau] = psrf(S{:});        
    end        
    warning(warning_orig);

    % Slice sampler issues
    diagstr = [];
    if isfield(sampleState,'slicecollapsed')
        slicecollapsed = sampleState.slicecollapsed;
        if ~isempty(slicecollapsed) && ...
                slicecollapsed > ceil(N/1000) && ~options.Noise
            diagstr = ['\n * ' num2str(slicecollapsed) ' slice sampling iterations failed (slicing window shrunk back to current point).\n   Something may be wrong with the target function. Set OPTIONS.Noise = 1 if the target function is noisy.'];
            if exitflag == 0; exitflag = -5; end
        end
    end
    
    % Potential reduction scale factor (Rhat)
    if any(R > 1.2)
        diagstr = ['\n * Detected lack of convergence! (max R = ' num2str(max(R),'%.2f') ' >> 1, mean R = ' num2str(mean(R),'%.2f') ').'];
        exitflag = -4;
    elseif any(R > 1.05)
        diagstr = ['\n * Detected probable lack of convergence (max R = ' num2str(max(R),'%.2f') ' > 1, mean R = ' num2str(mean(R),'%.2f') ').'];
        exitflag = -3;
    else
        diagstr = ['\n * No issues with potential reduction scale factor (max R = ' num2str(max(R),'%.2f') ' ~ 1, mean R = ' num2str(mean(R),'%.2f') ').'];
    end
    
    % Effective sample size (ESS)
    if any(Neff < N/10)
        diagstr = [diagstr '\n * Low number of effective samples (min Neff = ' num2str(min(Neff), '%.1f') ...
            ', mean Neff = ' num2str(mean(Neff),'%.1f') ', requested N = ' num2str(N,'%d') ').'];
        if exitflag == 0; exitflag = -1; end
    else
        diagstr = [diagstr '\n * Effective sample size: min Neff = ' num2str(min(Neff), '%.1f') ...
            ', mean Neff = ' num2str(mean(Neff),'%.1f') ', requested N = ' num2str(N,'%d') '.'];        
    end
    
    % Efficiency
    diagstr = [diagstr '\n * Efficiency: ~ ' num2str(min(Neff)/sampleState.funccount(end), '%.2g') ...
        ' effectively independent samples per full function evaluation.'];    
    
    % No problems so far?
    if exitflag == 0; exitflag = 1; end

    if trace > 0 && ~isempty(diagstr)
        fprintf(diagstr);
    end

catch
    warning('Error while computing convergence diagnostics with PSRF.');
    R = NaN;
    Neff = NaN;
    tau = NaN;
end

end