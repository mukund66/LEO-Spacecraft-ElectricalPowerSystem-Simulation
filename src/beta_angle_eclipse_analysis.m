%% DAY 8 : BETA ANGLE AND ECLIPSE SENSITIVITY ANALYSIS
% PROJECT : LEO SPACECRAFT ELECTRICAL POWER SYSTEM SIMULATOR 
% OBJECTIVES : 
% 1 . Understand orbital beta angle
% 2 . Caluclate the critical beta angle 
% 3 . Caluclate eclipse duratin at different bera angles 
% 4 . Use vector geometry to detect eclipse condition 
% 5 . Study the effect of beta angle on battery SOC .
% 6 . Compare analytical and time-sampled eclipse duration
%
%ASSUMPTION :
% CIRCULAR ORBIT, spherical earth ,cylindrical shadow
% Ideal Sun - pointing solar array and fixed EOL efficiency 
%
% Operational loads are illustrative , carried forward from Day 7 .


clc;
clear;
close all;

%% 1 . DEFINE CONSTANTS
earth_radius_m = 6371e3;
altitude_m = 400e3;
earth_mu_m3_s2 = 3.986004418e14;
orbital_radius_m =  earth_radius_m + altitude_m;
orbital_period_s = 2*pi*sqrt(orbital_radius_m^3/earth_mu_m3_s2);
orbital_period_min = orbital_period_s / 60 ;
angular_veloctiy_radps = sqrt(earth_mu_m3_s2/orbital_radius_m^3);

%% 2 . CALUCLATE CIRCULAR BETA ANGLE
critical_beta_rad = asin(earth_radius_m / orbital_radius_m);
critical_beta_deg = rad2deg(critical_beta_rad);
fprintf('\n==== DAY 8 : BETA ANGLE ANALYSIS====\n');
fprintf('\n--ORBIT INFORMATION---\n');
fprintf('Orbital radius   : %.2f km \n',orbital_radius_m / 1000);
fprintf('orbital period   : %.2f minutes \n',orbital_period_min);
fprintf('Critical beta angle   : %.2f degrees \n',critical_beta_deg);

%% 3 . SOLAR ARRAY PARAMETERS : EOL CONDITION
solar_irrandiance_W_m2 = 1361;
solar_array_area_m2 = 5;
solar_array_efficiency_BOL = 0.28;
spacecraft_load_W = 800;
annual_degration_rate = 0.02;
mission_life_years = 5 ; 
solar_array_efficiency_EOL = solar_array_efficiency_BOL * (1-annual_degration_rate)^mission_life_years;
solar_array_power_EOL_W =  solar_irrandiance_W_m2 * solar_array_area_m2 * solar_array_efficiency_EOL;

%% 4 . SPACECRAFT OPERATIONAL LOADS 
safe_mode_load_W = 400 ;
nominal_mode_load_W = 500 ;
science_mode_load_W = 800;
communication_mode_load_W = 900 ;

%% 5 . BATTERY PARAMETERS
battery_capacity_Wh = 1000;
initial_soc_percent = 100;
minimum_soc_percent = 20;
charging_efficiency = 0.95;
discharging_efficiency = 0.95;
initial_battery_energy_Wh = battery_capacity_Wh*initial_soc_percent/ 100;
maximun_battery_energy_Wh = battery_capacity_Wh;
minimum_battery_energy_Wh =  battery_capacity_Wh * minimum_soc_percent /100; 

%% 6 . SIMUALTION TIME 
number_of_orbits = 2;
simulation_duration_s = number_of_orbits*orbital_period_s;
time_step_s = 10;
time_s = 0 : time_step_s : floor(simulation_duration_s / time_step_s)*time_step_s;
time_min = time_s / 60;
delta_time_h = time_step_s / 3600 ; 
number_of_samples = numel(time_s);
orbital_angle_rad = mod(angular_veloctiy_radps * time_s , 2 * pi);
time_in_orbit_min = mod(time_min , orbital_period_min) ;

%% 7 . DEFINE BETA ANGLES TO INVESTIGATE 
beta_angles_deg= [0 15 30 45 60 70 71 72];
number_of_beta_cases = numel(beta_angles_deg);

%% 8 . INITIALISE RESULT ARAYS
eclipse_duration_analytical_min = zeros(1,number_of_beta_cases);
eclipse_duration_sampled_min = zeros(1, number_of_beta_cases);
sunlight_duration_analytical_min = zeros(1, number_of_beta_cases);
minimum_soc_all_percent = zeros(1,number_of_beta_cases);
final_soc_all_percent = zeros(1, number_of_beta_cases);
unserved_load_all_Wh = zeros(1, number_of_beta_cases);
battery_soc_all_percent = zeros(number_of_beta_cases, number_of_samples);

