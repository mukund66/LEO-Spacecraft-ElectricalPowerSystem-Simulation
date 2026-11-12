%% DAY . 7 : SPACECRAFT OPERATIONAL MODES AND DYNAMIC LOAD 
% PROJECT : LEO SPACECRAFT ELECTRICAL POWER SYSTEM SIMULATOR 
%
% OBJECTIVES :
% 1 . Create a time varying spacecraft electrical load profile
% 2 . Model safe , Nominal , science and communication modes.
% 3 . Caluclate the EOL solar array power .
% 4 . simulate battery SoC and unserved electrical energy.
% 5 . Track battery soc and unserved electrical energy.
% IMPORTANT :
% The operational schedule and load values are illustrative 
% They are not measured data from a real spacecraft 

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
orbital_period_min = orbital_period_s / 60 ;


%% 2 . CALUCLATE ECLLIPSE GEOMENTRY 
eclipse_half_angle_rad = asin(earth_radius_m/ orbital_radius__m);
eclipse_start_angle_rad = pi - eclipse_half_angle_rad;
eclipse_end_angle_rad = pi + eclipse_half_angle_rad;
eclipse_duration_s = 2*eclipse_half_angle_rad / angular_velocity_radps;
sunlight_duration_s = orbital_period_s - eclipse_duration_s;
eclipse_duration_min = eclipse_duration_s / 60;
sunlight_duration_min = sunlight_duration_s / 60;

%% 3 . DEFINE SOLAR ARRAY PARAMETERS
solar_irrandiance_W_m2 = 1361;
solar_array_area_m2 = 5;
solar_array_efficiency_BOL = 0.28;
annual_degradation_rate = 0.02 ;
mission_life_years = 5
% Compound annual degradation 
solar_array_efficiency_EOL = solar_array_efficiency_BOL * (1 - annual_degradation_rate)^ mission_life_years ;
% solar ARRAY POWER AT EOL
solar_array_power_EOL_W = solar_irrandiance_W_m2 * solar_array_area_m2 * solar_array_efficiency_EOL;

%% 4 . SPACECRAFT OPERATIONAL MODE LOANS
% These loads are illustrative design assumption
safe_mode_loads_W = 400 ;
nominal_mode_load_W = 500 ; 
science_mode_load_W = 800 ;
communications_mode_load_W = 900 ;

%% 5 . BATTERY PARAMETERS
battery_capacity_Wh = 1000;
initial_soc_percent = 100;
minimum_soc_percent = 20;
charging_efficiency = 0.95;
discharging_efficiency = 0.95;
initial_battery_energy_Wh = battery_capacity_Wh*initial_soc_percent/ 100;
maximun_battery_energy_Wh = battery_capacity_Wh;
minimum_battery_energy_Wh =  battery_capacity_Wh * minimum_soc_percent /100; 

%% 6 . SIMULATION TIME 
number_of_orbits = 2;
simulation_duration_s = number_of_orbits*orbital_period_s;
time_step_s = 10;
time_s = 0 : time_step_s : floor(simulation_duration_s / time_step_s)*time_step_s;
time_min = time_s / 60;
delta_time_h = time_step_s / 3600 ; 
number_of_samples = numel(time_s);

%% 7 . CALUCLATE ORBITAL ANGLE
orbital_angle_rad = mod(angular_velocity_radps * time_s,2*pi);

%% 8 . IDENTIFY ECLISE PERIODS 
is_eclipse = (orbital_angle_rad>= eclipse_start_angle_rad)&(orbital_angle_rad<=eclipse_end_angle_rad);

%% 9 . DETERMINE TIME WITHIN EACH ORBIT
% This resets the orbital clock after every orbital  period 
time_in_orbit_min = mod(time_min , orbital_period_min);


