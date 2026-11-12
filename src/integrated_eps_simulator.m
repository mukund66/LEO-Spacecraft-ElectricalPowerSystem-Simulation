%% DAY 9 :  INTEGRATED LEO SPACECRAFT ELECTRICSL POPWER SYSTEM 
%PROJECT : LEO SPACECRAFT ELECTRICAL POWER SYSTEM SIMULATOR
%
% INTERGRATED MODELS : 
% 1 . Circular LEO orbital mechanics 
% 2 . Beta angle dependent eclipse geometry
% 3 . EOL SOLAR ARRAY power generation
% 4 . DYNAMIC spacecraft operational loads
% 5 . Battery energy and soc simulation 
% 6 . unserved load detection 
% 7 . System - level energy accounting
% 8 . Baseline and failure scenario comparison
%
% Important assumption :
% - Circular orbit
% - Spherical Earth 
% - Cylindrical Earth shadow 
% - Ideal Sun - pointing solar 
% - Constant solar irandiane
% - Illustrative operational loads
% 
% This is an educational engineering simulation,
% not a flight - qualified spacecraft design 

clc;
clear;
close all;

%% ======================================================
% 1 . EARTH AND ORBITAL PARAMETRES
% =======================================================
earth_radius_m = 6371e3;
altitude_m = 400e3;
earth_mu_m3_s2 = 3.986004418e14;
orbital_radius_m = earth_radius_m + altitude_m;
orbital_speed_mps = sqrt(earth_mu_m3_s2 / orbital_radius_m);
orbital_period_s = 2*pi*sqrt(orbital_radius_m^3/earth_mu_m3_s2);
angular_velocity_radps = sqrt(earth_mu_m3_s2/orbital_radius_m^3);
orbital_period_min = orbital_period_s / 60 ;

%% ============================================================
% 2 . ORBITAL BETA ANGLE ECLIPSE GEOMENTRY 
%==============================================================
beta_angle_deg = 30;
beta_angle_rad = deg2rad(beta_angle_deg);
critical_beta_rad = asin(earth_radius_m / orbital_radius_m);
critical_beta_deg = rad2deg(critical_beta_rad);
if abs(beta_angle_deg) < critical_beta_deg 
    eclipse_half_angle_rad = acos(sqrt(1 - (earth_radius_m / orbital_radius_m)^2) / cos(beta_angle_rad));
    eclipse_duration_s_analytical = (orbital_period_s / pi) * (eclipse_half_angle_rad);
else
    eclipse_half_rad = 0 ;
    eclipse_duration_s_analytical = 0 ;
end
eclipse_duration_min_analytical = eclipse_duration_s_analytical / 60 ;
sunlight_duration_min_analytical = orbital_period_min - eclipse_duration_min_analytical;

%% ===============================================================
% 3 . SOLAR ARRAY PARAMETERS AND EOL DEGRADATION
% ================================================================
solar_irradiance_W_m2 = 1361 ;
solar_array_area_m2 = 5 ;
solar_array_efficiency_BOL = 0.28 ;
annual_degradation_rate = 0.02 ;
mission_life_years = 5 ;
solar_array_efficiency_EOL = solar_array_efficiency_BOL * (1 - annual_degradation_rate) ^ ( mission_life_years);
solar_array_power_EOL_W = solar_irradiance_W_m2 * solar_array_area_m2 * solar_array_efficiency_EOL ;

%% ====================================================
% 4 . SPACECRAFT OPERATIONAL LOAD PARAMETERS 
% ==================================================
nominal_mode_load_W = 500;
science_mode_load_W = 800 ;
communications_mode_loads_W = 900;

% Safe - mode load is changed for the stress - test scenario.

safe_mode_load_cases_W = [400 1400 400] ;

%%==============================================================
% 5 . BATTERY PARAMETERS
%===============================================================
battery_capacity_cases_Wh = [1000 1000 250];
initial_soc_percent = 100;
minimum_allowed_soc_percent = 20;
charging_efficiency = 0.95 ;
discharging_efficiency = 0.95;

