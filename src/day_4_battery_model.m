%% DAY 4 : SPACECRAFT BATTERY STATE OF CHARGE MODEL 
% PROJECT : LEO SPACECRAFT ELECTRICAL POWER SYSTEM SIMULATOR
% MODEL : 400KM CIRCULAR LEO 
% BATTERY MODEL : SIMPLIFIED ENERGY BASED MODEL

clc;
clear;
close all;

%% 1 . DEFINE EARHT AND ORBIT PARAMETERS
earth_radius_m = 6371e3;
altitude_m = 400e3;
earth_mu_m3_s2 = 3.986004418e14;
orbital_radius__m = earth_radius_m + altitude_m;
orbital_period_s = 2*pi*sqrt(orbital_radius__m^3/earth_mu_m3_s2);
angular_velocity_radps = sqrt(earth_mu_m3_s2/orbital_radius__m^3);

%% 2 . CALUCLATE ECLLIPSE GEOMENTRY 
eclipse_half_angle_rad = asin(earth_radius_m/ orbital_radius__m);
eclipse_start_angle_rad = pi - eclipse_half_angle_rad;
eclipse_end_angle_rad = pi + eclipse_half_angle_rad;
eclipse_duration_s = 2*eclipse_half_angle_rad / angular_velocity_radps;
sunlight_duration_s = orbital_period_s - eclipse_duration_s;

%% 3 . DEFINE SOLAR ARRAY PARAMETERS
solar_irrandiance_W_m2 = 1361;
solar_array_area = 5;
solar_array_efficiency_BOL = 0.28;
spacecraft_load_W = 800;
solar_array_power_w = solar_irrandiance_W_m2*solar_array_area*solar_array_efficiency_BOL;

%% 4 . BATTERY PARAMETERS
battery_capacity_Wh = 1000;
initial_soc_percent = 100;
minimun_soc_percent = 20;
charging_efficiency = 0.95;
discharging_efficiency = 0.95;
initial_battery_energy_Wh = battery_capacity_Wh*initial_soc_percent/ 100;
maximun_battery_energy_Wh = battery_capacity_Wh;
minimum_battery_energy_Wh =  battery_capacity_Wh * minimun_soc_percent /100; 

%% 5 . SIMULATION TIME
number_of_orbits = 2;
simulation_duration_s = number_of_orbits*orbital_period_s;
time_step_s = 10;
time_s = 0: time_step_s:simulation_duration_s;
time_min = time_s/60;
delta_time_h = time_step_s / 3600;

%% 6 . CALUCLATE ORBITAL ANGLE
orbital_angle_rad = mod(angular_velocity_radps* time_s,2*pi);

%% 7 .  DETECT ECIPSE
is_eclipse = (orbital_angle_rad>= eclipse_start_angle_rad)&(orbital_angle_rad<=eclipse_end_angle_rad);

%% 8 . CALUCLATE SOLAR ARRAY POWER AT EACH STEP 
solar_power_w = zeros(size(time_s));
solar_power_w(~is_eclipse) =solar_array_power_w;

%% 9 . INITIALIZE BATTERY VARIABLES
number_of_samples = numel(time_s);
battery_energy_Wh = zeros(size(time_s));
battery_soc_percent = zeros(size(time_s));
batter_energy_change_Wh = zeros(size(time_s));
battery_energy_Wh(1) = initial_battery_energy_Wh;
battery_soc_percent(1) = initial_soc_percent ;