%% 10 . CREATE THE DYNAMIC LOAD PROFILE 
% BEgin with nominal mode throughout the simulation 
load_profile_W = nominal_mode_load_W * ones(size(time_s));
operating_mode_code = 2 * ones(size(time_s));
%% 10A . SCIENCE MODE : 0 TO 20 MINUTES 
science_indices = (time_in_orbit_min >= 0 ) & (time_in_orbit_min < 20);
load_profile_W(science_indices) = science_mode_load_W;
operating_mode_code(science_indices) = 3;

%% 10B . COMMUNICATION MODE : 75 TO 82 MINUTES
communication_indices = (time_in_orbit_min >= 75) & (time_in_orbit_min < 82);
load_profile_W(communication_indices) = communications_mode_load_W ;
operating_mode_code(communication_indices) = 4 ;
%% 10C . SAFE MODE DURING ECLIPSE
%Eclipse condition overrides other operating modes 
load_profile_W(is_eclipse) = safe_mode_loads_W;
operating_mode_code(is_eclipse) = 1;

%% 11 . CREATE SOLAR POWER PROFILE
solar_power_W = zeros(size(time_s));
% Solar array generates power only outside eclipse 
solar_power_W(~is_eclipse) = solar_array_power_EOL_W;

%% 12 . CALUCLATE POWER MARGIN 
power_margin_W = solar_power_W - load_profile_W;

%% 13 . INITIALIZE BATTERY ARRAYS
battery_energy_Wh = zeros(size(time_s));
battery_soc_percent = zeros(size(time_s));
battery_energy_Wh(1) = initial_battery_energy_Wh ;
battery_soc_percent(1) = initial_soc_percent;
%Stored energy added to battery at each time step 
energy_removed_from_battery_Wh = zeros(size(time_s));
energy_stored_by_battery_Wh =  zeros(size(time_s));


%% 14 . INITIALISE ENERGY ACCOUNTING VARIABLES 
total_unserved_load_Wh = 0 ;
total_charging_loass_Wh = 0 ;
total_discharging_loss_Wh = 0 ;
total_curtailed_solar_energy_Wh = 0 ;

%% 15. BATTERY ENERGY SIMULATION
for k = 1 : number_of_samples-1
    % Read solar power and spacecraft load at this time step 
    available_solar_power_W = solar_power_W(k);
    required_load_power_W = load_profile_W(k);

    %% CASE A : SOLAR POWER IS GREATER THAN OR EQUAL TO LOAD 
    if available_solar_power_W >= required_load_power_W
        % Solar array directly supplies the spacecraft load 
        surplus_power_W = available_solar_power_W - required_load_power_W;
        % Surplus electrical energy availble for charging
        surplus_energy_Wh = surplus_power_W * delta_time_h ; 
        % MAximum additional energy battery can store
        remaining_battery_space_Wh = battery_capacity_Wh - battery_energy_Wh(k) ;
        %Energy that can actually be stored after charging losses
        stored_energy_Wh = min(surplus_energy_Wh*charging_efficiency,remaining_battery_space_Wh);
        % Electrical energy drawn from surplus to store this energy 
        energy_into_battery_Wh = stored_energy_Wh / charging_efficiency;
        % Caluclate charging loss ,
        charging_loss_Wh = energy_into_battery_Wh - stored_energy_Wh ;
        %Surplus that cannot be accepted by the battery 
        curtailed_energy_Wh = surplus_energy_Wh - energy_into_battery_Wh ;
        % Caluclate charging loss
        charging_loss_Wh = energy_into_battery_Wh - stored_energy_Wh ;
        %Surplus that cannot be accepted byb the battery 
        curtailed_energy_Wh = surplus_energy_Wh - energy_into_battery_Wh;
        %update battery energy
        battery_energy_Wh(k+1) = battery_energy_Wh(k) + stored_energy_Wh ;
        % Record energy flow
        energy_stored_by_battery_Wh(k+1) = stored_energy_Wh ;
        total_charging_loass_Wh = total_charging_loass_Wh + charging_loss_Wh ;
        total_curtailed_solar_energy_Wh = total_curtailed_solar_energy_Wh+ max(curtailed_energy_Wh,0);

        %% CASE B :SOAR POWER IS LESS THAN LOAD
    else
        % Caluclate  the power deficite .
        deficit_power_W = required_load_power_W - available_solar_power_W;
        % Required energy delivered to spacecraft load
        demand_energy_Wh = deficit_power_W * delta_time_h ;
        %Required stored battery energy accounting for losses
        required_battery_energy_Wh = demand_energy_Wh / discharging_efficiency ;
        % Battery energy available above th minimum reserve
        available_battery_energy_Wh = max(battery_energy_Wh(k) - minimum_battery_energy_Wh,0);
        %Energy actually removed from the battery 
        actual_energy_drawn_Wh = min(required_battery_energy_Wh,available_battery_energy_Wh);
        %Energy actually delivered to the space craft load
        delivered_energy_Wh = actual_energy_drawn_Wh * discharging_efficiency;
        %Energy not supplied to the spacecraft load 
        unserved_energy_Wh = max(demand_energy_Wh - delivered_energy_Wh,0);
        %Battery dischage loss 
        discharging_loss_Wh = actual_energy_drawn_Wh - delivered_energy_Wh ;
        %Update battery energy
        battery_energy_Wh(k+1) = battery_energy_Wh(k) - actual_energy_drawn_Wh;
        %Record energy flow 
        energy_removed_from_battery_Wh(k+1) = actual_energy_drawn_Wh ;
        total_unserved_load_Wh = total_unserved_load_Wh + unserved_energy_Wh;
        total_discharging_loss_Wh = total_discharging_loss_Wh + discharging_loss_Wh ;
    end