%%==============================================================
% 6 . DEFINE TEST SCENARIOS 
%================================================================
scenario_names = {'Baseline','High - loadstress','low-capacity battery'};
number_of_scenarios = numel(scenario_names);

%% =============================================================
% 7 . SIMULATION TIME PARAMETERS
% ==============================================================
number_of_orbits = 2;
simulation_duration_s = number_of_orbits*orbital_period_s;
time_step_s = 10;
time_s = 0 : time_step_s : floor(simulation_duration_s / time_step_s)*time_step_s;
time_min = time_s / 60;
delta_time_h = time_step_s / 3600 ; 
number_of_samples = numel(time_s);

%%===============================================================
% 8 . CALCULATE SPACECRAFT ORBITAL POSITION
% ==============================================================
orbital_angle_rad = mod(angular_velocity_radps * time_s,2 * pi);
time_in_orbit_min = mod(time_min , orbital_period_min);

%% =============================================================
% 9 . DETECT ECLIPSE USING VETOR GEOMENTRY
% =================================================================
sunward_projection_m = orbital_radius_m * cos(orbital_angle_rad) * cos(beta_angle_rad) ;
perpendicular_distance_m = sqrt(max(orbital_radius_m^2 - sunward_projection_m.^ 2 ,0));
is_eclipse = (sunward_projection_m < 0) & (perpendicular_distance_m <= earth_radius_m);

%%===================================================================
% 10 . VERIFY NUMERICAL ECLISPE DURATION
%====================================================================
first_orbit_intervals = time_s(1:end-1) < orbital_period_s;
sampled_eclipse_duration_min = sum(is_eclipse(1:end-1) & first_orbit_intervals) * time_step_s / 60 ;

%%=====================================================================
% 11 . CREATE THE SOLAR ARRAY POWER PROFILE 
%=========================================================================
solar_power_W = zeros(size(time_s));
solar_power_W(~is_eclipse) = solar_array_power_EOL_W;

%%====================================================================
% 12 . INITIALISE SYSYTEM - LEVEL RESULT ARRAY 
%==================================================================
minimum_soc_results_percent = zeros(number_of_scenarios,1);
maximum_soc_results_percent = zeros(number_of_scenarios,1);
final_soc_results_percent = zeros(number_of_scenarios,1);
unserved_load_results_Wh = zeros(number_of_scenarios,1);
charging_loss_results_Wh = zeros(number_of_scenarios,1);
discharging_loss_results_Wh = zeros(number_of_scenarios,1);
curtailed_solar_results_Wh = zeros(number_of_scenarios,1);
feasibility_results = false(number_of_scenarios,1);
load_balance_residuals_Wh = zeros(number_of_scenarios,1);
battery_balance_residuals_Wh = zeros(number_of_scenarios,1);
solar_balance_residuals_Wh = zeros(number_of_scenarios,1);
scenario_results = struct([]);

