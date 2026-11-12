%% DAY 3 : SOLAR ARRAY POWER GENERATION MODEL
% PROJECT :LEO SPACECRAFT ELECTRICAL POWER SYSTEM SIMULATOR
%MODEL : 400 KM CIRCULAR LOW EARTH ORBIT
% ASSUMPTION : IDEAL SUN POINTING SOLAR ARRAY
clc;
clear;
close all;

%% 1 . DEFINE EARHT AND ORBIT PARAMETERS
earth_radius_m = 6371e3;
altitude_m = 400e3;
earth_mu_m3_s2 = 3.986004418e14;

%% 2 . CALUCLATE ORBITAL PARAMETERS
orbital_radius__m = earth_radius_m + altitude_m;
orbital_period_s = 2*pi*sqrt(orbital_radius__m^3/earth_mu_m3_s2);
angular_velocity_radps = sqrt(earth_mu_m3_s2/orbital_radius__m^3);

%% 3 . CALUCLATE ECLLIPSE GEOMENTRY 
eclipse_half_angle_rad = asin(earth_radius_m/ orbital_radius__m);
eclipse_start_angle_rad = pi - eclipse_half_angle_rad;
eclipse_end_angle_rad = pi + eclipse_half_angle_rad;
eclipse_duration_s = 2*eclipse_half_angle_rad / angular_velocity_radps;
sunlight_duration_s = orbital_period_s - eclipse_duration_s;

%% 4 . CREATE THE SIMULATION TIME ARRAY
number_of_orbits = 2;
simulation_duration_s = number_of_orbits*orbital_period_s;
time_step_s = 10;
time_s = 0: time_step_s:simulation_duration_s;
time_min = time_s/60;

%% 5 . CALUCLATE SPACECRAFT ORBITAL POSITION
orbital_angle_rad = mod(angular_velocity_radps* time_s,2*pi);

%% 6 .  DETECT ECIPSE
is_eclipse = (orbital_angle_rad>= eclipse_start_angle_rad)&(orbital_angle_rad<=eclipse_end_angle_rad);

%% 7 . DEFINE SOLAR ARRAY PARAMETERS
solar_irrandiance_W_m2 = 1361;
solar_array_area = 5;
solar_array_efficiency_BOL = 0.28;
spacecraft_load_W = 800;

%%  8 . CALUCLATE SOLAR ARRAY POWER
solar_array_power_BOL_W = solar_irrandiance_W_m2*solar_array_area *solar_array_efficiency_BOL;

%% 9  . CREATE SOLAR TIME PROFILE
solar_power_W = zeros(size(time_s));
solar_power_W(~is_eclipse) = solar_array_power_BOL_W ;

%% 10 . CALUCLATE POWER SURPLUS OR DEFICT 
power_margin_W = solar_power_W - spacecraft_load_W;

%% 11 . CALUCLATE AVERAGE SOLAR OUTPUT- 
average_solar_power_W  = mean(solar_power_W);
%% 12 . DIAPLAY RESULTS
fprintf('\n ===== SOALR ARRAY POWER MODEL====\n');
fprintf('solar irradiance    : %.2f W/m2\n',solar_irrandiance_W_m2);
fprintf('solar array area   :  %.2f m2\n',solar_array_area);
fprintf('solar cell efficiency  : %.2f %%\n',solar_array_efficiency_BOL*100);
fprintf('solar array power   : %.2f W \n',solar_array_power_BOL_W);
fprintf('spacecraft load   : %.2f W \n',spacecraft_load_W);
fprintf('power surplusing sun   : % .2f W\n',solar_array_power_BOL_W - spacecraft_load_W);
fprintf('power deficit in eclipse : %.2f W\n',spacecraft_load_W);
fprintf('Average solar output   : %.2f W\n',average_solar_power_W);

fprintf('\n====DAY 3 CSAMAOTAM ====');
fprintf('\nTHADHASTU');

%% 13 . PLOT SOLAR ARRAY POWER 
figure('Name','day 3 solar array power model');
subplot(2,1,1);
stairs(time_min ,solar_power_W,'LineWidth',1.4);
hold on;
plot(time_min,spacecraft_load_W*ones(size(time_s)),'--','linewidth',1.2);
xlabel('time(minutes)')
ylabel('power(W)');
title('solar array output and spacecraft load');
legend('Solar Array output','spacecraft load ','Location','best');
grid on;
ylim([0 2200]);

%% 14 . PLOT POWER SURPLUS AND DEFICIT 
subplot(2,1,2);
stairs(time_min,power_margin_W,'LineWidth',1.4);
hold on;
plot(time_min,zeros(size(time_s)),'--');
xlabel('time(minutes)');
ylabel('power margin (W)');
legend('power margin','zero-power reference','Location','best');
grid on;

%% 15 . SAVE THE GRAPH IN THE RESULTS FOLDER 
script_folder = fileparts(mfilename('fullpath'));
project_folder = fileparts(script_folder);
results_folder = fullfile(project_folder,'results');
if ~ exist(results_folder,'dir')
        mkdir(results_folder);
end
saveas(gcf,fullfile(results_folder,'day3_solar_power_timeline.png'));
fprintf('\nGraph saved in results folder . \n');


