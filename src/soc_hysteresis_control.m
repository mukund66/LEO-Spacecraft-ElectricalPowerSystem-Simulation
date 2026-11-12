%% DAY 9.5: SOC-FEEDBACK HYSTERESIS LOAD-SHEDDING CONTROL
%
% Project: LEO Spacecraft Electrical Power System Simulator
%
% Purpose:
% Compare an uncontrolled spacecraft load schedule against
% a battery-SoC feedback-based payload load-shedding controller.
%
% Control thresholds:
% OFF threshold = 45% SoC
% ON threshold = 60% SoC
%
% Simulation:
% 20 orbital periods, beta angle = 30 degrees.
%
% Important:
% This is an illustrative hybrid feedback-control experiment.
% It is not a flight-qualified spacecraft controller.

clc;
clear;
close all;


%% 1. ORBITAL PARAMETERS

earth_radius_m = 6371e3;

altitude_m = 400e3;

earth_mu_m3_s2 = 3.986004418e14;

orbital_radius_m = earth_radius_m + altitude_m;

orbital_period_s = ...
    2*pi*sqrt(orbital_radius_m^3/earth_mu_m3_s2);

orbital_period_min = orbital_period_s/60;

angular_velocity_radps = ...
    sqrt(earth_mu_m3_s2/orbital_radius_m^3);

beta_angle_deg = 30;

beta_angle_rad = deg2rad(beta_angle_deg);


%% 2. ECLIPSE GEOMETRY

sunward_projection_m = [];

critical_beta_rad = ...
    asin(earth_radius_m/orbital_radius_m);

critical_beta_deg = rad2deg(critical_beta_rad);

if abs(beta_angle_deg) < critical_beta_deg

    eclipse_half_angle_rad = acos( ...
        sqrt(1-(earth_radius_m/orbital_radius_m)^2) ...
        /cos(beta_angle_rad));

    theoretical_eclipse_duration_s = ...
        (orbital_period_s/pi)*eclipse_half_angle_rad;

else

    theoretical_eclipse_duration_s = 0;

end

theoretical_eclipse_duration_min = ...
    theoretical_eclipse_duration_s/60;


%% 3. SOLAR ARRAY AT END OF LIFE

solar_irradiance_W_m2 = 1361;

solar_array_area_m2 = 2.5;

solar_array_efficiency_BOL = 0.28;

annual_degradation_rate = 0.02;

mission_life_years = 5;

solar_array_efficiency_EOL = ...
    solar_array_efficiency_BOL * ...
    (1-annual_degradation_rate)^mission_life_years;

solar_array_power_EOL_W = ...
    solar_irradiance_W_m2 * ...
    solar_array_area_m2 * ...
    solar_array_efficiency_EOL;


%% 4. SPACECRAFT OPERATING LOADS

safe_mode_load_W = 400;

nominal_mode_load_W = 500;

science_mode_load_W = 800;

communications_mode_load_W = 900;


%% 5. BATTERY PARAMETERS

battery_capacity_Wh = 1000;

initial_SoC_percent = 100;

minimum_allowed_SoC_percent = 20;

charging_efficiency = 0.95;

discharging_efficiency = 0.95;

minimum_battery_energy_Wh = ...
    battery_capacity_Wh * ...
    minimum_allowed_SoC_percent/100;


%% 6. HYSTERESIS CONTROLLER PARAMETERS

SoC_OFF_threshold_percent = 45;

SoC_ON_threshold_percent = 60;

% OFF threshold must be below ON threshold.

if SoC_OFF_threshold_percent >= SoC_ON_threshold_percent

    error('Controller OFF threshold must be lower than ON threshold.');

end

% The controller initially permits payload operation.

initial_payload_enabled = true;


%% 7. SIMULATION TIME

number_of_orbits = 20;

simulation_duration_s = ...
    number_of_orbits*orbital_period_s;

time_step_s = 10;

time_s = 0:time_step_s: ...
    floor(simulation_duration_s/time_step_s)*time_step_s;

time_min = time_s/60;

delta_time_h = time_step_s/3600;

number_of_samples = numel(time_s);


%% 8. CALCULATE ORBITAL POSITION

orbital_angle_rad = ...
    mod(angular_velocity_radps*time_s,2*pi);

time_in_orbit_min = ...
    mod(time_min,orbital_period_min);


%% 9. DETECT ECLIPSE USING VECTOR GEOMETRY