%%===================================================================
% 13 . RUN THE INTEGRATED SIMULATION FOR EACH SCENARIO
%====================================================================
for s = 1 : number_of_scenarios

    %% 13A . SELECT SCENARIOS PARAMETERS
    selected_safe_load_W = safe_mode_load_cases_W(s);
    battery_capacity_Wh = battery_capacity_cases_Wh(s);
    initial_battery_energy_Wh = battery_capacity_Wh * initial_soc_percent / 100 ;
    minimum_battery_energy_Wh = battery_capacity_Wh * minimum_allowed_soc_percent / 100 ;
    
    %% 13B .    CREATE DYNAMIC OPERATINAL LOAD PROFILE
    load_profile_W = nominal_mode_load_W * ones(size(time_s));
    % Mode codes :
    % 1 = Safe 
    % 2 = Nominal
    % 3 = Science 
    % 4 = Communication
    operating_mode_code = 2 * ones(size(time_s));

    % Science : 0 to 20 minutes per orbit 
    science_indices = (time_in_orbit_min >= 0) & (time_in_orbit_min < 20);
    load_profile_W(science_indices) = science_mode_load_W ;
    operating_mode_code(science_indices) = 3;

    %Communications : 75 to 82 minutes per orbit
    communications_indices = (time_in_orbit_min >= 75) & (time_in_orbit_min < 82);
    load_profile_W(communications_indices) = communications_mode_loads_W ;
    operating_mode_code(communications_indices) = 4;

    % Safe mode overrides all other modes during eclipse
    load_profile_W(is_eclipse) = selected_safe_load_W ;
    operating_mode_code(is_eclipse) = 1 ;

    %% 13C . CALUCLATE POWER MARGIN
    power_margin_W = solar_power_W - load_profile_W ;

    %% 13D . INITIALISE BATTERY STATE ARRAYS
    battery_energy_Wh = zeros(size(time_s)) ;
    battery_soc_percent = zeros(size(time_s));
    battery_energy_Wh(1) = initial_battery_energy_Wh ;
    battery_soc_percent(1) = initial_soc_percent;

    %% 13E . INITIALISE ENERGY FLOW ARRAYS
    solar_to_loads_Wh = zeros(size(time_s)) ;
    battery_to_load_Wh = zeros(size(time_s));
    battery_energy_stored_Wh = zeros(size(time_s));
    battery_energy_removed_Wh = zeros(size(time_s));
    solar_energy_into_charging_Wh = zeros(size(time_s));
    unserved_energy_Wh = zeros(size(time_s));
    charging_loss_Wh = zeros(size(time_s));
    discharging_loss_Wh = zeros(size(time_s));
    curtailed_solar_energy_Wh = zeros(size(time_s));

    %% 13F . BATTERY ENERGY SIMULATION 
    for k= 1 : number_of_samples-1 

        % Energy demanded by spacecraft during this interval 
        load_demand_Wh = load_profile_W(k) * delta_time_h ;

        % Solar energy available during this interval
        solar_available_Wh = solar_power_W(k) * delta_time_h;

        %% CASE 1 : SOLAR POWER CAN SUPPLY THE FULL LOAD
        if solar_power_W(k) >= load_profile_W(k) 

            %Solar array directly supplies spacecraft load 
            solar_to_loads_Wh(k) = load_demand_Wh ;

            % Remaining solar energy is available for charging
            surplus_solar_Wh = solar_available_Wh - load_demand_Wh ;

            % Battery storage space 
            battery_headroom_Wh = battery_capacity_Wh - battery_energy_Wh(k);

            % Energy that can actually be stored
            stored_energy_Wh = min(surplus_solar_Wh * charging_efficiency,battery_headroom_Wh);

            % Electrical energy consumed by battery charging 
            charging_input_Wh = stored_energy_Wh / charging_efficiency ;

            %Charging loss 
            charge_loss_Wh = charging_input_Wh - stored_energy_Wh ;

            % Excess solar energy that cannot be stored
            curtailed_energy_Wh = max(surplus_solar_Wh - charging_input_Wh, 0);

            % Update battery energy 
            battery_energy_Wh(k+1) = battery_energy_Wh(k) + stored_energy_Wh ;

            % Store energy accounting information
            battery_energy_stored_Wh(k) = stored_energy_Wh ;
            solar_energy_into_charging_Wh(k) = charging_input_Wh ;
            charging_loss_Wh(k) = charge_loss_Wh ;
            curtailed_solar_energy_Wh(k) = curtailed_energy_Wh ;

            %% CASE 2 : SOLAR POWER CANNOT SUPPLY THE FULL LOAD
        else

            % Solar power directly supplies part of the load
            solar_to_loads_Wh(k) = solar_available_Wh ;

            % Remaining load demand 
            load_deficit_Wh = load_demand_Wh - solar_to_loads_Wh (k);

            % Stored battery energy required to deliver this deficit 
            required_battery_energy_Wh = load_deficit_Wh / discharging_efficiency ;

            % Available battery energy above the reserve 
            available_battery_energy_Wh = max(battery_energy_Wh(k) - minimum_battery_energy_Wh , 0 ) ;

            % Actual energy that canbe removed
            actual_energy_drawn_Wh = min(required_battery_energy_Wh, available_battery_energy_Wh);

            % Electrical energy delivered from battery to load
            delivered_battery_energy_Wh = actual_energy_drawn_Wh * discharging_efficiency ;

            % Unserved spacecraft load 
            unserved_load_Wh = max(load_deficit_Wh - delivered_battery_energy_Wh,0 );

            % Battery discharge loss .
         
            discharge_loss_Wh = actual_energy_drawn_Wh - delivered_battery_energy_Wh;

            % Update battery energy 
            battery_energy_Wh(k+1) = battery_energy_Wh(k) - actual_energy_drawn_Wh ;

            % Store energy accounting information
            battery_energy_removed_Wh(k) = actual_energy_drawn_Wh ;
            battery_to_load_Wh(k) = delivered_battery_energy_Wh;
            unserved_energy_Wh(k) = unserved_load_Wh ;
            discharging_loss_Wh(k) = discharge_loss_Wh ;
        end

        %% UPDATE STATE OF CHARGE 
        battery_soc_percent(k+1) = (battery_energy_Wh(k+1) / battery_capacity_Wh) * 100;
    end
    %% 13G . CALUCLATE TOTAL ENERGY FLOW 
    total_load_energy_Wh = sum(load_profile_W(1:end-1)) * delta_time_h ;
    total_solar_energy_Wh = sum(solar_power_W(1:end-1)) * delta_time_h ;
    total_solar_to_load_Wh = sum(solar_to_loads_Wh);
    total_battery_to_load_Wh = sum(battery_to_load_Wh);
    total_battery_energy_stored_Wh = sum(battery_energy_stored_Wh);
    total_battery_energy_removed_Wh = sum(battery_energy_removed_Wh);
    total_solar_energy_into_charging_Wh = sum(solar_energy_into_charging_Wh);
    total_unserved_load_Wh = sum(unserved_energy_Wh);
    total_charging_loss_Wh = sum(charging_loss_Wh) ;
    total_discharging_loss_Wh = sum(discharging_loss_Wh) ;
    total_curtailed_solar_energy_Wh = sum(curtailed_solar_energy_Wh);

    %% 13H . CHECK LOAD ENERGY ACCOUNTING
    % Loads demand must equal 
    % Solar energy delivered directly to load
    % + battery energy delivered to load 
    % + unserved load energy 

    load_balance_residual_Wh = total_load_energy_Wh - total_solar_to_load_Wh - total_battery_to_load_Wh - total_unserved_load_Wh ;


    %% 13I . CHECK BATTERY ENERGY ACCOUNTING
    % Final battery energy = 
    % Initial battery energy 
    % + battery energy stored 
    % - battery energy removed

    battery_balance_residual_Wh = battery_energy_Wh(end) - (initial_battery_energy_Wh + total_battery_energy_stored_Wh - total_battery_energy_removed_Wh);


    %% 13J . CHECK SOLAR ENERGY ACCOUNTING
    % Total solar energy = 
    % Solar supplied directly to load
    % + solar input to battery charging 
    % + curtailed solar energy 
    solar_balance_residual_Wh = total_solar_energy_Wh - total_solar_to_load_Wh -  total_solar_energy_into_charging_Wh - total_curtailed_solar_energy_Wh;
  

    %% 13K . CALCULATE BATTERY PERFORMANCE 
    minimum_soc_percent = min(battery_soc_percent);
    maximum_soc_percent = max(battery_soc_percent);
    final_soc_percent = battery_soc_percent(end) ; ...
        ...
        %% 13L . CHECK SYSTEM FEASIBILITY
    load_is_fully_supplied = total_unserved_load_Wh < 1e-6 ;
    battery_reserve_respected = minimum_soc_percent >= minimum_allowed_soc_percent- 1e-6 ;
    battery_upper_limit_respected = maximum_soc_percent <= 100 + 1e-6 ;
    configuration_is_feasible = load_is_fully_supplied && battery_reserve_respected && battery_upper_limit_respected ;

    %% 13M . STORE SCEARIO RESULTS
    minimum_soc_results_percent(s) = minimum_soc_percent ;
    maximum_soc_results_percent(s) = maximum_soc_percent ;
    final_soc_results_percent(s) = final_soc_percent ; 
    unserved_load_results_Wh(s) = total_unserved_load_Wh ;
    charging_loss_results_Wh(s) = total_charging_loss_Wh ;
    discharging_loss_results_Wh(s) = total_discharging_loss_Wh;
    curtailed_solar_results_Wh(s) = total_curtailed_solar_energy_Wh ;
    feasibility_results(s) = configuration_is_feasible;
    load_balance_residuals_Wh(s) = load_balance_residual_Wh ;
    battery_balance_residuals_Wh(s) = battery_balance_residual_Wh ;
    solar_balance_residuals_Wh(s) = solar_balance_residual_Wh;

    %% 13N . SAVE FULL SCENARIO DATA IN A STRUCTURE 
    scenario_results(s).name = scenario_names(s);
    scenario_results(s) . safe_mode_load_W = selected_safe_load_W ;
    scenario_results(s) .  battery_capacity_Wh = battery_capacity_Wh  ;
    scenario_results(s) . load_profile_W = load_profile_W ;
    scenario_results(s) . solar_power_W = solar_power_W ;
    scenario_results(s) . power_margin_W = power_margin_W ;
    scenario_results(s) . operating_mode_code = operating_mode_code ;
    scenario_results(s) . battery_energy_Wh =  battery_energy_Wh ;
    scenario_results(s) . battery_soc_percent = battery_soc_percent ;
    scenario_results(s) . total_load_energy_Wh = total_load_energy_Wh ;
    scenario_results(s) . total_unserved_load_Wh = total_unserved_load_Wh ;
    scenario_results(s) . total_charging_loss_Wh = total_charging_loss_Wh ;
    scenario_results(s) .  total_discharging_loss_Wh = total_discharging_loss_Wh ;
    scenario_results(s) . total_curtailed_solar_energy_Wh = total_curtailed_solar_energy_Wh ;
    scenario_results(s) . minimum_soc_percent = minimum_soc_percent ;
    scenario_results(s) . final_soc_percent = final_soc_percent ;
    scenario_results(s) . is_feasible = configuration_is_feasible ;
    scenario_results(s) . load_balance_residuals_Wh = load_balance_residuals_Wh ;
    scenario_results(s) . battery_balance_residuals_Wh = battery_balance_residuals_Wh ;
    scenerio.results(s) . battery_energy_stored_Wh = battery_energy_stored_Wh ;
    scenario.results(s) . solar_balance_residual_Wh = solar_balance_residual_Wh ;
    scenario.results(s) . solar_to_loads_Wh = solar_to_loads_Wh ;
    sceanrio.results(s) . battery_to_load_Wh = battery_to_load_Wh ;
    scenario.results(s) .  battery_energy_removed_Wh =  battery_energy_removed_Wh ;
    scenario.results(s) . unserved_energy_Wh = unserved_energy_Wh;

