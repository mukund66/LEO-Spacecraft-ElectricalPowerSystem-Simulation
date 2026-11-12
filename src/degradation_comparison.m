%% 5 : SOLAR ARRAY DEGRADATION COMPARISON
% PROJECT : LEO SPACECRAFT ELECTRICAL POWER SYSTEM SIMULATION
% COMPARE BEGINNING OF LIFE (BOL) AND END OF LIFE (EOL)
% EOL CONDITION : 5 YEARS AT 2% COMPOUND ANNUAL DEGRADATION
%SIMULATION : TWO ORBITAL PERIODS


clc;
clear;
close all;
%% 1 . DEFINE CONSTANTS
earth_radius_m = 6371e3;
altitude_m = 400e3;
earth_mu_m3_s2 = 3.986004418e14;
orbital_radius_m =  earth_radius_m + altitude_m;
orbital_period_s = 2*pi*sqrt(orbital_radius_m^3/earth_mu_m3_s2);
angular_veloctiy_radps = sqrt(earth_mu_m3_s2/orbital_radius_m^3);

%% 2 . CALUCLATE ECLLIPSE GEOMENTRY 
eclipse_half_angle_rad = asin(earth_radius_m/orbital_radius_m);
eclipse_start_angle_rad = pi - eclipse_half_angle_rad;
eclipse_end_angle_rad = pi + eclipse_half_angle_rad;
eclipse_duration_s = 2*eclipse_half_angle_rad / angular_veloctiy_radps;
sunlight_duration_s = orbital_period_s - eclipse_duration_s;

%% 3 . DEFINE SOLAR ARRAY PARAMETERS
solar_irrandiance_W_m2 = 1361;
solar_array_area_m2 = 5;
solar_array_efficiency_BOL = 0.28;
spacecraft_load_W = 800;

%% 4 . CALUCLATE EOL EFFICIENCY 
annual_degration_rate = 0.02;
mission_life_years = 5 ; 
solar_array_efficiency_EOL = solar_array_efficiency_BOL * (1-annual_degration_rate)^mission_life_years;
total_relative_degradation_percent = (1- solar_array_efficiency_EOL/solar_array_efficiency_BOL)* 100;

%% 5 . CALUCLATE BOL AND EOL SOLAR POWER 
solar_array_power_BOL_W = solar_irrandiance_W_m2 * solar_array_area_m2 * solar_array_efficiency_BOL;
solar_array_power_EOL_W =  solar_irrandiance_W_m2 * solar_array_area_m2 * solar_array_efficiency_EOL;

%% 6. BATTERY PARAMETERS
battery_capacity_Wh = 1000;
initial_soc_percent = 100;
minimum_soc_percent = 20;
charging_efficiency = 0.95;
discharging_efficiency = 0.95;
initial_battery_energy_Wh = battery_capacity_Wh*initial_soc_percent/ 100;
maximun_battery_energy_Wh = battery_capacity_Wh;
minimum_battery_energy_Wh =  battery_capacity_Wh * minimum_soc_percent /100; 

%% 7 . SIMULATION TIME
number_of_orbits = 2;
simulation_duration_s = number_of_orbits*orbital_period_s;
time_step_s = 10;
time_s = 0 : time_step_s : floor(simulation_duration_s / time_step_s)*time_step_s;
time_min = time_s / 60;
delta_time_h = time_step_s / 3600 ; 
number_of_samples = numel(time_s);

%% 8 .  CALUCLATE ORBITAL ANGLE
orbital_angle_rad = mod(angular_veloctiy_radps* time_s,2*pi);

%% 9 . DETECT ECIPSE
is_eclipse = (orbital_angle_rad>= eclipse_start_angle_rad)&(orbital_angle_rad<=eclipse_end_angle_rad);

%% 10 . CREATE BOL AND EOL SOLAR POWER PROFILES 
solar_power_BOL_W = zeros(size(time_s));
solar_power_EOL_W = zeros(size(time_s));
solar_power_BOL_W(~is_eclipse) = solar_array_power_BOL_W;
solar_power_EOL_W(~is_eclipse) = solar_array_power_EOL_W ; 

%% 11 . INITIALIZE BOL BATTERY ARRAYS
battery_energy_BOL_Wh = zeros(size(time_s));
battery_soc_BOL_percent = zeros(size(time_s));
battery_energy_BOL_Wh(1) = initial_battery_energy_Wh;
unserved_load_BOL_Wh = 0 ;