%% 9 . SELECT THE BETA ANGLES FOR BATTERY COMPARISION 
% We will compare the battery behaviour at : 
% Beta = 0 degrees ;
% Beta = 30 degrees ;
% Beta = 60 degrees ; 
beta_comparision_deg = [0 30 60];
beta_comparision_indices = zeros(1, numel(beta_comparision_deg));
for k = 1 : numel(beta_comparision_deg)
    beta_comparision_indices(k) = find(beta_angles_deg == beta_comparision_deg(k),1);
end

%% 10 . INITIALISE Day 7 DEMONSTRATION ARRAYS
solar_power_beta30_W = zeros(size(time_s));
load_profile_beta30_W = zeros(size(time_s));
power_margin_beta30_W = zeros(size(time_s));
battery_soc_beta30_percent = zeros(size(time_s));
operating_mode_beta30 = zeros(size(time_s));
eclipse_beta30 = false(size(time_s));

%% 11 . LOOP THROUGH ALL BETA ANGLES
for i = 1 : number_of_beta_cases 

    %% 11A . CONVERT BETA ANGLES TO RADIANS 
    beta_angle_rad = deg2rad(beta_angles_deg(i));

    %% 11B . CALUCLATE ANALYTICAL ECLIPSE DURATION 
    if abs(beta_angles_deg(i)) < critical_beta_deg
        eclipse_half_angle_rad = acos(   sqrt(1-(earth_radius_m/orbital_radius_m)^2)   / cos(beta_angle_rad));

        eclipse_duration_s_analytical = (orbital_period_s/pi)*eclipse_half_angle_rad;
    else
        eclipse_duration_s_analytical = 0;
    end
   eclipse_duration_analytical_min(i) = eclipse_duration_s_analytical / 60 ;
   sunlight_duration_analytical_min(i) = orbital_period_min - eclipse_duration_analytical_min(i) ;

   %% 11C . DETECT ECLIPSE USING VECTOR GEOMENTRY
   % sun unit vector is defined as: 
   % s_hat = [cos(beta) , 0 , sin(beta)]

   %SPACECCRAFT POSIITON : 
   % r_vec = r * [cos(theta) , sin(theta) , 0 ]

   % Projection of spacecraft position onto sunvector:

   sunward_projection_m =  orbital_radius_m .* cos(orbital_angle_rad)  .* cos(beta_angle_rad);
   % Perpendiclar distance from Earth - sun shadow axis ;
   perpendicular_distance_m = sqrt(max(orbital_radius_m ^ 2 - sunward_projection_m .^ 2 , 0));

   % Eclipse requires :
   %  1 . Spacecraft behind earth
   % 2 . Spacecraft within cylindical shadow
   is_eclipse = (sunward_projection_m < 0) & (perpendicular_distance_m <= earth_radius_m);

   %% 11D .  CALUCLATE SAMPLED ECLIPSE DURATION
   % Every time-step interval uses the eclipse flag 
   % at its beginning
   eclipse_duration_sampled_min(i) = sum(is_eclipse(1:end-1)) * time_step_s / 60 / number_of_orbits;

   %% 11E . CREATE EOL SOLAR POWER PROFILE 
   solar_power_W = zeros(size(time_s));

   %Ideal sun pointing soalar array 
   %Fixed output during sunlight , zero in eclipse 
   solar_power_W(~is_eclipse) = solar_array_power_EOL_W;

   %% 11F . CREATE DYNAMIC SPACECRAFT LOAD PROFILE 
   load_profile_W = nominal_mode_load_W * ones(size(time_s)) ;
   operating_mode_code = 2 * ones(size(time_s));

   % Science mode : 0 to 20 minutes of each orbit 

   science_indices = (time_in_orbit_min >= 0) & (time_in_orbit_min < 20);
   load_profile_W(science_indices) = science_mode_load_W ;
   operating_mode_code(science_indices) = 3 ;

   % Communication mode : 75 to 82 minutes of each orbit 
   communications_indices = (time_in_orbit_min >= 75 ) & (time_in_orbit_min < 82) ;
   load_profile_W(communications_indices) = communication_mode_load_W ;
   operating_mode_code(communications_indices) = 4 ;

   % Safe mode overide all other modes during eclipse
   load_profile_W(is_eclipse) = safe_mode_load_W ;
   operating_mode_code(is_eclipse) = 1 ; 

   %% 11G . INITIALISE BATTERY ENERGY 
   battery_energy_Wh = zeros(size(time_s));
   battery_energy_Wh(1) = initial_battery_energy_Wh;
   total_unserved_load_Wh = 0 ;

   %% 11H . SIMULATE BATTERY CHARGING AND DISCHARGING
   for k = 1 : number_of_samples - 1 
       available_solar_power_W = solar_power_W(k);
       required_load_power_W = load_profile_W(k);

       if available_solar_power_W >= required_load_power_W 