end

%% =================================================================
% 14 . CREATE SUMMARY TABLE
% ====================================================================
scenario_summary = table(scenario_names(:),safe_mode_load_cases_W(:),battery_capacity_cases_Wh(:),minimum_soc_results_percent,final_soc_results_percent,unserved_load_results_Wh,feasibility_results,'VariableNames',{'Scenario','Safe_Load_W','Battery_capacity_Wh','Minimum_soc_percent','Final_soc_percent','Unserved_Load_Wh','Feasibility'});

%% =================================================================
% 15 . DISPLAY INTEGRATED ORBIT AND SOLAR RESULTS
% ====================================================================
fprintf('\n===========================================================\n');
fprintf('\n-- ORBITAL MODEL--\n');
fprintf('Orbit altitude   : %.2f km \n',altitude_m / 1000);
fprintf('orbit radius   : %.2f km \n',orbital_radius_m/ 1000);
fprintf('orbital period   : %.2f minutes \n',orbital_period_min);
fprintf('orbital speed   :%.3f km/s \n ',orbital_speed_mps / 1000);
fprintf('Beta angle   %.2f derees\n',beta_angle_deg);
fprintf('critical beta angle : %.2f degrees \n',critical_beta_deg);
fprintf('analytical eclipse model   : %.2F minutes \n',eclipse_duration_min_analytical);
fprintf('sampled eclipse duration   : % .2f minutes \n',sampled_eclipse_duration_min);