sunward_projection_m = ...
    orbital_radius_m * ...
    cos(orbital_angle_rad) * ...
    cos(beta_angle_rad);

perpendicular_distance_m = sqrt(max( ...
    orbital_radius_m^2-sunward_projection_m.^2,0));

is_eclipse = ...
    (sunward_projection_m < 0) & ...
    (perpendicular_distance_m <= earth_radius_m);


%% 10. CREATE SOLAR POWER PROFILE

solar_power_W = zeros(size(time_s));

solar_power_W(~is_eclipse) = ...
    solar_array_power_EOL_W;


%% 11. CREATE SCHEDULED PAYLOAD WINDOWS

science_window = ...
    (time_in_orbit_min >= 0) & ...
    (time_in_orbit_min < 20);

communications_window = ...
    (time_in_orbit_min >= 75) & ...
    (time_in_orbit_min < 82);

payload_scheduled = ...
    science_window | communications_window;


%% 12. RUN OPEN-LOOP SIMULATION

open_loop = simulate_eps_case( ...
    false, ...
    time_s, ...
    time_step_s, ...
    time_in_orbit_min, ...
    is_eclipse, ...
    solar_power_W, ...
    science_window, ...
    communications_window, ...
    safe_mode_load_W, ...
    nominal_mode_load_W, ...
    science_mode_load_W, ...
    communications_mode_load_W, ...
    battery_capacity_Wh, ...
    initial_SoC_percent, ...
    minimum_allowed_SoC_percent, ...
    charging_efficiency, ...
    discharging_efficiency, ...
    initial_payload_enabled, ...
    SoC_OFF_threshold_percent, ...
    SoC_ON_threshold_percent);


%% 13. RUN CLOSED-LOOP HYSTERESIS CONTROL SIMULATION

closed_loop = simulate_eps_case( ...
    true, ...
    time_s, ...
    time_step_s, ...
    time_in_orbit_min, ...
    is_eclipse, ...
    solar_power_W, ...
    science_window, ...
    communications_window, ...
    safe_mode_load_W, ...
    nominal_mode_load_W, ...
    science_mode_load_W, ...
    communications_mode_load_W, ...
    battery_capacity_Wh, ...
    initial_SoC_percent, ...
    minimum_allowed_SoC_percent, ...
    charging_efficiency, ...
    discharging_efficiency, ...
    initial_payload_enabled, ...
    SoC_OFF_threshold_percent, ...
    SoC_ON_threshold_percent);


%% 14. SAMPLE BATTERY SOC AT ORBIT STARTS

orbit_numbers = 0:number_of_orbits;

orbit_sample_indices = zeros(size(orbit_numbers));

for k = 1:numel(orbit_numbers)

    target_time_s = orbit_numbers(k)*orbital_period_s;

    [~,orbit_sample_indices(k)] = ...
        min(abs(time_s-target_time_s));

end

open_loop_orbit_SoC = open_loop.battery_SoC_percent(orbit_sample_indices);

closed_loop_orbit_SoC = ...
    closed_loop.battery_SoC_percent(orbit_sample_indices);

orbit_summary = table( ...
    orbit_numbers(:), ...
    open_loop_orbit_SoC(:), ...
    closed_loop_orbit_SoC(:), ...
    'VariableNames', { ...
    'Orbit_Number', ...
    'Open_Loop_Start_SoC_percent', ...
    'Controlled_Start_SoC_percent'});


%% 15. CREATE PERFORMANCE COMPARISON TABLE

control_case = {'Open loop';'Hysteresis feedback'};

minimum_SoC_results = [ open_loop.minimum_SoC_percent;closed_loop.minimum_SoC_percent];

final_SoC_results = [ ...
    open_loop.final_SoC_percent; ...
    closed_loop.final_SoC_percent];

unserved_energy_results = [ ...
    open_loop.total_unserved_load_Wh; ...
    closed_loop.total_unserved_load_Wh];

payload_shed_time_results = [ ...
    open_loop.payload_shed_time_min; ...
    closed_loop.payload_shed_time_min];

controller_switch_results = [ ...
    open_loop.number_of_controller_switches; ...
    closed_loop.number_of_controller_switches];

comparison_table = table( ...
    control_case, ...
    minimum_SoC_results, ...
    final_SoC_results, ...
    unserved_energy_results, ...
    payload_shed_time_results, ...
    controller_switch_results, ...
    'VariableNames', { ...
    'Control_Case', ...
    'Minimum_SoC_percent', ...
    'Final_SoC_percent', ...
    'Unserved_Load_Wh', ...
    'Payload_Shed_Time_min', ...
    'Controller_Switches'});


