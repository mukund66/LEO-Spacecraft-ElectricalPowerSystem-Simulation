%% DAY 6: SPACECRAFT EPS SIZING SENSITIVITY ANALYSIS
% PROJECT : LEO SPACECRAFT ELECTRCAL POWER SYSTEM SIMULATOR 
% STUDY : SOLAR ARRAY AREA VERSUS BATTERY CAPACITY
%DESING CONDITIONS : FIVE YEAR EOL SOLAR ARRAY PERORMANCE 
% simulation : TWO ORBITAL PERIODS 

clc;
clear;
close all;
%% 1 . EARTH AND ORBIT PARAMETERS
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
eclipse_duration_h =  eclipse_duration_s / 3600 ;
sunlight_duration_h = sunlight_duration_s /  3600 ;

%% 3 . EOL SOLAR CELL EFFICIENCY
solar_irrandiance_W_m2 = 1361;
solar_array_area_m2 = 5;
solar_array_efficiency_BOL = 0.28;
annual_degradation_rate = 0.02 ; 
mission_life_years = 5; 
solar_array_efficiency_EOL = solar_array_efficiency_BOL * (1 - annual_degradation_rate)^mission_life_years;

%% 4  . SPACECRAFT LOAD AND BATTERY PARAMEETERS
spacecraft_load_W = 800;
battery_capacity_Wh = 1000;
initial_soc_percent = 100;
minimum_soc_percent = 20;
charging_efficiency = 0.95;
discharging_efficiency = 0.95;
initial_battery_energy_Wh = battery_capacity_Wh*initial_soc_percent/ 100;
maximun_battery_energy_Wh = battery_capacity_Wh;
minimum_battery_energy_Wh =  battery_capacity_Wh * minimum_soc_percent /100; 

%% 5 . DEFING SIZING RANGES
array_area_values_m2 = 2:0.25:6 
battery_capacity_values_Wh = 400:50:1400;
number_of_areas = numel(array_area_values_m2);
number_of_capacities = numel(battery_capacity_values_Wh);
%% 6 . CALUCLATE MINIMUM THEORITICAL BATTERY CAPACITY
eclipse_energy_required_Wh = (spacecraft_load_W / discharging_efficiency)*eclipse_duration_h;
minimum_battery_capacity_Wh = (eclipse_energy_required_Wh / (1 - minimum_soc_percent / 100));

%% 7 . CALUCLATE MINIMUM THEORETICAL ARRAY AREA 
minimum_array_area_m2 = (spacecraft_load_W +( spacecraft_load_W / discharging_efficiency)*(eclipse_duration_h / sunlight_duration_h) / charging_efficiency) / (solar_irrandiance_W_m2 * solar_array_efficiency_EOL);

%% 8 . CRATE SIMULATION TIME ARRAY 
number_of_orbits = 2;
simulation_duration_s = number_of_orbits*orbital_period_s;
time_step_s = 10;
time_s = 0 : time_step_s : floor(simulation_duration_s / time_step_s)*time_step_s;
time_min = time_s / 60;
delta_time_h = time_step_s / 3600 ; 

%% 9 . CALUCLATE ORBITAL POSITION
orbital_angle_rad = mod(angular_veloctiy_radps * time_s,2*pi);

%% 10 . IDENTIFY ECLISE PERIODS 
is_eclipse = (orbital_angle_rad>= eclipse_start_angle_rad)&(orbital_angle_rad<=eclipse_end_angle_rad);
% IDENTIFY THE SAMPLE INDICES WHERE ECLIPSE BEGINS
eclipse_start_indices = find(diff([false,is_eclipse]) == 1 );
if numel(eclipse_start_indices)< 2 
    error('two eclipse periods were not deteced .CHECK THE SIMULATION TIME .');
end
second_eclipse_start_index = eclipse_start_indices(2);


%% 11 . INITIALISE SENSITIVITY RESULTS
feasible_matrix = false(number_of_areas,number_of_capacities);
minimum_soc_matrix = zeros(number_of_areas,number_of_capacities);
unserved_load_matrix_Wh = zeros(number_of_areas,number_of_capacities);
energy_at_second_eclipse_Wh = zeros(number_of_areas,number_of_capacities);