fprintf('\n -- SOLAR ARRAY MODEL ---\n');
fprintf('BOL efficiency  : %.2f %%\n',solar_array_efficiency_BOL*100);
fprintf('EOL efficiency  : %.2f %%\n',solar_array_efficiency_EOL*100);
fprintf('EOL solar-array power  : % .2f W\n',solar_array_power_EOL_W);

%% ======================================================================]
% 16 . DISPLAY SCENATIO SUMMARY 
% ===========================================================================
fprintf('\n --- SCENRIO PERFORMACE SUMMARY---\n');
disp(scenario_summary);

%% ========================================================================
% 17 . DISPLAY ENERGY ACCOUNTING RESIDUALS
%======================================================================
fprintf('\n ---ENERGY ACCOUNTING RESIDUALS---\n');
energy_check_table =  table(scenario_names(:),load_balance_residuals_Wh,battery_balance_residuals_Wh,solar_balance_residuals_Wh,'VariableNames',{'scenario','load_balance_residuals_Wh' ,'battery_balance_residual_Wh','Solar_Balance_residual_Wh'});
disp(energy_check_table);


%% =====================================================================
% 18 . DISPLAY BASELINE SYSTEM PERFORMANCE
% =====================================================================

fprintf('\n --- BASELINE SCENARIO DETAILS---\n');
fprintf('Minimum battery soc   : %.2f %% \n',minimum_soc_results_percent(1));
fprintf('Final battery soc   : %.2f%% \n',final_soc_results_percent(1));
fprintf('Unserved spacecraft load %.6f Wh \n',unserved_load_results_Wh(1));
fprintf('Charging losses   : %.2f Wh \n',charging_loss_results_Wh(1));
fprintf('Discharging losses   : %.2f Wh \n',discharging_loss_results_Wh(1));
fprintf('Curtailed solar energy   : %.2f Wh \n',curtailed_solar_results_Wh(1));