%% 16. DISPLAY ORBITAL AND SOLAR PARAMETERS

fprintf('\n============================================\n');

fprintf('DAY 9.5: SOC FEEDBACK CONTROL EXPERIMENT\n');

fprintf('============================================\n');

fprintf('\n--- ORBIT ---\n');

fprintf('Orbital period : %.2f minutes\n', ...
    orbital_period_min);

fprintf('Beta angle : %.2f degrees\n', ...
    beta_angle_deg);

fprintf('Critical beta angle : %.2f degrees\n', ...
    critical_beta_deg);

fprintf('Eclipse duration : %.2f minutes\n', ...
    theoretical_eclipse_duration_min);


fprintf('\n--- SOLAR ARRAY ---\n');

fprintf('Solar array area : %.2f m2\n', ...
    solar_array_area_m2);

fprintf('EOL efficiency : %.2f %%\n', ...
    solar_array_efficiency_EOL*100);

fprintf('EOL solar power : %.2f W\n', ...
    solar_array_power_EOL_W);


fprintf('\n--- HYSTERESIS CONTROLLER ---\n');

fprintf('Payload OFF threshold : %.2f %% SoC\n', ...
    SoC_OFF_threshold_percent);

fprintf('Payload ON threshold : %.2f %% SoC\n', ...
    SoC_ON_threshold_percent);


%% 17. DISPLAY PERFORMANCE RESULTS

fprintf('\n--- CONTROL COMPARISON ---\n');

disp(comparison_table);


fprintf('\n--- ORBIT-TO-ORBIT SOC ---\n');

disp(orbit_summary);


%% 18. CHECK CONTROLLED SYSTEM

fprintf('\n--- CONTROL SYSTEM VALIDATION ---\n');

fprintf('Minimum controlled SoC : %.2f %%\n', ...
    closed_loop.minimum_SoC_percent);

fprintf('Final controlled SoC : %.2f %%\n', ...
    closed_loop.final_SoC_percent);

fprintf('Controlled unserved load: %.6f Wh\n', ...
    closed_loop.total_unserved_load_Wh);

if closed_loop.minimum_SoC_percent >= ...
        minimum_allowed_SoC_percent-1e-6

    fprintf('Battery reserve: RESPECTED.\n');

else

    fprintf('Battery reserve: VIOLATED.\n');

end

if closed_loop.total_unserved_load_Wh < 1e-6

    fprintf('Spacecraft load supply: PASSED.\n');

else

    fprintf('Spacecraft load supply: FAILED.\n');

end

if abs(closed_loop.load_balance_residual_Wh) < 1e-6 && ...
   abs(closed_loop.battery_balance_residual_Wh) < 1e-6 && ...
   abs(closed_loop.solar_balance_residual_Wh) < 1e-6

    fprintf('Energy accounting: PASSED.\n');

else

    fprintf('Energy accounting: CHECK REQUIRED.\n');

end


%% 19. FIGURE 1: OPEN-LOOP VERSUS CONTROLLED SOC

fig1 = figure( ...
    'Name','Day 9.5 - Open Loop and Closed Loop SoC');

plot(time_min,open_loop.battery_SoC_percent, ...
    'LineWidth',1.2);

hold on;

plot(time_min,closed_loop.battery_SoC_percent, ...
    'LineWidth',1.3);

yline(minimum_allowed_SoC_percent,'--', ...
    'Minimum permitted SoC');

yline(SoC_OFF_threshold_percent,':', ...
    'Payload OFF threshold');

yline(SoC_ON_threshold_percent,':', ...
    'Payload ON threshold');

xlabel('Simulation time (minutes)');

ylabel('Battery SoC (%)');

title('Open-Loop and Hysteresis-Controlled Battery SoC');

legend('Open loop', ...
       'Hysteresis control', ...
       'Minimum permitted SoC', ...
       'OFF threshold', ...
       'ON threshold', ...
       'Location','best');

ylim([0 105]);

grid on;


%% 20. FIGURE 2: ORBIT-TO-ORBIT SOC

fig2 = figure( ...
    'Name','Day 9.5 - Orbit to Orbit SoC');