%% 12. RUN ALL ARRAY AREA AND BATTERY CAPACITY COMBINATIONS
for i = 1 : number_of_areas
    % select solar array area
    selected_area_m2 = array_area_values_m2(i);
    %caluclate EOL solar output for this area
    solar_array_power_EOL_W = solar_irrandiance_W_m2 * selected_area_m2 * solar_array_efficiency_EOL;
    % create solar power profile 
    solar_power_W = zeros(size(time_s));
    solar_power_W(~is_eclipse) = solar_array_power_EOL_W;
    for j = 1 : number_of_capacities 
        % select battery capacity 
        battery_capacity_Wh = battery_capacity_values_Wh(j);
        % caluclate minimum allowed energy
        minimum_battery_energy_Wh = battery_capacity_Wh * minimum_soc_percent /100 ;
        %Start with fully charged battery
        battery_energy_Wh = zeros(size(time_s));
        battery_energy_Wh(1) = battery_capacity_Wh ; 
        % track energy not supplied to the spacecraft load
        total_unserved_load_Wh = 0;
        %battery energy simulation
        for k = 1 : numel(time_s) - 1
            if solar_power_W(k) >= spacecraft_load_W
                % SUNLIGHT : solar array supplies load and charge battery
                surplus_power_W = solar_power_W(k) - spacecraft_load_W ;
                energy_charged_Wh = surplus_power_W * charging_efficiency * delta_time_h ;
                proposed_energy_Wh = battery_energy_Wh (k) + energy_charged_Wh;
                battery_energy_Wh(k+1) = min(proposed_energy_Wh,battery_capacity_Wh);
            else
                %load exceeds solar output :battery supplies deficit
                deficit_power_W = spacecraft_load_W - solar_power_W (k);
                required_energy_Wh = (deficit_power_W / discharging_efficiency) * delta_time_h;
                available_energy_Wh  = max(battery_energy_Wh(k) - minimum_battery_energy_Wh,0);
                actual_energy_drawn_Wh = min(required_energy_Wh,available_energy_Wh);
                delivered_energy_Wh = actual_energy_drawn_Wh * discharging_efficiency;
                demanded_energy_Wh = deficit_power_W * delta_time_h ;
                unserved_energy_Wh = max(demanded_energy_Wh - delivered_energy_Wh,0);
                total_unserved_load_Wh = total_unserved_load_Wh + unserved_energy_Wh ;
                battery_energy_Wh (k+1) = battery_energy_Wh(k) - actual_energy_drawn_Wh;
            end
        end
        % caluclate be=attery performance 
        battery_soc_percent = (battery_energy_Wh / battery_capacity_Wh) * 100 ;
        minimum_observed_soc = min(battery_soc_percent);
        energy_at_second_eclipse_value_Wh = battery_energy_Wh(second_eclipse_start_index);
        %% check 3 feasibility conditions
        load_is_supplied = total_unserved_load_Wh < 1e-6 ;
        battery_limits_respected = minimum_observed_soc >= minimum_soc_percent - 1e-6 ;
        battery_recharged_before_second_eclipse = energy_at_second_eclipse_value_Wh >= battery_capacity_Wh - 1e-3;
        configuration_is_feasible = load_is_supplied && battery_limits_respected && battery_recharged_before_second_eclipse;
        %% results storing
          feasible_matrix(i,j) = configuration_is_feasible ;
          minimum_soc_matrix(i,j) = minimum_observed_soc ;
          unserved_load_matrix_Wh(i,j) = total_unserved_load_Wh ;
          energy_at_second_eclipse_Wh(i,j) = energy_at_second_eclipse_value_Wh ;
    end
end

%% 13 . DISPLAY RESULTS
fprintf('\n====DAY 6 : EPS SIZZING ANALYSIS ====\n');
fprintf('\n---THEORETICAL LIMITS AT EOL ---\n');
fprintf('EOL SOLAR EFFICIENCY   : %.2f %% \n ',solar_array_efficiency_EOL*100);
fprintf('Eclipse energy requirements   : %.2f Wh\n',eclipse_energy_required_Wh);
fprintf('minimum Battery Capacity   :%.2f Wh \n',minimum_battery_capacity_Wh);
fprintf('Minimum solar array area   : %.2f m2 \n',minimum_array_area_m2);