% Sunlight : solar array supplies load
surplus_power_W = available_solar_power_W - required_load_power_W ;
surplus_energy_Wh = surplus_power_W * delta_time_h;
remaining_battery_space_Wh = battery_capacity_Wh - battery_energy_Wh(k);
stored_energy_Wh = min(surplus_energy_Wh * charging_efficiency , remaining_battery_space_Wh);

% Update battery energy 
battery_energy_Wh(k+1) = battery_energy_Wh(k) + stored_energy_Wh;
       else
           % Deficit : battery supplies the spacecraft load 
           deficit_power_W = required_load_power_W - available_solar_power_W ;
           required_energy_Wh = (deficit_power_W / discharging_efficiency) * delta_time_h;
           available_battery_energy_Wh = max(battery_energy_Wh(k) - minimum_battery_energy_Wh,0);
           actual_energy_drawn_Wh = min(required_energy_Wh ,available_battery_energy_Wh);
           delivered_energy_Wh = actual_energy_drawn_Wh * discharging_efficiency;
           demanded_energy_Wh = deficit_power_W * delta_time_h ;
           unserved_energy_Wh = max(demanded_energy_Wh - delivered_energy_Wh,0);
           total_unserved_load_Wh = total_unserved_load_Wh + unserved_energy_Wh ;

           % Update battery energy 
           battery_energy_Wh(k+1) = battery_energy_Wh(k) - actual_energy_drawn_Wh ;
       end
   end

   %% 11I . CALUCLATE BATTERY SOC
   battery_soc_percent = (battery_energy_Wh / battery_capacity_Wh) * 100 ;
   battery_soc_all_percent(i,:) = (battery_soc_percent);
   minimum_soc_all_percent(i) = min(battery_soc_percent) ;
   final_soc_all_percent(i) = battery_soc_percent(end);
   unserved_load_all_Wh(i) = total_unserved_load_Wh;

   %% 11J . SAVE THE BETA 30 DEGREE PROFILE FOR PLOTING
   if beta_angles_deg(i) == 30 
       solar_power_beta30_W = solar_power_W ;
       load_profile_beta30_W = load_profile_W ;
       power_margin_beta30_W = solar_power_W - load_profile_W ;
       battery_soc_beta30_percent = battery_soc_percent ;
       operating_mode_beta30 = operating_mode_code ;
       eclipse_beta30 = is_eclipse;
   end
end

%% 12 . DISPLAY RESULTS TABLE 
fprintf('\n---BETA ANGLE RESULTS---\n');
results_table = table(beta_angles_deg(:),eclipse_duration_analytical_min(:),eclipse_duration_sampled_min(:),sunlight_duration_analytical_min(:),minimum_soc_all_percent(:),final_soc_all_percent(:),unserved_load_all_Wh(:),'VariableNames',{'Beta_deg','Analytical_Eclipse_min','Sampled_Eclipse_min','Sunlight_min','Minimum_soc_percent','Final_soc_percent','Unserved_load_Wh'});
disp(results_table);

%% 13 . DISPLAY IMPORTANT RESULTS
fprintf('\n---SOLAR ARRAY---\n');
fprintf('EOL solar array efficiency   : %.2f %% \n',solar_array_efficiency_EOL * 100);
fprintf('EOL solar- array output   : %.2f W \n',solar_array_power_EOL_W);
fprintf('\n--- BETA ANGLE---\n');
fprintf('Critical beta angle   : %.2f degrees\n',critical_beta_deg);
fprintf('\n---BASELINE : BETA = 0 DEG ---\n');
fprintf('Eclipse duration   : %.2f minutes\n',eclipse_duration_analytical_min(1));
fprintf('minimum battery soc   : %.2f %% \n',minimum_soc_all_percent(1));
fprintf('\n---BETA = 30 DEG ---\n');
fprintf('Eclipse duration   : %.2f minutes\n',eclipse_duration_analytical_min(3));
fprintf('minimum battery soc   : %.2f %% \n',minimum_soc_all_percent(3));
fprintf('\n---BETA = 60 DEG ---\n');
fprintf('Eclipse duration   : %.2f minutes\n',eclipse_duration_analytical_min(5));
fprintf('minimum battery soc   : %.2f %% \n',minimum_soc_all_percent(5));
fprintf('\n====Day 8 caluclation SAMAPTAM====\n');