end

%% 16 . CALUCLATE BATTERY STATE OF CHARGE 
battery_soc_percent = (battery_energy_Wh / battery_capacity_Wh) * 100 ;


%% 17 . CALUCLATE SYSTEM PERFORMANCE
minimum_battery_soc_percent = min(battery_soc_percent);
maximum_battery_soc_percent = max(battery_soc_percent);
final_battery_soc_percent = battery_soc_percent(end);
average_spacecraft_load_W = mean(load_profile_W(1:end-1));
peak_spaecraft_load_W = max(load_profile_W);
total_load_energy_Wh = sum(load_profile_W(1:end-1))* delta_time_h;
total_solar_energy_Wh = sum(solar_power_W(1:end-1))* delta_time_h;
total_battery_energy_stored_Wh = sum(energy_stored_by_battery_Wh);
total_battery_energy_removed_Wh = sum(energy_removed_from_battery_Wh);

%% 18 . DISPLAY RESULTS
fprintf('\n ==== DAY 7 :DYNAMIC LOAD SIMULATION ,SAMPATAM=====\n ');
fprintf('\n--ORBIT --\n');
fprintf('Orbital period   : %.2f minutes\n',orbital_period_min);
fprintf('Sunlight duration   : %.2fminutes\n ',sunlight_duration_min);
fprintf('eclipse duration   : %.2f minutes \n',eclipse_duration_min);
fprintf('\n---SOLAR ARRAY---\n');
fprintf('EOL efficiency   :%.2f %% \n',solar_array_efficiency_EOL*100);
fprintf('EOL solar power   : % .2f W \n',solar_array_power_EOL_W);
fprintf('\n --- SPACECRAFT LOAD ---\n');
fprintf('Peak load   : %.2f W\n',peak_spaecraft_load_W );
fprintf('average load   : %.2f W\n',average_spacecraft_load_W);
fprintf('total load energy   : %.2f Wh \n',total_load_energy_Wh);
fprintf('total solar energy   : %.2f Wh\n',total_solar_energy_Wh);
fprintf('\n---BATTERY---\n');
fprintf('Minimum battery soc   : %.2f %%\n',minimum_battery_soc_percent);
fprintf('Maximum battery soc   : %.2f %% \n',maximum_battery_soc_percent);
fprintf('Final battery soc   :%.2f Wh\n',final_battery_soc_percent);
fprintf('\n -- ENERGY ACCOUNTING ---\n');
fprintf('Unserved load energy   : %.6f Wh \n',total_unserved_load_Wh);
fprintf('charging loss   : %.2f Wh \n',total_charging_loass_Wh);
fprintf('Discharing loss   : %.2f Wh \n ',total_discharging_loss_Wh);
fprintf('Curtailed solar energy   : % .2f Wh \n',total_curtailed_solar_energy_Wh);