%% 12 . INITIALIZE EOL BATTERY ARRAYS
battery_energy_EOL_Wh = zeros(size(time_s));
battery_soc_EOL_percent = zeros(size(time_s));
battery_energy_EOL_Wh(1) = initial_battery_energy_Wh;
unserved_load_EOL_Wh = 0 ;

%% 13 . SIMULATE BOL BATTERY
for k =1: number_of_samples-1 
    if solar_power_BOL_W(k) >= spacecraft_load_W 
        %Solar power supplies load ; surplus charges battery
        surplus_power_W = solar_power_BOL_W(k)  - spacecraft_load_W ;
        energy_charged_Wh = surplus_power_W * charging_efficiency * delta_time_h ;
        proposed_energy_Wh = battery_energy_BOL_Wh(k) + energy_charged_Wh ;
        battery_energy_BOL_Wh(k+1) = min(proposed_energy_Wh,battery_capacity_Wh);
    else
        % battery supplies the deficit 
        deficit_power_W = spacecraft_load_W - solar_power_BOL_W(k);
        required_energy_Wh = (deficit_power_W/ discharging_efficiency) * delta_time_h ;
        available_energy_Wh = max(battery_energy_BOL_Wh(k) - minimum_battery_energy_Wh,0);
        actual_energy_drawn_Wh = min(required_energy_Wh, available_energy_Wh);
        delivered_energy_Wh = actual_energy_drawn_Wh * discharging_efficiency ;
        demand_energy_Wh = deficit_power_W * delta_time_h ;
        unserved_load_BOL_Wh = unserved_load_BOL_Wh + max(demand_energy_Wh - delivered_energy_Wh,0);
        battery_energy_BOL_Wh(k+1) = battery_energy_BOL_Wh(k) - actual_energy_drawn_Wh ;
    end
end

%% 14 . SIMULATE EOL BATTERY 
for k =1: number_of_samples-1 
    if solar_power_EOL_W(k) >= spacecraft_load_W 
        %Solar power supplies load ; surplus charges battery
        surplus_power_W = solar_power_EOL_W(k)  - spacecraft_load_W ;
        energy_charged_Wh = surplus_power_W * charging_efficiency * delta_time_h ;
        proposed_energy_Wh = battery_energy_EOL_Wh(k) + energy_charged_Wh ;
        battery_energy_EOL_Wh(k+1) = min(proposed_energy_Wh,battery_capacity_Wh);
    else
        % battery supplies the deficit 
        deficit_power_W = spacecraft_load_W - solar_power_EOL_W(k);
        required_energy_Wh = (deficit_power_W/ discharging_efficiency) * delta_time_h ;
        available_energy_Wh = max(battery_energy_EOL_Wh(k) - minimum_battery_energy_Wh,0);
        actual_energy_drawn_Wh = min(required_energy_Wh, available_energy_Wh);
        delivered_energy_Wh = actual_energy_drawn_Wh * discharging_efficiency ;
        demand_energy_Wh = deficit_power_W * delta_time_h ;
        unserved_load_EOL_Wh = unserved_load_EOL_Wh + max(demand_energy_Wh - delivered_energy_Wh,0);
        battery_energy_EOL_Wh(k+1) = battery_energy_EOL_Wh(k) - actual_energy_drawn_Wh ;
    end
end

%% 15 . CALUCLATE BOL AND EOL SOC
battery_soc_BOL_percent = (battery_energy_BOL_Wh / battery_capacity_Wh) * 100 ;
battery_soc_EOL_percent = (battery_energy_EOL_Wh / battery_capacity_Wh) * 100 ;

%% 16 . CALUCLATE BATTERY PERFORMANCE 
minimum_soc_BOL = min(battery_soc_BOL_percent);
minimum_soc_EOL = min(battery_soc_EOL_percent);
final_soc_BOL = battery_soc_BOL_percent(end);
final_soc_EOL = battery_soc_EOL_percent(end);

%% 17 . ESTIMATE BATTERY RECHARGE TIME 
eclipse_energy_required_Wh = (spacecraft_load_W / discharging_efficiency) * (eclipse_duration_s / 3600) ;
charging_power_BOL_W = (solar_array_power_BOL_W - spacecraft_load_W) * charging_efficiency ;
charging_power_EOL_W = (solar_array_power_EOL_W - spacecraft_load_W) * charging_efficiency ; 
recharge_time_BOL_min = eclipse_energy_required_Wh / charging_power_BOL_W * 60 ;
recharge_time_EOL_min = eclipse_energy_required_Wh / charging_power_EOL_W * 60 ;