%%=========================================================================
% 19 . FIGURE 1 : BASELINE INTERGRATED SIMULATION
% =========================================================================
baseline = scenario_results(1);
fig1 = figure('Name','Day 9 - integrated baseline simulation');
subplot(4,1,1);
stairs(time_min,baseline.solar_power_W , 'LineWidth',1.3);
hold on;
plot(time_min,baseline.load_profile_W,'LineWidth',1.2);
xlabel('Time(minutes)');
ylabel('Power(W)');
title('Intergrated solar power and spacecraft dynamic load');
legend('EOL solar power ','Spacecraft load','Location','best');
grid on;
subplot(4,1,2);
plot(time_min,baseline.power_margin_W,'LineWidth',1.3);
hold on;
yline(0,'--','Zero power margin');
xlabel('Tie(minutes)');
ylabel('Power margin (W)');
title('Integrated Electrical power Margin');
grid on;
subplot(4,1,3);
plot(time_min,baseline.battery_soc_percent,'LineWidth',1.3);
hold on;
yline(minimum_allowed_soc_percent,'--','Minimum permitted soc');
yline(100,':','Maximum soc');
xlabel('Time(minutes)');
ylabel('Battery soc (%)');
title('Integrated battery state of charge');
ylim([0 105]);
grid on ;
subplot(4,1,4);
stairs(time_min,baseline.operating_mode_code,'LineWidth',1.3);
xlabel('TIme(minutes)');
ylabel('operating mode');
title('Intergrated spacecraft operational mode');
yticks(1:4);
yticklabels({'Safe','Nominal','Science','Comms'});
ylim([0.5 4.5]);
grid on;

