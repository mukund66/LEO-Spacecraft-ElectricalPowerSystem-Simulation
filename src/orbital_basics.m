%day1 :LEO orbital mechanics
%project:LEO SPACCRAFT ORBITAL POWER SYSTEMS SIMULATOR
%MODEL:circular 400 km low earth orbit
clc;
clear;
close all;

%% 1 . DEFINE CONSTRAINTS
earth_radius_m = 6371e3;
altitude_m = 400e3;
earth_mu_m3_s2 = 3.986004418e14;

%% 2. CALUCLATE ORBITAL RADIUS
orbital_radius_m = earth_radius_m + altitude_m;

%% 3. CALUCLATE ORBITAL PERIOD
orbital_period_s = 2*pi*sqrt(orbital_radius_m^3/earth_mu_m3_s2);
orbital_period_min = orbital_period_s / 60 ;

%% 4. CALUCLATE ORBITAL VELOCITY
orbital_speed_mps = sqrt(earth_mu_m3_s2/orbital_radius_m);
orbital_speed_kmps = orbital_speed_mps/1000;

%% 5 . CALUCLATE ANGULAR VELOCITY
angular_veloctiy_radps = sqrt(earth_mu_m3_s2/orbital_radius_m^3);

%% 6 . DISPLAY RESULTS
fprintf('\n =====LEO ORBITAL MODEL =====\n');
fprintf('orbital altitude  : %.2f km\n',altitude_m/1000);
fprintf('orbit radius      : %.2f km\n',orbital_radius_m/1000);
fprintf('orbital period    : %.2f s (%.2f min) \n',orbital_period_s,orbital_period_min);
fprintf('obital velocity   : %.3f kmps \n',orbital_speed_kmps);
fprintf('angular velocity  : %.8f rads \n',angular_veloctiy_radps);
fprintf('\n====day1samaptAM=====\n tadastu');