%% 11 . SIMULATE BATTERY ENERGY FLOW
for k = 1 :number_of_samples-1
    if is_eclipse(k)
 %during sunlight,solar surplus can charge the battery 
 energy_discharged_Wh = (spacecraft_load_W / discharging_efficiency)* delta_time_h;
 proposed_energy_Wh = battery_energy_Wh(k) - energy_discharged_Wh ;
    else
        %during sunlight ,solar surplus can charge the battery
        available_surplus_W = max(solar_power_w(k) - spacecraft_load_W , 0);
        energy_charged_Wh = available_surplus_W * charging_efficiency * delta_time_h ; 
        proposed_energy_Wh = battery_energy_Wh(k) + energy_charged_Wh ; 
    end
    %enforce minimum and maximum bATTERY ENERGY 
    battery_energy_Wh(k+1 ) = min (max(proposed_energy_Wh , minimum_battery_energy_Wh),maximun_battery_energy_Wh);
    %caluclate the next battery stage of charge 
    battery_soc_percent(k+1) = (battery_energy_Wh(k+1)/battery_capacity_Wh)* 100 ;
    %record the actual stored energy change
    batter_energy_change_Wh(k+1) = battery_energy_Wh(k+1) - battery_energy_Wh(k);
end

%% 11 . CALUCLATE BATTERY PERFORMANCE
minimum_observed_soc = min(battery_soc_percent);
maximum_observed_soc = max(battery_soc_percent);
final_soc_percent = battery_soc_percent(end);

%% 12 . DISPLAY RESULTS
fprintf('\n====SPACECRAFT ENERGY MODEL====\n');
fprintf('battery capacity   : %.2f Wh\n',battery_capacity_Wh);
fprintf('initial_batery energy   : %.2f Wh\n',initial_battery_energy_Wh);
fprintf('minimum energy allowed   : %.2f Wh\n',minimum_battery_energy_Wh);
fprintf('charging efficiency   : %.2f %% \n',charging_efficiency*100);
fprintf('discharging efficiency   :%.2f %% \n',discharging_efficiency*100);
fprintf('eclipse duration   : %.2f minutes \n',eclipse_duration_s/60);
fprintf('sunlight duration   : %.2f minutes \n',sunlight_duration_s);
fprintf('minimum obseved soc   : %.2f %%\n',minimum_observed_soc);
fprintf('maximum observed soc   : %.2f %% \n',maximum_observed_soc);
fprintf('final battery soc   : %.2f %%\n',final_soc_percent);
fprintf('\n====DAY 4 SAMAPTAM====');
fprintf('THADHASTHU');

%% 13 . PLOT BATTERY STATE OF CHARGE 
figure('Name','day 4 battery simulation');
subplot(3,1,1);
hold on ;
yline(minimun_soc_percent,'--','minimum permitter soc');
yline(100 ,'--','maximum soc');
xlabel('Time(minutes)');
ylabel('soc(%)');
title('battery state of charge ');
ylim([0 105]);
grid on;

%% 14 . PLOT THE BATTERY STORED ENERGY

subplot(3,1,2)
plot(time_min,battery_energy_Wh,'LineWidth',1.4);
hold on;
yline(minimum_battery_energy_Wh,'LineWidth',1.4);
hold on ; 
yline(minimum_battery_energy_Wh,'--','minimum battery energy');
yline(maximun_battery_energy_Wh,'--','maximum battery energy');
xlabel('time(minutes)');
ylabel('stored energy(Wh)');
title('BATTERY STORED ENERGY');
grid on;

%% 15 . PLOT SOLAR ARRAY 
subplot(3,1,3);
stairs(time_min ,solar_power_w,'LineWidth',1.3);
xlabel('time(minutes)')
ylabel('power(W)');
title('solar array output POWER PROFILE');
grid on;

%% 16 . SAVE RESULTS
script_folder = fileparts(mfilename('fullpath'));
project_folder = fileparts(script_folder);
results_folder = fullfile(project_folder,'results');

if ~exist(results_folder,'dir')
    mkdir(results_folder);
end
saveas(gcf,fullfile(results_folder,'day4_battery_simulation.png'));
save(fullfile('day4_battery_data.mat'),'time_s','battery_energy_Wh','battery_soc_percent','solar_power_w','is_eclipse');
fprintf('\n BATTERY GRAPH AND SIMULATION DATA SAVED ,\n');