%% =========================================================================
% . 20 . FIGURE 2 : COMPARE BATTERY SOC IN ALL SCENARIOS
% =====================================================================
fig2 = figure('Name','Day 9 - scenario battery comparison');
hold on;
for s=1 : number_of_scenarios
plot(time_min,scenario_results(s).battery_soc_percent,'LineWidth',1.3);
end
yline(minimum_allowed_soc_percent,'--','Minimum permitted soc');
xlabel('Time(minutes)');
ylabel('Battery soc(%)');
title('Battery soc under three system - level scenarios');
legend('Baseline','High-load stress ','Low capacity battery','Minimum permtited soc','location','best');
ylim([0 105]);
grid on;


%% =======================================================================
% 21. FIGURE 3 : UNSERVED LOAD COMPARISION
% -----------------------------------------------------------------------
fig3 = figure('Name','day 9 - Unserved load compariosn');
bar(unserved_load_results_Wh);
xlabel('Scenario');
ylabel('Unserved load energy (Wh)');
title('Spacecraft Electrcal load not supplies ');
set(gca,'XTick',1:number_of_scenarios);
set(gca,'XTicklabel',scenario_names);
grid on;


%% ===================================================================
% 22 . SAVE FINAL FIGURES AND DATA
% ======================================================================
script_folder = fileparts(mfilename('fullpath'));
results_folder = fullfile(script_folder,'results');
if ~exist(results_folder,'dir')
    mkdir(results_folder);
end
saveas(fig1,fullfile(results_folder,'day 9_intergrated_baseline.png'));
saveas(fig2,fullfile(results_folder,'day9_scenario_battery_comparison.png'));
saveas(fig3,fullfile(results_folder,'day9_unserved_load_comparison.png'));

%% -====================================================================
% 23 . SAVE THE COMPLETE NUMERICAL RESULTS
% ======================================================================
save(fullfile(results_folder,'day9_intergrated_eps_results.mat'),'scenario_results','scenario_summary','energy_check_table','time_s','time_min','orbital_period_s','orbital_radius_m','orbital_speed_mps','beta_angle_deg','critical_beta_deg','eclipse_duration_min_analytical','sampled_eclipse_duration_min','solar_array_power_EOL_W','is_eclipse');


%% =========================================================================
% 24 . FINAL SYSTEM - LEVEL VALIDATION
% =========================================================================
fprintf('\n---FINAL SYSTEM-LEVEL VALIDATION---\n');
for s = 1:number_of_scenarios
    fprintf('\n scenario : % s\n',scenario_names{s});
    if feasibility_results(s) 
        fprintf('results: FEASIBLE under the defined asssumptions.\n');
    else
        fprintf('Result : NOT FEASIBLE UNDER THE DEFINED ASSUPTION.\n');
    end
    if abs(load_balance_residuals_Wh(s)) < 1e-6 && abs(battery_balance_residuals_Wh(s)) < 1e-6 &&  abs(solar_balance_residuals_Wh(s)) < 1e-6 
        fprintf('Energy acounting : PASSED.\n');
    else
        fprintf('Energy acounting : CHECK REQUIRED .\n');
    end
end
fprintf('\n ===============================================\n');
fprintf('DAY 9 INTERGRATED SIMULATION COMPLETED \n');
fprintf('======================================================');
fprintf('\n All day 9 figures and date have een saved .\n');





             