%% 14 . FIGURE 1 : ECLIPSE DURATION VERSUS BETA ANGLE
beta_curve_deg = 0:0.25:90;
eclipse_curve_min = zeros(size(beta_curve_deg));
for k = 1 : numel(beta_curve_deg) 
    if beta_curve_deg(k) < critical_beta_deg
        beta_curve_rad = deg2rad(beta_curve_deg(k));
        delta_rad = acos(sqrt(1 - (earth_radius_m / orbital_radius_m)^2) / cos(beta_curve_rad));
        eclipse_curve_min(k) = (orbital_period_s / pi) * delta_rad / 60;
    else
        eclipse_curve_min(k) = 0 ;
    end
end
figure('Name','Day 8 - Eclipse Duratio versusu beta angle');
plot(beta_curve_deg,eclipse_curve_min,'LineWidth',1.6);
hold on;
plot(beta_angles_deg,eclipse_duration_analytical_min,'o','LineWidth',1.2);
xline(critical_beta_deg,'--','CRITICAL BETA ANGLE');
xlabel('Absolute beta angle (degrees)');
ylabel('Eclipse duration (minutes)');
title('Effet oforbital beta angle on eclipse duration ');
grid on ;
xlim([0 90 ]);

%% 15 . FIGURE 2 : BATTERY SOC COMPARISION
figure('Name','Day 8 - Battery soc versus beta angle');
hold on;
for k = 1 :numel(beta_comparision_indices)
    selected_index = beta_comparision_indices(k);
    plot(time_min,battery_soc_all_percent(selected_index,:),'LineWidth',1.4);
end
yline(minimum_soc_percent,'--','minimum permitted soc');
xlabel('simulation time(minutes)');
ylabel('Battery soc(%)');
title('Battery soc at beta angles of 0 , 30 and 60 degrees');
legend('Beta = 0 degrees','Beta = 30 degrees','Beta = 60 degrees','Minimum permitted soc','Location','best');
ylim([0 105]);
grid on ;

%% 16 . FIGURE 3 : DETAILED BETA 30 DEGREE SIMULATION
figure('Name','Day 8 - Detailed beta 30 degree simulation');
subplot(4,1,1);
plot(time_min,solar_power_beta30_W,'LineWidth',1.3);
hold on;
plot(time_min,load_profile_beta30_W,'LineWidth',1.3);
xlabel('time(minutes)');
ylabel('Power(W)');
title('EOL Solar power and Dynamic load at beta = 30 degrees');
legend('solar power','Spacecraft load','Location','best');
grid on;
subplot(4,1,2);
plot(time_min,power_margin_beta30_W,'LineWidth',1.3);
hold on;
yline(0,'--','Zero power margin ');
xlabel('time(minutes)');
ylabel('power margin(W)');
ylabel('Power margin(W)');
title('Electrical power margin at beta = 30 degrees');
grid on ;
subplot(4,1,3);
plot(time_min,battery_soc_beta30_percent ,'LineWidth',1.3);
hold on;
yline(minimum_soc_percent,'--','minimum permitted soc');
yline(100,':','Maximum soc ');
xlabel('TIme(minutes)');
ylabel('Battery soc(%)');
title('Battery soc at beta = 30 degrees');
ylim([0 105]);
grid on;
subplot(4,1,4);
stairs(time_min,operating_mode_beta30,'LineWidth',1.3);
xlabel('Time(minutes)');
ylabel('operating mode');
title('Operational mode at beta = 30 degrees');
yticks([1 2 3 4]);
yticklabels({'safe','Nominal','Science','Comes'});
ylim([0.5 4.5]);
grid on;

%% 17 . SAVE RESULTS
scripts_folder = fileparts(mfilename('fullpath'));
project_folder = fileparts(scripts_folder);
results_folder = fullfile(project_folder,'results');
if ~exist(results_folder,'dir')
    mkdir(results_folder);
end

% save figure 1
figure(1);
saveas(gcf,fullfile(results_folder,'day8_eclipse_vs_beta.png'));
%save figure 2 
figure(2);
saveas(gcf,fullfile(results_folder,'day8_battery_soc_comparision.png'));
% save figure 3 
figure(3);
saveas(gcf,fullfile(results_folder,'day8_beta30_detailed_simulation.png'));
% save figure 3 
figure(3);
saveas(gcf,fullfile(results_folder,'day8_beta30_detailed_simulation.png'));

% save all numerical results
save(fullfile(results_folder,'day8_beta_angle_results.mat'),'beta_angles_deg','critical_beta_deg','eclipse_duration_analytical_min','eclipse_duration_sampled_min','sunlight_duration_analytical_min','minimum_soc_all_percent','final_soc_all_percent','unserved_load_all_Wh','battery_soc_all_percent','results_table','time_s','time_min','battery_soc_beta30_percent','solar_power_beta30_W','load_profile_beta30_W','power_margin_beta30_W','operating_mode_beta30','eclipse_beta30');
fprintf('\n Day 8 figures and numerical date saved successfully .\n');