plot(orbit_numbers,open_loop_orbit_SoC, ...
    'o-','LineWidth',1.3);

hold on;

plot(orbit_numbers,closed_loop_orbit_SoC, ...
    's-','LineWidth',1.3);

yline(minimum_allowed_SoC_percent,'--', ...
    'Minimum permitted SoC');

xlabel('Orbit number');

ylabel('SoC at orbit start (%)');

title('Orbit-to-Orbit Battery State');

legend('Open loop', ...
       'Hysteresis control', ...
       'Minimum permitted SoC', ...
       'Location','best');

grid on;


%% 21. FIGURE 3: CONTROLLED LOAD AND CONTROLLER STATE

fig3 = figure( ...
    'Name','Day 9.5 - Hysteresis Controller Operation');

subplot(3,1,1);

plot(time_min,closed_loop.solar_power_W, ...
    'LineWidth',1.2);

hold on;

plot(time_min,closed_loop.load_profile_W, ...
    'LineWidth',1.2);

xlabel('Simulation time (minutes)');

ylabel('Power (W)');

title('Solar Power and Controlled Spacecraft Load');

legend('Solar power','Spacecraft load', ...
    'Location','best');

grid on;


subplot(3,1,2);

stairs(time_min,double(closed_loop.payload_enabled), ...
    'LineWidth',1.3);

xlabel('Simulation time (minutes)');

ylabel('Payload state');

title('Payload Enable/Disable State');

yticks([0 1]);

yticklabels({'Disabled','Enabled'});

ylim([-0.2 1.2]);

grid on;


subplot(3,1,3);

plot(time_min,closed_loop.battery_SoC_percent, ...
    'LineWidth',1.3);

hold on;

yline(SoC_OFF_threshold_percent,'--','OFF');

yline(SoC_ON_threshold_percent,'--','ON');

yline(minimum_allowed_SoC_percent,':','Reserve');

xlabel('Simulation time (minutes)');

ylabel('Battery SoC (%)');

title('Battery State During Feedback Control');

ylim([0 105]);

grid on;


%% 22. FIGURE 4: UNSERVED ENERGY COMPARISON

fig4 = figure( ...
    'Name','Day 9.5 - Unserved Energy Comparison');

bar([open_loop.total_unserved_load_Wh, ...
     closed_loop.total_unserved_load_Wh]);

set(gca,'XTick',1:2);

set(gca,'XTickLabel',{'Open loop','Hysteresis control'});

ylabel('Unserved energy (Wh)');

title('Effect of Feedback Control on Unserved Energy');

grid on;


%% 23. SAVE THE RESULTS

script_folder = fileparts(mfilename('fullpath'));

project_folder = fileparts(script_folder);

results_folder = fullfile(project_folder,'results');

if ~exist(results_folder,'dir')

    mkdir(results_folder);

end

saveas(fig1,fullfile(results_folder, ...
    'day9_5_open_loop_vs_controlled_soc.png'));

saveas(fig2,fullfile(results_folder, ...
    'day9_5_orbit_to_orbit_soc.png'));

saveas(fig3,fullfile(results_folder, ...
    'day9_5_controller_operation.png'));

saveas(fig4,fullfile(results_folder, ...
    'day9_5_unserved_energy_comparison.png'));

save(fullfile(results_folder, ...
    'day9_5_hysteresis_control_results.mat'), ...
    'comparison_table', ...
    'orbit_summary', ...
    'open_loop', ...
    'closed_loop', ...
    'beta_angle_deg', ...
    'solar_array_area_m2', ...
    'solar_array_efficiency_EOL', ...
    'solar_array_power_EOL_W', ...
    'SoC_OFF_threshold_percent', ...
    'SoC_ON_threshold_percent', ...
    'time_s', ...
    'time_min');


fprintf('\nDay 9.5 experiment and figures saved.\n');

fprintf('\n============================================\n');

fprintf('FEEDBACK CONTROL EXPERIMENT COMPLETED\n');

fprintf('============================================\n');


%% ============================================================
% LOCAL FUNCTION: BATTERY AND LOAD SIMULATION
% =============================================================