%% 19 . CHECK BATTERY OPERATION
fprintf('\n ----BATTERY OPERATION----\n');
if total_unserved_load_Wh < 1e-6
    fprintf('Spacecraft load demand was fully supplied .\n');
else
    fprintf('WARNING : spacecraft load was not fullu supplied .\n');
end
if minimum_battery_soc_percent >= minimum_soc_percent - 1e-6 
    
end
fprintf('\n====DAY 7 SIMULATION SAMAPTAM ====\n');

    %% . 20 . FIGUTR : SOLAR POWER AND DYNAMIC LOAD 
    figure('Name','day 7 - solar power and dynamic load ');
    subplot(4,1,1);
    plot(time_min,solar_power_W,'LineWidth',1.3);
    hold on ;
    plot(time_min,load_profile_W,'LineWidth',1.3);
    xlabel('TIme (minutes)');
    ylabel('Power(W)');
    title('Solar array power and dynamic spcecraft load ');
    legend('EOL solar power','Spacecraft load','Location','best');
    grid on;

    %% 21 . FIGURE : POWER MARGIN
    subplot(4,1,2);
    plot(time_min , power_margim_W,'LineWidth',1.3);
    hold on ;
    yline(0 , '-- ', ' Zero power margin');
    xlabel('Time(minutes)');
    ylabel('Power margin(W)');
    title('Instantaneous ELectrical power margin');
    grid on ;

    %% 22  . FIGURE : BATTERY STATE OF CHARGE 
    subplot(4,1,3);
    plot(time_min,battery_soc_percent,'LineWidth',1.3);
    hold on ;
    yline(minimum_soc_percent,'--','Minimum permitted soc');
    xlabel('Time(minutes)');
    ylabel('baterry soc (%)');
    title('Battery state of charge under dynamic loads');
    ylim([0 105]);
    grid on;

    %% 23 . FIGURE : SPACECRAFT OPERATING MODE 
    subplot(4,1,4);
    stairs(time_min,operating_mode_code,'LineWidth',1.3);
    xlabel('Time (minutes)');
    ylabel('operating mode');
    title('Spacecraft operationa; mode schedule');
    yticklabels({'safe','Nominal','science','coms'});
    ylim([0.5 4.5]);
    grid on;

    %% 24 . SAVE RESULTS
    script_folder = fileparts(mfilename('fullpath'));
    project_folder = fileparts(script_folder);
    results_folder = fullfile(project_folder,'results');
    if ~exist(results_folder , 'dir')
        mkdir(results_folder);
    end
    % Save the simulation figure 
    saveas(gcf,fullfile(results_folder,'day7_dynamic_load_simulation.png'));
    % save the numerical simulation results 
    save(fullfile(results_folder,'day7_dynamic_load_data.mat'),'time_s','time_min','is_eclipse','time_in_orbit_min','solar_power_W','load_profile_W','power_margin_W','operating_mode_code','battery_energy_Wh','battery_soc_percent','energy_stored_by_battery_Wh','energy_removed_from_battery_Wh','total_unserved_load_Wh','total_charging_loass_Wh','total_discharging_loss_Wh','total_curtailed_solar_energy_Wh');
    fprintf('\n DAY 7 graph and date files saved successfully.\n');


        

