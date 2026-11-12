%%Day 2: ORBITAL TIMELINE AND ECLIPSE MODEL
% PROJECT: LEO SPACECRAFT AND ELECTRICAL POWER SYSTEM SIMULATION
% MODEL : Earth shadow with cylindrical earth shadow
% ASSUMPTION : Sun lies in the orbital plane(beta = 0)

clc;
clear;
close all;

%1 . DEFINE CONSTANTS
earth_radius_m = 6371e3;
altitude_m = 400e3;
earth_mu_m3_s2 = 3.986004418e14;

% 2 . CALUCLATE ORBITAL PARAMETER
orbital_radius_m =  earth_radius_m + altitude_m;
orbital_period_s = 2*pi*sqrt(orbital_radius_m^3/earth_mu_m3_s2);
orbital_period_min = orbital_period_s / 60 ;
angular_veloctiy_radps = sqrt(earth_mu_m3_s2/orbital_radius_m^3);

% 3 . CALUCLATE ECLIPSE GEOMENTRY
eclipse_half_angle_rad = asin(earth_radius_m/orbital_radius_m);
eclipse_start_angle_rad = pi - eclipse_half_angle_rad;
eclipse_end_angle_rad = pi + eclipse_half_angle_rad;

%4 . CALUCLATE ECLIPSE AND SUNLIGHT DURATION 
eclipse_duration_s = 2*eclipse_half_angle_rad / angular_veloctiy_radps;
sunlight_duration_s = orbital_period_s - eclipse_duration_s;
eclipse_duration_min = eclipse_duration_s/60;
sunlight_duration_min = sunlight_duration_s/60;
eclipse_fraction_percent = (eclipse_duration_s/orbital_period_s)*100;

%5. CREATE AN ARRAY FOR OTHER TWO ORBITS
number_of_orbits = 2;
simulation_duration_s = number_of_orbits*orbital_period_s;
time_step_s = 10;
time_s = 0: time_step_s:simulation_duration_s;

%6 . CALUCLATE ORBITAL ANGLE 
orbital_angle_rad = mod(angular_veloctiy_radps* time_s,2*pi);

%7. DETECT ECIPSE
is_eclipse = (orbital_angle_rad>= eclipse_start_angle_rad)&(orbital_angle_rad<=eclipse_end_angle_rad);

% 8 . CALUCLATE ECLIPSE ENTRY AND EXIT 
first_eclipse_entry_s = eclipse_start_angle_rad/angular_veloctiy_radps;
first_eclipse_exit_s = eclipse_end_angle_rad/angular_veloctiy_radps;

% 9 . DIAPLAY RESULTS
fprintf('\n ====== LEO ORBITAL ECLIPSE MODEL ======\n');
fprintf('orbital period : %2f minutes\n',orbital_period_s/60);
fprintf('eclipse duration: %2f minutes\n',eclipse_duration_min);
fprintf('Sun duration : %2f minutes\n',sunlight_duration_min);
fprintf('eclipse_percetage : %2f %%\n',eclipse_fraction_percent);
fprintf('eclipse entry : %2f minutes\n',first_eclipse_entry_s/60);
fprintf('eclipse exit   : %2f minutes\n',first_eclipse_exit_s/60);

% 10 . PLOT ORBITAL ANGLE
figure('name','LEO ORBITAL TIMELINE');
subplot(2,1,1);
plot(time_s/60,rad2deg(orbital_angle_rad),'linewidth',1.5);
xlabel('time(minutes)');
ylabel('orbital angle(degrees)');
title('spacecraft orbital angular position');
grid on;

%. 11. PLOT SUNLIGHT AND ECLLIPSE
subplot(2,1,2);
stairs(time_s/60,double(is_eclipse),'linewidth',1.5);
xlabel('time(minutes)');
ylabel('lighting cnditions');
title('SUNLIGHT AND EARTH ECLIPSE TIMELINE');
ylim([-0.1 1.1]);
yticks([0 1]);
yticklabels({'sunlight ','eclipse'});
grid on;

%DAY 2 SAMAPTAM 
fprintf('\n ========TADHASTHU======');