function result = simulate_eps_case( ...
    use_controller, ...
    time_s, ...
    time_step_s, ...
    time_in_orbit_min, ...
    is_eclipse, ...
    solar_power_W, ...
    science_window, ...
    communications_window, ...
    safe_mode_load_W, ...
    nominal_mode_load_W, ...
    science_mode_load_W, ...
    communications_mode_load_W, ...
    battery_capacity_Wh, ...
    initial_SoC_percent, ...
    minimum_allowed_SoC_percent, ...
    charging_efficiency, ...
    discharging_efficiency, ...
    initial_payload_enabled, ...
    SoC_OFF_threshold_percent, ...
    SoC_ON_threshold_percent)

    %% Function setup

    number_of_samples = numel(time_s);

    delta_time_h = time_step_s/3600;

    initial_energy_Wh = ...
        battery_capacity_Wh*initial_SoC_percent/100;

    minimum_energy_Wh = ...
        battery_capacity_Wh*minimum_allowed_SoC_percent/100;

    battery_energy_Wh = zeros(size(time_s));

    battery_SoC_percent = zeros(size(time_s));

    load_profile_W = zeros(size(time_s));

    operating_mode_code = zeros(size(time_s));

    payload_enabled = ...
        false(size(time_s));

    solar_to_load_Wh = zeros(size(time_s));

    battery_to_load_Wh = zeros(size(time_s));

    battery_energy_stored_Wh = zeros(size(time_s));

    battery_energy_removed_Wh = zeros(size(time_s));

    charging_input_Wh = zeros(size(time_s));

    unserved_energy_Wh = zeros(size(time_s));

    charging_loss_Wh = zeros(size(time_s));

    discharging_loss_Wh = zeros(size(time_s));

    curtailed_solar_Wh = zeros(size(time_s));

    battery_energy_Wh(1) = initial_energy_Wh;

    battery_SoC_percent(1) = initial_SoC_percent;

    payload_state = initial_payload_enabled;


    %% Time-step simulation

    for k = 1:number_of_samples-1

        current_SoC_percent = ...
            100*battery_energy_Wh(k)/battery_capacity_Wh;


        %% Hysteresis feedback law

        if use_controller

            if payload_state && ...
                    current_SoC_percent <= SoC_OFF_threshold_percent

                payload_state = false;

            elseif ~payload_state && ...
                    current_SoC_percent >= SoC_ON_threshold_percent

                payload_state = true;

            end

        else

            % Open-loop reference: payload always enabled.

            payload_state = true;

        end

        payload_enabled(k) = payload_state;


        %% Determine spacecraft operating mode

        if is_eclipse(k)

            selected_load_W = safe_mode_load_W;

            operating_mode_code(k) = 1;

        elseif science_window(k) && payload_state

            selected_load_W = science_mode_load_W;

            operating_mode_code(k) = 3;

        elseif communications_window(k) && payload_state

            selected_load_W = communications_mode_load_W;

            operating_mode_code(k) = 4;

        else

            % If payload activity is disabled, spacecraft
            % retains the nominal essential load.

            selected_load_W = nominal_mode_load_W;

            operating_mode_code(k) = 2;

        end

        load_profile_W(k) = selected_load_W;


        %% Calculate energy demanded and solar energy available

        load_demand_Wh = ...
            selected_load_W*delta_time_h;

        available_solar_Wh = ...
            solar_power_W(k)*delta_time_h;


        %% Case A: Solar power fully supplies the load

        if solar_power_W(k) >= selected_load_W

            solar_to_load_Wh(k) = load_demand_Wh;

            surplus_solar_Wh = ...
                available_solar_Wh-load_demand_Wh;

            battery_headroom_Wh = ...
                battery_capacity_Wh-battery_energy_Wh(k);

            stored_energy_Wh = min( ...
                surplus_solar_Wh*charging_efficiency, ...
                battery_headroom_Wh);

            actual_charging_input_Wh = ...
                stored_energy_Wh/charging_efficiency;

            charging_loss_Wh(k) = ...
                actual_charging_input_Wh-stored_energy_Wh;

            curtailed_solar_Wh(k) = max( ...
                surplus_solar_Wh-actual_charging_input_Wh,0);

            battery_energy_Wh(k+1) = ...
                battery_energy_Wh(k)+stored_energy_Wh;

            battery_energy_stored_Wh(k) = stored_energy_Wh;

            charging_input_Wh(k) = actual_charging_input_Wh;


        %% Case B: Battery must supply the load deficit

        else

            solar_to_load_Wh(k) = available_solar_Wh;

            deficit_Wh = ...
                load_demand_Wh-solar_to_load_Wh(k);

            required_battery_energy_Wh = ...
                deficit_Wh/discharging_efficiency;

            available_battery_energy_Wh = max( ...
                battery_energy_Wh(k)-minimum_energy_Wh,0);

            actual_energy_drawn_Wh = min( ...
                required_battery_energy_Wh, ...
                available_battery_energy_Wh);

            delivered_energy_Wh = ...
                actual_energy_drawn_Wh*discharging_efficiency;

            unserved_energy_Wh(k) = max( ...
                deficit_Wh-delivered_energy_Wh,0);

            discharging_loss_Wh(k) = ...
                actual_energy_drawn_Wh-delivered_energy_Wh;

            battery_energy_Wh(k+1) = ...
                battery_energy_Wh(k)-actual_energy_drawn_Wh;

            battery_energy_removed_Wh(k) = ...
                actual_energy_drawn_Wh;

            battery_to_load_Wh(k) = ...
                delivered_energy_Wh;

        end


        %% Update battery SoC

        battery_SoC_percent(k+1) = ...
            100*battery_energy_Wh(k+1)/battery_capacity_Wh;

    end


    %% Copy final sample status for plotting

    payload_enabled(end) = payload_enabled(end-1);

    load_profile_W(end) = load_profile_W(end-1);

    operating_mode_code(end) = operating_mode_code(end-1);


    %% Calculate performance metrics

    minimum_observed_SoC_percent = ...
        min(battery_SoC_percent);

    final_observed_SoC_percent = ...
        battery_SoC_percent(end);

    total_load_energy_Wh = ...
        sum(load_profile_W(1:end-1))*delta_time_h;

    total_solar_energy_Wh = ...
        sum(solar_power_W(1:end-1))*delta_time_h;

    total_solar_to_load_Wh =  sum(solar_to_load_Wh);

    total_battery_to_load_Wh = sum(battery_to_load_Wh);
    total_battery_energy_stored_Wh = sum(battery_energy_stored_Wh);
    total_battery_energy_removed_Wh = sum(battery_energy_removed_Wh);
    total_charging_input_Wh = sum(charging_input_Wh);
    total_unserved_load_Wh = sum(unserved_energy_Wh);
    total_charging_loss_Wh = sum(charging_loss_Wh);
    total_discharging_loss_Wh = sum(discharging_loss_Wh);
    total_curtailed_solar_Wh = sum(curtailed_solar_Wh);

    % Payload time lost: scheduled payload windows while disabled
    payload_scheduled = science_window | communications_window;
    shed_samples = payload_scheduled(1:end-1) & ~payload_enabled(1:end-1);
    payload_shed_time_min = sum(shed_samples)*time_step_s/60;

    % Number of controller state changes
    number_of_controller_switches = ...
        sum(abs(diff(double(payload_enabled(1:end-1)))));

    % Energy accounting checks
    load_balance_residual_Wh = total_load_energy_Wh ...
        - total_solar_to_load_Wh ...
        - total_battery_to_load_Wh ...
        - total_unserved_load_Wh;

    battery_balance_residual_Wh = battery_energy_Wh(end) ...
        - (initial_energy_Wh + total_battery_energy_stored_Wh ...
        - total_battery_energy_removed_Wh);

    solar_balance_residual_Wh = total_solar_energy_Wh ...
        - total_solar_to_load_Wh ...
        - total_charging_input_Wh ...
        - total_curtailed_solar_Wh;

    % Output structure
    result.battery_energy_Wh = battery_energy_Wh;
    result.battery_SoC_percent = battery_SoC_percent;
    result.load_profile_W = load_profile_W;
    result.solar_power_W = solar_power_W;
    result.operating_mode_code = operating_mode_code;
    result.payload_enabled = payload_enabled;
    result.minimum_SoC_percent = minimum_observed_SoC_percent;
    result.final_SoC_percent = final_observed_SoC_percent;
    result.total_unserved_load_Wh = total_unserved_load_Wh;
    result.total_charging_loss_Wh = total_charging_loss_Wh;
    result.total_discharging_loss_Wh = total_discharging_loss_Wh;
    result.total_curtailed_solar_Wh = total_curtailed_solar_Wh;
    result.payload_shed_time_min = payload_shed_time_min;
    result.number_of_controller_switches = number_of_controller_switches;
    result.load_balance_residual_Wh = load_balance_residual_Wh;
    result.battery_balance_residual_Wh = battery_balance_residual_Wh;
    result.solar_balance_residual_Wh = solar_balance_residual_Wh;

end