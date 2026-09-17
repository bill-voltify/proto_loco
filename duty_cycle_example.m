function [t, v_mph] = duty_cycle_example()
% DUTY_CYCLE_EXAMPLE  Placeholder switcher duty cycle: accel, cruise, decel, dwell, reverse.
% Replace with actual yard duty cycle (CSV/import) — this is a stand-in shape only.

t = (0:1:1200)';               % 20 min, 1s steps
v_mph = zeros(size(t));

% accel 0->15mph over 60s
i1 = t<=60;            v_mph(i1) = 15*(t(i1)/60);
% cruise 15mph
i2 = t>60 & t<=300;     v_mph(i2) = 15;
% decel to 0 over 30s (coupling move)
i3 = t>300 & t<=330;    v_mph(i3) = 15*(1-(t(i3)-300)/30);
% dwell (switching cars)
i4 = t>330 & t<=450;    v_mph(i4) = 0;
% reverse accel to -10mph
i5 = t>450 & t<=510;    v_mph(i5) = -10*(t(i5)-450)/60;
% reverse cruise
i6 = t>510 & t<=700;    v_mph(i6) = -10;
% decel to 0
i7 = t>700 & t<=730;    v_mph(i7) = -10*(1-(t(i7)-700)/30);
% dwell
i8 = t>730;             v_mph(i8) = 0;

end
