function [ x_tr,y_tr, pred_multi, y_te, speed_te, acc_nosemi_novoting, acc_nosemi_voting, acc_semi_novoting, acc_semi_voting , confi, pred_table] = run_svm(num_trace_per, trace_random, ind_speed_tr,  ind_speed_te, semi_layer, x_old, y_old)
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here

load steps_10p_8s.mat

i1 = find(speedIDLabel==1);
i2 = find(speedIDLabel==2);
i3 = find(speedIDLabel==3);
i4 = find(speedIDLabel==4);
i5 = find(speedIDLabel==5);
i6 = find(speedIDLabel==6);
i7 = find(speedIDLabel==7);
i8 = find(speedIDLabel==8);

speedIDLabel(i1) = 4;
speedIDLabel(i2) = 5;
speedIDLabel(i3) = 6;
speedIDLabel(i4) = 7;
speedIDLabel(i5) = 3;
speedIDLabel(i6) = 2;
speedIDLabel(i7) = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ind_trace_tr = trace_random(1:6);
ind_trace_te = trace_random(7:10);

% ind_speed_tr = [4];
% ind_speed_te = [3 5];

% ind_speed_tr = [3 4 5];
% ind_speed_te = [1 2 6 7];

using_speed_feature = 1;
using_smart_semi = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% training and test data generation

x_tr = [];
x_te = [];

y_tr = [];
y_te = [];

for i = ind_trace_tr
    
    ind_select = find(traceIDLabel==i);
    speed_select = [];
    for j = ind_speed_tr    
        speed_select = [speed_select; find(speedIDLabel==j)];
    end
    both_select = intersect(ind_select,speed_select);
    if using_speed_feature
        x_tr = [x_tr; stepInfoAll(both_select,5) stepPattern(both_select,:)];
    else
        x_tr = [x_tr; stepPattern(both_select,:)];
    end
    y_tr = [y_tr; personIDLabel(both_select,:)];
    
end

if semi_layer == 3
    y_tr = y_old;
    x_tr = x_old;
end
speed_te =[];

for i = ind_trace_te
    ind_select = find(traceIDLabel==i);
    speed_select = [];
   
    for j = ind_speed_te
        speed_select = [speed_select; find(speedIDLabel==j)];
    end
    both_select = intersect(ind_select,speed_select);
    
    if using_speed_feature
        
        x_te = [x_te; stepInfoAll(both_select,5) stepPattern(both_select,:)];
    else
        x_te = [x_te; stepPattern(both_select,:)];
    end
    y_te = [y_te; personIDLabel(both_select,:)];
    speed_te = [speed_te; speedIDLabel(both_select)];
    
end