%% 14 . CHECK BASELINE CONFIGURATION
[~,baseline_area_index] = min(abs(array_area_values_m2 - 5));
[~, baseline_battery_index] = min(abs(battery_capacity_values_Wh - 1000));
baseline_is_feasible = feasible_matrix(baseline_area_index,baseline_battery_index);
fprintf('\n---BASELINE CONFIGURATION ---\n');
fprintf('Solar array area   : %.2fm2 \n',array_area_values_m2(baseline_area_index));
fprintf('Battery capacity   : %.2f Wh\n',battery_capacity_values_Wh(baseline_battery_index));
fprintf('Minimum Battery Soc   : %.2f %%\n',minimum_soc_matrix(baseline_area_index,baseline_battery_index));
fprintf('Unserved load   : %.6f Wh\n',unserved_load_matrix_Wh(baseline_area_index,baseline_battery_index));
fprintf('Feasible configurations   : %d\n',baseline_is_feasible);
fprintf('\n==== dAY ^ SAMAPTAM\n');
fprintf('\nTHADHASTHU\n');

%% 15 . PLOT THE FEASIBILITY MAP
figure('Name','EPs sizing feasibility Map');
imagesc(array_area_values_m2,battery_capacity_values_Wh,double(feasible_matrix'));
set(gca,'YDir','normal');
xlabel('solar array area(m2)');
ylabel('Battery capacity (Wh)');
title('EOL EPS sizing feasibility Map');
colorbar;
caxis([0 1]);
grid on ;

%% 16 . PLOT MINIMUM SOC MAP 
figure('Name','Minimum battery  Soc map');
imagesc(array_area_values_m2,battery_capacity_values_Wh,minimum_soc_matrix');
set(gca,'YDir','normal');
xlabel('solar array area (m2)');
ylabel('batttery capacity (Wh)');
title('minimum battery soc across two orbits');
colorbar;
grid on;

%% 17 . CREATE ONE PARAMETER SENSIITVITY PLOTS
figure('Name','EPS SIzing sensitivity');
subplot(2,1,1);
feasibility_at_1000Wh = double(feasible_matrix(:,baseline_battery_index));
plot(array_area_values_m2,feasibility_at_1000Wh,'o-','LineWidth',1.4);
xlabel('solar array area(m2)');
ylabel('Feasibility');
title('Effect of Solar array Area (1000Wh Battery)');
ylim([-0.1  1.1]);
yticks([0 1]);
yticklabels({'Not feasible','feasible'});
grid on;
subplot(2,1,2);
feasibility_at_5m2 = double(feasible_matrix(baseline_area_index,:));
plot(battery_capacity_values_Wh,feasibility_at_5m2,'o-','LineWidth',1.4);
xlabel('Battery capcity (Wh)');
ylabel('Feasibility');
title('Effect of Battery Capacity (5 m2 Solar array )');
ylim([-0.1  1.1]);
yticks([0 1]);
yticklabels({'Not feasible','Feasible'});
grid on;

%% 18 . SAVE RESULTS 
script_folder = fileparts(mfilename('fullpath'));
project_folder = fileparts(script_folder);
results_folder = fullfile(project_folder,'results');
if ~exist(results_folder,'dir')
    mkdir(results_folder);
end
% Save the first figure
fig1 = findobj('Type','figure','Name','EPs sizing feasibility Map');
if ~isempty(fig1)
    saveas(fig1,fullfile(results_folder,'day6_sizing_feasibility_map.png'));
end
%Save the second figure
fig2 = findobj('Type','figure','Name','Minimum battery  Soc map');
if ~isempty(fig2)
    saveas(fig2,fullfile(results_folder,'day6_minimum_soc_map.png'));
end
% Save the third figure
fig3 = findobj('Type','Figure','Name','EPS SIzing sensitivity');
if ~isempty(fig3)
    saveas(fig3,fullfile(results_folder,'day6_sizing_sensitivity.png'));
end
% save numerical data
save(fullfile(results_folder,'day6_sizing_results.mat'),'array_area_values_m2','battery_capacity_values_Wh','feasible_matrix',"minimum_soc_matrix","unserved_load_matrix_Wh",'energy_at_second_eclipse_Wh','minimum_array_area_m2','minimum_battery_capacity_Wh');
fprintf('\n day 6 figures and numerical results saved. \n');