%% 18 . DIAPLAY RESULTS
fprintf('\n==== DAY 5 % : DEGRADATION ANANLYSIS====\n');
fprintf('\n ---SOLAR ARRAY ---\n');
fprintf('BOL efficiency    : %.2f %%\n',solar_array_efficiency_BOL*100);
fprintf('EOL efficiency    : %.2f %%\n',solar_array_efficiency_EOL*100);
fprintf('Total relative loss    : %.2f %% \n',total_relative_degradation_percent);
fprintf('BOL solar power    : %.2f W\n',solar_array_power_BOL_W);
fprintf('EOL solar power    : %.2f W\n',solar_array_power_EOL_W);
fprintf('\n---BATTERY ---\n');
fprintf('ecllipse energy required   : %.2f Wh\n ',eclipse_energy_required_Wh);
fprintf('BOL recharge time    :%.2f minutes \n',recharge_time_BOL_min);
fprintf('EOL recharge time    :%.2f minutes \n',recharge_time_EOL_min);
fprintf('BOL minimum soc    : %.2f %%\n',minimum_soc_BOL);
fprintf('EOL minimum soc    : %.2f %%\n',minimum_soc_EOL);
fprintf('BOL final soc    :%.2f %% \n',final_soc_BOL);
fprintf('EOL final soc    :%.2f %% \n',final_soc_EOL);
fprintf('BOL funreserved load    : %.6f Wh\n ',unserved_load_BOL_Wh);
fprintf('EOL funreserved load    : %.6f Wh \n ',unserved_load_EOL_Wh);
fprintf('\n====DAY 5 SAMAPTAM ====\n');
fprintf('THADHASTHU\n');

%% 19 . PLOT SOLAR POWER COMPARISON
figure('Name','BOL and EOL degradation comparisons');
subplot(3,1,1);
plot(time_min,solar_power_BOL_W,'linewidth',1.3);
hold on;
plot(time_min,solar_power_EOL_W,'LineWidth',1.3);
plot(time_min , spacecraft_load_W * ones(size(time_s)),'--','LineWidth',1.1);
xlabel('time(minutes)');
ylabel('power (w)');
title('BOL andEOL solar array power');
legend('BOL solar power','EOL solar power','spacecraft load','Location','best');
grid on ;

%% 20 . PLOT BATTERY SOC COMPARISION
subplot(3,1,2);
plot(time_min,battery_soc_BOL_percent,'linewidth',1.3);
hold on;
plot(time_min,battery_soc_BOL_percent,'linewidth',1.3);
plot(time_min,minimum_soc_percent * ones(size(time_s)),'--','LineWidth',1.1);
xlabel('time(minutes)');
ylabel('soc(%)');
title('battery soc : BOL versus EOL');
legend('BOL battery ','EOl battery','minimum permitted soc','Location','best');
ylim([0 105]);
grid on;

%% 21 . PLOT BATTERY ENERGY COMPARISON
subplot(3,1,3);
plot(time_min,battery_energy_BOL_Wh,'LineWidth',1.3);
hold on ;
plot (time_min, battery_energy_EOL_Wh,'LineWidth',1.3);
ylabel('stored energy(Wh)');
xlabel('time (minutes)');
title('battery stored energy : BOL versus EOL');
legend('BOL battery ','EOL battery','Location','best');
grid on;

%% 22 . SAVE RESULTS
script_folder = fileparts(mfilename('fullpath'));
project_folder = fileparts(script_folder);
results_folder = fullfile(project_folder,'results');
if~exist(results_folder,'dir')
    mkdir(results_folder);
end
saveas(gcf,fullfile(results_folder,'day5_bol_eol_compariso.png'));
save(fullfile(results_folder,'day5_degradation_data.mat'),'time_s','solar_power_BOL_W','solar_power_EOL_W','battery_energy_BOL_Wh','battery_energy_EOL_Wh','battery_soc_BOL_percent','battery_soc_EOL_percent','is_eclipse'); 
    fprintf('\n Day 5 graph nd numerical results saved .\n');
