%read data from file
fid = fopen('slp04annotations.txt', 'r');
line = textscan(fid, '%s%s%s%s%s%s%s%*[^\n]');
fclose(fid);
line{1}(1) = []; % hapus line pertama kalo di file data ada header

total_row = size(line{1});
total_row = total_row(1);
annotation = zeros(total_row, 4);
%{
annotations:
01. hour
02. minute
03. second
04. sleep_state:
    1 = stage 1
    2 = stage 2
    3 = stage 3
    4 = stage 4
    W = Wake
    R = REM
%}
%annotation(find(a==7)) = 10

for i=1:total_row
    time = strsplit(char(line{1}(i)), ':')';
    time_size = size(time);
    count_time = time_size(1);
    
    for j=3:-1:1
        if j == 1 && time_size(1) == 2
            annotation(i, j) = 0;
        else
            annotation(i, j) = str2num(cell2mat(time(count_time)));
        end
        count_time = count_time - 1;
    end
    
    
end