if ~isempty(num_trace_per)
    
    num_user = unique(y_te);
    
    ind_remove = [];
    for n = num_user'
        tmp = find(y_te==n);
        num_trace = size(tmp,1)/7;
        trace_sub = randsample(num_trace,num_trace-num_trace_per(n));
        ind_start = (trace_sub-1)*7+1;
        ind_end = trace_sub*7;
        for i = 1:size(ind_start,1)
            ind_remove = [ind_remove tmp(ind_start(i):ind_end(i))'];
        end
    end
    
    if semi_layer == 3
        tag_4 = ones(size(speed_te));
        tag_4(ind_remove) = 0;
        tag_4(speed_te ~= 4) = [];
        save('tag_4.mat','tag_4');
    end
    
    x_te(ind_remove,:) = [];
    y_te(ind_remove,:) = [];
    speed_te(ind_remove,:) = [];
    
    
%     tag_4 = zeros(size(speed_te));
%     tag_4(speed == 4) = 1;
    
end

if semi_layer == 3
    load('tmp.mat')
    y_te = [y_te; y_te_old];
    x_te = [x_te; x_te_old];
    speed_te = [speed_te; speed_te_old];
end

if semi_layer == 2
   system('rm tmp.mat');
   x_te_old = x_te;
   y_te_old = y_te;
   speed_te_old = speed_te;
   save('tmp.mat','x_te_old','y_te_old','speed_te_old');
end
    


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% training and test data scaling to [0 1]

num_dim = size(x_tr,2);

x_tr_scale = zeros(size(x_tr));
x_te_scale = zeros(size(x_te));

for d = 1:num_dim
    up = max(x_tr(:,d));
    low = min(x_tr(:,d));
    
    
    x_tr_scale(:,d) = (x_tr(:,d)-low)/(up-low);
    x_te_scale(:,d) = (x_te(:,d)-low)/(up-low);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% evaluated by libsvm

m = svmtrain(y_tr, sparse(x_tr_scale), '-c 16 -g 1 -b 1 -q');
[y_pred, acc, confi] = svmpredict(y_te, sparse(x_te_scale), m,'-b 1');

acc_nosemi_novoting = sum(y_pred==y_te)/size(y_pred,1);

num_trace = size(y_pred,1)/7;

y_conf = zeros(size(y_pred));

for i = 1:num_trace
    tmp = y_pred(7*(i-1)+1:7*i);
    y_pred(7*(i-1)+1:7*i) = mode(tmp);
    y_conf(7*(i-1)+1:7*i) = sum(tmp== mode(tmp));
end

acc_nosemi_voting = sum(y_pred==y_te)/size(y_pred,1);

conftable1 = confusionmat(y_te, y_pred);

if semi_layer == 1
    pred_multi = y_pred;
    acc_semi_novoting=acc_nosemi_novoting;
    acc_semi_voting=acc_nosemi_voting;
    pred_table = [];
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% writing training and test data into files, input to libsvm

libsvmwrite('train.svm', y_tr, sparse(x_tr_scale));
libsvmwrite('test.svm', y_te, sparse(x_te_scale));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% writing training and test data into files, input to svmlight
for i = 1:10
    for j = i+1:10
        ind_pos = find(y_tr==i);
        ind_neg = find(y_tr==j);
        
        x_pos = x_tr_scale(ind_pos,:);
       
        y_pos = ones(size(y_tr(ind_pos,:)));
        
        x_neg = x_tr_scale(ind_neg,:);
        y_neg = -1*ones(size(y_tr(ind_neg,:)));
        
        libsvmwrite(['train' num2str(i) '_' num2str(j) '.svm'], [y_pos; y_neg], sparse([x_pos; x_neg]));
        
        if using_smart_semi
            y_add = union(find(y_pred==i), find(y_pred==j));
            y_add = setdiff(y_add,find(y_conf<=2));
            x_add = x_te_scale(y_add,:);
            
            y_semi = [y_pos; y_neg; zeros(size(y_add))];
            x_semi = [x_pos; x_neg; x_add];
        else
            y_semi = [y_pos; y_neg; zeros(size(y_te))];
            x_semi = [x_pos; x_neg; x_te_scale];
        end
        
        libsvmwrite(['train_semi' num2str(i) '_' num2str(j) '.svm'], y_semi, sparse(x_semi));
        
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% evaluated by svmlight, no semi supervised learning, should generate the
% same results as libsvm does

options = svmlopt('ExecPath', '.');
options.Kernel = 2;
options.C = 16;
options.KernelParam=1;
options.Verbosity =0;

pred_table = [];

for i = 1:10
    for j = i+1:10
        
        svm_learn(options, ['train' num2str(i) '_' num2str(j) '.svm'], 'model');
        svm_classify(options, 'test.svm', 'model', ...
            'predictions');
        
        pred = load('predictions');
        pred(pred>=0) = i;
        pred(pred<0) = j;
        
        %        num_trace = size(pred,1)/7;
        %
        %        for k = 1:num_trace
        %            tmp = pred(7*(k-1)+1:7*k);
        %            pred(7*(k-1)+1:7*k) = mode(tmp);
        %        end
        
        %         for k = 1:num_trace
        %             tmp = pred(7*(k-1)+1:7*k);
        %             if sum(tmp) >=0
        %                 pred(7*(k-1)+1:7*k) = i;
        %             else
        %                 pred(7*(k-1)+1:7*k) = j;
        %             end
        %         end
        
               
        pred_table = [pred_table pred];
    end
end

pred_multi = mode(pred_table,2);
size(find(y_te == pred_multi),1)/size(y_te,1);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% evaluated by svmlight, with semi supervised learning


pred_table = [];

for i = 1:10
    for j = i+1:10
        [i j]
        
        svm_learn(options, ['train_semi' num2str(i) '_' num2str(j) '.svm'], 'model');
        svm_classify(options, 'test.svm', 'model', ...
            'predictions');
        
        pred = load('predictions');
        pred(pred>=0) = i;
        pred(pred<0) = j;
        pred_table = [pred_table pred];
    end
end

pred_multi = mode(pred_table,2);
acc_semi_novoting = size(find(y_te == pred_multi),1)/size(y_te,1);


num_trace = size(pred_multi,1)/7;
y_conf = zeros(size(pred_multi));

for i = 1:num_trace
    tmp = pred_multi(7*(i-1)+1:7*i);
    pred_multi(7*(i-1)+1:7*i) = mode(tmp);
    y_conf(7*(i-1)+1:7*i) = sum(tmp== mode(tmp));
end

acc_semi_voting = sum(pred_multi==y_te)/size(pred_multi,1);

conftable2 = confusionmat(y_te, pred_multi);

system('rm *.svm model predictions trans_predictions');

if semi_layer == 2
    x_tr = [x_tr; x_te(y_conf>4,:) ];
    y_tr = [y_tr; pred_multi(y_conf>4)];
end

end

