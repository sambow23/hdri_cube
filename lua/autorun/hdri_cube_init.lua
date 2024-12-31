print("[HDRI Cube] Loading properties...") 
include("properties/hdri_cube_editor.lua")

if SERVER then
    util.AddNetworkString("HDRICube_OpenEditor")
    util.AddNetworkString("HDRICube_UpdateTexture")
end

-- Create materials directory if it doesn't exist
if not file.Exists("materials/hdri_cube", "GAME") then
    file.CreateDir("materials/hdri_cube")
end