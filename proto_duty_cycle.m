function D = proto_duty_cycle()
bp = [ ...
%   t      mph  P_chg   moving charging
    0      0    0       0      0
    20     0    0       0      0
    80     10   0       1      0
    260    10   0       1      0
    320    0    0       1      0
    440    0    0       0      0
    470    5    0       1      0
    590    5    0       1      0
    620    0    0       1      0
    700    0    0       0      0
    705    0    2.25e6  0      1
    1300   0    2.25e6  0      1
    1305   0    0       0      0
    1360   0    0       0      0];
t = (0:0.5:bp(end,1))';
mph = interp1(bp(:,1), bp(:,2), t, 'linear');
pchg = interp1(bp(:,1), bp(:,3), t, 'linear');
moving = interp1(bp(:,1), bp(:,4), t, 'previous');
charging = interp1(bp(:,1), bp(:,5), t, 'previous');
grade = zeros(size(t));
paux = 30e3 + 42e3*moving + 60e3*charging;
en = double(t >= 2);
D.U = [t mph grade paux pchg en];
D.t_end = bp(end,1);
end
